#!/usr/bin/env bash
# Every skill follows Anthropic's skill authoring guidance
# (platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices) and what Claude
# Code's loader actually reads. Each rule below is one this repository broke:
#
# - wp-demo-craft's frontmatter did not parse as YAML, so Claude Code loaded it with no fields
#   set; tests/checks/frontmatter-yaml.sh owns that rule, for every layer.
# - Eleven descriptions said what a skill was and never when to use it, and two carried
#   `trigger:`, a key Claude Code ignores. The description is the only text Claude reads before
#   choosing a skill, so a skill without a "Use when" clause is found by luck.
# - Eight SKILL.md bodies ran past 500 lines, one to 1,187, so every agent that read one paid
#   for all of it before it needed any of it.
# - Reference files over 100 lines had no contents list, so a partial read could not see what
#   it had skipped, and some reference files were never named in SKILL.md at all.
# - Four bundled scripts (resolve-link-targets.php, pll-setup.php, pll-export.php,
#   read-s3-config.php) were not named in their own SKILL.md, so Claude could not know from
#   the skill whether to run them.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail=0
err() { echo "FAIL: $*"; fail=1; }
# A quoted YAML scalar is the same value as the bare one; compare the value, not the quotes.
unquote() { sed -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'\$/\1/"; }

for f in skills/*/SKILL.md; do
  dir=$(dirname "$f")
  sk=$(basename "$dir")
  fm=$(awk 'NR == 1 && !/^---$/ { exit } NR > 1 && /^---$/ { exit } NR > 1' "$f")
  [ -n "$fm" ] || { err "$f has no frontmatter block"; continue; }
  # Without a closing ---, the whole file reads as frontmatter and the body counts as 0 lines.
  awk 'NR > 1 && /^---$/ { found = 1; exit } END { exit !found }' "$f" \
    || { err "$f has no closing frontmatter delimiter"; continue; }
  name=$(printf '%s\n' "$fm" | sed -n 's/^name: *//p' | unquote)
  desc=$(printf '%s\n' "$fm" | sed -n 's/^description: *//p' | unquote)

  [ "$name" = "$sk" ] || err "$f: name '$name' does not match its directory '$sk'"
  printf '%s' "$name" | grep -Eq '^[a-z0-9-]{1,64}$' \
    || err "$f: name must be 1-64 lowercase letters, digits or hyphens"

  [ -n "$desc" ] || err "$f: description is empty, or not on the description: line"
  [ "${#desc}" -le 1024 ] || err "$f: description is ${#desc} characters; the limit is 1024"
  # Whether the frontmatter parses as YAML at all is tests/checks/frontmatter-yaml.sh, for
  # every layer.
  case "$desc" in *'<'*|*'>'*) err "$f: description contains an angle bracket; descriptions carry no XML tags" ;; esac
  case "$desc" in *'Use when'*) ;; *) err "$f: description says what the skill is but not when to use it — add a 'Use when …' clause" ;; esac
  ! printf '%s\n' "$fm" | grep -q '^trigger:' \
    || err "$f: trigger: is not a frontmatter field and is ignored — say when to use the skill in the description"

  body=$(awk 'n >= 2 { b++ } /^---$/ && n < 2 { n++ } END { print b + 0 }' "$f")
  [ "$body" -le 500 ] \
    || err "$f: body is $body lines; keep it under 500 and move detail into references/, linked from SKILL.md"

  # Reference material. The design-md corpus is third-party DESIGN.md files read as data, not
  # instructions written for this plugin, so it is held to neither rule.
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    if [ "$(wc -l < "$r")" -gt 100 ]; then
      head -30 "$r" | grep -Eqi '^#{1,3} +(table of )?contents' \
        || err "$r is over 100 lines with no '## Contents' list near the top"
    fi
  done < <(find "$dir" -name '*.md' ! -path "$f" ! -path '*/design-md/*' | sort)

  # A bundled script SKILL.md never names is one Claude cannot know to run, or knows only by
  # reading the script; the skill must say which scripts exist and what each is for.
  if [ -d "$dir/scripts" ]; then
    while IFS= read -r s; do
      grep -Fq "$(basename "$s")" "$f" || err "$s is never named in $f — say whether to run it or what calls it"
    done < <(find "$dir/scripts" -type f | sort)
  fi

  # One level deep: every top-level reference file is named in SKILL.md itself, so a reader
  # never has to find it through another reference.
  if [ -d "$dir/references" ]; then
    for r in "$dir"/references/*.md; do
      [ -e "$r" ] || continue
      grep -Fq "$(basename "$r")" "$f" || err "$r is never named in $f"
    done
  fi
done

[ "$fail" -eq 0 ] || exit 1
echo PASS
