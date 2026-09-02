#!/usr/bin/env bash
# The contributor skill and /wp-contribute teach the conventions this repo enforces, so they
# are the two files most able to teach a WRONG one. Each assertion below pins a rule that was
# learned by breaking it — a contributor who follows a stale instruction here reintroduces the
# exact defect the rule exists to prevent, and no runtime error will tell them.
#
# This check also dogfoods its own rule: new behavior gets a check.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

s=skills/wp-contributing/SKILL.md
c=commands/wp-contribute.md
d=bin/doc-sync-check.sh

for f in "$s" "$c" "$d"; do [ -f "$f" ] || fail "$f is missing"; done
[ -x "$d" ] || fail "$d is not executable"

# ---------------------------------------------------------------------------
# 1. Frontmatter — the loader contract each layer's own docs must satisfy.
# ---------------------------------------------------------------------------
awk 'NR<=8 && /^user-invocable: false/ { f = 1 } END { exit !f }' "$s" \
  || fail "$s does not declare user-invocable: false — a skill that reads as invocable invites the 'skills act' mistake it warns against"
awk 'NR<=8 && /^trigger:/ { f = 1 } END { exit !f }' "$s" \
  || fail "$s has no trigger, so it never auto-loads and a contributor never sees it"
awk 'NR<=8 && /^argument-hint:/ { f = 1 } END { exit !f }' "$c" || fail "$c has no argument-hint"

# ---------------------------------------------------------------------------
# 2. The layer rule. "Dispatch, never reimplement" is the single most expensive
#    thing to get wrong: a second implementation diverges silently.
# ---------------------------------------------------------------------------
grep -Eqi 'never reimplement|not reimplement|reimplement(ing)? a builder' "$s" \
  || fail "$s does not state that a command dispatches builders rather than reimplementing them"
grep -Fq 'user-invocable: false' "$s" || fail "$s does not state the skill contract"
grep -Eqi 'skills inform' "$s" || fail "$s does not state that skills inform and never act"

# ---------------------------------------------------------------------------
# 3. Tests-are-grep-gates. A contributor who does not learn this writes no check
#    at all, because there is no test framework to imitate.
# ---------------------------------------------------------------------------
grep -Fq 'tests/checks' "$s" || fail "$s never points at tests/checks/"
grep -Eqi 'grep gate|grep-gate' "$s" || fail "$s does not explain that checks are grep gates over prose"
grep -Eqi 'would (still )?pass with the (contract )?sentence deleted|satisfied by deleting' "$s" \
  || fail "$s does not warn that an assertion which survives deleting the contract protects nothing"

# ---------------------------------------------------------------------------
# 4. The two i18n systems. Mixing them fatals a theme; the choice is recorded,
#    never guessed.
# ---------------------------------------------------------------------------
grep -Fq 'i18n strategy' "$s" || fail "$s does not name the recorded 'i18n strategy' line"
grep -Fq 'polylang' "$s" || fail "$s does not cover the Polylang model"
grep -Eqi 'options' "$s" || fail "$s omits the options-page crossover, the one place suffixes survive under Polylang"

# ---------------------------------------------------------------------------
# 5. Version discipline. A contributor bumping the version guarantees a conflict;
#    a maintainer bumping three of four ships a marketplace entry that disagrees.
# ---------------------------------------------------------------------------
grep -Eqi 'do not bump|never bump|no version bump' "$s" \
  || fail "$s does not tell contributors to leave the version alone"
grep -Fq 'marketplace.json' "$s" || fail "$s does not name every file holding the version"
grep -Eqi 'four (files|version references|places)|all four' "$s" \
  || fail "$s does not say how many places state the version"
grep -Eqi 'do not bump|no version bump' "$c" \
  || fail "$c does not gate the version bump to the release path"

# ---------------------------------------------------------------------------
# 6. No AI attribution — the repo's own commit rule, stated where a contributor
#    using an AI tool will actually read it.
# ---------------------------------------------------------------------------
for f in "$s" "$c"; do
  grep -Eqi 'no AI attribution|Co-Authored-By' "$f" \
    || fail "$f does not state the no-AI-attribution commit rule"
done

