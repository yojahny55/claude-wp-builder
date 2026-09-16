#!/usr/bin/env bash
# Seeding may invent a biography. It may not invent something that resolves to a real person,
# and whatever it invents has to be listed for the client.
set -euo pipefail
cd "$(dirname "$0")/../.."

# Flatten before matching multi-word prose: a line wrap inside one of these phrases
# would silently break the plain grep, the exact failure mode the sibling checks
# (wp-research.sh, design-value-transfer.sh, wp-tailwind-migrate.sh) already guard against.
flat() { tr '\n' ' ' | sed -e 's/  */ /g'; }

s=commands/wp-seed.md
[ -f "$s" ] || { echo "FAIL: $s missing"; exit 1; }
t=$(flat < "$s")

grep -q 'Values the demo does not supply' <<<"$t" || { echo "FAIL: /wp-seed has no contract for values with no source"; exit 1; }
grep -qi 'resolve to a real person' <<<"$t" || { echo "FAIL: /wp-seed does not forbid generating real-resolvable identities"; exit 1; }
grep -qi 'stay EMPTY' <<<"$t" || { echo "FAIL: /wp-seed does not say those fields stay empty"; exit 1; }
grep -qi 'one shape for the whole site' <<<"$t" || { echo "FAIL: /wp-seed does not require one shape for generated contact values"; exit 1; }
grep -qi 'Invented, needs client data' <<<"$t" || { echo "FAIL: /wp-seed does not require the invented-values list"; exit 1; }

echo PASS
