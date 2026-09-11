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

# GEO codes carry a layer letter, so they need their own pattern. Both the auditor
# and the fixer must tabulate every GEO code they mention.
for f in agents/wp-audit-geo.md agents/wp-agentic-surfaces.md; do
  [ -f "$f" ] || fail "$f is missing"
  for code in $(grep -oE "GEO-[DAUP][0-9]{2}" "$f" | sort -u); do
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
# functions.php at the theme root. Match any quoting or concatenation style.
if grep -rnE 'glob\(.*\*\*' agents/ skills/ >/dev/null 2>&1; then
  fail "glob() with '**' is not recursive in PHP — use RecursiveDirectoryIterator"
fi

# A permalink is a prefix of its own paginated children, so a substring test reports
# /page/ as listed because /page/2/ is. Sitemap membership is an exact <loc> comparison.
if grep -n 'strpos(\\\$all, get_permalink' agents/wp-audit-rankmath.md >/dev/null 2>&1; then
  fail "wp-audit-rankmath.md: sitemap membership must compare whole URLs, not substrings"
fi

# The head snapshot issues one request per post against the site itself; it must stay capped.
grep -q 'posts_per_page.*\\\$limit' agents/wp-audit-seo.md \
  || fail "wp-audit-seo.md: the rendered-head snapshot must cap how many posts it fetches"

# A blanket link[media="print"] sweep also unhides the theme's real print stylesheet.
if grep -n 'querySelectorAll(.link\[media="print"\]' agents/wp-audit-performance.md >/dev/null 2>&1; then
  fail "wp-audit-performance.md: defer CSS per link, not by sweeping every media=print link"
fi

# sitemap_index.xml lists child sitemaps, not post URLs. Matching a permalink against
# the index alone never fires, and the check reports a clean sitemap either way.
grep -q "child sitemaps" agents/wp-audit-rankmath.md \
  || fail "wp-audit-rankmath.md: sitemap validation must follow the index into its child sitemaps"

# Head values must be parsed, not pattern-matched: a regex that assumes double quotes or
# rel-before-href returns '' on valid markup, which reads as "no finding" and passes a
# broken site.
grep -q "DOMXPath" agents/wp-audit-seo.md \
  || fail "wp-audit-seo.md: the rendered-head snapshot must parse the DOM, not regex the markup"
if grep -q 'preg_match.*rel=.*canonical' agents/wp-audit-seo.md; then
  fail "wp-audit-seo.md: canonical is being regexed out of the markup again"
fi

echo PASS
