#!/usr/bin/env bash
# /wp-yolo is thirty to fifty dispatches and the better part of an hour, and until the
# build ledger existed an interruption threw all of it away: the only way to run the
# command again was from Step 2, which converts demo/*.html in place and regenerates the
# manifest the build reads. The command refused to run twice for exactly that reason.
#
# So the resume contract is not "let it run twice". It is a second entrypoint that starts
# after the destructive steps have already finished, and every assertion here pins one of
# the properties that makes that safe rather than merely convenient:
#
#   - it enters at Step 4, never earlier (skipping 2/2.6 IS the mechanism)
#   - a unit is done when the ledger says so AND its artifact is still on disk
#   - a changed input refuses, naming what moved
#   - the ledger records generation and never verification
#
# Drop any one of those and the command still completes and still reports success, which
# is the defect shape this whole item exists to prevent.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

f=commands/wp-yolo.md
[ -f "$f" ] || fail "$f is missing"
[ -r "$f" ] || fail "$f exists but cannot be read"

# Every needle below is a phrase from running prose, and prose wraps. grep -F matches
# within a line, so a needle spanning a line break silently misses and the assertion
# reports the contract as absent when it is present -- the one failure mode that makes a
# check worse than no check. Flatten the file to a single space-separated line first.
flat=$(tr '\n' ' ' < "$f" | tr -s ' ')

# -- guards against the needle itself being wrong ----------------------------
# `--needle` starts with a dash and grep parses it as an option without the `--`
# terminator, so the check would die with a usage error instead of reporting a miss.
need() {
  printf '%s' "$flat" | grep -Fq -- "$1" || fail "$2"
}

# ---------------------------------------------------------------------------
# 1. The flags exist and are documented where arguments are parsed.
# ---------------------------------------------------------------------------
need '**`--resume`** = continue an interrupted run' \
  "Step 1 does not document --resume. A flag the command accepts but never defines is one an operator only discovers by reading the implementation"
need '**`--accept-drift`** = with `--resume` only' \
  "Step 1 does not document --accept-drift, or does not scope it to --resume"

# ---------------------------------------------------------------------------
# 2. Where a resume enters. This is the whole mechanism: Steps 2, 2.5, 2.6 and 3 are the
#    ones that convert demo/*.html in place and rewrite the manifest, so a resume that
#    started where a build starts would reproduce the silent degradation the command
#    already refuses to risk -- normalize re-deriving cssRules from Tailwind-native
#    markup that no longer carries the declarations they came from.
# ---------------------------------------------------------------------------
need 'Skips Steps 2, 2.5, 2.6 and 3 entirely' \
  "Step 1's --resume bullet does not say which steps it skips. 'Resume' without that reads as 'run it again', which is the path that empties the manifest"
need '`--resume` enters **here**, at Step 4' \
  "Step 4.0 does not state that --resume enters at Step 4. An entrypoint whose position is implied rather than stated is one a later edit moves without noticing"

# ---------------------------------------------------------------------------
# 3. Refusing when there is nothing to resume. --resume against a project with no ledger
#    is a typo; treating it as a fresh build overwrites a finished site.
# ---------------------------------------------------------------------------
need 'Error: no demo/.yolo-progress.json' \
  "Step 4.0 does not refuse --resume when no ledger exists"
need 'is a typo, not a request for a fresh build' \
  "Step 4.0 does not say WHY a missing ledger refuses instead of falling back to a normal build -- and the fallback is the dangerous reading"

# ---------------------------------------------------------------------------
# 4. Drift. A resume across a changed manifest builds half a theme from one input and
#    half from another, and nothing downstream fails: the parity gate measures the built
#    site against the demo as it stands now, so the stale half is wrong and green.
# ---------------------------------------------------------------------------
need 'Re-digest `demo/.yolo-manifest.json` and every page named in' \
  "Step 4.0 does not re-digest the inputs on resume, so drift cannot be detected at all"
need 'changed since the interrupted run' \
  "Step 4.0 has no drift refusal message"
need 'units completed against the previous version' \
  "the drift refusal does not say how far the previous run got -- an operator cannot judge whether to rebuild or accept without knowing what is at stake"
need 'Rebuild from scratch:' \
  "the drift refusal does not offer the rebuild path"
need 'Continue anyway:' \
  "the drift refusal does not offer --accept-drift, leaving an operator who edited the manifest on purpose with no way forward but a full rebuild"
