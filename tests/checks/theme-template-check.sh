#!/usr/bin/env bash
# bin/theme-template-check.mjs is the gate for three defects that shipped silently:
#  - sixteen inc/seed/*.php files without the ABSPATH guard the agents already required;
#  - `group-aria-[expanded=&quot;false&quot;]:rotate-90` in a template: an HTML entity in
#    an arbitrary variant, so Tailwind emitted nothing and the icon never rotated;
#  - role="tab" markup whose script only moved the marker and never switched a panel.
# This runs the script against a fixture theme and mutations of it, and asserts what it
# decided, then asserts /wp-finalize and the practices audit actually run it.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
command -v node >/dev/null || { echo "SKIP: node not installed"; exit 0; }

bin=bin/theme-template-check.mjs
fx=tests/fixtures/theme-template-check
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fresh() { rm -rf "$tmp/t"; cp -R "$fx" "$tmp/t"; }
expect_pass() { node "$bin" "$tmp/t" > "$tmp/out" 2>&1 || { cat "$tmp/out"; fail "expected PASS: $1"; }; }
expect_fail() {
  if node "$bin" "$tmp/t" > "$tmp/out" 2>&1; then cat "$tmp/out"; fail "expected FAIL: $1"; fi
  grep -Fq -- "$2" "$tmp/out" || { cat "$tmp/out"; fail "FAIL did not name: $2 ($1)"; }
}
# A sed that matches nothing exits 0 and would leave the case testing the clean fixture:
# every mutation is followed by a check that its text is really there.
applied() { grep -Fq -- "$2" "$1" || fail "mutation did not apply: $2 in $1"; }

fresh; expect_pass "the clean fixture"
grep -Fq 'runtime-built token(s) could not be verified' "$tmp/out" \
  || fail "a runtime-built class is not reported as unverifiable"

# (a) an HTML entity inside a class token fails, whatever the CSS holds.
fresh
sed -i 's/group-aria-\[expanded=false\]/group-aria-[expanded=\&quot;false\&quot;]/' "$tmp/t/index.php"
applied "$tmp/t/index.php" 'group-aria-[expanded=&quot;false&quot;]'
expect_fail "entity in an arbitrary variant" 'HTML entity inside class token'

# (b) a utility-shaped token the compiled CSS never emitted fails.
fresh; sed -i 's/class="flex mt-4/class="flex mt-[31px]/' "$tmp/t/index.php"
applied "$tmp/t/index.php" 'class="flex mt-[31px]'
expect_fail "arbitrary value missing from dist" '"mt-[31px]" looks like a Tailwind utility'
fresh; sed -i 's/class="flex mt-4/class="flex hover:mt-4/' "$tmp/t/index.php"
applied "$tmp/t/index.php" 'class="flex hover:mt-4'
expect_fail "variant missing from dist" '"hover:mt-4"'
fresh; sed -i 's/bg-brand/bg-brandx text-primary/' "$tmp/t/index.php"
applied "$tmp/t/index.php" 'bg-brandx text-primary'
echo '@theme { --color-primary: #000; }' >> "$tmp/t/assets/css/src/tailwindcss/main.css"
expect_fail "theme-colour utility missing from dist" '"text-primary"'
# A value that is no token (`brandx`) reads like a component class (`text-block`): by
# design it is not utility-shaped, so the typo is a known blind spot, not a finding.
if grep -Fq '"bg-brandx"' "$tmp/out"; then cat "$tmp/out"; fail "bg-brandx was read as a utility"; fi

# Noise stays out: BEM, js-* hooks, plain words, partly-dynamic tokens.
fresh
sed -i 's/card__title js-toggle text-block/card__title card--featured js-open-menu text-block menu-item/' "$tmp/t/index.php"
applied "$tmp/t/index.php" 'card--featured js-open-menu text-block menu-item'
# The fixture ends inside PHP, so close it before appending markup.
printf '?>\n<div class="card--<?php echo esc_attr( $mod ); ?>"></div>\n' >> "$tmp/t/index.php"
expect_pass "non-utility and dynamic tokens"
grep -Fq 'CANNOT VERIFY' "$tmp/out" || fail "a partly runtime-built token is not named as CANNOT VERIFY"

# abspath: a missing guard and the unquoted (PHP 8 fatal) form both fail.
fresh; printf '<?php\nreturn array();\n' > "$tmp/t/inc/seed/data.php"
expect_fail "seed without a guard" "inc/seed/data.php: no defined( 'ABSPATH' ) guard"
fresh; sed -i "s/defined( 'ABSPATH' ) || exit;/defined( ABSPATH ) || exit;/" "$tmp/t/inc/seed/items.php"
applied "$tmp/t/inc/seed/items.php" 'defined( ABSPATH ) || exit;'
expect_fail "unquoted ABSPATH" 'unquoted defined( ABSPATH )'
fresh; printf '<?php return array();\n' > "$tmp/t/assets/js/src/index.asset.php"
expect_pass "a generated *.asset.php is not a template"

