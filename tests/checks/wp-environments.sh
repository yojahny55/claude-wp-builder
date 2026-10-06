#!/usr/bin/env bash
# wp-environments is loaded by its description alone, and an agent setting up a site follows
# it literally. Four things in it were false, and each produced a broken environment:
#
#   1. It ran `bin/wp-env-setup.sh detect`, a path relative to the plugin that resolves to
#      nothing from a user's project.
#   2. Its placeholder table listed `{{db_host}}`, which no template uses, and missed nine
#      tokens the templates do use (`{{http_port}}`, `{{tests_port}}`, `{{theme_slug}}`, …), so
#      a docker-compose.yml or .wp-env.json built from it kept unreplaced tokens.
#   3. Its port list checked 3306, which docker-compose.yml.tpl does not publish, and missed
#      Mailpit's SMTP port, so a native MariaDB read as a conflict and a real one did not.
#   4. Its PHP table typed package names the script does not install and called `php-list`
#      a list of available versions; it lists installed ones.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

s=skills/wp-environments/SKILL.md
[ -f "$s" ] || fail "$s is missing"

# 1. Plugin paths.
grep -Fq 'bash -c "${CLAUDE_PLUGIN_ROOT}/bin/wp-env-setup.sh detect"' "$s" \
  || fail "$s does not run detect through \${CLAUDE_PLUGIN_ROOT}"
! grep -Eq '(^|[^}/])bin/wp-env-setup\.sh' "$s" \
  || fail "$s names bin/wp-env-setup.sh by a relative path, which resolves against the user's project"

# 2. The table covers every token the templates use, and nothing they do not.
table=$(grep -oE '^\| `\{\{[a-z_]+\}\}`' "$s" | grep -oE '\{\{[a-z_]+\}\}' | sort -u)
used=$(grep -rhoE '\{\{[a-z_]+\}\}' templates --exclude-dir=audit-suite | sort -u)
[ -n "$used" ] || fail "no {{placeholder}} found under templates/ — this check is matching nothing"
missing=$(comm -13 <(printf '%s\n' "$table") <(printf '%s\n' "$used"))
[ -z "$missing" ] || fail "$s has no row for template tokens: $(echo $missing)"
extra=$(comm -23 <(printf '%s\n' "$table") <(printf '%s\n' "$used"))
[ -z "$extra" ] || fail "$s documents tokens no template uses: $(echo $extra)"

# 3. Ports: the ones the template publishes, and not the database's.
for p in '{{mailpit_smtp_port}}' '{{tests_port}}' '{{https_port}}'; do
  grep -Eq "^\| [0-9]+ \| \`$p\`" "$s" || fail "$s's port table does not map $p"
done
! grep -Eq '(ss -tlnp|lsof).*3306' "$s" \
  || fail "$s checks 3306, which docker-compose.yml.tpl does not publish"
grep -Fq 'No manifest field holds' "$s" \
  || fail "$s does not say where a changed port is recorded"

# 4. PHP: what the script does, not a hand-typed second copy.
! grep -Fq 'sudo dnf install php8.3 php8.3-fpm' "$s" \
  || fail "$s still types Fedora package names wp-env-setup.sh does not install"
! grep -Fq 'Update PHP-FPM pool and restart service' "$s" \
  || fail "$s still offers a PHP switch command no script performs"
grep -Fq 'php-list` lists the versions already **installed**' "$s" \
  || fail "$s does not say php-list lists installed versions only"
grep -Fq 'php-install --version=8.3' "$s" || fail "$s does not name the php-install form"

# The manifest gate: no manifest is exit 3, not "everything still works".
! grep -Fq 'no breaking changes to existing workflows' "$s" \
  || fail "$s still says a project without .wp-create.json works unchanged; validate exits 3"

# detect's real shape: an absent tool still carries an empty version.
grep -Fq '"caddy": { "installed": false, "version": "", "running": false }' "$s" \
  || fail "$s does not show detect's real shape for an absent tool"

# 5. Every subcommand the script dispatches is named, with the SELinux rule for vhosts — it
#    lived only in commands/wp-create.md, so an agent reading the skill had `sudo mv` left.
setup=bin/wp-env-setup.sh
# Only the dispatch block: main() also parses flags in a case of its own.
subs=$(awk '/^main\(\)/{f=1} f && /case "\$cmd" in/{c=1; next} c && /^ *esac/{exit} c && /^ *[a-z][a-z-]*\)/{sub(/^ */,""); sub(/\).*/,""); print}' "$setup")
[ -n "$subs" ] || fail "no subcommands parsed from $setup — this assertion is matching nothing"
for sub in $subs; do
  grep -Fq "\`$sub\`" "$s" || fail "$s does not name the $sub subcommand of $setup"
done
case "$(tr '\n' ' ' < "$s")" in *'never `sudo mv`'*) ;; *) fail "$s does not forbid moving a vhost into place with sudo mv" ;; esac
grep -Fq 'restorecon' "$s" || fail "$s does not say vhost-install restores the SELinux context"

# 6. Manifest values are read through the validator, and the engine is defined.
grep -Fq "wp-config.mjs get '\${PROJECT_PATH}' wp_cli.wrapper" "$s" \
  || fail "$s does not read the wrapper through wp-config.mjs get"
! grep -Fq "jq -r '.wp_cli.wrapper'" "$s" || fail "$s still reads the wrapper with jq, around the validator"
for e in native docker-compose ddev lando wp-env; do
  grep -Fq "\`$e\`" "$s" || fail "$s does not list the $e engine"
done
grep -Fq 'need `native`' "$s" || fail "$s does not say store profiles need the native engine"
! grep -Fq 'All operations are idempotent' "$s" || fail "$s still makes the unsupported blanket idempotency claim"
grep -Fq "\"Adopt Mode\" section" "$s" || fail "$s does not send /wp-create's Adopt Mode procedure to the command that owns it"

echo PASS
