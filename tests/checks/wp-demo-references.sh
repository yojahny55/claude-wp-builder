#!/usr/bin/env bash
# Asserts a PRODUCED demo actually cites its reference servers, and — when a spy
# log is present — that the citations correspond to calls that really happened.
#
# Every other check in this directory greps a contract: it proves /wp-demo still
# SAYS to consult the library and inspo. None of them can see whether a build
# did. This one reads the build's own output instead, so it needs a demo:
#
#   DEMO_DIR=~/project/demo bash tests/checks/wp-demo-references.sh
#
# and, to prove the calls rather than the claims, the demo must have been built
# with tests/fixtures/mcp-spy.sh wrapping the server and MCP_SPY_LOG set to the
# same path passed here.
set -euo pipefail

DEMO="${DEMO_DIR:-}"
if [[ -z "$DEMO" ]]; then
  echo "SKIP: set DEMO_DIR to a demo/ directory produced by /wp-demo"
  exit 0
fi
[[ -d "$DEMO" ]] || { echo "FAIL: DEMO_DIR '$DEMO' is not a directory"; exit 1; }

fail() { echo "FAIL: $1"; exit 1; }

# Craft writes demo/BRIEF.md and cites under a '## References' heading; plain
# writes no brief and cites in an HTML comment at the top of index.html. Which
# mode ran is read off the artifacts, not asked — a brief that exists is craft.
if [[ -f "$DEMO/BRIEF.md" ]]; then
  MODE=craft
  grep -q '^## References' "$DEMO/BRIEF.md" \
    || fail "craft build: demo/BRIEF.md has no '## References' heading"
  # The section runs to the next '## ' heading or to EOF.
  CITES="$(awk '/^## References/{f=1;next} /^## /{f=0} f' "$DEMO/BRIEF.md")"
else
  MODE=plain
  [[ -f "$DEMO/index.html" ]] || fail "plain build: no demo/index.html to read citations from"
  # The contract puts the comment at the top; read the head rather than the file
  # so a 'References:' appearing in body copy cannot satisfy this.
  CITES="$(head -40 "$DEMO/index.html" | grep -E 'References:|^\s*inspo:' || true)"
fi

[[ -n "${CITES// /}" ]] || fail "$MODE build: the references section is empty — neither a citation nor a degrade line"

# Two degrade lines are verbatim contract strings. Either is a legitimate outcome
# (a server may genuinely be unregistered), so they PASS — but they are reported,
# because "it was unavailable" on every build is the signal that it is never wired.
LIB_DOWN=0; INSPO_DOWN=0
grep -q 'References: library unavailable' <<<"$CITES" && LIB_DOWN=1 || true
grep -q 'References: inspo unavailable'  <<<"$CITES" && INSPO_DOWN=1 || true

# Library lines start with the slug alone; inspo lines are prefixed 'inspo:'.
INSPO_N=$(grep -cE '(^|[^a-z])inspo:' <<<"$CITES" || true)
LIB_N=$(grep -vE '(^|[^a-z])inspo:|References:|^\s*$|^\s*<!--|^\s*-->' <<<"$CITES" | grep -cE '[a-z0-9]' || true)

if [[ "$MODE" == craft && "$LIB_DOWN" -eq 0 && "$LIB_N" -eq 0 ]]; then
  fail "craft build: no library citation and no 'References: library unavailable' line — the section says nothing either way"
fi
if [[ "$INSPO_DOWN" -eq 0 && "$INSPO_N" -eq 0 ]]; then
  echo "note: no inspo citation and no unavailable line — inspo is opt-in, so this is expected unless it was registered"
fi

# The spy log is the only evidence that survives a fabricated citation: a build
# can write a plausible slug it never fetched, but it cannot write a request into
# a transport log it does not control.
if [[ -n "${MCP_SPY_LOG:-}" ]]; then
  [[ -s "$MCP_SPY_LOG" ]] || fail "MCP_SPY_LOG '$MCP_SPY_LOG' is empty — the server was never started through the spy, so nothing about calls is proven"
  # No match is the normal case for most tool names, and under `set -o pipefail`
  # grep's exit 1 would take the whole check down instead of counting zero. The
  # guard has to sit on grep itself: `... | wc -l || true` only guards wc, and
  # the pipeline's status is still grep's. It survived before only because every
  # caller consumed the result inside $(( )), which set -e does not inspect.
  calls() { { grep -o "\"name\"[[:space:]]*:[[:space:]]*\"$1\"" "$MCP_SPY_LOG" || true; } | wc -l; }
  # Only tools unique to one server can attribute a call. The two inventories
  # are the live `tools/list` of wp-design-library@1.1.0 (add, add_batch,
  # get_entry, get_motion, get_vocab, recommend, refresh, save_entry, search,
  # set_fields, similar) and inspo-mcp@0.1.16 (search_screens, get_screen,
  # find_similar, get_site_pages, recommend, get_reference_jsx, find_by_color,
  # get_design_system, ...), probed 2026-09-21. `recommend` is defined by BOTH,
  # so counting it toward either lets an inspo-only build read as having reached
  # the library. It is reported and asserted on by neither. A renamed tool on
  # either server makes its count read 0 here, never a false positive.
  LIB_CALLS=$(( $(calls search) + $(calls get_entry) + $(calls similar) + $(calls get_motion) ))
  INSPO_CALLS=$(( $(calls search_screens) + $(calls get_screen) + $(calls find_similar) + $(calls get_site_pages) ))
  AMBIG=$(calls recommend)
  echo "spy: library tool calls=$LIB_CALLS  inspo tool calls=$INSPO_CALLS  ambiguous (recommend, both servers)=$AMBIG"

  # The exclusions in /wp-demo Step 2.6 sub-step 3.7 name two inspo tools that a
  # build may never reach: the colour table must never become tokens, and JSX is
  # never fetched. Until a transport log existed those were prose a reader had to
  # honour; here they are measurable, so a violation is a failure rather than a
  # ceiling. Both names are real tools on inspo-mcp@0.1.16 — a build CAN call them.
  for forbidden in get_reference_jsx find_by_color get_design_system; do
    n=$(calls "$forbidden")
    [[ "$n" -eq 0 ]] || fail "the build called inspo's '$forbidden' $n time(s) — /wp-demo Step 2.6 sub-step 3.7 forbids it (colour and JSX never cross the fence)"
  done
  if [[ "$LIB_N" -gt 0 && "$LIB_CALLS" -eq 0 ]]; then
    fail "demo cites $LIB_N library reference(s) but the spy log records no library tool call — the citations were not fetched"
  fi
  if [[ "$INSPO_N" -gt 0 && "$INSPO_CALLS" -eq 0 ]]; then
    fail "demo cites $INSPO_N inspo reference(s) but the spy log records no inspo tool call — the citations were not fetched"
  fi
  if [[ "$MODE" == craft && "$LIB_DOWN" -eq 0 && "$LIB_CALLS" -eq 0 ]]; then
    fail "craft build made no library tool call at all — the library is registered but /wp-demo never reached it"
  fi
else
  echo "note: MCP_SPY_LOG unset — citations are read as written, not verified against calls"
fi

echo "mode=$MODE library_citations=$LIB_N inspo_citations=$INSPO_N library_unavailable=$LIB_DOWN inspo_unavailable=$INSPO_DOWN"
echo PASS
