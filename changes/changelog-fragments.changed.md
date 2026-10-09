- **Changelog entries are `changes/<slug>.<section>.md` fragments, not edits to `CHANGELOG.md`.**
  Every PR inserted under the same `## [Unreleased]` heading. `merge=union` resolved that in a
  local `git merge`, but GitHub ignores merge drivers, so merging one PR marked every other open
  PR as conflicting on `CHANGELOG.md`, and union hid real same-line collisions besides. A PR now
  adds its own file; `bin/changelog-release.sh X.Y.Z` compiles them into the release block at
  release and deletes them. `bin/doc-sync-check.sh` requires a new fragment (or a release
  heading) when `commands/`, `agents/`, `skills/`, `starter-theme/` or `bin/` change, and
  `.gitattributes` no longer marks the file `merge=union`.
