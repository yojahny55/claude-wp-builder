- **`/wp-webp upload` makes every new upload a WebP.** It installs a must-use plugin that, on
  `wp_handle_upload` and `wp_handle_sideload` before WordPress makes the sizes, encodes a PNG
  or JPEG with `cwebp` up a quality ladder and keeps the first candidate that reaches 40 dB
  PSNR and is smaller than the original, so every size is born WebP and nothing has to be
  delivered by rewriting. When no candidate qualifies the original is kept. `s3://` uploads
  work through a local copy. Without `cwebp`, `proc_open` or a WebP-capable editor it does
  nothing, and `status` says why. Existing images are not touched.
