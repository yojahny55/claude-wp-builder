#!/usr/bin/env bash
# Agent shell habits that cost a session real time, each seen in a live run:
#   - a bare `wp` piped into `grep -v Deprecated` on PHP 8.5 dumped ~91 KB of phar notices,
#     and the fix flows bypassed bin/wp-quiet.sh that exists for exactly this;
#   - `wp eval` crashed inside WP-CLI's own Eval_Command, and only `wp eval-file` ran;
#   - chained `sleep` and `nohup` jobs were blocked by the harness, and with nohup the user
#     was never told the job had ended;
#   - an interactive `cp` alias prompted, and the assistant retried with `cp -f`;
#   - visual and tag changes were measured with ad hoc scripts although bin/style-diff.mjs
#     exists for them.
# The rules live in wp-cli-patterns, which every seeding and audit agent loads, and in
# fix.md, which owns the visual class. This pins the sentences, both directions.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

s=skills/wp-cli-patterns/SKILL.md
fix=skills/wp-audit-run/references/fix.md
[ -f "$s" ] || fail "$s is missing"
[ -f "$fix" ] || fail "$fix is missing"

# Scoped to the section when its heading is there; the whole file otherwise, so a renamed
# heading weakens the scope instead of muting the check.
sec=$(awk '/^## Shell Hygiene/{f=1; next} f && /^## /{exit} f{print}' "$s" | tr '\n' ' ' | sed 's/  */ /g')
[ -n "$sec" ] || fail "$s has no 'Shell Hygiene' section"

case "$sec" in *'${CLAUDE_PLUGIN_ROOT}/bin/wp-quiet.sh $WP'*) ;; *)
  fail "$s does not route quiet WP-CLI through bin/wp-quiet.sh" ;; esac
case "$sec" in *'Never pipe bare `wp` into `grep -v Deprecated`'*) ;; *)
  fail "$s does not forbid a bare wp piped into grep -v Deprecated" ;; esac
case "$sec" in *'Eval_Command'*) ;; *)
  fail "$s does not name the wp eval failure inside WP-CLI's Eval_Command" ;; esac
case "$sec" in *'mktemp` file and run `$WP eval-file <file>`'*) ;; *)
  fail "$s does not send a failed wp eval to a mktemp file and wp eval-file" ;; esac
case "$sec" in *'Never chain `sleep`, and never use `nohup`.'*) ;; *)
  fail "$s does not forbid chained sleep and nohup" ;; esac
case "$sec" in *'run_in_background'*) ;; *)
  fail "$s does not name the harness background run for long jobs" ;; esac
case "$sec" in *'Use `cp -f` and `mv -f` in scripted copies.'*) ;; *)
  fail "$s does not require cp -f and mv -f in scripted copies" ;; esac

# Nothing in the plugin teaches the filter the rule forbids, or a nohup launch.
hits=$(grep -rnE '(wp|\$WP|\$\{WP\})[^|]*\| *grep -vi? +["'\'']?[Dd]eprecated|nohup[[:space:]]' commands agents skills bin || true)
[ -z "$hits" ] || fail "a shell pattern the hygiene rules forbid is still taught:
$hits"

# The visual class of the fix procedure must keep measuring with style-diff.mjs, and must
# still name a tag change as visual (a span becoming a button changes the render).
grep -Fq 'a tag or class (a `<span>` becoming a `<button>` changes the render' "$fix" \
  || fail "$fix no longer classes a tag change as visual"
grep -Fq 'node ${CLAUDE_PLUGIN_ROOT}/bin/style-diff.mjs` takes this measurement' "$fix" \
  || fail "$fix no longer measures visual fixes with bin/style-diff.mjs"

echo "PASS: agent shell hygiene"
