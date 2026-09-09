#!/usr/bin/env bash
# The gate is the whole difference between v1 and v2: a craft build that cannot
# render stops. The last failed build shipped because verification exited 2 and
# nobody noticed.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

d=commands/wp-demo.md
grep -Fq -- 'demo-verify.mjs" --probe' "$d" || fail "$d does not run the probe"
grep -Eqi 'exit(s| code)? 2' "$d" || fail "$d does not branch on probe exit 2"
grep -Fq 'npm i -D playwright-core' "$d" || fail "$d does not try to install playwright-core"
# Anchored to the gate itself: a bare 'stop' is satisfied by the verify loop's
# own stop-after-three-rounds, which would leave this check green with Step 0
# deleted outright.
grep -Fq 'probe again' "$d" || fail "$d does not retry the probe after installing playwright-core"
grep -Fq 'way **stop**' "$d" || fail "$d does not stop on a missing browser"
grep -Eqi 'only exit 0 continues|any other exit code' "$d" || fail "$d proceeds to build when the probe fails in any way other than exit 2"
grep -Eqi 'never fall(s)? back to plain|not fall back to plain' "$d" || fail "$d may still fall back to plain"
grep -Fq 'demo/DESIGN.md' "$d" || fail "$d does not write demo/DESIGN.md"
grep -Fq 'designlang' "$d" || fail "$d does not run designlang on the client's site"
grep -Fq 'design-md/INDEX.md' "$d" || fail "$d does not read the catalogue index"
grep -Fq 'compositions/README.md' "$d" || fail "$d does not plan from the composition role table"
grep -Fq 'data-motion-peak' "$d" || fail "$d does not mark the peak"
grep -Eqi 'three rounds' "$d" || fail "$d does not cap the loop"
# The loop must walk the directory: an index-only walk is how empty interior
# pages shipped, and it is also why the build step must name them.
grep -Fq '/wp-demo-verify demo/' "$d" || fail "$d verifies a single page instead of walking demo/"
grep -Fq 'one file per page' "$d" || fail "$d does not tell a craft build to write the interior pages"
grep -Eqi 'Steps 3 and 4 are the plain path' "$d" || fail "$d does not resolve what a craft build takes from Steps 3 and 4"
grep -Fq 'as a subagent' "$d" || fail "$d grades its own render instead of dispatching the critique"
grep -Fq 'demo/VERIFY.md' "$d" || fail "$d does not read the score card"
grep -Eqi 'no fingerprint|not record' "$d" || fail "$d records a fingerprint for a failing build"
grep -Fq '"design_md"' "$d" || fail "$d does not record design_md in the manifest"
grep -Fq 'firecrawl_url' "$d" || fail "$d does not document firecrawl_url"
grep -Eqi 'four device families|never the same device|signature move' "$d" && fail "$d still carries a removed v1 rule"
echo PASS
