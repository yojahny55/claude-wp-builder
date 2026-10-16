- **`bin/h2-proxy.mjs` and `bin/contrast-propose.mjs`, plus the performance lessons of a full
  store optimization.** Lighthouse on a clone behind a stock local server (HTTP/1.1, no
  compression) reports serving-layer artifacts as findings and doubles the simulated LCP.
  `h2-proxy.mjs` fronts a local HTTP site with HTTP/2, brotli and an anonymous-HTML cache using
  a throwaway certificate generated at runtime. `contrast-propose.mjs` turns failing contrast
  pairs into the nearest compliant shade with ratios before and after, for client approval.
  `performance-lessons.md` gains the lab recipe (5 runs, median), the used-CSS subset method
  and its carousel regression, deferring stylesheets that touch nothing above the fold, the
  JavaScript, image and layout-shift lessons. `tests/checks/perf-local-lab.sh` covers them.
