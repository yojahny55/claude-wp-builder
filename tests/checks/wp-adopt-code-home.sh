#!/usr/bin/env bash
# An adopted site with no code of its own had no home for the fixes an audit proposes; every
# plugin change interrupted the audit with a drift prompt; a deleted plugin stayed in the
# scope lists and the generated block; re-adoption left manifest backups in the docroot; and
# `adopt --dry-run` had no machine-readable form. Drives wp-config.mjs against a fake `wp`.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
cfg="node $PWD/bin/wp-config.mjs"
tmp=$(mktemp -d); export WP_BUILDER_BACKUP_DIR="$tmp/backups"; trap 'rm -rf "$tmp"' EXIT
site="$tmp/site"
mkdir -p "$tmp/bin" "$site/wp-content/themes/vendor" "$site/wp-content/plugins/ix-wp-envsync" \
  "$site/wp-content/plugins/seo-by-rank-math" "$site/wp-content/plugins/wordfence" "$site/wp-content/plugins/extra"
touch "$site/wp-load.php" "$site/wp-config.php"

# A commercial theme with no child, one tooling plugin no updater knows, three vendor plugins.
plug() { printf '{"file":"%s/%s.php","slug":"%s","name":"%s","update_uri":"","active":%s,"known_to_updater":%s,"path":"wp-content/plugins/%s"}' "$1" "$1" "$1" "$1" "$2" "$3" "$1"; }
mkprobe() {
  printf '{"home":"https://x.test","blogname":"X","locale":"en_US","pll_default":null,"pll_languages":[],"multisite":false,"php":"8.2.1","wp":"6.8","stylesheet":"vendor","template":"vendor","theme_path":"wp-content/themes/vendor","parent_path":null,"theme_known_to_updater":true,"parent_known_to_updater":null,"plugins":[%s],"mu_plugins":[],"mu_path":"wp-content/mu-plugins"}' "$1" >"$tmp/probe.json"
}
base="$(plug ix-wp-envsync true false),$(plug seo-by-rank-math true true),$(plug wordfence true true),$(plug extra true true)"
mkprobe "$base"
cat >"$tmp/bin/wp" <<SH
#!/usr/bin/env bash
echo "PHP Notice: noisy on boot"
printf '<<WPCB-PROBE>>'; cat "$tmp/probe.json"; printf '<<END-WPCB-PROBE>>\n'
SH
chmod +x "$tmp/bin/wp"; export PATH="$tmp/bin:$PATH"
jq_() { node -e "const j=JSON.parse(require('fs').readFileSync(0,'utf8'));const v=($1);console.log(typeof v==='string'?v:JSON.stringify(v))"; }

# 1. No site-owned editable code: the dry run says so and offers the three homes.
out=$($cfg adopt "$site" --dry-run --json)
[ "$(jq_ 'j.code_home_needed' <<<"$out")" = true ] || fail "code_home_needed not reported"
[ "$(jq_ 'j.code_home_options.map(o=>o.kind).join()' <<<"$out")" = child-theme,site-plugin,mu-plugin ] || fail "code home options missing"
[ "$(jq_ 'j.code_home_options[0].path' <<<"$out")" = wp-content/themes/vendor-child ] || fail "child theme path not derived from the parent"
[ "$(jq_ 'j.dry_run' <<<"$out")" = true ] || fail "dry-run flag missing from the JSON"

# 2. --json on a real adoption: stdout is ONE document, notes included, nothing else.
$cfg adopt "$site" --code-home=child-theme --json >"$tmp/o.json" 2>/dev/null || fail "adopt --json failed"
[ "$(jq_ 'j.manifest.code_home.kind' <"$tmp/o.json")" = child-theme ] || fail "code_home not recorded"
[ "$(jq_ 'j.manifest.code_home.created' <"$tmp/o.json")" = false ] || fail "a planned child theme was marked created"
[ "$(jq_ 'j.code_home_needed' <"$tmp/o.json")" = false ] || fail "code_home_needed still true after the choice"
jq_ 'j.notes.length>0' <"$tmp/o.json" | grep -Fq true || fail "notes were not folded into the JSON"
$cfg validate "$site" >/dev/null || fail "adopted manifest does not validate"

# 3. code-home prints the theme_mods copy, before activation; once the dir exists it joins editable.
msg=$($cfg code-home "$site" --kind=child-theme)
echo "$msg" | grep -Fq 'option get theme_mods_vendor' || fail "theme_mods copy step missing"
echo "$msg" | grep -Fq 'option update theme_mods_vendor-child' || fail "theme_mods target missing"
[ "$(echo "$msg" | grep -n 'theme_mods_vendor ' | head -1 | cut -d: -f1)" -lt "$(echo "$msg" | grep -n 'theme activate' | head -1 | cut -d: -f1)" ] || fail "copy must come before activate"
mkdir -p "$site/wp-content/themes/vendor-child"
$cfg code-home "$site" --kind=child-theme >/dev/null || fail "code-home failed after creation"
jq_ 'j.code_scope.editable.includes("wp-content/themes/vendor-child")' <"$site/.wp-create.json" | grep -Fq true || fail "created home not in editable scope"
$cfg code-home "$site" | grep -Fq 'child-theme at wp-content/themes/vendor-child' || fail "code-home does not report the recorded choice"
$cfg validate "$site" >/dev/null || fail "validate after code-home"
if $cfg code-home "$site" --kind=bogus 2>/dev/null; then fail "bogus kind accepted"; fi

