#!/usr/bin/env bash
# Field labels were generated in English whatever language the site was in. On a
# Spanish-primary build the editor read "Content", "Title" and "Leave empty to use English
# version" over Spanish content, and the person filling the page was not the person who
# ordered it in English.
#
# The fix has two halves, and shipping only the first is worse than shipping neither:
#   1. every string the EDITOR reads follows the project's primary language — group title,
#      tab and field labels, instructions, button_label, message;
#   2. every string a MACHINE reads stays English — `key`, `name`, the file name, the
#      language suffix. A `name` is the meta key: `prefix_get_field()` asks for it, every
#      template and seeding script names it, and the rows in wp_postmeta are keyed on it.
#      Translating one does not rename data, it orphans it — the field reads empty while the
#      content sits in the database under the old key.
#
# And the suffix marks the SECONDARY language. On a Spanish-primary site `hero_title` is the
# Spanish and `hero_title_en` is the translation; a hardcoded `_es` there names a Spanish
# field as the translation of itself.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

f=agents/wp-acf.md
skill=skills/wp-bilingual/SKILL.md
init=commands/wp-init.md
for x in "$f" "$skill" "$init"; do
  [ -s "$x" ] || fail "$x is missing or empty"
  [ -r "$x" ] || fail "$x exists but cannot be read"
done
flat=$(tr '\n' ' ' < "$f" | sed 's/  */ /g')
flatskill=$(tr '\n' ' ' < "$skill" | sed 's/  */ /g')
has() { case "$2" in *"$1"*) return 0 ;; *) return 1 ;; esac; }

# 1. The agent is told to read the language, and by the exact heading /wp-init writes.
grep -Fq -e '- **Primary language:**' "$init" \
  || fail "$init no longer writes a '- **Primary language:**' line into .claude/CLAUDE.md — the agent has nothing to read"
has '`- **Primary language:**`' "$flat" \
  || fail "$f does not tell the agent to read the '- **Primary language:**' line from .claude/CLAUDE.md"
grep -q '^## Editor Language' "$f" \
  || fail "$f has no 'Editor Language' section, so nothing states which strings follow the site's language"

# 2. Both halves of the rule, in one sentence each.
has 'Every string the editor reads is written in the project' "$flat" \
  || fail "$f does not state that editor-facing strings follow the primary language"
has 'Every string a machine reads stays English' "$flat" \
  || fail "$f does not state that key, name and the suffix stay English — a translated meta key orphans the rows already stored under the old one"
# The reason, not just the rule: a rule with no reason is edited away by the next reader.
has 'orphans it' "$flat" \
  || fail "$f does not say WHY a name stays English (a renamed meta key orphans its data), so the next edit translates it"

# 3. The suffix belongs to the secondary language, and the agent is told not to assume.
has 'The suffix marks the secondary language, never the primary' "$flat" \
  || fail "$f does not state that the language suffix marks the SECONDARY language"

# 4. A worked example in a language that is not English. Without one the rule is abstract and
# the English-primary examples below it are read as the template.
grep -q '^### Spanish-primary example' "$f" \
  || fail "$f has no non-English worked example"
# The section alone, not the whole file: every needle below also appears in the
# English-primary examples, so a whole-file grep stayed green with the field name in the
# Spanish example translated — the one error this check exists to catch.
example=$(awk '/^### Spanish-primary example/{f=1; next} f && /^#{2,3} /{exit} f{print}' "$f")
[ -n "$example" ] || fail "$f's Spanish-primary example section is empty"
flatex=$(printf '%s' "$example" | tr '\n' ' ' | sed 's/  */ /g')
for phrase in "'Contenido'" "'Título'" "Dejar vacío para usar la versión en español."; do
  has "$phrase" "$flatex" \
    || fail "$f's Spanish-primary example is missing $phrase"
done
# ...whose keys and names are still English, which is the half that gets lost in translation.
has "'name' => 'hero_title'," "$flatex" \
  || fail "$f's Spanish-primary example translated the field name; the name is the meta key and stays English"
has "'key' => 'field_hero_title'," "$flatex" \
  || fail "$f's Spanish-primary example translated the field key; keys stay English"
has "'name' => 'hero_title_en'," "$flatex" \
  || fail "$f's Spanish-primary example does not show the suffix on the SECONDARY language"

# 5. UTF-8 literals. The label reached the editor as its own source text before this.
# Scoped to a label VALUE, not to the word anywhere: the section above names `&ntilde;` in
# prose precisely to forbid it, and a whole-file grep would fail on its own warning.
grep -Eq "'label' => '[^']*&[a-zA-Z]+;" "$f" \
  && fail "$f writes a label as an HTML entity; these files are UTF-8 and whether the entity reaches the screen as a letter or as its own source text depends on how the admin escapes that string"

# 6. The skill says the same thing. It is what the agent reads for the suffix convention, and
# a skill that still calls the English wording THE rule undoes the agent's instruction.
has 'name the PRIMARY language, and are written in it' "$flatskill" \
  || fail "$skill still gives one English instruction string as the rule for secondary fields"
has 'Dejar vacío para usar la versión en español.' "$flatskill" \
  || fail "$skill shows no non-English fallback instruction"
has 'translating one orphans the rows' "$flatskill" \
  || fail "$skill does not warn that a translated field name orphans stored rows"

echo "PASS: editor-facing strings follow the site's primary language, names and keys stay English, and the suffix marks the secondary language"
