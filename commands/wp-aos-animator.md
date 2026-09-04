---
description: Runner for the wp-aos-animator skill — audits, installs, enqueues, initializes and seeds AOS scroll animations across a theme's templates
allowed-tools: Read, Write, Edit, Grep, Glob, Bash, Agent, AskUserQuestion
argument-hint: "[<theme-path>] [template ...] [--report-only]"
---

# WP AOS Animator — Runner for the `wp-aos-animator` Skill

This command is a **runner**, nothing more. `skills/wp-aos-animator/SKILL.md` is the source of
truth for the pipeline — audit → install → enqueue → init → animate, the element allow/skip
lists, the animation-and-delay convention, and the stacking-context and containing-block traps
that decide which elements must never be animated. This command dispatches that skill; it does
not restate the phases.
**Dispatch, never reimplement**: the phases exist in one place so that fixing them fixes them
everywhere.

It exists because the skill is `user-invocable: false` — as every skill in this plugin is —
so a user cannot reach it by typing its name. Skills inform; commands act. This is the command.

Motion is not one-size-fits-all here: AOS is for a **plain** demo. A craft project already
ships GSAP-driven motion through its theme bundle, so if `.wp-create.json` records
`demo mode: craft`, say so and ask for confirmation before adding a second motion system.

## Step 0: Parse Arguments

`$ARGUMENTS` is optional. Everything in it is positional except the flag:

| Argument | Required | Description |
|----------|----------|-------------|
| `<theme-path>` | no | Path to the theme to animate. Defaults to the active theme of the current project. |
| `template ...` | no | Scope: one or more template paths or globs (e.g. `front-page.php template-parts/section-*.php`). Defaults to every `.php` template in the theme root and `template-parts/`. |
| `--report-only` | no | Audit only — run the skill's Phase 1 and stop. Writes nothing. |

`--report-only` matches `/wp-audit`'s flag of the same name: report, never fix.

## Step 1: Read Project Context

Read the project's `.claude/CLAUDE.md` for the theme slug, template and `demo mode`. If it is
missing, tell the user to run `/wp-init` first — this command edits a theme this plugin
generated, and without that file the theme path is a guess.

Resolve the theme path when it was not passed:

```bash
bash -c "cat .wp-create.json"
```

Verify the resolved directory is a theme before touching it:

```bash
test -f "<theme-path>/functions.php" && test -f "<theme-path>/style.css" && echo OK
```

## Step 2: Read the Skill

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-aos-animator/SKILL.md` in full. It owns all five phases,
the two transform traps, the skip list, the per-element animation table and the verification
grep. Everything below only sequences it and decides what runs in parallel.

## Step 3: Phase 1 — Audit

Run the skill's Phase 1 against the resolved theme and record the baseline `data-aos` count it
tells you to record. Report what is present and what is missing.

If `--report-only` was passed, print that report and **stop here**. Say what a full run would
change, and that `/wp-aos-animator` without the flag performs it.

## Step 4: Phases 2–4 — Install, Enqueue, Initialize

Run phases 2, 3 and 4 exactly as the skill specifies, in order, skipping any phase its audit
found already satisfied. Each depends on the previous one succeeding — stop and report on the
first failure rather than continuing into Phase 5 with no library loaded.

## Step 5: Phase 5 — Animate the Templates

Build the file list from the scope in Step 0, then run the skill's Phase 5 over it.

The skill states that this phase parallelizes per template. Dispatch **one subagent per
template file** when there is more than one in scope, each given: the single file path it owns,
the elements the audit found in it, and the instruction to follow
`${CLAUDE_PLUGIN_ROOT}/skills/wp-aos-animator/SKILL.md` Phase 5 — the skip list and the
animation table included. No subagent gets more than one file, so two agents never edit the
same template.

Orchestrate and verify; do not author the edits yourself when you have dispatched them.

## Step 6: Verify and Report

Run the skill's verification grep and compare against the Phase 1 baseline.

Then rebuild if the project's template needs it:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/bin/tailwind-rebuild.sh" <theme-path>
```

Report, one line per template: elements animated, elements deliberately skipped and why —
naming the trap from the skill when the reason was a stacking context or a sliding element.
Close with `/wp-demo-verify <url>` as the next command, since a scroll-walk is how a wrong
animation actually shows itself.
