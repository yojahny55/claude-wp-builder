#!/usr/bin/env bash
# /wp-audit, /wp-debug and /wp-clone stopped at "not created by /wp-create" on every site this
# plugin did not build -- a client site on a commercial theme could not be audited at all.
# `wp-config.mjs adopt` registers such a site read-only. This drives it against a fake `wp`
# on PATH and asserts what it writes, what it refuses, and that the fix phase and the agents
# honour the read-only code scope and the site's own plugin stack.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
cfg="node $PWD/bin/wp-config.mjs"

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/site/wp-content/themes/shop-child" "$tmp/site/wp-content/themes/shop"
touch "$tmp/site/wp-load.php" "$tmp/site/wp-config.php"
cat >"$tmp/site/wp-content/themes/shop-child/functions.php" <<'PHP'
<?php
function shop_child_enqueue() {}
function shop_child_fonts() {}
function shop_child_footer() {}
function custom_heading() {}
PHP

# The probe's answer. `shop` is a commercial parent known to an updater, `hello` inactive,
# `acme-gateway` the site's own plugin, Yoast owns SEO and Wordfence owns security.
cat >"$tmp/probe.json" <<'JSON'
{"home":"https://shop.test","blogname":"Shop","locale":"es_ES","pll_default":null,"pll_languages":[],
 "multisite":false,"php":"8.2.10","wp":"6.8","stylesheet":"shop-child","template":"shop",
 "theme_path":"wp-content/themes/shop-child","parent_path":"wp-content/themes/shop",
 "theme_known_to_updater":false,"parent_known_to_updater":true,
 "plugins":[
  {"file":"wordpress-seo/wp-seo.php","slug":"wordpress-seo","name":"Yoast","update_uri":"","active":true,"known_to_updater":true,"path":"wp-content/plugins/wordpress-seo"},
  {"file":"wordfence/wordfence.php","slug":"wordfence","name":"Wordfence","update_uri":"","active":true,"known_to_updater":true,"path":"wp-content/plugins/wordfence"},
  {"file":"elementor/elementor.php","slug":"elementor","name":"Elementor","update_uri":"","active":true,"known_to_updater":true,"path":"wp-content/plugins/elementor"},
  {"file":"acme-gateway/acme-gateway.php","slug":"acme-gateway","name":"Acme","update_uri":"","active":true,"known_to_updater":false,"path":"wp-content/plugins/acme-gateway"},
  {"file":"hello/hello.php","slug":"hello","name":"Hello","update_uri":"","active":false,"known_to_updater":false,"path":"wp-content/plugins/hello"}
 ],"mu_plugins":[],"mu_path":"wp-content/mu-plugins"}
JSON
cat >"$tmp/bin/wp" <<SH
#!/usr/bin/env bash
# Every call is logged: adopt may only ever run \`eval\`, never a write.
sub=none; for a in "\$@"; do case "\$a" in --*) ;; *) sub=\$a; break;; esac; done; echo "\$sub" >>"$tmp/wp.log"
[ "\${FAKE_WP_FAIL:-}" = 1 ] && { echo "Error: Error establishing a database connection" >&2; exit 1; }
[ "\${FAKE_WP_MULTISITE:-}" = 1 ] && { sed 's/"multisite":false/"multisite":true/' "$tmp/probe.json" | tr -d '\n'; echo; exit 0; }
echo "PHP Notice: something noisy on boot"
tr -d '\n' <"$tmp/probe.json"; echo
SH
chmod +x "$tmp/bin/wp"
export PATH="$tmp/bin:$PATH"

# --- Dry run writes nothing and proposes the split -----------------------------
out=$($cfg adopt "$tmp/site" --dry-run) || fail "dry run exited non-zero"
[ ! -e "$tmp/site/.wp-create.json" ] || fail "dry run wrote a manifest"
[ ! -e "$tmp/site/.claude/CLAUDE.md" ] || fail "dry run wrote CLAUDE.md"
j() { node -e "const j=JSON.parse(require('fs').readFileSync(0,'utf8'));console.log(JSON.stringify($1))" <<<"$out"; }
[ "$(j 'j.manifest.code_scope.editable')" = '["wp-content/themes/shop-child","wp-content/plugins/acme-gateway"]' ] \
  || fail "editable scope wrong: $(j 'j.manifest.code_scope.editable')"
