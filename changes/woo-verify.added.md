- **`/wp-woo-verify` checks a store from outside.** `bin/woo-verify.mjs` runs setup's dry run
  (nothing left to set), visits the shop, cart, checkout and account pages, reads the shop for a
  product, and puts one in a cart and takes it out through the Store API, deleting the cart
  session afterwards. `--order`, only on a local store that sells and has no other order, places
  a cash-on-delivery order, checks the new-order email was sent, then cancels it (stock and sales
  count back) and deletes it for good, so setup never reads the store as one with orders.
