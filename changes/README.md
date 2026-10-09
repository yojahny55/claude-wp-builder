# Changelog fragments

Every PR that changes behavior adds **one file here** instead of editing `CHANGELOG.md`.
Two branches then never touch the same file, so they cannot conflict on it.

## File name

`<slug>.<section>.md`, where `<section>` is one of `added`, `changed`, `deprecated`,
`removed`, `fixed`, `security`. Example: `audit-same-day-compare.fixed.md`.

## File content

The entry exactly as it should read in the changelog, starting with `- `:

```markdown
- **Short bold lead.** What changed, and why it was wrong before. Continuation
  lines are indented two spaces.
```

One entry per file. Do not add a heading.

## At release

`bin/changelog-release.sh X.Y.Z` compiles every fragment into a new
`## [X.Y.Z] - date` block below `## [Unreleased]`, grouped by section, and deletes
the fragments. `tests/checks/changelog-fragments.sh` pins the format.
