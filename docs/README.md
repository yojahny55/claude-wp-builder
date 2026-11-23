# Documentation index

Every document in `docs/`, one line each. `tests/checks/docs-index.sh` fails when a file
here is missing from this list.

- [architecture.md](architecture.md) — why the plugin is shaped the way it is: i18n, craft token vocabularies, the store model.
- [changelog-archive.md](changelog-archive.md) — releases before 1.30.0, moved verbatim out of `CHANGELOG.md`.
- [cinematic-mode.md](cinematic-mode.md) — scroll-driven cinematic sites: when to use them and the pipeline from video to theme.
- [code-connect-draft.md](code-connect-draft.md) — draft proposal (not implemented) for mapping Figma Code Connect to the canonical demo snippets.
- [commands.md](commands.md) — reference for every slash command: what it needs and what it writes.
- [exit-codes.md](exit-codes.md) — the exit codes of every `bin/*.mjs` tool, as they are, and the scheme a new tool follows.
- [known-ceilings.md](known-ceilings.md) — deliberate, documented limits of the plugin and its checks.
- [plugin-code.md](plugin-code.md) — every shipped script and Node tool in `bin/`, and the PHP the plugin copies or runs.
- [postmortem-reference-build.md](postmortem-reference-build.md) — defects with a traceable tool root cause, from one full bilingual build.
- [releasing.md](releasing.md) — cutting a release: version strings, tag, `BACKLOG.md` reconciliation, changelog fragments.
- [testing.md](testing.md) — how the contract checks run, what CI adds, and what nothing covers.
- [workflows.md](workflows.md) — the three build paths from nothing to a working theme.
