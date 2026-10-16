- **A WooCommerce shopper-flow regression suite ships with the browser suite.** Performance
  and update work had no way to prove it broke nothing: the audit measures quality, not whether
  a customer can still search, add to cart and reach the checkout. `npm run test:regression` in
  `.wp-audit/suite/` (desktop and mobile projects, `@regression` tests) walks home, live and
  results search, archive filters and pagination, sorting, currency switching, product gallery,
  zoom and variations, AJAX add to cart, quick view, wishlist, cart update/remove/coupon,
  checkout validation, account forms, contact and newsletter forms, mobile menu, sticky header,
  an admin smoke and a final URL sweep recording JS errors and failed requests. Each flow is
  `PASS`, `FAIL` or `SKIP` with a reason, and a flow whose feature the site lacks skips rather than
  fails. It never places an order or presses the checkout button, and the two flows that write
  (contact, newsletter) run only on a local clone or with `allowWrites`, where a Contact Form 7
  `mail_failed` is accepted as the expected result of disabled mail. `REGRESSION_LABEL=before|after`
  names a run and `npm run regression:compare -- before after` exits 1 on any PASS to FAIL.
  Configured through a `regression` block in `audit.config.js`; the report lands in
  `results/regression/<label>.md`. `tests/checks/audit-regression-suite.sh` covers it.
