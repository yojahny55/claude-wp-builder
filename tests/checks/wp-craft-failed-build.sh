#!/usr/bin/env bash
# A craft build that fails verification must be unmistakable on disk and must
# stop every command that would build on it. Before v3.1 the only penalty was an
# unwritten fingerprint row — invisible to the client — so a build that failed
# five of seven rubric lines shipped with the shortfall as a footnote.
set -euo pipefail
cd "$(dirname "$0")/../.."

fail() { echo "FAIL: $*" >&2; exit 1; }

d=commands/wp-demo.md
grep -Fq 'demo/FAILED.md' "$d" \
  || fail "$d never writes demo/FAILED.md, so a failed build is indistinguishable from a passing one"
grep -Fq 'is not a deliverable' "$d" \
  || fail "$d does not say a failed craft build is not a deliverable"

# Every command that builds on a demo must refuse a failed one.
for c in commands/wp-init.md commands/wp-section.md commands/wp-yolo.md; do
  grep -Fq 'demo/FAILED.md' "$c" \
    || fail "$c does not stop on demo/FAILED.md, so a theme can be built from an unverified demo"
done

v=commands/wp-demo-verify.md
grep -Fq '## Round N' "$v" \
  || fail "$v does not require a per-round heading, so rounds cannot be counted from disk"
grep -Fq 'Findings judged to be capture artefacts' "$v" \
  || fail "$v does not require dismissals to be written under a named heading with measurements"

echo PASS
