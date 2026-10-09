- **`/wp-demo-verify --no-motion` stops an existing site from failing on an engine it never had.**
  `/wp-responsive-check` now dispatches to `/wp-demo-verify`, and a URL target runs against any
  page. Against a site the plugin did not build, every section on every page reported the
  blocking `no-engine` (40 rows across 5 pages in a real run, with overflow and clipped copy all
  clean), so the walk exited 1 for a reason that does not apply, which teaches people to ignore
  the gate. The flag drops the `no-engine` and `dead-scroll` judgments and keeps overflow,
  clipped copy, container-noop, the full-page shots and the Firefox pass. It is explicit rather
  than inferred because a converted plugin page that lost its engine looks identical and must
  still fail; without the flag a URL page with no `[data-motion]` only gains one line suggesting
  it. `/wp-responsive-check` passes it for existing sites.
