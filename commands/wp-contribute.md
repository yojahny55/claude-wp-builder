---
description: Contributor workflow for the plugin itself — scaffold a command/agent/skill with its check and doc rows, verify the repo, or open the PR in the house format
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
argument-hint: "<new|check|pr|release> [type] [name]"
---

# WP Contribute — Working on the Plugin Itself

This command operates on **this repository**, not on a user's WordPress project. Everything
below assumes the working directory is the plugin root (it contains `.claude-plugin/`).

**Required skill:** read `${CLAUDE_PLUGIN_ROOT}/skills/wp-contributing/SKILL.md` before doing
anything. It owns the layer rules, the grep-gate test style and the frontmatter contracts that
every step here assumes.

## Step 1: Parse arguments

`$ARGUMENTS` starts with a subcommand:

| Subcommand | Form |
|---|---|
| `new` | `/wp-contribute new <command\|agent\|skill\|check> <name>` |
| `check` | `/wp-contribute check` |
| `pr` | `/wp-contribute pr [--title "..."]` |
| `release` | `/wp-contribute release [major\|minor\|patch]` — maintainers |

With no subcommand, print the table above and exit 0.

Confirm the working directory is the plugin root:

```bash
[ -d .claude-plugin ] && [ -d commands ] && [ -d tests/checks ]
```

If not, stop: "Not in the claude-wp-builder repository root. This command edits the plugin
itself — to build a WordPress site, use `/wp-init` and `/wp-yolo`."

---

## Step 2 — `new`: scaffold a layer file with everything it needs

The point of this subcommand is that a new capability is **never one file**. Emit all of it,
so the PR cannot arrive with the check or the doc row missing.

### `new command <name>`

1. `commands/<name>.md` — frontmatter carrying `description`, `allowed-tools` and
   `argument-hint` (add `Agent` to `allowed-tools` only if it will dispatch subagents), then
   numbered `## Step N:` sections. The first step parses `$ARGUMENTS`; the second reads the
   project's `.claude/CLAUDE.md` for prefix, theme slug, languages, template and
   `i18n strategy`, and tells the user to run `/wp-init` first when it is missing.
2. `tests/checks/<name>.sh` — a grep gate in the house style: a comment naming the contract it
   protects, `set -euo pipefail`, `cd "$(dirname "$0")/../.."`, a `fail()` helper, assertions,
   `echo PASS`. Make it executable.
3. A row in the README Commands Reference table (Command · Path · Required? · Description).
4. An entry in `docs/commands.md`, and a step in `docs/workflows.md` if it belongs to a build
   path (A `/wp-yolo`, B step-by-step, C cinematic).
5. A `CHANGELOG.md` entry under `[Unreleased]` → `### Added`.

**Do not write the command's body from a template.** Read the closest existing command
(`commands/wp-section.md` for a builder, `commands/wp-audit.md` for a flag-driven one) and
follow its shape. A generic scaffold is exactly the unreviewed-AI-output shape reviewers reject.

### `new agent <name>`

`agents/<name>.md` with frontmatter `name`, `description`, `tools` (in the order
`Read, Write, Edit, Grep, Glob, Bash`) and `model` — the cost tier: `opus` for planning and
analysis, `sonnet` for code authoring and judgment audits, `haiku` for mechanical WP-CLI work.
The body **must** open with the "First Action (MANDATORY)" block that reads the project's
`.claude/CLAUDE.md`. Add the agent to the README agents table. `tests/checks/model-routing.sh`
enforces the tier, so a missing `model:` fails the suite.

### `new skill <name>`

`skills/<name>/SKILL.md` with `name`, `description`, `user-invocable: false`, plus `trigger:`
when it should auto-invoke. Skills inform; they never act. If what you are writing tells an
agent to *run* something, it belongs in an agent instead. Add it to the README skills table.

### `new check <name>`

