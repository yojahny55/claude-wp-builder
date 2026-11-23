#!/usr/bin/env bash
# /wp-webp migrate runs skills/wp-robin/scripts/webp-migrate.php. This pins the order the
# command follows (backup before convert, verify before move-aside, redirect rules printed and
# never written) and the script's refusals. What the script does to a real library is
# tests/checks/webp-migrate-integration.sh.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/lib/assert.sh

cmd=commands/wp-webp.md
script=skills/wp-robin/scripts/webp-migrate.php
[ -f "$script" ] || fail "$script is missing"

need_token "$cmd" '## `migrate`: convert the PNG library already on disk'
need_token "$cmd" 'skills/wp-robin/scripts/webp-migrate.php'
need_token "$cmd" 'bin/wp-backup.sh'
need_token "$cmd" '--uploads --label pre-webp'
need_token "$cmd" 'Never write server config'
need_token "$cmd" 'It re-runs `verify` first and refuses if it fails.'
need_token "$cmd" 'Nothing is deleted'
# The backup must come before the first convert, and verify before move-aside.
line() { grep -nF -- "$2" "$1" | sed -n 1p | cut -d: -f1; }
b=$(line "$cmd" 'bin/wp-backup.sh'); c=$(line "$cmd" 'convert <work>'); v=$(line "$cmd" 'verify <work>'); m=$(line "$cmd" 'move-aside <work>')
[ -n "$b" ] && [ -n "$c" ] && [ "$b" -lt "$c" ] || fail "$cmd converts before it backs up"
[ -n "$v" ] && [ -n "$m" ] && [ "$v" -lt "$m" ] || fail "$cmd moves files aside before it verifies"

need_token "$script" "defined( 'ABSPATH' ) || exit;"
need_token "$script" 'the workdir must be outside the WordPress root and uploads'
need_token "$script" 'the backup folder must be outside uploads and the WordPress root'
need_token "$script" 'uploads live behind a stream wrapper'
need_token "$script" "'allowed_classes' => false"
need_token "$script" 'register_shutdown_function'
need_token "$script" 'only a single site whose uploads URL ends in /uploads is supported'
need_token BACKLOG.md 'tests/checks/webp-migrate-integration.sh'
need_token skills/wp-robin/SKILL.md 'scripts/webp-migrate.php'
if grep -nE '\bunlink\(|wp_delete_file|wp_delete_attachment' "$script" | grep -vE 'wm_progress|unlink\( \$target \)' >/dev/null; then
  fail "$script deletes a file other than its progress marker or the WebP it just wrote; old files are only moved aside"
fi

require_tool php
php -l "$script" >/dev/null || fail "$script does not parse"
echo "PASS: webp-migrate backs up first, verifies before it moves anything, and deletes nothing"
