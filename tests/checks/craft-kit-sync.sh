#!/usr/bin/env bash
# The kit carries a rules-only copy of the design floor so it stands alone, which means the
# two copies can drift apart silently, and a rule that exists in one repo and not the other
# is worse than no rule, because whichever path you took last is the one you trust.
#
# Set CSK_PATH to a cinematic-scroll-kit checkout to run the comparison; otherwise SKIP.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

c=commands/wp-cinematic-demo.md
a=agents/wp-cinematic.md

grep -Fq 'wp-demo-craft' "$c" || fail "$c does not read the wp-demo-craft skill"
grep -Fq 'wp-demo-craft' "$a" || fail "$a does not read the wp-demo-craft skill"
grep -Fq '/wp-demo-verify' "$c" || fail "$c does not verify with /wp-demo-verify"

if [ -z "${CSK_PATH:-}" ] || [ ! -d "${CSK_PATH:-}" ]; then
  echo "SKIP: set CSK_PATH to a cinematic-scroll-kit checkout to compare the rules copies"
  echo PASS
  exit 0
fi

k="$CSK_PATH/skills/06-anti-ai-editorial-design.md"
[ -f "$k" ] || fail "$k is missing, is CSK_PATH a cinematic-scroll-kit checkout?"
for t in 'em dash' 'gradient text' 'invented statistic' 'one engineered peak'; do
  grep -Fqi "$t" "$k" || fail "the kit's design skill has drifted: missing '$t'"
done

echo PASS
