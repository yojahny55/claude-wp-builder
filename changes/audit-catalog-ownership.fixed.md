- **`/wp-audit` scores each defect once, audits to WCAG 2.2 AA, and no longer writes reports
  into the site.** The accessibility auditor now targets WCAG 2.2 AA and tabulates the new
  criteria as A11Y-070 to A11Y-074 (focus obscured, accessible authentication, dragging
  movements, redundant entry, consistent help). The PHP version floor is `>= 8.2`, written
  only in SEC-026 and in the new "Same defect, one owner" table; PERF-040 and WP-042 point at
  it. That table names the owner of defects listed under several ids (PHP floor, XML-RPC,
  `WP_DEBUG`, escaping, dangerous functions, `wp_body_open`, image alt) and the `root_cause`
  slug owner and duplicates share, so the report's existing root-cause fold counts the defect
  once; a defect only the duplicate finds is still reported, at the owner's severity, and a
  folded id stays `still_failing` in the ledger. Rules that now report differently carry a
  revision (`SEC-026@2`, `SEC-008@2`, `PERF-029@2`, `PERF-040@2`, `WP-042@2`), and SEC-008
  joins WP-040 under the local-clone `INFO` ceiling. The SEO, accessibility and GEO auditors
  return their findings to the parent instead of writing `audit/` or `audit-results/` files
  inside the site. Unused and retired check ids are listed and never reused; new usability
  ids start after UX-058.
