#!/usr/bin/env bash
# wp-agentic-surfaces shipped two defects a real build's SEO audit caught:
#
# 1. The "is this a non-browser agent" UA sniff (`bot|crawl|spider|agent`) matches
#    "Googlebot" on `bot` alone, so a named search indexer received the markdown 404
#    body instead of the themed page a browser gets on the same URL — cloaking, even
#    though the mismatch was an accident of the pattern. Named indexers must be
#    excluded BEFORE the generic pattern and always get the human HTML.
# 2. `Content-Signal` was written as a robots.txt directive. No robots.txt grammar
#    defines that line, so a linter reports the whole file invalid over it. The spec
#    defines Content-Signal as an HTTP response header; it belongs on `send_headers`,
#    and stays in robots.txt only as a comment.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

f=agents/wp-agentic-surfaces.md
[ -f "$f" ] || fail "$f is missing"

# 1a. Named search indexers are matched and excluded inside wants_markdown().
grep -qE 'function <prefix>_wants_markdown' "$f" || fail "$f must define <prefix>_wants_markdown()"
grep -qi 'googlebot' "$f" || fail "$f must exclude googlebot from the agent/markdown sniff"
grep -qi 'bingbot' "$f" || fail "$f must exclude bingbot from the agent/markdown sniff"

# The indexer exclusion must appear, in source order, before the generic bot|crawl|spider
# pattern — excluding after would already have returned true for "Googlebot".
indexer_line=$(grep -n 'googlebot' "$f" | head -1 | cut -d: -f1)
generic_line=$(grep -n "bot|crawl|spider|agent|curl|wget|python|httpx|libwww|httpclient" "$f" | head -1 | cut -d: -f1)
[ -n "$indexer_line" ] && [ -n "$generic_line" ] || fail "$f is missing one of the two UA patterns"
[ "$indexer_line" -lt "$generic_line" ] || fail "$f must exclude named indexers BEFORE the generic bot pattern, not after"

# Applebot-Extended (the AI-training crawler, allowlisted in Step 4) must stay distinct
# from Applebot (the search indexer) — a careless exclusion would swallow both.
grep -qE '\(\?!-extended\)' "$f" || fail "$f must not exclude Applebot-Extended when excluding Applebot"

# Step 5's verification must actually probe as Googlebot and check the response, not just
# fetch the plain route.
grep -qF "'user-agent'" "$f" || fail "$f Step 5 must fetch a route while impersonating a named indexer"
grep -qF 'CLOAKING' "$f" || fail "$f Step 5 must fail loudly if a named indexer gets markdown"

# 2. Content-Signal is an HTTP header, not a robots.txt directive.
grep -qE "define\\( *'<prefix>_CONTENT_SIGNAL'" "$f" || fail "$f must define a shared Content-Signal constant"
grep -qE "header\\( *<prefix>_CONTENT_SIGNAL *\\)" "$f" || fail "$f must send Content-Signal as a response header"

# The robots_txt filter and the physical robots.txt writer (Step 4) must not emit a bare
# Content-Signal directive — only a comment form is legal robots.txt.
# The pattern is deliberately single-quoted: the agent file holds PHP SOURCE, where the
# old defect was written as the two characters backslash-n inside a double-quoted string
# (`$output .= "\nContent-Signal: ..."`). Matching a real newline would never fire.
! grep -qF '.= "\nContent-Signal: ai-train' "$f" || fail "$f must not append a bare Content-Signal line to robots.txt"
! grep -qE "\\\$robots \\.= 'Content-Signal: [a-z=,; -]+' \\. PHP_EOL;\$" "$f" \
  || fail "$f Step 4 must not write a bare Content-Signal directive into the physical robots.txt file"
grep -qE '# Content-Signal' "$f" || fail "$f must document Content-Signal in robots.txt only as a comment"

# GEO-D02's own row must no longer claim Content-Signal comes from the robots_txt filter.
! grep -qF '| GEO-D02 | robots AI crawler allowlist + `Content-Signal` — Step 4 and the `robots_txt` filter |' "$f" \
  || fail "$f GEO-D02 row still attributes Content-Signal to the robots_txt filter"

echo PASS
