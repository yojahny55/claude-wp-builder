- **`/wp-favicon <image>`.** One square image becomes the favicon set: 16, 32, 180, 192 and
  512 px PNGs, a multi-size `favicon.ico` and `site.webmanifest` in the theme, plus the
  WordPress Site Icon set through WP-CLI. A non-square or under-512 px raster is refused
  rather than cropped or upscaled, and an icon already set is kept unless `--force`.