# ---------------------------------------------------------------------------
# 7. The stacked-PR squash hazard. Squash-merging a base branch strands its
#    child re-proposing the parent's whole diff; this is the recovery.
# ---------------------------------------------------------------------------
grep -Eqi 'squash' "$s" || fail "$s does not cover the squash hazard for stacked PRs"
grep -Fq 'rebase --onto' "$s" || fail "$s names the squash hazard but not the recovery"
grep -Eqi 'delete head branches|automatically delete' "$s" \
  || fail "$s does not explain that auto-delete is what makes GitHub retarget a stacked PR"

# ---------------------------------------------------------------------------
# 8. The command must actually run both gates — the suite alone misses doc drift,
#    which is how phantom command rows survived two releases.
# ---------------------------------------------------------------------------
grep -Fq 'bin/doc-sync-check.sh' "$c" || fail "$c does not run the doc-sync gate"
grep -Fq 'tests/checks' "$c" || fail "$c does not run the check suite"
grep -Eqi 'loosening its assertion|do not .fix. a failing check' "$c" \
  || fail "$c does not forbid fixing a red check by weakening it"

# ---------------------------------------------------------------------------
# 9. The gate itself must keep asserting both drift directions. Dropping the
#    phantom-row direction is what let /wp-robin and /wp-aos-animator sit in the
#    README as commands that never existed.
# ---------------------------------------------------------------------------
grep -Fq 'docs/commands.md' "$d" || fail "$d does not check docs/commands.md"
grep -Eqi 'does not exist' "$d" || fail "$d lost the phantom-command direction"
grep -Fq 'CHANGELOG.md' "$d" || fail "$d does not require a CHANGELOG entry for behavior changes"
grep -Fq 'marketplace.json' "$d" || fail "$d does not verify the version references agree"

# 9a. Rules tightened after review of #35. Each was a way for the gate to pass on
#     a repo it should have failed, so each is pinned against being loosened back.
grep -Fq 'user-invocable: false' "$d" \
  || fail "$d accepts any user-invocable value again — 'true' is precisely the state the layer rules forbid"
grep -Eq 'for doc in .\$README. .\$DOCS.' "$d" \
  || fail "$d scans only one file for phantom command rows; a phantom row in the reference is as misleading as one in the README"
grep -Fq 'in_table_row' "$d" \
  || fail "$d matches documentation anywhere in the file again — a prose mention would satisfy it, leaving the command out of every table a reader scans"
# The prose loophole is only closed if EVERY layer uses the row matcher. Skills and
# agents were left on a whole-file grep in the first pass, and the README discusses
# wp-robin and wp-aos-animator in prose outside the skills table — so their rows
# could be deleted and the gate still passed.
for layer in 'skill $sk' 'agent $a'; do
  grep -Fq "in_table_row \"\$README\" \"${layer##* }\"" "$d" \
    || fail "$d checks ${layer%% *}s with something other than the table-row matcher — the prose loophole is open for that layer"
done
grep -Fq 'Unreleased' "$d" \
  || fail "$d accepts a touched CHANGELOG again — a whitespace edit to an old release note is not an [Unreleased] entry"
! grep -Eq '^[[:space:]]*mapfile ' "$d" \
  || fail "$d calls mapfile, which is bash 4+; macOS ships bash 3.2 and the gate would abort there"
grep -Eq 'awk -F.\|' "$d" \
  || fail "$d no longer matches on the first cell of a table row; a name appearing in some other row's description cell would count as documented"
grep -Fq '|| true' "$d" \
  || fail "$d extracts versions without '|| true'; under set -euo pipefail a MISSING version aborts the script before it can report"
grep -Fq 'allowed-tools' "$d" || fail "$d no longer checks command frontmatter beyond description"
grep -Eq 'for key in name description tools model' "$d" \
  || fail "$d no longer checks the full agent frontmatter contract"

# ---------------------------------------------------------------------------
# 10. Both are documented where a contributor looks.
# ---------------------------------------------------------------------------
grep -Fq 'wp-contributing' README.md || fail "the wp-contributing skill is not in README.md's skills table"
grep -Fq 'wp-contribute' CONTRIBUTING.md \
  || fail "CONTRIBUTING.md — the front door — never mentions /wp-contribute"

# ---------------------------------------------------------------------------
# 11. And the gate actually passes on this repo right now.
# ---------------------------------------------------------------------------
bash "$d" >/dev/null || fail "$d fails against the current repository"

echo PASS
