# Cutting a release

Moved out of `CLAUDE.md`, which keeps the rules.

## Version and docs

Version lives in `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` (twice) and the
README badge — bump all of them together. Add a `changes/<slug>.<section>.md` fragment (format
in `changes/README.md`) and never edit `CHANGELOG.md` in a PR; update `README.md` when adding a
command.

## Branch, tag, publish

A release is a `release/X.Y.Z` branch and PR (never a push to `main`); once it merges, tag the
merge commit with an annotated `vX.Y.Z` tag and publish it with `gh release create vX.Y.Z --latest`.
The merged PR alone is not a release.

## Reconcile `BACKLOG.md`

Reconcile `BACKLOG.md` as part of cutting the release, and update its `**Reconciled** on`
line. `tests/checks/backlog-freshness.sh` fails when the newest release in the CHANGELOG is
dated after that line, so this is a gate rather than a good intention. It became one because
the last hand reconciliation went stale in a single day: three releases shipped a clone
anonymiser, resumable builds, a findings ledger, ACF nesting and a WordPress fixture, and the
backlog mentioned none of them. The check cannot tell whether a reconciliation was any good —
only that one happened, which is the part that kept being skipped.

## Changelog fragments

`bin/changelog-release.sh X.Y.Z` turns `changes/*.md` into a `## [X.Y.Z] - date` block inserted
*below* `## [Unreleased]` and deletes the fragments; entries already under `[Unreleased]` are
carried into the block. It never renames `## [Unreleased]`, which stays as an empty anchor at the
top. Fragments exist because PRs that all insert under one heading conflict with each other once
any one merges, and GitHub ignores `merge=union`, so the old workaround only worked in a local
`git merge`. `tests/checks/changelog-fragments.sh` pins the format and runs the script on a
scratch copy.
