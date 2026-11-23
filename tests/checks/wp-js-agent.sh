#!/usr/bin/env bash
# /wp-section had no JavaScript step: a single-section build rendered a carousel that did
# nothing. agents/wp-js.md ports a section's script, and /wp-section Step 6.4 dispatches it.
# This pins the contract that keeps the port safe on a WordPress page: no-op without its
# markup, data- hooks rather than the CSS's classes, guarded lookups, no second copy of a
# module the theme has, no CDN and no npm install, the bundle rebuilt.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/lib/assert.sh

agent=agents/wp-js.md
cmd=commands/wp-section.md
[ -f "$agent" ] || fail "$agent is missing"

grep >/dev/null -c '^name: wp-js$' "$agent" || fail "$agent has no name: wp-js"
grep >/dev/null -c '^model: sonnet$' "$agent" || fail "$agent is not on sonnet"
grep >/dev/null -c '^tools: Read, Write, Edit, Grep, Glob, Bash$' "$agent" || fail "$agent tools are not in the house order"
need_token "$agent" '## First Action (MANDATORY)'
need_token "$agent" 'BLOCKED: <reason>'
need_token "$agent" 'assets/js/src/sections/<slug>.js'
need_token "$agent" '**No-op without its markup.**'
need_token "$agent" '**Hooks are `data-` attributes**'
need_token "$agent" '**Guard every lookup.**'
need_token "$agent" '**Never write a second implementation of a behaviour the theme'
need_token "$agent" 'do not add a CDN `<script>` and do not run `npm install`'
need_token "$agent" 'npm run buildwp'
need_token "$agent" 'prefers-reduced-motion'
need_token "$agent" '`<PREFIX>_data`'
need_token "$agent" '**Check the libraries now,'
need_token "$agent" 'undo the whole port before returning:'
need_token "$agent" 'remove the `data-` hooks you added to the template'
need_token "$agent" 'is never ported or copied: it is a dependency'
need_token "$agent" '**The CSS sees the state.**'
need_token "$agent" '"CSS needed: <selector> for <state>"'
need_token "$agent" '**Port this section only.**'
need_token "$agent" 'is not a theme dependency; add it with npm install'

need_token "$cmd" '## Step 6.4: Behaviour (`wp-js`)'
need_token "$cmd" 'Skip this step under `--transcribe`'
need_token "$cmd" 'under `--hybrid`, and on a'
need_token "$cmd" 'search scripts only:'
need_token "$cmd" '--exclude=*.min.js --exclude-dir=vendor'
need_token "$cmd" 'bin/demo-scripts.mjs" "$2" --match "$3"'
grep >/dev/null -c "sed -n '/<script" "$cmd" && fail "$cmd still extracts scripts by line range (prints markup after a one-line <script src>)"
need_token commands/wp-yolo.md '`wp-tailwind`, `wp-js`,'
need_token "$cmd" 'dispatch **wp-js**'
need_token "$cmd" 'Behaviour: assets/js/src/sections/<slug>.js (wp-js)'
need_token README.md '| `wp-js` |'
need_token BACKLOG.md 'tests/checks/wp-js-agent.sh'

# What the agent relies on in the starter it targets.
starter="starter-theme/__tailwind__"
need_token "$starter/assets/js/src/index.js" 'const startWidgets'
need_token "$starter/package.json" '"buildwp"'
need_token "$starter/functions.php" "wp_localize_script( '__starter__-main', '__STARTER___data'"
# bin/demo-scripts.mjs, run for real: a one-line <script src> before the inline script,
# JSON-LD naming the class, a commented-out script, and markup naming the class.
tool=${DEMO_SCRIPTS:-bin/demo-scripts.mjs}
require_tool node
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cat >"$tmp/page.html" <<'HTML'
<!doctype html><html><head>
<script src="vendor/swiper.min.js"></script>
<script type="application/ld+json">{"name":"hero-carousel"}</script>
</head><body>
<!-- SECTION: Hero -->
<section class="hero-carousel"><div class="hero-carousel__track"></div></section>
<!-- <script>document.querySelector('.hero-carousel').remove()</script> -->
<script>
document.querySelectorAll('.hero-carousel').forEach(function (el) { el.dataset.ok = '1'; });
</script>
<script type="module">import './app.js';</script>
</body></html>
HTML
out=$(node "$tool" "$tmp/page.html" --match 'hero-carousel') || fail "demo-scripts found no inline script naming hero-carousel"
printf '%s\n' "$out" | grep >/dev/null -c "querySelectorAll('.hero-carousel')" || fail "demo-scripts did not print the inline script body"
printf '%s\n' "$out" | grep >/dev/null -c '<section' && fail "demo-scripts printed markup: $out"
printf '%s\n' "$out" | grep >/dev/null -c 'ld+json\|"name"' && fail "demo-scripts printed JSON-LD: $out"
printf '%s\n' "$out" | grep >/dev/null -c 'remove()' && fail "demo-scripts printed a commented-out script: $out"
printf '%s\n' "$out" | grep >/dev/null -c '^// inline script 1, line 8$' || fail "demo-scripts header or line number is wrong: $out"
[ "$(node "$tool" "$tmp/page.html" | grep -c '^// inline script')" = 2 ] || fail "demo-scripts without --match must print both inline scripts"
rc=0; node "$tool" "$tmp/page.html" --match 'no-such-class' >/dev/null || rc=$?
[ "$rc" = 1 ] || fail "demo-scripts must exit 1 when nothing matches (got $rc)"
rc=0; node "$tool" "$tmp/missing.html" >/dev/null 2>&1 || rc=$?
[ "$rc" = 2 ] || fail "demo-scripts must exit 2 on an unreadable page (got $rc)"
rc=0; node "$tool" >/dev/null 2>&1 || rc=$?
[ "$rc" = 64 ] || fail "demo-scripts must exit 64 without a page (got $rc)"

echo "PASS: wp-js ports a section's script under a guarded, no-op-without-markup contract, and /wp-section dispatches it"
