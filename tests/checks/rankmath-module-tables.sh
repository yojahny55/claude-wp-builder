#!/usr/bin/env bash
# Rank Math modules enabled by writing `rank_math_modules` never get their tables: the
# option skips the activation routine that creates them. On a real build 404-monitor and
# redirections then ran two failing queries per request, and TTFB sat at 1.7-5.8 s until
# `RankMath\Installer::create_tables()` ran (0.5-0.7 s after). Nothing on the page shows
# it, so the configurator must create and verify the tables, and the audit must catch a
# site where nobody did.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

rm=agents/wp-audit-rankmath.md
perf=agents/wp-audit-performance.md
skill=skills/wp-audit-seo-standards/SKILL.md

for f in "$rm" "$skill"; do
  grep -Fq 'RankMath\Installer::create_tables(get_option("rank_math_modules"))' "$f" \
    || fail "$f enables modules without creating their tables"
done
for t in rank_math_404_logs rank_math_redirections; do
  grep -Fq "$t" "$rm" || fail "$rm does not verify the $t table exists"
  grep -Fq "$t" "$perf" || fail "$perf does not check the $t table"
done
grep -Fq 'MISSING' "$rm" || fail "$rm's table verification never reports a missing table"
grep -qE '^\| PERF-060 \| Rank Math module on without its table' "$perf" \
  || fail "$perf has no tabulated PERF-060 row for a module without its table"

echo PASS