j 'j.manifest.code_scope.read_only' | grep -Fq '"wp-content/themes/shop"' || fail "parent theme not read-only"
j 'j.manifest.code_scope.read_only' | grep -Fq 'wordpress-seo' || fail "updater-known plugin not read-only"
j 'j.manifest.code_scope' | grep -Fq 'hello' && fail "an inactive plugin entered the code scope"
[ "$(j 'j.manifest.stack.seo')" = '"yoast"' ] || fail "SEO stack not detected as yoast"
[ "$(j 'j.manifest.stack.security')" = '"wordfence"' ] || fail "security stack not detected as wordfence"
[ "$(j 'j.manifest.stack.builder')" = '"elementor"' ] || fail "builder not detected"
[ "$(j 'j.manifest.project.prefix')" = '"shop_child_"' ] \
  || fail "prefix should be the child's shop_child_, not the vendor's shop_: $(j 'j.manifest.project.prefix')"
[ "$(j "j.manifest['i18n strategy']")" = '"none"' ] || fail "monolingual adopted site should record i18n strategy none"
[ "$(j 'j.manifest.languages.primary')" = '"es"' ] || fail "primary language not taken from the locale"
[ "$(j 'j.problems')" = '[]' ] || fail "the proposal does not validate: $(j 'j.problems')"
# An empty value is an empty list for both flags; a bare flag keeps the proposal.
ro=$($cfg adopt "$tmp/site" --dry-run --read-only= | node -e "console.log(JSON.stringify(JSON.parse(require('fs').readFileSync(0,'utf8')).manifest.code_scope.read_only))")
[ "$ro" = '[]' ] || fail "--read-only= did not give an empty list: $ro"
ed=$($cfg adopt "$tmp/site" --dry-run --editable | node -e "console.log(JSON.parse(require('fs').readFileSync(0,'utf8')).manifest.code_scope.editable.length)")
[ "$ed" = 2 ] || fail "a bare --editable dropped the proposal"
grep -vx 'eval' "$tmp/wp.log" && fail "adopt ran a WP-CLI command other than eval"

# --- Real run: operator moved nothing; writes both files, validates ------------
mkdir -p "$tmp/site/.claude"
printf '# Operator notes\n\nKeep this line.\n' >"$tmp/site/.claude/CLAUDE.md"
$cfg adopt "$tmp/site" --prefix=shop_child_ --industry=retail >/dev/null || fail "adopt exited non-zero"
$cfg validate "$tmp/site" >/dev/null || fail "adopted manifest does not validate"
grep -Fq 'Keep this line.' "$tmp/site/.claude/CLAUDE.md" || fail "adopt destroyed operator text in CLAUDE.md"
for row in '- **Origin:** adopted' '- **Function prefix:** shop_child_' '- **Industry:** retail' \
           '- **Read-only code:** `wp-content/themes/shop`' 'seo=yoast, security=wordfence'; do
  grep -Fq -- "$row" "$tmp/site/.claude/CLAUDE.md" || fail "generated block lacks: $row"
done

# --- Refusals -------------------------------------------------------------------
$cfg adopt "$tmp/site" >/dev/null 2>&1 && fail "adopt overwrote an existing manifest"
mkdir -p "$tmp/empty"
$cfg adopt "$tmp/empty" >/dev/null 2>&1 && fail "adopt accepted a directory with no WordPress"
cp -r "$tmp/site" "$tmp/site2"; rm "$tmp/site2/.wp-create.json"
FAKE_WP_MULTISITE=1 $cfg adopt "$tmp/site2" >/dev/null 2>&1 && fail "adopt accepted a multisite"
FAKE_WP_FAIL=1 $cfg adopt "$tmp/site2" >/dev/null 2>&1 && fail "adopt succeeded on a failed probe"
[ ! -e "$tmp/site2/.wp-create.json" ] || fail "a refused adoption wrote a manifest"
$cfg adopt "$tmp/site2" --editable=../outside >/dev/null 2>&1 && fail "adopt accepted a path that climbs out of the root"
[ ! -e "$tmp/site2/.wp-create.json" ] || fail "an invalid adoption wrote a manifest"