`tests/checks/<name>.sh` alone, for a contract that already exists but is unprotected. Start
the comment with the defect it would have caught — what shipped, what it cost. An assertion
that would still pass with the contract sentence deleted protects nothing; assert both
directions where a wrong old form once existed.

---

## Step 3 — `check`: verify the repository

Run both gates and report them together:

```bash
for f in tests/checks/*.sh; do bash "$f" || echo "FAILED: $f"; done
bash bin/doc-sync-check.sh
```

`bin/doc-sync-check.sh` asserts what the greps cannot: every command has a README row and a
`docs/commands.md` entry, every documented command exists, every agent and skill is listed,
frontmatter is present per layer, the four version references agree, and `CHANGELOG.md` moved
when `commands/`, `agents/`, `skills/`, `starter-theme/` or `bin/` did.

Report each failure with the file and the one-line fix. Do not "fix" a failing check by
loosening its assertion — that is the failure mode the check exists to prevent.

---

## Step 4 — `pr`: open it in the house format

1. **Refuse on `main`.** Create a branch first: `feat/…`, `fix/…`, `docs/…`, `chore/…`.
2. Re-run Step 3. A red suite stops here.
3. Confirm the contributor checklist: new behavior has a check · CHANGELOG `[Unreleased]`
   entry · README and `docs/` updated · **no version bump** (maintainer-only, and a bump in a
   PR conflicts at release).
4. Commit with a Conventional Commits subject in English — `feat:`, `fix:`, `docs:`, `chore:`,
   `refactor:` — and **no AI attribution**: no `Co-Authored-By`, no "Generated with", nothing
   naming the tool. The body says what was wrong before, not just what changed.
5. Push over SSH with `git push -u origin <branch>` (not `gh`).
6. Create the PR with `env -u GH_TOKEN gh pr create`, body in English:

```
## Summary
What was wrong, and what this changes.

## Changes
- one bullet per file or behavior

## Testing
Which checks, which real WordPress project, what you verified by hand.

## Checklist
- [ ] Tested against a real WordPress project
- [ ] New behavior has a check in tests/checks/
- [ ] CHANGELOG.md [Unreleased] updated
- [ ] README / docs updated
- [ ] No version bump
```

**Stacked PRs.** When the work depends on another open PR, set that PR's branch as the base
(`--base <branch>`) and say so in the summary — do not target `main` with a diff that contains
someone else's unmerged work.

---

## Step 5 — `release`: maintainers only

Refuse unless the working tree is clean, the branch is `main`, `main` is up to date with
`origin`, and Step 3 is green.

1. Determine the bump from what merged since the last tag (`git log --oneline vX.Y.Z..HEAD`):
   a new command, agent or skill → minor; fixes and docs → patch; a changed contract that
   users' projects depend on → major. State the choice and why before applying it.
2. Bump **all four** version references together: `.claude-plugin/plugin.json`,
   `.claude-plugin/marketplace.json` (twice — `metadata.version` and the plugin entry), and the
   README badge.
3. Roll `[Unreleased]` into `## [X.Y.Z] - YYYY-MM-DD`. **Read every merged PR since the last
   tag** and write entries for any that landed without one.
4. `chore(release): vX.Y.Z`, then `git tag -a vX.Y.Z -m "vX.Y.Z"`, then push the commit and the
   tag over SSH.
5. `env -u GH_TOKEN gh release create vX.Y.Z --title "…" --notes-file <file> --latest`.
6. **Verify**: the release is published and not a draft; the tag resolves on the remote; and
   the raw `.claude-plugin/*.json` served from GitHub carry the new version — that is what a
   user's install reads. There is no publish CI here; the GitHub release is the artifact.
7. Delete the merged head branch, and check whether older branches can go too.

## Step 6: Report

Print what was created or verified, one path per line, then the exact next command — for
`new`, that is `/wp-contribute check`; for `check`, either `/wp-contribute pr` or the list of
failures; for `pr`, the PR URL.
