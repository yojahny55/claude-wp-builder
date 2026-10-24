- **Manifest writes are atomic and the Tailwind rebuild lock holds.** `wp-config.mjs`
  wrote `.wp-create.json` (migrate, adopt, refresh) and the rendered CLAUDE.md block with a
  bare `writeFileSync`, and `wp-research` edited the manifest freehand, so parallel builders
  could read a torn file or lose each other's keys. Writes now go through a temp file plus
  rename, and a new `wp-config.mjs set <project> <key> <value>` changes one key under a lock
  and validates before writing; `wp-research` uses it. `bin/tailwind-rebuild.sh` deleted its
  lock file after building, and since `flock` locks the inode a third process could end up
  holding an unlinked file while a fourth created a new one, so two compiles ran together.
  The lock file is now kept (and gitignored by `/wp-init`), the wait for it is bounded, and
  the implicit `npm install` inside it has a timeout.
