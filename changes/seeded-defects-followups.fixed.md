- **Agent reports in the shapes agents actually write.** A live audit over the seeded-defects
  corpus found every seeded defect, and showed four of five agents writing `not_applicable`
  and `unmeasured` as maps keyed by check id and leaving out `category`. The aggregator read
  only arrays, so Step 6.8 saw those checks as never reported. `bin/lib/audit-schema.mjs` now
  reads the map form, takes a missing category from the `wp-audit-<x>.json` file name, and
  moves a scan note written into `findings` (`check: "VENDOR"`, `status: "INFO"`) to the
  report's notes. The dispatch prompt carries a literal JSON skeleton, and
  `wp-audit-standards` says a `root_cause` slug is one defect with one fix: a SQL injection
  and a missing nonce in one function keep separate slugs. The seeded-defects comparison
  counts a code folded under `also_affects` as fired. The WordPress fixture strips the
  corpus's `SEEDED` markers, which were served in the page source, and verifies core against
  its checksums: WP-CLI's PharData extraction cuts file names over 100 characters, so it
  re-extracts the cached tarball with the system `tar` and stops if core still does not verify.
