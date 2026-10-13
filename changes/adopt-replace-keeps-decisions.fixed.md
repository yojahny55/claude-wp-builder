- **Re-adopting a site no longer wipes its audit history and confirmed code scope.**
  `wp-config.mjs adopt --replace` built a new manifest from the probe and kept only a backup,
  so the `audit` block (the next audit's baseline), the `store` block, the prefix, the industry
  and the code scope the operator had confirmed were lost; the scope was re-proposed from update
  transients and client code moved to read-only came back as editable. `/wp-audit` sends the
  operator to `--replace` whenever `drift` exits 4, so every such re-adoption did this. Over a
  real adoption `--replace` now carries those over (explicit flags still win, vanished paths are
  dropped, new plugins go through the normal proposal) and the dry-run reports `carried_over`;
  over a blank scaffold it behaves as before.
