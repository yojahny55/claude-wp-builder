- **CI checks now measure what they claim.** `tests/run.sh` runs every check in parallel and counts a
  skip (a `SKIP` line, or a browser check's "static only -- NOT exercised" pass) apart from a pass.
  With `CHECKS_REQUIRE_BROWSER=1` those browser checks fail instead of skipping, and the browser job
  sets it for the ones its runner can serve. The syntax job also parses `.cjs` files, shellcheck now
  covers `tests/`, actions are pinned to commit SHAs, the WP-CLI phar is verified against its
  published checksum, and a push to main is no longer cancelled by the next one.
