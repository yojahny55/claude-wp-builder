# Store selectors — where a demo's store element lands in WooCommerce

The `Section: Store demo` of a theme's `assets/css/store.css` restyles WooCommerce's own markup,
not the demo's. This table names, per store surface, the WooCommerce selector that carries each
element a demo's store page draws. Measured on WooCommerce 11.1.2 in a classic theme with
`add_theme_support( 'woocommerce' )` (what `inc/store-theme.php` declares): shop and product are
WooCommerce's classic templates, cart and checkout its blocks, my account its classic shortcode.

`Probe` is how `tests/checks/store-theme-integration.sh` pins the row against a real store:
`html` — the class is in the page WordPress serves; `js` — the block renders it in the browser,
so the class is pinned in WooCommerce's block scripts instead; `—` — only some stores render it
(a product with a short description, a sale, a second product, a logged-in shopper), so nothing
pins it.

Prefix every selector with the body class of its surface, as the base sections do:
`body.woocommerce-page` for shop and product, `body.woocommerce-cart`, `body.woocommerce-checkout`,
`body.woocommerce-account`. WooCommerce's own selectors carry up to five classes and its block
stylesheets print after `store.css`; the body class is what lets a rule win without
`!important`.

## Shop (`store: shop`)

| Demo element | WooCommerce selector | Probe |
|---|---|---|
| page title | `.woocommerce-products-header__title` | html |
| breadcrumb | `.woocommerce-breadcrumb` | html |
| result count | `.woocommerce-result-count` | html |
| sort dropdown | `.woocommerce-ordering select` | html |
| product grid | `ul.products` | html |
| product card | `ul.products li.product` | html |
| card link (image and title) | `ul.products li.product .woocommerce-loop-product__link` | html |
| card title | `.woocommerce-loop-product__title` | html |
| card price | `ul.products li.product .price` | html |
| card button | `ul.products li.product .add_to_cart_button` | html |
| sale badge | `span.onsale` | — |
| pagination | `nav.woocommerce-pagination` | — |

## Product (`store: product`)

| Demo element | WooCommerce selector | Probe |
|---|---|---|
| gallery | `.woocommerce-product-gallery` | html |
| title | `.product_title` | html |
| price | `div.product p.price` | html |
| short description | `.woocommerce-product-details__short-description` | — |
| quantity input | `form.cart .quantity input.qty` | html |
| add to cart button | `button.single_add_to_cart_button` | html |
| SKU and categories | `.product_meta` | html |
| tab list | `.woocommerce-tabs ul.tabs li` | html |
| tab panel | `.woocommerce-Tabs-panel` | html |
| related products | `section.related.products` | — |

## Cart (`store: cart`)

| Demo element | WooCommerce selector | Probe |
|---|---|---|
| cart frame | `.wp-block-woocommerce-cart` | html |
| empty-cart title | `.wc-block-cart__empty-cart__title` | html |
| line items table | `.wc-block-cart-items` | js |
| line item | `.wc-block-cart-items__row` | js |
| line item name | `.wc-block-components-product-name` | js |
| quantity stepper | `.wc-block-components-quantity-selector` | js |
| totals rows | `.wc-block-components-totals-item` | js |
| proceed button | `.wc-block-cart__submit-button` | js |

## Checkout (`store: checkout`)

| Demo element | WooCommerce selector | Probe |
|---|---|---|
| checkout frame | `.wp-block-woocommerce-checkout` | js |
| form steps | `.wc-block-components-checkout-step` | js |
| text field | `.wc-block-components-text-input` | js |
| order summary | `.wc-block-checkout__sidebar` | js |
| place order button | `.wc-block-components-checkout-place-order-button` | js |

## My account (`store: account`)

| Demo element | WooCommerce selector | Probe |
|---|---|---|
| login form | `form.woocommerce-form-login` | html |
| form field | `.woocommerce-form-row input.input-text` | html |
| login button | `.woocommerce-form-login__submit` | html |
| account menu | `.woocommerce-MyAccount-navigation` | — |
| account content | `.woocommerce-MyAccount-content` | — |

## Traps

- **WooCommerce lays the shop grid out with floats.** `woocommerce-layout.css` gives each
  `li.product` a width, a right margin and `float: left`, and `ul.products` a clearfix
  `::before`/`::after`. A demo grid (`display: grid` or flex) on `ul.products` therefore also
  needs `float: none; width: auto; margin: 0` on `ul.products li.product` and
  `display: none` on `ul.products::before, ul.products::after`; otherwise the clearfix takes the
  first grid cell and the cards keep their percentage widths.
- **Cart and checkout are rendered in the browser.** Their inner markup does not exist in the
  served HTML; read a rule's effect in a browser, not with `curl`.
- **The demo's own classes do not exist on these pages.** A demo selector such as
  `.shop-card__title` is translated to its row above, never copied: WooCommerce renders its
  own markup and no demo class reaches it.
