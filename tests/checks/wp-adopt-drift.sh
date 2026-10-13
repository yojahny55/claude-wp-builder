#!/usr/bin/env bash
# A blank scaffold restored over by a real site validates and describes the wrong site; adopt
# refused to replace it; a plugin echoing on boot broke the probe; a temp helper wrapper was
# persisted into the manifest. Drives wp-config.mjs against a fake `wp` and bin/wp-quiet.sh.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
cfg="node $PWD/bin/wp-config.mjs"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/site/wp-content/themes/real-child"
touch "$tmp/site/wp-load.php" "$tmp/site/wp-config.php"

probe='{"home":"https://x.test","blogname":"X","locale":"en_US","pll_default":null,"pll_languages":[],"multisite":false,"php":"8.2.1","wp":"6.8","stylesheet":"real-child","template":"real","theme_path":"wp-content/themes/real-child","parent_path":null,"theme_known_to_updater":false,"parent_known_to_updater":null,"plugins":[{"file":"a/a.php","slug":"a","name":"A","update_uri":"","active":true,"known_to_updater":false,"path":"wp-content/plugins/a"}],"mu_plugins":[],"mu_path":"wp-content/mu-plugins"}'
printf '%s' "$probe" >"$tmp/probe.json"
# Noise before AND after the JSON, multi-line, with a stray brace line last.
cat >"$tmp/bin/wp" <<SH
#!/usr/bin/env bash
echo "PHP Deprecated:  noisy in /p.php on line 1"
printf '<<WPCB-PROBE>>'; cat "$tmp/probe.json"; printf '<<END-WPCB-PROBE>>\\n'
printf 'logger shutdown\n  {not json}\n'
SH
chmod +x "$tmp/bin/wp"; export PATH="$tmp/bin:$PATH"

# 1. Sentinels: noise on both sides of the JSON no longer breaks the probe.
out=$($cfg adopt "$tmp/site" --dry-run) || fail "probe broke on boot noise"
echo "$out" | grep -Fq '"real-child"' || fail "probe JSON not parsed from between sentinels"

# 2. A stale blank-scaffold manifest validates but drifts.
cat >"$tmp/site/.wp-create.json" <<'JSON'
{"manifest_version":3,"project":{"source":"blank","name":"x"},"theme":{"slug":"ghost","initialized":false},"plugins":{"installed":[]},"wp_cli":{"wrapper":"wp"}}
JSON
set +e; d=$($cfg drift "$tmp/site"); rc=$?; set -e
[ "$rc" = 4 ] || fail "drift exit was $rc, expected 4"
echo "$d" | grep -Fq 'ghost' || fail "drift did not name the missing theme"
echo "$d" | grep -Fq 'not in plugins.installed' || fail "drift did not name the plugin gap"

# 3. adopt refuses without --replace, and names the way out.
set +e; $cfg adopt "$tmp/site" 2>"$tmp/err"; rc=$?; set -e
[ "$rc" = 1 ] || fail "adopt over an existing manifest should exit 1"
grep -Fq -- '--replace' "$tmp/err" || fail "refusal does not mention --replace"

# 4. --replace backs up, then writes the real site.
$cfg adopt "$tmp/site" --replace >/dev/null || fail "adopt --replace failed"
ls "$tmp/site"/.wp-create.json.bak-* >/dev/null 2>&1 || fail "no backup kept"
grep -Fq '"real-child"' "$tmp/site/.wp-create.json" || fail "manifest not rewritten"
$cfg drift "$tmp/site" >/dev/null || fail "fresh adoption still drifts"

# 5. A temp-dir helper wrapper is used for the probe and not persisted.
printf '#!/usr/bin/env bash\nexec wp "$@"\n' >"$tmp/h.sh"; chmod +x "$tmp/h.sh"
cp "$tmp/h.sh" /tmp/wpcb-helper-$$.sh
$cfg adopt "$tmp/site" --replace --wrapper="/tmp/wpcb-helper-$$.sh" >/dev/null 2>&1 || { rm -f /tmp/wpcb-helper-$$.sh; fail "adopt with helper wrapper failed"; }
rm -f /tmp/wpcb-helper-$$.sh
grep -Fq 'wpcb-helper' "$tmp/site/.wp-create.json" && fail "temp helper wrapper was persisted"

