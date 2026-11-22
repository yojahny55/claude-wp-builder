- **A family lint measures the Avoid items that are visible in CSS.** `bin/family-lint.mjs`
  reports `backdrop-filter` glass, a `border-radius` over 12px on a box with a border on all
  sides (pills and circles left out, `var()` resolved), and more than one saturated hue across
  a demo's colours, each with its file and line. `/wp-demo` hands the report to the verify
  critique, which names every finding in `demo/VERIFY.md` as an Avoid hit or as the family's
  deliberate exception. The lint never blocks and always exits 0, so a brutalist page's one
  intended exception stays the evaluator's decision. Before this, nothing measured the Avoid
  list: the evaluator found these by eye on contact sheets.