# widgets: tab/accordion markup needs its module imported.
fresh; printf '?>\n<button role="tab">A</button>\n' >> "$tmp/t/index.php"
expect_fail "tabs without tabs.js" 'does not import ./tabs.js'
echo "import './tabs.js';" >> "$tmp/t/assets/js/src/index.js"
echo 'export {};' > "$tmp/t/assets/js/src/tabs.js"
expect_pass "tabs with tabs.js"
fresh; printf '?>\n<button data-accordion-trigger aria-expanded="true">Q</button>\n' >> "$tmp/t/index.php"
expect_fail "accordion without accordion.js" 'does not import ./accordion.js'
fresh; printf '?>\n<div data-directory><ul><li data-filter-item>A</li></ul></div>\n' >> "$tmp/t/index.php"
expect_fail "directory filter without directory-filter.js" 'does not import ./directory-filter.js'

# Comments are not code: a docblock naming the unquoted form, a commented-out class or
# tab, in PHP (`//`, `#`, `/* */`) or HTML (`<!-- -->`), fails nothing.
fresh; sed -i 's/ \* Fixture seed\./ * Fixture seed. Never write defined( ABSPATH ) unquoted./' "$tmp/t/inc/seed/items.php"
applied "$tmp/t/inc/seed/items.php" 'Never write defined( ABSPATH ) unquoted.'
expect_pass "unquoted ABSPATH inside a docblock"
fresh; cat "$fx/comments.php.txt" >> "$tmp/t/index.php"
expect_pass "classes and a tab inside PHP and HTML comments"
# ...while markup in a PHP string, even next to a URL or a trailing comment, is still read.
fresh; printf "\$u = 'https://example.test/#a'; echo '<div class=\"mt-[31px]\">'; // note\n" >> "$tmp/t/index.php"
expect_fail "class in a PHP string beside a URL and a comment" '"mt-[31px]"'
fresh; printf "?>\n<!-- note --><button role=\"tab\">A</button>\n" >> "$tmp/t/index.php"
expect_fail "tab markup after an HTML comment" 'does not import ./tabs.js'

# Only selectors define classes: `.mt-7` inside a declaration value does not.
fresh; sed -i 's/class="flex mt-4/class="flex mt-7/' "$tmp/t/index.php"
applied "$tmp/t/index.php" 'class="flex mt-7'
echo '.x{content:".mt-7";opacity:0.5}' >> "$tmp/t/assets/css/dist/main.css"
expect_fail "a class named only in a declaration" '"mt-7"'

# Families outside the spacing/colour prefixes are checked; their component look-alikes are not.
fresh; sed -i 's/class="flex mt-4/class="flex pointer-events-non select-none table-cell select-wrapper table-responsive/' "$tmp/t/index.php"
applied "$tmp/t/index.php" 'pointer-events-non select-none table-cell select-wrapper table-responsive'
expect_fail "pointer-events typo" '"pointer-events-non"'
grep -Fq '"select-none"' "$tmp/out" || { cat "$tmp/out"; fail "select-none missing from dist is not reported"; }
grep -Fq '"table-cell"' "$tmp/out" || { cat "$tmp/out"; fail "table-cell missing from dist is not reported"; }
if grep -Eq '"(select-wrapper|table-responsive)"' "$tmp/out"; then cat "$tmp/out"; fail "a component class was read as a utility"; fi

# No compiled CSS: the class rule skips instead of failing a theme that is not built.
fresh; rm -rf "$tmp/t/assets/css/dist"; expect_pass "no dist"
grep -Fq 'SKIP classes' "$tmp/out" || fail "a theme without dist/ does not report the class rule as skipped"

# Bad arguments are a usage error (exit 2) that says what is wrong, never a silent run.
usage_err() {
  local rc=0
  node "$bin" "$@" > "$tmp/out" 2>&1 || rc=$?
  [ "$rc" = 2 ] || { cat "$tmp/out"; fail "exit $rc, not 2, for: $*"; }
  grep -Fq -- "$USAGE_WHY" "$tmp/out" || { cat "$tmp/out"; fail "usage error did not say: $USAGE_WHY"; }
}
USAGE_WHY='--rule needs a value' usage_err "$fx" --rule
USAGE_WHY='unknown rule: bogus' usage_err "$fx" --rule bogus
USAGE_WHY='unknown option: --rules' usage_err --rules abspath "$fx"
USAGE_WHY='missing theme dir' usage_err --rule abspath
USAGE_WHY='not a directory' usage_err "$tmp/nope"
USAGE_WHY='more than one theme dir' usage_err "$fx" "$fx"
node "$bin" --rule abspath "$fx" > "$tmp/out" 2>&1 || { cat "$tmp/out"; fail "--rule before the theme dir is not accepted"; }

# Both starters must pass their own gate.
for st in starter-theme/__tailwind__ starter-theme/__cinematic__; do
  node "$bin" "$st" > "$tmp/out" 2>&1 || { cat "$tmp/out"; fail "$st fails theme-template-check"; }
done

# Wired where a delivery and an audit actually run it.
grep -Fq 'bin/theme-template-check.mjs' commands/wp-finalize.md || fail "/wp-finalize does not run theme-template-check"
grep -Fq 'bin/theme-template-check.mjs' agents/wp-audit-practices.md || fail "wp-audit-practices does not run theme-template-check"

echo PASS
