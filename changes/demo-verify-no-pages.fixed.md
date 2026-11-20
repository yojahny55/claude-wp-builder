- **`demo-verify` refuses a target with nothing to walk.** A directory with no `.html`
  files, or a page path that does not exist, used to end in "no machine findings on
  0 page(s)" with exit 0, so an empty `demo/` or a typo read as a clean verification. It
  now exits 1 with "no pages to verify" before looking for a browser, and
  `/wp-demo-verify`'s walk reference says to fix the target rather than report a pass.
