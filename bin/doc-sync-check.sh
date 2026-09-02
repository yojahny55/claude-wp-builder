#!/usr/bin/env bash
# Assert the docs still describe the plugin that exists.
#
# Almost everything here is prose, so nothing fails at runtime when a command is added,
# renamed or removed and the docs are not updated — the drift only surfaces when a user
# follows a table row that no longer resolves. Both directions have shipped: /wp-robin and
# /wp-aos-animator sat in the README's command table for two releases as slash commands
# that never existed, and #30/#31 merged without a CHANGELOG entry, so their fixes were
# invisible at release time.
#
# Usage: bin/doc-sync-check.sh [--changelog-base <ref>]
#   --changelog-base  compare against this ref for the CHANGELOG rule (default: origin/main
#                     when it resolves, else skip that rule — a fresh clone has no base).
set -euo pipefail
cd "$(dirname "$0")/.."

base="origin/main"
while [ $# -gt 0 ]; do
  case "$1" in
    --changelog-base) base="${2:?--changelog-base needs a ref}"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

fail=0
err() { echo "FAIL: $1"; fail=1; }

README="README.md"
DOCS="docs/commands.md"

# ---------------------------------------------------------------------------
# 1. Every command file is documented in BOTH tables — as a TABLE ROW or (in the
#    reference) a section heading, never merely as a prose mention. A whole-file
#    grep passes on a sentence like "run /wp-foo after /wp-bar", which leaves the
#    command absent from every table a reader actually scans.
# ---------------------------------------------------------------------------
# Documented means "named in the FIRST cell of a table row", for every layer. Two
# weaker forms were tried and both let real drift through:
#   - a whole-file grep passes on a prose sentence, so deleting a table row while
#     leaving a mention elsewhere in the README still passed;
#   - a whole-line match passes when the name only appears in some other row's
#     description cell.
# The first cell is what a reader scans, so that is what is asserted.
#
# A cell names a command with its flags — `/wp-clone --from --to` — so the name is
# not followed by a closing backtick. Require instead that the next character is
# not one a name could continue with, or /wp-init would count as documented by a
# /wp-init-foo row, and the wp-css agent by the wp-css-system skill's row.
NOT_NAME_CHAR='([^a-zA-Z0-9-]|$)'
in_table_row() {  # file, name — inside the first cell of a markdown table row
  awk -F'|' -v n="$2" '
    NF > 2 && $2 ~ ("`" n "([^a-zA-Z0-9-]|$)") { found = 1 }
    END { exit !found }
  ' "$1"
}
in_section_heading() {
  grep -Eq "^#{2,4} .*\`$2$NOT_NAME_CHAR" "$1"
}
for f in commands/*.md; do
  name="/$(basename "$f" .md)"
  in_table_row "$README" "$name" \
    || err "$name exists in commands/ but has no table row in $README (a prose mention does not count)"
  in_table_row "$DOCS" "$name" || in_section_heading "$DOCS" "$name" \
    || err "$name exists in commands/ but has no table row or section heading in $DOCS"
done

# ---------------------------------------------------------------------------
# 2. ...and nothing is documented that does not exist. This is the phantom-row
#    direction. Only `/wp-foo` in a table cell counts: prose may legitimately
#    mention a command being removed, and a skill name is not a command.
# ---------------------------------------------------------------------------
#    Both files are scanned: a phantom row is as misleading in the reference as in
#    the README. `|| true` because a file with no command rows at all is a
#    different failure, caught by rule 1 — here it must not abort the run.
for doc in "$README" "$DOCS"; do
  documented=$(grep -oE '^\| \[?`/wp-[a-z0-9-]+' "$doc" | grep -oE '/wp-[a-z0-9-]+' | sort -u || true)
  for name in $documented; do
    [ -f "commands/${name#/}.md" ] \
      || err "$doc documents $name as a command, but commands/${name#/}.md does not exist"
  done
done

# ---------------------------------------------------------------------------
# 3. Every skill directory is named in the skills table — as a table row, not as
#    a prose mention. The README discusses wp-robin and wp-aos-animator in prose
#    outside the table, so a whole-file grep passed even with their rows deleted.
# ---------------------------------------------------------------------------
for d in skills/*/; do
  sk=$(basename "$d")
  [ -f "$d/SKILL.md" ] || { err "skills/$sk has no SKILL.md"; continue; }
  in_table_row "$README" "$sk" \
    || err "skill $sk has no row in $README's skills table (a prose mention does not count)"
done