# --- A created project's block is unchanged by the adopted rows -----------------
node -e "
import('$PWD/bin/lib/manifest.mjs').then((m) => {
  const man = JSON.parse(require('fs').readFileSync('tests/fixtures/manifests/valid/.wp-create.json', 'utf8'));
  const b = m.renderContext(man);
  if (/Origin|Function prefix|Editable code|Stack/.test(b)) { console.error('adopted rows leaked into a created block'); process.exit(1); }
  if (m.validateManifest({ ...man, 'i18n strategy': 'none' }).length === 0) { console.error('none accepted on a created project'); process.exit(1); }
  const md = '- **Function prefix:** kairo_\n';
  if (m.supersedeProseDecisions(md, man) !== md) { console.error('a created project lost its prose prefix line'); process.exit(1); }
});" || fail "adopted rows changed created-project behaviour"

# --- Probe semantics the fake `wp` cannot exercise ---------------------------------
# core fills `checked` with every installed theme and plugin before any updater answers, so
# reading it made a bespoke theme on any site that ever ran its update cron read-only.
node -e "
import('$PWD/bin/lib/adopt.mjs').then(({ PROBE_PHP, buildManifest }) => {
  if (/'checked'/.test(PROBE_PHP)) { console.error('the probe reads update_*->checked'); process.exit(1); }
  const base = JSON.parse(require('fs').readFileSync('$tmp/probe.json', 'utf8'));
  const { manifest: m } = buildManifest('$tmp/site', { ...base, pll_default: 'en-us', pll_languages: ['en-us', 'pt-br', 'es'] },
    { wrapper: 'wp', engine: 'native', type: 'native' });
  const got = JSON.stringify([m.languages.primary, m.languages.additional]);
  if (got !== JSON.stringify(['en', ['pt', 'es']])) { console.error('languages wrong: ' + got); process.exit(1); }
});" || fail "probe semantics"

# --- The prose honours it --------------------------------------------------------
grep -Fq 'Step 2.2: Adopted sites' commands/wp-audit.md || fail "wp-audit has no adopted-site step"
grep -Fq 'forbid writes under `code_scope.read_only`' commands/wp-audit.md || fail "wp-audit fix phase does not guard read-only code"
grep -Fq 'dispatch `wp-audit-rankmath` only when `stack.seo` is `rankmath`' commands/wp-audit.md \
  || fail "wp-audit would dispatch Rank Math onto another SEO plugin"
grep -Fq 'do not list `seo-by-rank-math`' commands/wp-audit.md || fail "wp-audit Step 4 still offers Rank Math beside another SEO plugin"
for c in wp-audit wp-debug wp-clone; do
  grep -Fq '${CLAUDE_PLUGIN_ROOT}/commands/wp-adopt.md' "commands/$c.md" || fail "$c does not offer adoption"
  # A literal install path resolves only on the machine it was typed on.
  # Strip the correct references, then any path left ending in /commands/wp-adopt.md is literal.
  sed 's#${CLAUDE_PLUGIN_ROOT}/commands/wp-adopt\.md##g' "commands/$c.md" | grep -Eq '/commands/wp-adopt\.md' \
    && fail "$c points at wp-adopt.md through a literal path"
done
for a in security seo a11y performance practices geo ux; do
  grep -Fq 'Read-only code is reported, never fixed.' "agents/wp-audit-$a.md" || fail "wp-audit-$a ignores the read-only scope"
done
for a in rankmath aios; do
  grep -Fq 'Adopted sites: check the stack before installing anything' "agents/wp-audit-$a.md" \
    || fail "wp-audit-$a installs without checking the site's stack"
done
grep -Fq 'never changes the site' commands/wp-adopt.md || fail "wp-adopt does not state it is read-only"

echo PASS
