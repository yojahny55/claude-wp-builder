---
name: wp-contributing
description: Contributing to the claude-wp-builder plugin itself — the four-layer architecture and what may call what, why tests are grep gates over prose, the frontmatter contract per layer, the two i18n systems, and the PR and release rituals. Use when editing this repository's own commands/, agents/, skills/, starter-theme/, bin/ or tests/, not when building a WordPress site with it.
user-invocable: false
trigger: auto-invoke when working inside the claude-wp-builder repository itself — editing commands/*.md, agents/*.md, skills/*/SKILL.md, starter-theme/**, bin/*.sh or tests/checks/*.sh
---

# Contributing to Claude WP Builder

`CONTRIBUTING.md` is the front door: how to fork, where files go, the PR template, the code
of conduct. Read it first. This skill is the part that is not written down anywhere else —
the rules you only learn by breaking them.

**The one sentence that explains this repo:** it is a plugin made almost entirely of prose,
so nothing fails at runtime when the prose goes wrong. A contract that drifts produces a
worse site, silently, three commands later. Every convention below exists because that
already happened.

---

## Part 1 — Contributors

### The four layers, and what may call what

```
commands/*.md     user-facing slash commands — orchestration, argument parsing, step order
   ↓ dispatches
agents/*.md       specialized subagents (wp-template, wp-css, wp-acf, wp-audit-*, …)
   ↓ reads
skills/*/SKILL.md knowledge libraries — methodology, never actions
   ↓ produces
