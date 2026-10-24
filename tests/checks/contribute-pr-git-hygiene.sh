#!/usr/bin/env bash
# Two gaps in the contributor and fix flows:
#   - /wp-contribute pr opened the PR without the local diff review CI runs with OCR, and
#     `review` (a skill review) was easy to mistake for it.
#   - /wp-update and the /wp-audit fix step edited with no check that the git tree was clean;
#     several sessions ended with uncommitted work, and one session's commit swept up
#     thousands of deleted plugin files it never touched.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
has() { grep -Fq -- "$2" "$1" || fail "$1 lost: $2"; }

has commands/wp-contribute.md 'Before the push, review the diff with OCR'
has commands/wp-contribute.md 'If `ocr` is not installed, stop'
has commands/wp-contribute.md 'It does not review a diff'
has skills/wp-contributing/SKILL.md 'Before the push, review the diff with OCR'
has skills/wp-contributing/SKILL.md 'do not install it'
has skills/wp-contributing/SKILL.md 'not a diff'

has commands/wp-update.md 'git status --short | head -20'
has commands/wp-update.md 'git add <paths>'
has commands/wp-update.md 'more than 50 deleted files'
has skills/wp-audit-run/references/fix.md 'Git hygiene for any phase that edits'
has skills/wp-audit-run/references/fix.md 'git status --short | head -20'
has skills/wp-audit-run/references/fix.md 'git add <paths>'
has skills/wp-audit-run/references/fix.md 'more than 50 files are deleted'
has skills/wp-audit-run/references/fix.md 'since the last reviewed point'
echo "PASS: contribute pr and git hygiene wording present"
