#!/usr/bin/env bash
# Seeding may invent a biography. It may not invent something that resolves to a real person,
# and whatever it invents has to be listed for the client.
set -euo pipefail
s=commands/wp-seed.md

grep -q 'Values the demo does not supply' "$s" || { echo "FAIL: /wp-seed has no contract for values with no source"; exit 1; }
grep -qi 'resolve to a real person' "$s" || { echo "FAIL: /wp-seed does not forbid generating real-resolvable identities"; exit 1; }
grep -qi 'stay EMPTY' "$s" || { echo "FAIL: /wp-seed does not say those fields stay empty"; exit 1; }
grep -qi 'one shape for the whole site' "$s" || { echo "FAIL: /wp-seed does not require one shape for generated contact values"; exit 1; }
grep -qi 'Invented, needs client data' "$s" || { echo "FAIL: /wp-seed does not require the invented-values list"; exit 1; }

echo PASS
