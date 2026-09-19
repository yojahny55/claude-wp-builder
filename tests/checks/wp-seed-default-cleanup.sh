#!/usr/bin/env bash
# /wp-seed Phase 7 deletes three records it does not own: the "Hello world!" post, the
# sample page and the sample comment. Every other record in that command follows the
# Phase 1.5 rule -- no `_<prefix>_seeded_content` marker means the client owns it -- but
# WordPress ships these three, so they never carry the marker and the rule has to be
# spelled differently for them.
#
# It used to be spelled `wp post delete 2 --force 2>/dev/null || true`, unconditionally.
# Repurposing the sample page into About is ordinary; that line destroyed it permanently
# on the site's second seed run, with `--force` bypassing the trash and `|| true` hiding
# that anything had happened.
#
# This check is not a contract grep. It EXTRACTS the bash block from commands/wp-seed.md
# and RUNS it against a stub `wp`, because the defect was in what the block does, and a
# grep for the word "untouched" would pass against a block that deletes everything anyway.
# The stub records deletions instead of performing them, so the assertions are about which
# records the shipped text decided to remove.
set -uo pipefail

cd "$(dirname "$0")/../.." || exit 1
SEED="commands/wp-seed.md"
fails=0
fail() { printf 'FAIL: %s\n' "$1"; fails=$((fails + 1)); }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# --- extract the two shipped blocks -----------------------------------------------------
# Everything between the Phase 7 heading and the next heading, keeping only fenced bash.
awk '
  /^### Delete default WordPress content/ { on = 1; next }
  on && /^### / { exit }
  on && /^```bash$/ { fence = 1; next }
  on && fence && /^```$/ { fence = 0; next }
  on && fence { print }
' "$SEED" > "$work/block.sh"

if [ ! -s "$work/block.sh" ]; then
  fail "could not extract a bash block from the Phase 7 cleanup section of $SEED"
  printf 'FAILED %d\n' "$fails"
  exit 1
fi

# --- the stub -----------------------------------------------------------------------------
# Answers `post get`/`comment get` from a fixture file and appends `delete` calls to a log.
# Exits non-zero for a record the fixture does not define, which is how a real `wp post get`
# behaves for a post that is already gone -- the rerun case.
mkdir -p "$work/bin"
cat > "$work/bin/wp" <<'STUB'
#!/usr/bin/env bash
# fixture lines: <type>|<id>|<field>|<value>
get() { grep -m1 "^$1|$2|$3|" "$FIXTURE" 2>/dev/null | cut -d'|' -f4-; }
case "$1 $2" in
  "post get"|"comment get") ;;
  "post delete"|"comment delete") printf '%s %s\n' "${1}" "$3" >> "$DELLOG"; exit 0 ;;
esac
kind="$1"; verb="$2"; id="$3"
if [ "$verb" = delete ]; then printf '%s %s\n' "$kind" "$id" >> "$DELLOG"; exit 0; fi
field="${4#--field=}"
value="$(get "$kind" "$id" "$field")"
[ -n "$value" ] || exit 1
printf '%s\n' "$value"
STUB
chmod +x "$work/bin/wp"

run_case() {
  # run_case <name> <fixture-heredoc-file>; prints the deletion log
  : > "$work/deleted.log"
  FIXTURE="$1" DELLOG="$work/deleted.log" WP="$work/bin/wp" \
    bash "$work/block.sh" > "$work/out.txt" 2>&1
  cat "$work/deleted.log"
}

# --- case 1: pristine install -- every default is still the default ----------------------
cat > "$work/fx-pristine" <<'FX'
post|1|post_name|hello-world
post|1|post_date|2026-01-01 00:00:00
post|1|post_modified|2026-01-01 00:00:00
post|2|post_name|sample-page
post|2|post_date|2026-01-01 00:00:00
post|2|post_modified|2026-01-01 00:00:00
comment|1|comment_author|A WordPress Commenter
FX
got="$(run_case "$work/fx-pristine")"
for want in "post 1" "post 2" "comment 1"; do
  printf '%s\n' "$got" | grep -qx "$want" \
    || fail "an untouched default was not deleted: expected '$want' in the deletion log, got: $(printf '%s' "$got" | tr '\n' ' ')"
done

# --- case 2: the sample page was repurposed into About -----------------------------------
# The defect this check exists for. The slug moved, so page 2 is the client's.
cat > "$work/fx-repurposed" <<'FX'
post|1|post_name|hello-world
post|1|post_date|2026-01-01 00:00:00
post|1|post_modified|2026-01-01 00:00:00
post|2|post_name|about
post|2|post_date|2026-01-01 00:00:00
post|2|post_modified|2026-03-04 11:22:00
comment|1|comment_author|A WordPress Commenter
FX
got="$(run_case "$work/fx-repurposed")"
printf '%s\n' "$got" | grep -qx "post 2" \
  && fail "a repurposed sample page (slug 'about') was deleted -- Phase 7 must keep a record the client owns"
printf '%s\n' "$got" | grep -qx "post 1" \
  || fail "the untouched 'Hello world!' post was not deleted in the repurposed-page case"
grep -q "KEPT post 2" "$work/out.txt" \
  || fail "keeping page 2 was not reported -- a default that survived must be named, not silently skipped"

# --- case 3: slug untouched, body edited -------------------------------------------------
# An editor who rewrote the sample page without renaming it still owns it.
cat > "$work/fx-edited" <<'FX'
post|2|post_name|sample-page
post|2|post_date|2026-01-01 00:00:00
post|2|post_modified|2026-05-05 09:00:00
FX
got="$(run_case "$work/fx-edited")"
printf '%s\n' "$got" | grep -qx "post 2" \
  && fail "a sample page edited after creation was deleted -- post_modified moving means the client touched it"

# --- case 4: the comment was replaced by a real one --------------------------------------
cat > "$work/fx-comment" <<'FX'
comment|1|comment_author|Jane Client
FX
got="$(run_case "$work/fx-comment")"
printf '%s\n' "$got" | grep -qx "comment 1" \
  && fail "a comment by a real author was deleted -- only the WordPress default comment may go"

# --- case 5: rerun, everything already gone ----------------------------------------------
# `wp post get` exits non-zero. Nothing may be deleted and nothing may error.
: > "$work/fx-empty"
got="$(run_case "$work/fx-empty")"
[ -z "$got" ] \
  || fail "a rerun against a site with no defaults left tried to delete: $(printf '%s' "$got" | tr '\n' ' ')"

# --- the contract wording, so the reasoning cannot be deleted with the code ---------------
grep -q 'post_modified' "$SEED" \
  || fail "$SEED no longer names post_modified -- the signal that a default was edited"
grep -qi 'KEPT post' "$SEED" \
  || fail "$SEED no longer reports kept defaults"

if [ "$fails" -gt 0 ]; then
  printf 'FAILED %d\n' "$fails"
  exit 1
fi
printf 'PASS: wp-seed Phase 7 deletes only untouched WordPress defaults (5 scenarios)\n'
