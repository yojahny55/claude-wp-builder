- **`/wp-clone` now disables payment gateways instead of only reporting them.** Step 5.5.2
  said reporting was the action, on the reasoning that a silent switch hides the bug a payment
  clone exists to reproduce. A clone that keeps an enabled gateway with live keys can charge or
  refund a real customer, so it now lists the enabled WooCommerce gateways, deactivates the
  plugin that owns each, sets `enabled` to `no` in `woocommerce_<gateway>_settings`, lists every
  one in the clone report and warns that the API keys stay stored and that reactivating a
  gateway points at the real API. Webhooks, live-mode options and other integrations are still
  reported only. `tests/checks/wp-clone-isolation.sh` asserts the new behaviour and that the
  report-only wording is gone. The mail guard section now also says `pre_wp_mail` does not stop
  code that drives PHPMailer directly, or a plugin that replaces `wp_mail()` wholesale, and that
  redefining `wp_mail()` in a must-use plugin is the stronger guard.