starter-theme/    PHP scaffolds copied into the user's project
```

Calls go **down** only. The rules that follow from that:

- **A command must never reimplement a builder.** `/wp-yolo` is the model: it normalizes the
  demo once, then drives `/wp-settings`, `/wp-cpt`, `/wp-header`, `/wp-footer`, `/wp-section`
  and `/wp-seed` in dependency order. It owns the *order*, never the *work*. When you need a
  command to do something a builder already does, dispatch that builder — a second
  implementation is a second thing to keep correct, and it will diverge.
- **Skills inform; they never act.** A skill that tells an agent to run WP-CLI belongs in an
  agent. `user-invocable: false` is not decoration — it is the whole contract.
- **Every agent's first mandatory step reads the project's `.claude/CLAUDE.md`** — the file
  `/wp-init` generates in the *user's* WordPress project, which is a different file from this
  repository's own `CLAUDE.md`. It carries the function prefix, theme slug, languages,
  template and i18n strategy. `prefix_` in any agent or skill doc is a placeholder, never a
  literal.
- **Plugin-relative paths in commands are always `${CLAUDE_PLUGIN_ROOT}/…`**, never relative.
  A relative path resolves against the user's project, not the plugin.

### Tests are grep gates over prose

There is no runner and no framework. Each check is a standalone bash script that prints
`PASS` or exits non-zero:

```bash
bash tests/checks/wp-yolo-gate.sh               # one check
for f in tests/checks/*.sh; do bash "$f"; done  # all of them
```

Because the "code" is instructions to a model, a check asserts that **the contract wording is
still present** in the command, agent or skill that owns it. That sounds weak and is not: the
wording IS the behavior. If a check would pass with the sentence deleted, it protects nothing.

**Writing one.** Name the defect in a comment at the top — what shipped, what it cost — then
assert the narrowest thing that would have caught it:

```bash
#!/usr/bin/env bash
# /wp-section --hybrid: /wp-init and docs/cinematic-mode.md both send users to this flag,
# so commands/wp-section.md must actually define it — and define it as the trailing-flex
# overlay the cinematic starter's front-page.php renders, not a standalone field group.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

grep -Fq -- '--hybrid' commands/wp-section.md || fail "wp-section.md does not parse --hybrid"
grep -Fq "have_rows('trailing_sections')" starter-theme/__cinematic__/front-page.php \
  || fail "cinematic front-page.php lost the loop --hybrid depends on"

echo PASS
```

Three habits that make the difference:

- **Assert both directions.** A positive grep alone is satisfied by deleting the feature.
  Where a wrong old form existed, assert it is *gone* as well as that the right one is present.
- **Anchor on behavior, not headings.** A check that fails when someone renames a heading gets
  muted. Degrade to searching the whole file when the anchor is missing.
- **Prefer `grep -F`** for text containing backticks, `$`, brackets or `--flags`. A clever
  regex that matches by accident today stops matching after an innocent rewording.

When the thing you changed is a real script (`bin/*.sh`), test its behavior, not its source:
build a temp directory, put a fake binary earlier on `PATH`, run the script, assert what it
did. `tests/checks/tailwind-rebuild.sh` does this with a fake `npm` and fake watcher processes.

### Frontmatter is the loader's contract

| Layer | Required | Notes |
|---|---|---|
| `commands/<name>.md` | `description`, `allowed-tools`, `argument-hint` | Add `Agent` to `allowed-tools` only if it actually dispatches subagents |
| `agents/<name>.md` | `name`, `description`, `tools`, `model` | `tools` in the order `Read, Write, Edit, Grep, Glob, Bash`; `model` is a cost tier — `opus` for planning, `sonnet` for authoring and judgment, `haiku` for mechanical work (`tests/checks/model-routing.sh`) |
| `skills/<name>/SKILL.md` | `name`, `description`, `user-invocable: false` | Add `trigger:` when it should auto-invoke |

A file missing its frontmatter is **inert, not broken** — nothing errors, the capability
simply never loads. That is why `bin/doc-sync-check.sh` asserts it mechanically.

### The traps that cost the most

- **Two i18n systems, never mixed.** `suffix` = one page with ACF fields duplicated as
  `hero_title_es`. `polylang` = one post per language joined by translation groups. Which one
  a project uses is a *recorded decision* — the `i18n strategy` line in the project's
  `.claude/CLAUDE.md` — not a guess. Absent line means `suffix`. The seam is a single file,
  `inc/i18n.php`; the Polylang variants live in `starter-theme/_i18n-variants/` and are kept
  **out** of the theme directories on purpose, because a starter carrying two definitions of
  the same function fatals the moment anything globs `inc/*.php`.
- **One deliberate crossover:** under Polylang, ACF **options-page** fields keep their
  `_<lang>` suffixes. Options are global, so Polylang's per-post model does not reach them.
- **Template routing changes which agent runs.** `tailwind` → `wp-tailwind` in author mode;
  `cinematic` → an entirely different shape (one continuous reel, `/wp-cinematic-scene` per
  scene, `/wp-section --hybrid` for trailing blocks) that the section walk must refuse to
  enter. `basic` is legacy: `starter-theme/__starter__/` was removed, so treat it as an alias
  for `tailwind` rather than failing on it.
- **Starter-theme edits use the placeholder tokens** — `__starter__`, `__STARTER__`,
  `__STARTER_NAME__`, `__STARTER_DOMAIN__` — replaced by `/wp-init`. A real slug committed
  into the starter ships to every future project.
- **PHP 7.4 floor** in `skills/wp-polylang/scripts/*.php`: no `match`, no union types. Those
  run inside a real WordPress through `wp eval-file`, and `pll-lib.php` bridges `eval-file`'s
  local `$args` into `$GLOBALS` — the scripts do not work without that require.
- **Markup that lives in the database is invisible to every build step.** A CF7 form is a post
  row: Tailwind utility classes written into it compile only while some theme file happens to
  use the same ones. One hook class per element, declared in the theme CSS.

### Before you open a PR

1. `for f in tests/checks/*.sh; do bash "$f"; done` — all green.
2. `bash bin/doc-sync-check.sh` — README tables, `docs/commands.md`, frontmatter and the
   version references all agree.
3. **New behavior has a new check.** This is the one reviewers actually block on.
4. `CHANGELOG.md` gains an `[Unreleased]` entry. Say what changed and *why it was wrong
   before*; a release note that only names the feature is useless six months later.
5. Docs follow the change: a new command needs a row in the README table **and** an entry in
   `docs/commands.md`, and a step in `docs/workflows.md` if it belongs to a build path.
6. **Do not bump the version.** Four files state it and the maintainer moves all four at
   release time; a bump in a PR is a guaranteed conflict.

Commits follow [Conventional Commits](https://www.conventionalcommits.org/) — `feat:`, `fix:`,
`docs:`, `chore:`, `refactor:` — in English, and carry **no AI attribution**: no
`Co-Authored-By`, no "Generated with", nothing referencing the tool that helped write them.
Using AI to write a contribution is welcome; shipping its raw output is not.

### What gets a PR sent back

Missing check · docs out of sync (`bin/doc-sync-check.sh` fails) · a command reimplementing a
builder instead of dispatching it · a skill that acts · a version bump · hallucinated WP-CLI
flags or ACF methods · untested against a real WordPress site · one PR doing three things.

---

## Part 2 — Maintainers

### Merging, and the stacked-PR hazard

Small PRs, one concern each. When a PR is stacked on another (its base is the first PR's
branch, because it edits files that only exist there), **merge the base first** — but *how*
matters:

- **Merge commit or rebase** → the base's commits land on `main` unchanged, GitHub retargets
  the child to `main`, and its diff cleanly shrinks to just its own work.
- **Squash** → the base's commits are replaced by one new SHA. The child's branch still
  carries the originals, so it re-proposes the parent's entire diff. Recover with
  `git rebase --onto main <last-parent-sha> <child-branch>` and force-push with lease.

GitHub only auto-retargets a child when the base branch is **deleted**, so keep
**Settings → Automatically delete head branches** on. Without it, a squash-merged base sits
around and the child silently keeps the wrong base.

### The release ritual

```bash
git checkout main && git pull --ff-only
for f in tests/checks/*.sh; do bash "$f"; done && bash bin/doc-sync-check.sh
```

1. **Pick the bump** (semver): new command, agent or skill → minor. Fixes and doc work →
   patch. A changed contract users' projects depend on → major.
2. **Bump all four references together** — `.claude-plugin/plugin.json`,
   `.claude-plugin/marketplace.json` (**twice**: `metadata.version` and the plugin entry), and
   the README badge. `bin/doc-sync-check.sh` fails if they disagree.
3. **Roll `[Unreleased]` into `## [X.Y.Z] - YYYY-MM-DD`**, and write entries for any PR that
   merged without one — that happens, and release time is the last chance to catch it.
4. `git commit -m "chore(release): vX.Y.Z"`, `git tag -a vX.Y.Z -m "vX.Y.Z"`, push the commit
   and the tag.
5. `env -u GH_TOKEN gh release create vX.Y.Z --title "…" --notes-file <file> --latest`.
6. **Verify it is actually live:** the release is published and not a draft, the tag resolves
   on the remote, and the raw `.claude-plugin/*.json` on GitHub serve the new version — that
   is what a user's install resolves against. There is no publish CI in this repo; the GitHub
   release *is* the artifact.

Then delete the merged branch, and check no others accumulated: a branch whose PR is merged —
or closed but superseded — is safe to delete once `git diff main <branch>` shows nothing on it
that `main` lacks.