# 5b. --replace over a REAL adoption keeps audit, store, decisions; over a scaffold it does not.
site="$tmp/site"
mkdir -p "$site/wp-content/plugins/mine" "$site/wp-content/plugins/vendor"
node -e "
const fs=require('fs');const f=process.argv[1]+'/.wp-create.json';const m=JSON.parse(fs.readFileSync(f));
m.audit={last_run:'2026-01-01',issues_found:3};m.store={tier:'catalog',address:{street:'1 Main',city:'Town',postcode:'1000',country:'US'},enquiry:['form'],currency:'USD',units:{weight:'kg',dimension:'cm'}};
m.project.prefix='keep_';m.project.industry='construction';m.project.adopted='2026-01-01';
m.code_scope={editable:['wp-content/plugins/mine','wp-content/gone'],read_only:['wp-content/themes/real-child','wp-content/plugins/a']};
fs.writeFileSync(f,JSON.stringify(m));" "$site"
d=$($cfg adopt "$site" --replace --dry-run) || fail "dry-run replace failed"
echo "$d" | grep -Fq '"carried_over"' || fail "dry-run does not report carried_over"
$cfg adopt "$site" --replace >/dev/null || fail "replace over a real adoption failed"
node -e "
const m=JSON.parse(require('fs').readFileSync(process.argv[1]+'/.wp-create.json'));
const bad=(w)=>{console.error('FAIL: '+w);process.exit(1)};
if(m.audit?.issues_found!==3)bad('audit block lost');
if(m.store?.tier!=='catalog')bad('store block lost');
if(m.project.prefix!=='keep_'||m.project.industry!=='construction')bad('prefix/industry lost');
if(m.project.adopted!=='2026-01-01')bad('adopted date lost');
if(!m.code_scope.read_only.includes('wp-content/themes/real-child'))bad('read-only decision reverted to editable');
if(m.code_scope.editable.includes('wp-content/themes/real-child'))bad('theme came back editable');
if(m.code_scope.editable.includes('wp-content/gone'))bad('a path gone from disk was kept');
if(!m.code_scope.editable.includes('wp-content/plugins/mine'))bad('editable decision lost');
" "$site" || exit 1
# An explicit flag beats the carried default.
$cfg adopt "$site" --replace --prefix=flag_ >/dev/null || fail "replace with --prefix failed"
grep -Fq '"flag_"' "$site/.wp-create.json" || fail "explicit --prefix did not win"
# Blank scaffold: nothing carried.
cat >"$site/.wp-create.json" <<'JSON'
{"manifest_version":3,"project":{"source":"blank","name":"x","prefix":"old_"},"audit":{"last_run":"2026-01-01"},"theme":{"slug":"ghost","initialized":false},"plugins":{"installed":[]},"wp_cli":{"wrapper":"wp"}}
JSON
$cfg adopt "$site" --replace >/dev/null || fail "replace over a scaffold failed"
grep -Fq '"audit"' "$site/.wp-create.json" && fail "a blank scaffold's audit block was carried over"
grep -Fq 'old_' "$site/.wp-create.json" && fail "a blank scaffold's prefix was carried over"

