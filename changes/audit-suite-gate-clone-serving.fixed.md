- **Three audit gaps found on real runs of a local clone.** The browser suite (Step 6.5) held the
  production gate's per-host lock for many minutes while Step 6 agents waited, exited 5 and reported
  `UNMEASURED: production gate busy`; the docs now order it to start only after every agent has
  returned. Timing and size metrics (LCP, FCP, TBT, Lighthouse score, bytes) measured on a clone
  were reported as the site's although they inherit the clone's serving layer (one baseline came
  from a 468 KB uncompressed stylesheet that production serves as 69 KB of brotli over h2); they
  are now probed against production's, labelled `clone measurement — serving layer differs`, and
  never a baseline or finding by themselves. Cache-purge instructions now say that on a clone only
  local caches are purged, because `wp cfcache purge_cache` can call the real Cloudflare API with
  production credentials restored from the database.
