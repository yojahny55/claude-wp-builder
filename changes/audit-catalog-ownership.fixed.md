- **`/wp-audit` scores each defect once, audits to WCAG 2.2 AA, and no longer writes reports
  into the site.** The accessibility auditor now targets WCAG 2.2 AA and tabulates the new
  criteria as A11Y-070 to A11Y-074 (focus obscured, accessible authentication, dragging
  movements, redundant entry, consistent help). The PHP version floor is `>= 8.2` and lives
  only in SEC-026 (now revision 2); PERF-040 and WP-042 point at it. A "Same defect, one
  owner" table names the owner of defects listed under several ids (XML-RPC, `WP_DEBUG`,
  escaping, dangerous functions, `wp_body_open`, image alt); when the owner ran, the parent
  marks the duplicates `N/A` instead of counting the defect twice, and owners and duplicates
  now carry the same severity. The SEO, accessibility and GEO auditors return their findings
  to the parent instead of writing `audit/` or `audit-results/` files inside the site. Unused
  and retired check ids are listed and never reused.