# ---------------------------------------------------------------------------
# 4. Every agent, same standard.
# ---------------------------------------------------------------------------
for f in agents/*.md; do
  a=$(basename "$f" .md)
  in_table_row "$README" "$a" \
    || err "agent $a has no row in $README's agents table (a prose mention does not count)"
done

# ---------------------------------------------------------------------------
# 5. A behavior change needs a CHANGELOG entry. Contracts live in prose, so the
#    changelog is the only record of what a release actually changed.
# ---------------------------------------------------------------------------
# `|| true` on the diff would turn a FAILED diff into "nothing changed" and skip the
# rule silently — a shallow clone with no merge-base looks identical to a clean tree.
# Distinguish the three states: no base (skip, say so), diff failed (report), diff
# succeeded (evaluate).
if ! git rev-parse --verify --quiet "$base" >/dev/null 2>&1; then
  echo "note: $base does not resolve — skipping the CHANGELOG rule"
elif ! changed=$(git diff --name-only "$base"...HEAD -- commands/ agents/ skills/ starter-theme/ bin/ 2>/dev/null); then
  err "could not diff against $base (shallow clone, or no merge base) — the CHANGELOG rule could not be evaluated; re-run with --changelog-base <ref> or fetch more history"
elif [ -n "$changed" ]; then
  # Touching the file is not the contract; having an entry is. A whitespace edit to an
  # old release note satisfied the previous check while the error message asked for an
  # [Unreleased] entry that was never added.
  if ! git diff --name-only "$base"...HEAD -- CHANGELOG.md | grep -q .; then
    err "commands/agents/skills/starter-theme/bin changed since $base but CHANGELOG.md did not — add an [Unreleased] entry"
  else
    entries=$(awk '/^## \[Unreleased\]/ { f = 1; next } /^## \[/ { f = 0 } f && /^- / { n++ } END { print n + 0 }' CHANGELOG.md)
    [ "$entries" -gt 0 ] \
      || err "CHANGELOG.md changed but its [Unreleased] section has no entries — behavior moved, so describe it there"
  fi
fi

# ---------------------------------------------------------------------------
# 6. The version is stated in four places and they must agree. Bumping three of
#    them ships a plugin whose marketplace entry disagrees with its manifest.
# ---------------------------------------------------------------------------
# `|| true` on every extraction: under `set -euo pipefail` a grep that matches
# nothing fails the pipeline and aborts the script, so a MISSING version would
# exit silently instead of reporting — the guards below would never run.
v_plugin=$(grep -oE '"version": "[0-9]+\.[0-9]+\.[0-9]+"' .claude-plugin/plugin.json | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || true)
v_badge=$(grep -oE 'version-[0-9]+\.[0-9]+\.[0-9]+-blue' "$README" | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || true)
# `while read` rather than `mapfile`: mapfile is bash 4+, and macOS still ships bash
# 3.2 as /bin/bash. A gate that aborts on a contributor's machine teaches them to
# skip it.
v_market=()
while IFS= read -r v; do
  [ -n "$v" ] && v_market+=("$v")
done < <(grep -oE '"version": "[0-9]+\.[0-9]+\.[0-9]+"' .claude-plugin/marketplace.json | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || true)

[ -n "$v_plugin" ] || err ".claude-plugin/plugin.json has no version"
[ "${#v_market[@]}" -eq 2 ] || err ".claude-plugin/marketplace.json should state the version twice, found ${#v_market[@]}"
[ -n "$v_badge" ] || err "$README has no version badge"
# Compare only when every reference was found: expanding an empty array under `set -u`
# aborts on bash 4.2 and older, which would swallow the reports just made above.
if [ -n "$v_plugin" ] && [ "${#v_market[@]}" -eq 2 ] && [ -n "$v_badge" ]; then
  for v in "${v_market[@]}" "$v_badge"; do
    [ "$v" = "$v_plugin" ] \
      || err "version mismatch: plugin.json says $v_plugin, another reference says $v — all four must match"
  done
fi

# ---------------------------------------------------------------------------
# 7. Frontmatter contracts, per layer. These are what the loader reads; a file
#    missing them is inert rather than broken, which is why it goes unnoticed.
# ---------------------------------------------------------------------------
# `awk NR<=N` rather than `head -N | grep -q`: under `set -o pipefail`, grep -q can exit
# on its match before head finishes writing, head takes SIGPIPE, and the pipeline reports
# 141 — a FALSE failure on a file whose frontmatter is correct.
fm() {  # file, regex, lines-to-scan
  awk -v re="$2" -v n="${3:-8}" 'NR <= n && $0 ~ re { found = 1 } END { exit !found }' "$1"
}
for f in commands/*.md; do
  fm "$f" '^description:' || err "$f has no description in its frontmatter"
  # The five cinematic commands follow the kit's own frontmatter shape (`name:` plus
  # an `arguments:` block) rather than the plugin's, so allowed-tools is required
  # only of the standard shape. `argument-hint` is deliberately NOT required: a
  # command that takes no arguments (/wp-finalize) legitimately has none, and there
  # is no way to tell those apart from prose.
  if ! fm "$f" '^name:'; then
    fm "$f" '^allowed-tools:' || err "$f has no allowed-tools in its frontmatter"
  fi
done
for f in agents/*.md; do
  for key in name description tools model; do
    fm "$f" "^$key:" 12 \
      || err "$f has no $key in its frontmatter (model is the cost tier — see tests/checks/model-routing.sh)"
  done
done
for f in skills/*/SKILL.md; do
  # The contract is the VALUE, not the key: a skill declaring `user-invocable: true`
  # is a skill that acts, which is the one thing the layer rules forbid.
  fm "$f" '^user-invocable: false' \
    || err "$f does not declare user-invocable: false"
done

[ "$fail" -eq 0 ] && echo "PASS: docs describe the plugin that exists"
exit "$fail"
