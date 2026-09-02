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
# A table cell names a command with its flags — `/wp-clone --from --to` — so the
# name is not followed by a closing backtick. Require instead that the next
# character is not one a command name could continue with, or /wp-init would be
# considered documented by a /wp-init-foo row.
NOT_NAME_CHAR='([^a-zA-Z0-9-]|$)'
in_table_row() {  # file, command name — the name inside a markdown table line
  grep -Eq "^\|.*\`$2$NOT_NAME_CHAR" "$1"
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
# 3. Every skill directory appears in the README skills table, and vice versa.
# ---------------------------------------------------------------------------
for d in skills/*/; do
  s=$(basename "$d")
  [ -f "$d/SKILL.md" ] || { err "skills/$s has no SKILL.md"; continue; }
  grep -Fq "\`$s\`" "$README" || err "skill $s is not listed in $README's skills table"
done

# ---------------------------------------------------------------------------
# 4. Every agent appears in the README agents table.
# ---------------------------------------------------------------------------
for f in agents/*.md; do
  a=$(basename "$f" .md)
  grep -Fq "\`$a\`" "$README" || err "agent $a is not listed in $README's agents table"
done

# ---------------------------------------------------------------------------
# 5. A behavior change needs a CHANGELOG entry. Contracts live in prose, so the
#    changelog is the only record of what a release actually changed.
# ---------------------------------------------------------------------------
if git rev-parse --verify --quiet "$base" >/dev/null 2>&1; then
  changed=$(git diff --name-only "$base"...HEAD -- commands/ agents/ skills/ starter-theme/ bin/ 2>/dev/null || true)
  if [ -n "$changed" ]; then
    if ! git diff --name-only "$base"...HEAD -- CHANGELOG.md | grep -q .; then
      err "commands/agents/skills/starter-theme/bin changed since $base but CHANGELOG.md did not — add an [Unreleased] entry"
    fi
  fi
else
  echo "note: $base does not resolve — skipping the CHANGELOG rule"
fi

# ---------------------------------------------------------------------------
# 6. The version is stated in four places and they must agree. Bumping three of
#    them ships a plugin whose marketplace entry disagrees with its manifest.
# ---------------------------------------------------------------------------
# `|| true` on every extraction: under `set -euo pipefail` a grep that matches
# nothing fails the pipeline and aborts the script, so a MISSING version would
# exit silently instead of reporting — the guards below would never run.
v_plugin=$(grep -oE '"version": "[0-9]+\.[0-9]+\.[0-9]+"' .claude-plugin/plugin.json | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || true)
mapfile -t v_market < <(grep -oE '"version": "[0-9]+\.[0-9]+\.[0-9]+"' .claude-plugin/marketplace.json | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || true)
v_badge=$(grep -oE 'version-[0-9]+\.[0-9]+\.[0-9]+-blue' "$README" | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || true)

[ -n "$v_plugin" ] || err ".claude-plugin/plugin.json has no version"
[ "${#v_market[@]}" -eq 2 ] || err ".claude-plugin/marketplace.json should state the version twice, found ${#v_market[@]}"
[ -n "$v_badge" ] || err "$README has no version badge"
for v in "${v_market[@]}" "$v_badge"; do
  [ "$v" = "$v_plugin" ] \
    || err "version mismatch: plugin.json says $v_plugin, another reference says $v — all four must match"
done

# ---------------------------------------------------------------------------
# 7. Frontmatter contracts, per layer. These are what the loader reads; a file
#    missing them is inert rather than broken, which is why it goes unnoticed.
# ---------------------------------------------------------------------------
for f in commands/*.md; do
  head -8 "$f" | grep -q '^description:' || err "$f has no description in its frontmatter"
  # The five cinematic commands follow the kit's own frontmatter shape (`name:` plus
  # an `arguments:` block) rather than the plugin's, so allowed-tools is required
  # only of the standard shape. `argument-hint` is deliberately NOT required: a
  # command that takes no arguments (/wp-finalize) legitimately has none, and there
  # is no way to tell those apart from prose.
  if ! head -8 "$f" | grep -q '^name:'; then
    head -8 "$f" | grep -q '^allowed-tools:' || err "$f has no allowed-tools in its frontmatter"
  fi
done
for f in agents/*.md; do
  for key in name description tools model; do
    head -12 "$f" | grep -q "^$key:" \
      || err "$f has no $key in its frontmatter (model is the cost tier — see tests/checks/model-routing.sh)"
  done
done
for f in skills/*/SKILL.md; do
  # The contract is the VALUE, not the key: a skill declaring `user-invocable: true`
  # is a skill that acts, which is the one thing the layer rules forbid.
  head -8 "$f" | grep -q '^user-invocable: false' \
    || err "$f does not declare user-invocable: false"
done

[ "$fail" -eq 0 ] && echo "PASS: docs describe the plugin that exists"
exit "$fail"