# 4. Plugin-list drift is refreshed without a backup churn; a second refresh is a no-op.
mkprobe "$base,$(plug newbie true true)"
mkdir -p "$site/wp-content/plugins/newbie"
set +e; $cfg drift "$site" >/dev/null; rc=$?; set -e
[ "$rc" = 4 ] || fail "new plugin not seen as drift"
$cfg refresh "$site" >/dev/null || fail "refresh failed"
$cfg drift "$site" >/dev/null || fail "still drifts after refresh"
n=$(ls "$tmp"/backups/*/ | wc -l)
$cfg refresh "$site" | grep -Fq 'nothing to refresh' || fail "second refresh was not a no-op"
[ "$(ls "$tmp"/backups/*/ | wc -l)" = "$n" ] || fail "a no-op refresh wrote a backup"
[ -z "$(ls "$site" | grep -F bak || true)" ] && [ -z "$(ls -A "$site" | grep -F '.wp-create.json.bak' || true)" ] || fail "backup left in the docroot"

# 5. An intentionally inactive plugin is not drift, survives refresh, and still counts for the stack.
mkprobe "$(plug ix-wp-envsync true false),$(plug seo-by-rank-math true true),$(plug wordfence false true),$(plug extra true true),$(plug newbie true true)"
set +e; $cfg drift "$site" >/dev/null; rc=$?; set -e
[ "$rc" = 4 ] || fail "deactivated plugin not seen as drift"
$cfg keep-inactive "$site" wordfence >/dev/null || fail "keep-inactive failed"
$cfg drift "$site" >/dev/null || fail "an intentionally inactive plugin still drifts"
$cfg refresh "$site" >/dev/null || fail "refresh failed with a parked plugin"
[ "$(jq_ 'j.plugins.intentionally_inactive' <"$site/.wp-create.json")" = '["wordfence"]' ] || fail "refresh lost the parked list"
[ "$(jq_ 'j.stack.security' <"$site/.wp-create.json")" = wordfence ] || fail "a parked plugin dropped out of the stack"
$cfg validate "$site" >/dev/null || fail "validate with parked plugin"

# 6. A deleted plugin: drift names its scope path, refresh drops it and the block together.
rm -rf "$site/wp-content/plugins/extra"
mkprobe "$(plug ix-wp-envsync true false),$(plug seo-by-rank-math true true),$(plug wordfence false true),$(plug newbie true true)"
set +e; d=$($cfg drift "$site"); rc=$?; set -e
[ "$rc" = 4 ] || fail "deleted plugin not seen as drift"
echo "$d" | grep -Fq 'no longer on disk' || fail "drift did not name the stale scope path"
$cfg refresh "$site" >/dev/null || fail "refresh failed after a plugin was deleted"
grep -Fq 'wp-content/plugins/extra' "$site/.wp-create.json" && fail "deleted plugin still in the manifest"
grep -Fq 'wp-content/plugins/extra' "$site/.claude/CLAUDE.md" && fail "deleted plugin still in the generated block"
$cfg validate "$site" >/dev/null || fail "validate failed after refresh (block out of step)"
# remove-plugin without a probe-able change: the same result by name.
$cfg remove-plugin "$site" newbie >/dev/null || fail "remove-plugin failed"
grep -Fq 'wp-content/plugins/newbie' "$site/.wp-create.json" && fail "remove-plugin left the scope path"
grep -Fq 'newbie' "$site/.claude/CLAUDE.md" && fail "remove-plugin left the plugin in the block"
$cfg validate "$site" >/dev/null || fail "validate failed after remove-plugin"
$cfg remove-plugin "$site" never-there | grep -Fq 'nothing to remove' || fail "remove-plugin of an unknown slug should be a no-op"

# 7. Re-adoption keeps the choices and parks its backup outside the docroot.
$cfg adopt "$site" --replace --json >"$tmp/r.json" 2>/dev/null || fail "adopt --replace --json failed"
bak=$(jq_ 'j.backup' <"$tmp/r.json")
case "$bak" in "$tmp/backups/"*) ;; *) fail "backup path is not under the backup dir: $bak" ;; esac
[ -f "$bak" ] || fail "backup file missing"
[ "$(jq_ 'j.manifest.code_home.kind' <"$tmp/r.json")" = child-theme ] || fail "replace lost code_home"
[ "$(jq_ 'j.manifest.plugins.intentionally_inactive' <"$tmp/r.json")" = '["wordfence"]' ] || fail "replace lost the parked list"
[ -z "$(ls -A "$site" | grep -F '.bak' || true)" ] || fail "re-adoption left a backup in the docroot"

# 8. The prose points at the new surface.
grep -Fq 'code_home' commands/wp-adopt.md || fail "wp-adopt.md lacks code_home"
grep -Fq -- '--json' commands/wp-adopt.md || fail "wp-adopt.md lacks --json"
grep -Fq 'keep-inactive' commands/wp-audit.md || fail "wp-audit.md lacks keep-inactive"
grep -Fq 'code_home' skills/wp-audit-run/references/fix.md || fail "fix.md does not read code_home"
grep -Fq 'theme_mods' commands/wp-adopt.md || fail "wp-adopt.md lacks the theme_mods step"
echo PASS
