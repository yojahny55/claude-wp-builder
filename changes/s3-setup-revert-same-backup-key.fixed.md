### Fixed

- `s3-setup.sh` now derives its private backup directory with the same key as `s3-revert.sh`
  (24 hex characters of the site root's sha256, `shasum -a 256` where `sha256sum` is absent), so
  a revert parks the config beside the backups setup made instead of in a different subdirectory.
