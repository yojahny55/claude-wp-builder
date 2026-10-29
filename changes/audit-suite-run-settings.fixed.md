- **The browser suite completes on third-party-heavy sites.** On a site loading 160-250
  requests a page (video embeds, analytics, widgets) the suite timed out on every page and
  Tier 3 stayed UNMEASURED. Pages now load to `domcontentloaded` plus a bounded settle
  (`--settle`, default 5 s) instead of waiting for a network idle that never comes. The
  timeout brake sends one GET to the audited host after each timeout and counts it only when
  the host does not answer or refuses (403/429/503); a slow page on a host that answers, and
  a check that ran on a page a timeout had closed, are recorded in
  `results/unmeasured-pages.json` and reach the run file as `SUITE-PAGE-*` UNMEASURED rows
  with the reason, instead of tripping the brake or reading as a metadata error.
