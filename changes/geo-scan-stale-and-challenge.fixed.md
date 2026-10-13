- **`geo-scan.sh` no longer presents two kinds of report as the site's current score.** A
  report that already existed was printed with exit 0 whatever its age, so an audit run after
  fixes could read the previous day's scan. The script now prints the report's `scanned_at`
  age on stderr and, past 24 h (`--max-age-hours N` or `GEO_SCAN_MAX_AGE_HOURS`), re-requests
  a scan through the same call the no-report path uses (with `--start`); a report it cannot
  refresh is printed marked `STALE:` with the new exit `4`. A report whose body is a CDN
  bot-challenge page (the scanner was served "One moment, please..." and scored that) is no
  longer printed as a score: it exits `2` with `SKIP: CHALLENGED` and the evidence. The
  audit docs map these to `Live scan: <score> (stale: scanned <date>)` and
  `Live scan: unavailable — challenged by a bot interstitial`.
