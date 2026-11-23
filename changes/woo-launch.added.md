- **`/wp-woo-launch` takes a store live on purpose.** Until now every store stayed in test
  mode and nothing switched it: the launch was a hand-off. The command runs only on
  production, checks the live Stripe keys and real Turnstile keys in `wp-config.php` without
  ever writing one, requires a clean `/wp-woo-verify` and a store audit with no blocking finding
  (empty terms or refund pages block too), takes a verified `pre-launch` backup, and asks the
  operator to type the site's host. It then switches Stripe live, cash on delivery off,
  Turnstile on the checkout and coming soon off last, verifies the live store and puts coming
  soon back when that fails. `store.launch` records it, and from then on `/wp-woo-setup` never
  writes launch state, `force` included; `--revert` puts coming soon back. Never run from
  `/wp-yolo`.