# 5c. refresh: plugins and stack only; refuses structural drift.
node -e "
const fs=require('fs');const f=process.argv[1]+'/.wp-create.json';const m=JSON.parse(fs.readFileSync(f));
m.audit={last_run:'2026-02-02'};m.project.industry='construction';m.plugins.installed=['a','gone'];m.stack.seo='rankmath';
fs.writeFileSync(f,JSON.stringify(m));" "$site"
set +e; $cfg drift "$site" >/dev/null; rc=$?; set -e
[ "$rc" = 4 ] || fail "plugin-list drift not detected before refresh"
$cfg refresh "$site" >/dev/null || fail "refresh failed"
node -e "
const m=JSON.parse(require('fs').readFileSync(process.argv[1]+'/.wp-create.json'));
const bad=(w)=>{console.error('FAIL: '+w);process.exit(1)};
if(m.plugins.installed.join()!=='a')bad('plugins.installed not refreshed');
if(m.stack.seo!=='none')bad('stack not refreshed');
if(m.audit?.last_run!=='2026-02-02'||m.project.industry!=='construction')bad('refresh touched a decision');
" "$site" || exit 1
$cfg drift "$site" >/dev/null || fail "still drifts after refresh"
ls "$site"/.wp-create.json.bak-* >/dev/null 2>&1 || fail "refresh kept no backup"
node -e "
const fs=require('fs');const f=process.argv[1]+'/.wp-create.json';const m=JSON.parse(fs.readFileSync(f));
m.theme.slug='ghost';fs.writeFileSync(f,JSON.stringify(m));" "$site"
set +e; $cfg refresh "$site" >/dev/null 2>&1; rc=$?; set -e
[ "$rc" = 1 ] || fail "refresh accepted structural drift"
grep -Fq 'ghost' "$site/.wp-create.json" || fail "refresh rewrote a refused manifest"
grep -Fq '[A] Refresh' commands/wp-audit.md || fail "wp-audit.md does not offer Refresh"
grep -Fq 'carried_over' commands/wp-adopt.md || fail "wp-adopt.md does not document carry-over"

# 6. wp-quiet strips diagnostics, keeps real output and the exit code.
printf '#!/usr/bin/env bash\necho "PHP Notice:  n in /a.php on line 2"\necho "Deprecated: d in /b.php on line 3"\necho "#0 /x.php(1): f()"\necho real\nexit 7\n' >"$tmp/noisy.sh"; chmod +x "$tmp/noisy.sh"
set +e; q=$(bin/wp-quiet.sh "$tmp/noisy.sh"); rc=$?; set -e
[ "$q" = real ] || fail "wp-quiet output was: $q"
[ "$rc" = 7 ] || fail "wp-quiet lost the exit code ($rc)"
# Look-alike real output survives; a "#N" line is dropped only right after a diagnostic.
printf '#!/usr/bin/env bash\necho "Warning: sale ends"\necho "#1 Best seller"\necho "PHP Warning:  w in /a.php on line 2"\necho "#0 /x.php(1): f()"\necho ok\n' >"$tmp/alike.sh"; chmod +x "$tmp/alike.sh"
q=$(bin/wp-quiet.sh "$tmp/alike.sh")
[ "$q" = $'Warning: sale ends\n#1 Best seller\nok' ] || fail "wp-quiet dropped or kept the wrong lines: $q"

# A folded sibling that outlives its parent is carried, not resolved-and-new.
node -e "
const fs=require('fs');const d=process.argv[1];
const f=(check,sev,extra={})=>({check,resource:'site',severity:sev,ownership:'setting',message:check,...extra});
fs.writeFileSync(d+'/r1.json',JSON.stringify({site:'s',date:'2026-01-01',findings:[f('A','CRITICAL',{root_cause:'x'}),f('B','INFO',{root_cause:'x'})]}));
fs.writeFileSync(d+'/r2.json',JSON.stringify({site:'s',date:'2026-01-02',findings:[f('B','INFO',{root_cause:'x'})]}));
" "$tmp"
mkdir -p "$tmp/o2"
node bin/audit-report.mjs --run "$tmp/r1.json" --out "$tmp/o2" --date 2026-01-01 --lang en --format md >/dev/null
node bin/audit-report.mjs --run "$tmp/r2.json" --out "$tmp/o2" --date 2026-01-02 --lang en --format md >/dev/null
grep -Fq -- '- **New since the previous run:** 0' "$tmp/o2/informe-2026-01-02.md" || fail "a folded sibling read as new"
grep -Fq -- '- **Still failing:** 1' "$tmp/o2/informe-2026-01-02.md" || fail "a folded sibling was not carried"
echo PASS
