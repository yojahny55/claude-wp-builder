#!/usr/bin/env bash
set -euo pipefail

# Every audit check code must live in the agent's own check TABLE, not in prose
# appended after it — an agent only runs what Step 1/Step 2 tabulate. This check
# exists because a batch of SEO/PERF codes was once pasted below Step 3 with a
# note to "add these to the tables above", so none of them ever ran.

fail() { echo "FAIL: $1"; exit 1; }

# A code is "tabulated" when a line starts with `| <CODE> |`.
for spec in "agents/wp-audit-seo.md:SEO" "agents/wp-audit-performance.md:PERF"; do
  f=${spec%%:*}
  prefix=${spec##*:}
  [ -f "$f" ] || fail "$f is missing"
  for code in $(grep -oE "${prefix}-[0-9]{3}" "$f" | sort -u); do
    grep -qE "^\| ${code} \|" "$f" || fail "$f: ${code} is referenced but never tabulated"
  done
done

# No client or site names in the plugin's own docs — checks are generic.
if grep -rniE "mkadventure" agents/ skills/ commands/ >/dev/null 2>&1; then
  fail "a real client site is named in the plugin docs"
fi

# The rankmath agent runs top to bottom, so its steps must be in order.
nums=$(grep -oE "^## Step [0-9]+(\.[0-9]+)?" agents/wp-audit-rankmath.md | grep -oE "[0-9]+(\.[0-9]+)?")
prev=0
for n in $nums; do
  awk -v a="$n" -v b="$prev" 'BEGIN { exit !(a > b) }' \
    || fail "agents/wp-audit-rankmath.md: Step $n comes after Step $prev"
  prev=$n
done

# PHP glob() has no recursive **; a theme-wide scan that uses it silently skips
# functions.php at the theme root.
if grep -rn "glob(get_template_directory() . '/\*\*" agents/ skills/ >/dev/null 2>&1; then
  fail "glob() with '**' is not recursive in PHP — use RecursiveDirectoryIterator"
fi

echo PASS
