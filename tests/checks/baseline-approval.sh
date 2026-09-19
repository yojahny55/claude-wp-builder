#!/usr/bin/env bash
# Baseline images change only through an explicit review step (I06).
#
# The review step is a commit message. Any commit that touches tests/baselines/ must open
# its subject with "baseline: <why>". That is a small ceremony, and it is aimed at one
# specific reflex: a visual check goes red, and the fastest way to green is to regenerate
# the PNGs and push. Under that reflex the baseline stops being an approved artifact and
# becomes a record of whatever the code last did, which is worse than having no baseline
# at all -- it reads as approval nobody gave.
#
# What this can enforce: that the change was deliberate and carries a stated reason, in
# its own commit, where a reviewer reading `git log` cannot miss it.
# What it cannot enforce: that anyone actually LOOKED at the images. No check can. The
# ceremony makes the claim explicit and attributable; judging it is the reviewer's job.
set -euo pipefail
cd "$(dirname "$0")/../.."

fail() { echo "FAIL: $*"; exit 1; }

BASELINES="tests/baselines"
[ -d "$BASELINES" ] || fail "$BASELINES is missing"

# The range to inspect. On a PR, CI passes the base branch; locally, origin/main is the
# useful default. With neither, there is nothing to compare against and the honest answer
# is to say so rather than to pass vacuously.
base="${1:-}"
if [ -z "$base" ]; then
  if git rev-parse --verify --quiet origin/main >/dev/null; then
    base="origin/main"
  else
    echo "SKIP: no base to compare against (pass one, or fetch origin/main)"
    exit 0
  fi
fi
git rev-parse --verify --quiet "$base" >/dev/null || fail "base ref '$base' does not exist"

range="$base..HEAD"
# --no-merges: a merge commit reports its parents' files as changed, so every merge of a
# branch that touched a baseline would demand the token from a commit message git wrote
# itself. Measured -- without this, merging main into a branch failed the check.
commits="$(git log --no-merges --format=%H "$range" -- "$BASELINES" || true)"

if [ -z "$commits" ]; then
  echo "PASS: no baseline images changed in $range"
  exit 0
fi

bad=0
n=0
while read -r sha; do
  [ -n "$sha" ] || continue
  n=$((n + 1))
  subject="$(git log -1 --format=%s "$sha")"
  files="$(git show --name-only --format= "$sha" -- "$BASELINES" | tr '\n' ' ')"
  case "$subject" in
    baseline:*)
      # A reason, not just the token. "baseline:" alone says a human typed nine
      # characters; it does not say what they approved.
      reason="${subject#baseline:}"
      reason="$(printf '%s' "$reason" | tr -d '[:space:]')"
      if [ ${#reason} -lt 10 ]; then
        echo "FAIL [${sha:0:8}] 'baseline:' carries no reason -- say what changed and why it is correct"
        echo "     subject: $subject"
        bad=1
      else
        echo "ok   [${sha:0:8}] $subject"
      fi
      ;;
    *)
      echo "FAIL [${sha:0:8}] changed baselines without approval"
      echo "     subject: $subject"
      echo "     files:   $files"
      echo "     a commit touching $BASELINES must start its subject with 'baseline: <why>'"
      bad=1
      ;;
  esac
done <<EOF
$commits
EOF

[ "$bad" -eq 0 ] || fail "baseline images changed outside the review step"
echo "PASS: all $n baseline change(s) in $range carry an explicit approval"
