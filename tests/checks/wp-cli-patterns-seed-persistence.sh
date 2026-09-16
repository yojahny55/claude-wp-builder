#!/usr/bin/env bash
# Content-writing scripts written straight into a session's scratchpad have
# one failure shape every time: the records they create survive in the
# database, the code that reproduces them does not, and neither a fresh clone
# nor a rollback can get it back. Measured on a real build: a whole content
# pass had to be reconstructed by reading the records back out of a live site
# because the scripts that seeded them were gone.
set -euo pipefail

flat() { tr '\n' ' ' | sed -e 's/  */ /g'; }

s=skills/wp-cli-patterns/SKILL.md
[ -f "$s" ] || { echo "FAIL: $s missing"; exit 1; }
t=$(flat < "$s")

grep -q '^## Non-Trivial Seed Logic Lives in `inc/seed/`' "$s" \
  || { echo "FAIL: wp-cli-patterns SKILL.md has no section on where non-trivial seed scripts belong"; exit 1; }
grep -qF 'inc/seed/data/' <<<"$t" \
  || { echo "FAIL: wp-cli-patterns does not say a seed script's data payload lives in inc/seed/data/"; exit 1; }
grep -qF '_<prefix>_seeded_content' <<<"$t" \
  || { echo "FAIL: wp-cli-patterns does not define the seeded-content marker meta convention"; exit 1; }
grep -qF '_<prefix>_seed_key' <<<"$t" \
  || { echo "FAIL: wp-cli-patterns does not define a stable seed-key convention -- a numeric post ID is not portable across installs"; exit 1; }
grep -qi "client's own edit always wins" <<<"$t" \
  || { echo "FAIL: wp-cli-patterns does not state that a client's edit must never be overwritten by a re-run"; exit 1; }
grep -qi 'scratchpad' <<<"$t" \
  || { echo "FAIL: wp-cli-patterns never names the scratchpad as the thing to avoid"; exit 1; }

# The command that actually runs seeding must point here, without landing
# inside the Phase 4/4.5/5 region another change already owns.
seed=commands/wp-seed.md
grep -q 'skills/wp-cli-patterns/SKILL.md' "$seed" \
  || { echo "FAIL: wp-seed.md never points at wp-cli-patterns' seed-persistence rule"; exit 1; }

echo PASS
