- **Env setup and encoder edge cases.** `wp-env-setup.sh detect` runs `npx --no-install`, so a
  detection pass can no longer download `@wordpress/env`; `is_running` returns the real state
  (`mariadb || mysql` now reaches the second service); empty arrays are guarded for bash 3.2.
  `wp-cinematic-encode.sh` exits 1 without importing when the all-keyframe check fails, refuses
  `--desktop-only --mobile-only` (exit 2), expands a leading `~` in `--kit` and resolves
  `--theme` to an absolute path. The Lando template no longer points at a `php.ini` nothing
  creates, and the `store-kit-sync.sh` comment no longer claims the swap has no gap.