# --force already means four different things in this command. --accept-drift folding
# into it would make one flag silently authorise building from mixed inputs.
need 'is **not** implied by `--force`' \
  "Step 4.0 does not state that --accept-drift is independent of --force"

# ---------------------------------------------------------------------------
# 5. Verify before skipping. A ledger can outlive the files it describes. Trusting it
#    alone leaves a hole the build reports as filled.
# ---------------------------------------------------------------------------
need 'file missing or empty** → **it is not done.**' \
  "Step 4.0 does not treat a ledger entry whose artifact is gone as not-done. Skipping on the ledger alone is how a resume leaves a hole it reports as filled"
need 'rebuilt-because-missing' \
  "Step 4.0 does not require rebuilt-because-missing units to be reported. It is the only signal that the ledger and the theme directory had diverged"

# ---------------------------------------------------------------------------
# 6. What the ledger must NOT cover. Both halves cause a defect if added:
#    a stale entry for an idempotent command skips a seed the demo needs, and an entry
#    for a measurement reports a gate result for a build that no longer exists.
# ---------------------------------------------------------------------------
need 'the ledger covers work that generates, never work that verifies' \
  "Step 4.0 does not state the generate-vs-verify rule. Without it the next author records the parity gate as a completed unit and a resumed build signs itself off unmeasured"
need 'These always run, on a resume exactly as on a fresh build' \
  "Step 4.0 does not say the measuring steps re-run on a resume"
need 'A resume simply runs it' \
  "Step 4.0 does not say that /wp-seed is re-run rather than ledgered, so a future edit adds a second source of truth for re-entrancy the command already owns"

# ---------------------------------------------------------------------------
# 7. The ledger file: where it lives, and that it is not configuration. .wp-create.json
#    is parsed by every command on every run; this is transient build state that dies
#    with the demo folder. Same argument that put the audit findings ledger in its own
#    file.
# ---------------------------------------------------------------------------
need '`demo/.yolo-progress.json`, beside the manifest — not in `.wp-create.json`' \
  "Step 4.0 does not place the ledger outside .wp-create.json, or does not say why"

# ---------------------------------------------------------------------------
# 8. Lifecycle. A ledger written only under --resume never exists when it is needed; a
#    ledger that outlives its build is a --resume aimed at a site that needs nothing.
# ---------------------------------------------------------------------------
need 'on **every** run, not only under `--resume`' \
  "Step 4.0 does not require the ledger on every run. One written only when resuming never exists at the moment an interruption creates the need for it"
need 'Delete it on a successful completion' \
  "Step 4.0 does not delete the ledger when the build finishes"
need 'delete it before Step 2 on a `--force`' \
  "Step 4.0 does not delete the ledger on a --force rebuild, where every digest in it is about to describe inputs that no longer exist"

# ---------------------------------------------------------------------------
# 9. How entries are written. Batching at the end of a phase loses exactly the units a
#    crash interrupted, and a non-atomic write turns a crash mid-write into the loss of
#    every unit recorded before it.
# ---------------------------------------------------------------------------
need 'the moment a unit returns' \
  "Step 4.0 does not require per-unit appends. A batch at the end of a phase loses precisely the units an interruption took"
need 'never in a batch at the end of a phase' \
  "Step 4.0 does not rule out batching ledger writes"
need 'Write it through a temp file and `mv`' \
  "Step 4.0 does not require an atomic ledger write"

# ---------------------------------------------------------------------------
# 10. Granularity. A section is one unit, not three: /wp-section dispatches three agents
#     in parallel, and recording any of them individually would let a resume skip a
#     section that has one agent's output and not the others'.
# ---------------------------------------------------------------------------
need 'A section is one unit, not three' \
  "Step 4.0 does not state that a section is a single unit, so a resume could skip a section built by one of its three parallel agents"
need 'There is no resume inside a unit' \
  "Step 4.0 does not rule out intra-unit resume, which is the only thing keeping partial state out of the design"

# ---------------------------------------------------------------------------
# 11. The gate. --resume must bypass refuse-to-run-twice (built template parts are the
#     state it exists for) and must bypass nothing else -- FAILED.md, a missing
#     .claude/CLAUDE.md and an invalid manifest do not describe an interrupted run.
# ---------------------------------------------------------------------------
need '**`--resume` bypasses this gate, and only this gate.**' \
  "Step 1 does not scope what --resume bypasses. A resume that also skipped the FAILED.md stop would build on a demo that never passed verification"

echo "PASS: /wp-yolo resume entrypoint, build ledger, drift refusal and verify-before-skip are all pinned"
