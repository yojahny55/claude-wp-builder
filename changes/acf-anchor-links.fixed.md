- **Anchor-only links no longer go into ACF `url` fields.** `wp-acf` always emitted
  `'type' => 'url'` for a link, but ACF validates that type as an absolute URL, so a `#contact`
  link was refused by the editor. A new rule picks `text` for anchors and site paths, `url` for
  external addresses and `page_link` for other pages, and a check keeps the rule in place.
