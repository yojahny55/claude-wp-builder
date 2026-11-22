- **Every skill keeps its description in the session listing.** Claude Code lists each
  skill's name and description under one shared character budget. The plugin's 36
  descriptions came to about 25 KB, and in a real session the listing ran out after
  `wp-create-run`, so `wp-css-system`, `wp-demo-craft`, `wp-environments`, `wp-polylang`,
  `wp-woocommerce` and the rest appeared with no description and nothing told Claude when
  to load them. The descriptions now total about 10.8 KB. The 14 `*-run` skills, loaded only
  when their command names a reference, say just that. The others keep what the skill is,
  its strongest triggers and the `Not for` line that tells it from a sibling.
