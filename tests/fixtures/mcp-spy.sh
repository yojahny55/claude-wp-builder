#!/usr/bin/env bash
# Records the JSON-RPC a session actually sends to a stdio MCP server, then runs
# the real server. Point an .mcp.json command at this instead of at the server:
#
#   "command": "tests/fixtures/mcp-spy.sh",
#   "args": ["npx", "-y", "@yojahny/wp-design-library@^1.0.0", "serve"]
#
# with MCP_SPY_LOG set. Every request Claude sends is appended to that file
# before the server sees it, so `tools/call` lines are proof a build reached the
# server — which a citation in demo/BRIEF.md is not. A build can write a
# plausible slug it never fetched; it cannot write a line into this log.
#
# ponytail: stdin only. Responses are not captured because the question is what
# the build asked for, not what came back; tee the other direction too if a
# future check needs to assert on corpus content.
set -euo pipefail
: "${MCP_SPY_LOG:?set MCP_SPY_LOG to the file to append requests to}"
mkdir -p "$(dirname "$MCP_SPY_LOG")"
tee -a "$MCP_SPY_LOG" | "$@"
