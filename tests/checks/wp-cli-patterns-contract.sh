#!/usr/bin/env bash
# wp-cli-patterns is loaded by every seeding and audit agent, and it was wrong in ways that
# produce broken sites rather than untidy ones:
#   - it taught `hero_title_es` suffix fields and per-language menu locations as THE
#     convention, without reading the recorded `i18n strategy` — on a Polylang project (the
#     default for new scaffolds) that seeds fields Polylang never serves and assigns menus to
#     `primary_en` / `primary_es`, locations that exist on neither strategy's starter;
#   - it glossed `wp post delete --force` as "skip confirmation prompts", when it deletes
#     permanently and bypasses the trash;
#   - it documented exits 0/1 for two scripts that also exit 2 when they could not measure,
#     so a deploy gate reading "not 1" as clean passed on a run that measured nothing;
#   - every invocation used a `<skill>/scripts/…` placeholder nothing can resolve.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

s=skills/wp-cli-patterns/SKILL.md
r=skills/wp-cli-patterns/references/seeding-recipes.md
for f in "$s" "$r" commands/wp-seed.md; do [ -f "$f" ] || fail "$f is missing"; done
skill_md=$(find skills/wp-cli-patterns -name '*.md' | sort)

# --- field names and menus follow the recorded i18n strategy --------------------
# Scoped to the section when its heading is there; the whole file otherwise, so a renamed
# heading weakens the scope instead of muting the check.
sec=$(awk '/^## Bilingual Field Names/{f=1; next} f && /^## /{exit} f{print}' "$s" | tr '\n' ' ' | sed 's/  */ /g')
[ -n "$sec" ] || sec=$(tr '\n' ' ' < "$s" | sed 's/  */ /g')
case "$sec" in *'Read the `i18n strategy` line'*) ;; *) fail "$s's bilingual section does not read the recorded i18n strategy" ;; esac
case "$sec" in *'options page'*) ;; *) fail "$s's bilingual section does not name the options page as Polylang's one suffixed exception" ;; esac
case "$sec" in *'An absent line means the project predates the choice and is `suffix`'*) ;; *)
  fail "$s's bilingual section does not state the absent-line fallback" ;; esac
grep -qF '`polylang`' "$r" || fail "$r has no polylang branch"
# Neither starter registers an underscore location; assigning to one is assigning nowhere.
grep -nE 'location assign .*(primary|footer|mobile)_(en|es)\b' $skill_md \
  && fail "a wp-cli-patterns recipe assigns a menu to an underscore location no starter registers"
grep -qF 'menu location list' "$r" \
  || fail "$r does not list the theme's registered locations before assigning one"

# --- a destructive flag is described as what it is ------------------------------
grep -qF 'skip confirmation prompts (e.g., `wp post delete' $skill_md \
  && fail "wp-cli-patterns still glosses wp post delete --force as a confirmation skip"
grep -qF 'permanently deletes, bypassing the trash' "$r" \
  || fail "$r does not say --force on wp post delete deletes permanently"

# --- every script's exit 2 is documented, in the skill and in the script --------
for script in check-dev-host find-orphan-acf-ids find-redeclared-functions find-missing-media-files resolve-link-targets; do
  f="skills/wp-cli-patterns/scripts/$script.php"
  grep -qE 'exit\( *2 *\)' "$f" || continue
  entry=$(awk -v h="### \`$script.php\`" 'index($0, h)==1{f=1; next} f && /^##/{exit} f{print}' "$s" | tr '\n' ' ')
  [ -n "$entry" ] || fail "$s has no entry for $script.php"
  case "$entry" in *' 2 '*|*'and 2'*|*'Exits 2'*|*'exits 2'*) ;; *)
    fail "$s's $script.php entry does not document exit 2, which the script returns when it could not measure" ;; esac
  # The header is the opening docblock. A bare `\b2\b` passed on "Step 2.3"; the 2 must sit
  # in the same sentence as an exit and not be part of another number.
  grep -qiE 'exit[^.]*[^0-9.]2[^0-9.]' <<<"$(awk '{print} /\*\//{exit}' "$f" | tr '\n' ' ')" \
    || fail "$f's header documents no exit 2, which it returns"
done
grep -qF 'Needs ACF or SCF active' "$s" \
  || fail "$s does not say find-orphan-acf-ids.php needs ACF or SCF"

# --- plugin paths resolve -------------------------------------------------------
grep -nF '<skill>/' $skill_md && fail "wp-cli-patterns still invokes scripts through an unresolvable <skill>/ placeholder"
grep -qF '${CLAUDE_PLUGIN_ROOT}/skills/wp-cli-patterns/scripts' "$s" \
  || fail "$s does not resolve its scripts through \${CLAUDE_PLUGIN_ROOT}"
grep -qF '${CLAUDE_PLUGIN_ROOT}/skills/wp-cli-patterns/SKILL.md' commands/wp-seed.md \
  || fail "commands/wp-seed.md cites wp-cli-patterns by a relative path, which resolves against the user's project"

echo PASS
