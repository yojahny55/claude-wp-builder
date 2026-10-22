#!/usr/bin/env bash
# Three audit gaps: the browser suite held the production gate for minutes while agents starved
# (UNMEASURED: production gate busy); clone timing/size metrics were reported as the site's
# although they inherit the clone's serving layer; a CDN purge on a clone can hit the real zone.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
has() { grep -Fq -- "$2" "$1" || fail "$1 lacks: $2"; }

has commands/wp-audit.md "starts only after every Step 6 agent has returned"
has skills/wp-audit-run/references/browser-suite.md "Start it only after every Step 6 agent has returned"
has skills/wp-audit-run/references/dispatch.md "never run beside the agents"
has skills/wp-audit-run/references/site-context.md "inherit the clone's serving layer"
has skills/wp-audit-run/references/site-context.md "clone measurement — serving layer differs"
has skills/wp-audit-run/references/site-context.md "never a baseline and never a finding by itself"
has skills/wp-audit-run/references/browser-suite.md "clone measurement — serving layer differs"
has $(bash tests/checks/lib/agent-text.sh wp-audit-performance) "clone measurement — serving layer differs"
has skills/wp-cli-patterns/SKILL.md "## Purging caches on a clone"
has skills/wp-cli-patterns/SKILL.md "wp cfcache purge_fallback_cache"
for f in skills/wp-audit-run/references/fix.md $(bash tests/checks/lib/agent-text.sh wp-audit-performance) agents/wp-audit-rankmath.md commands/wp-cinematic-scene.md; do
  has "$f" "Purging caches on a clone"
done

echo PASS
