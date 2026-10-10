---
description: Create a demo HTML mockup for client approval — responsive, section-separated, ready for WordPress conversion
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent, AskUserQuestion
argument-hint: "[brief] [--craft|--plain] | iterate"
---

# WP Demo — HTML Mockup Generator

Create a standalone HTML demo for client approval that will later be converted section-by-section into WordPress templates.

## Step 1: Read Project Context

**First: validate the project configuration.**

`${PROJECT_PATH}` is not an environment variable the way `${CLAUDE_PLUGIN_ROOT}` beside it is: it is the WordPress project root, the directory holding `.wp-create.json`, and you substitute the real path yourself — the one the user named, or the working directory when they named none — because an empty argument makes the validator print its usage line and exit `1`, which the table below then reads as "stop and report".

```bash
bash -c "node ${CLAUDE_PLUGIN_ROOT}/bin/wp-config.mjs validate '${PROJECT_PATH}'"
```

| Exit | Meaning | Do |
|---|---|---|
| `0` | valid | continue |
| `1` | invalid, or the generated context block disagrees with the manifest | stop and report the message verbatim |
| `2` | an older manifest can migrate | run `wp-config.mjs migrate '${PROJECT_PATH}'`, then continue |
| `3` | no manifest | this project was not created by `/wp-create`; stop and say so |

On exit 2, run the migration before continuing.

Read `.claude/CLAUDE.md` to get the project name, slug, industry, description, and languages. If the file does not exist, tell the user to run `/wp-init` first.

## Step 2: Get the Brief

Check `$ARGUMENTS`:

- **If `$ARGUMENTS` is "iterate"**: Read the existing `demo/index.html` file, then ask the user what changes they want. Apply changes and skip to Step 4 — **unless `.wp-create.json` says `"demo mode": "craft"`**, in which case re-enter Step 2.6: run its gate (step 0) again, then continue from its step 6 (the build) with the existing `demo/DESIGN.md` and `demo/BRIEF.md`, so the changes go through the compositions and the verify loop like any other craft build.
- **If `$ARGUMENTS` is provided** (not "iterate"): Use it as the client brief.
- **If `$ARGUMENTS` is empty**: Ask the user for:
  - Client brief / description of what the site should look and feel like
  - Reference screenshots or URLs (optional)
  - List of sections to include (e.g., Hero, About, Services, Team, Testimonials, Contact)

## Step 2.4: Research

Find out who this client actually is before deciding anything about the build.
This runs before the mode is chosen, so a plain demo gets the client's real
words too — invented copy is where a generated demo reads as generated, and a
plain build has no `demo/DESIGN.md` to lean on.

Take the first branch that applies:

1. **`demo/RESEARCH.md` already exists** — read it, say so in one line, continue.
   A re-run does not re-research; deleting the file is how you refresh it.
   `/wp-demo iterate` requires an existing `demo/index.html`, which can only
   exist because a prior full run already completed Step 4 — and that run
   necessarily passed through this step first. Research is therefore always
   already resolved by the time `iterate` runs: it is guaranteed by the
   bypass, not by landing on a branch, so `iterate` **never re-researches**.
2. **`.wp-create.json` records `"research": "none"`** — skip in one line, do not ask.
   The record is permanent: an earlier run already declined or already found
   nothing reachable.
3. **Otherwise** — dispatch the `wp-research` agent. It reads
   `${CLAUDE_PLUGIN_ROOT}/skills/wp-research/SKILL.md`, works the source ladder
   down from whatever is connected, and writes `demo/RESEARCH.md` plus the
   `"research"` key in `.wp-create.json`.

The agent shows its `## Identity` block once and waits. Three answers, and they
are not the same thing:

| Answer | Effect |
|---|---|
| yes | `confidence: "confirmed"`, `research.site` recorded |
| wrong business | the site is dropped, `confidence: "unconfirmed"`, that candidate joins the rejected list, and the build continues on the documents alone. Research still happened; the identity did not |
| no research | `"research": "none"` is written and nothing is researched again |

**Research never blocks a build.** The craft browser gate blocks because
building blind is wrong; this does not. If there is no network, if every rung of
the ladder fails, or if the business cannot be found, the run records what
happened in one line and Step 2.5 continues exactly as it does today.

## Step 2.5: Choose the Demo Mode

Craft mode builds against the `wp-demo-craft` skill: a design floor, a page
grammar, a feeling curve with one peak, scroll motion via `data-motion-*`, and a
fingerprint gate so two clients never get the same shape. Plain mode is the
existing single-file demo with no motion contract.

**Decide from the project, not from taste.** Read `.claude/CLAUDE.md` (including
any Project Constraints section written by `/wp-context`), anything under `docs/`,
and `.wp-create.json`.

- Choose **craft** when the site is marketing, brand, launch, portfolio, agency or
  campaign work; when the docs name reference sites; or when they ask for motion,
  animation or a premium feel.
- Choose **plain** when the site is an admin tool, an intranet, catalogue- or
  data-heavy, regulated, or when the docs put accessibility first.
- `--craft` and `--plain` in `$ARGUMENTS` override the decision. Honour them
  without arguing.

State the decision and the one-line reason for it. Then write it to
`.wp-create.json` as `"demo mode": "craft"` or `"demo mode": "plain"`, creating the
key if absent. Every downstream command reads that line instead of deciding again.

If the mode is **plain**, continue with the existing steps and skip Step 2.6.

## Step 2.6: Craft Mode

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-demo-craft/SKILL.md` and its `references/`
before writing any markup.

0. **Gate.** Run `node "${CLAUDE_PLUGIN_ROOT}/bin/demo-verify.mjs" --probe`.
   On exit 2, run `npm i -D playwright-core` in the project root and probe again
   (the probe resolves `playwright-core` from `PLAYWRIGHT_CORE`, then the
   plugin's own `node_modules`, then the project's, then the global npm root
   (`npm root -g`), which is why installing here works, and why a machine with
   Playwright installed globally already passes; say first that this writes a `package.json` and a `node_modules/` into
   the WordPress project root). After the retry, **only exit 0 continues** —
   exit 2 means print what the probe said is missing (`playwright-core` or
   Chrome; the fix is `WP_DEMO_CHROME` pointing at a Chrome or Chromium already on
   the machine, never a browser download), and any other exit
   code (127 for a missing `node`, or a crash) means print it verbatim. Either
   way **stop**. A craft build is never made blind and never falls back to plain;
   the user reruns once the browser exists.
1. **DESIGN.md.** Write `demo/DESIGN.md` per
   `${CLAUDE_PLUGIN_ROOT}/skills/wp-demo-craft/references/design-md.md`: client
   docs first; then `npx designlang@12 <url>` (major-version pinned for the reason
   `references/design-md.md` gives) on the client's current site — the URL the docs
   name, **or `research.site` from `demo/RESEARCH.md` when `confidence` is `confirmed`**
   — and on each reference URL the docs name (skip when there is neither); then
   two or three
   rows from `${CLAUDE_PLUGIN_ROOT}/skills/wp-demo-craft/references/design-md/INDEX.md`
   by industry and tone for the gaps, cited by domain. If `.wp-create.json` has
   `firecrawl_url` and a reference is a Refero Styles page, scrape it for its
   do/don't list. Record `"design_md": "demo/DESIGN.md"` in `.wp-create.json`.
   `firecrawl_url` is optional and set by hand (a self-hosted instance or the
   client's own); never ask for a key.
2. **Fingerprint gate.** Check `demo/DESIGN.md` against
   `~/.claude/wp-builder/FINGERPRINTS.md` on the terms in
   `${CLAUDE_PLUGIN_ROOT}/skills/wp-demo-craft/references/fingerprint.md`, which
   owns the row shape, the header and the comparison. On a failure change the
   type pair or the accent, not the log.

   If the registry already holds a row for this client, or the project shows a prior
   demo in `docs/` or in git history, the plan states how this build's grammar and
   hero composition differ from it. "It is a fresh build" is not an answer — the
   previous rebuild was written fresh and converged on the same silhouette anyway.
3. **Brief.** Read
   `${CLAUDE_PLUGIN_ROOT}/skills/wp-demo-run/references/craft-brief.md` now and
   follow it — it is this step, not background. It covers `demo/BRIEF.md`, the form
   interview (3a), the asset inventory (3.5), library references and motion clips
   (3.6), and reference precedence (3.7).

4. **Classify the domain.** If `.wp-create.json` already has `"domain"` — a prior
   `/wp-demo` or `/wp-yolo` run against this same project recorded it — read it and
   move on; **do not re-classify**. The manifest is the shared source of truth, and a
   second run that re-derives the domain overwrites an operator's `name the domain
   directly` override with the match it already rejected. Otherwise, match the
   English-language material in **the client documents and `demo/RESEARCH.md`**
   (sections `## What they actually say` and `## Competitors`) against the
   keyword lists in
   `${CLAUDE_PLUGIN_ROOT}/skills/wp-demo-craft/references/domains/domains.csv`.
   A domain is matched when **two distinct keywords** from its list appear in
   that corpus; below that, report `unclassified` and carry on without constraining
   anything, because a wrong category is worse than none. When more than one
   domain clears the threshold, the highest hit count wins; on an exact tie for
   the top count, report both names and proceed `unclassified` for the same
   reason. The lists are English-only: a corpus with no English-language
   material is `unclassified` **with that reason stated**, not silently, and the
   operator may name the domain directly instead of relying on the match. Record
   the result in `.wp-create.json` under `"domain"` as `name`, `score`, `matched`
   and `confidence`, recording in `matched` **which corpus produced each hit**
   — `docs` or `research` — so an operator can tell a category drawn from
   the client's own material from one drawn from a competitor's marketing
   copy. The threshold does not move: two distinct keywords are still
   required, so the decision is auditable and `/wp-yolo` reads it rather
   than re-deriving it. State the match and its score in one line.

   A matched domain does exactly two things. Its `page_pattern` and
   `considerations` both fold into the brief as stated constraints — never as a
   mapping onto this project's own section roles, which the catalogue's 77
   free-text patterns have no correspondence to. It **never touches tokens**:
   colour and type come from `demo/DESIGN.md` and the client's own material,
   never from a category. A low `confidence` value is reported alongside the
   match rather than hidden, and a build may ignore a weak match with a one-line
   reason.
5. **Grammar, then composition plan.** Read
   `${CLAUDE_PLUGIN_ROOT}/skills/wp-demo-run/references/craft-composition.md` now and
   follow it — it is this step, not background. It covers the grammar, the
   composition plan and where the form answers bind, the family, signature move and
   world (5.4), and the image plan (5.5).

6. **Build.** Read
   `${CLAUDE_PLUGIN_ROOT}/skills/wp-demo-run/references/craft-build.md` now and
   follow it — it is this step, not background. It covers `demo/index.html` and one
   file per page in the agreed page set, what each page carries from
   `demo/DESIGN.md`, and `demo/.image-plan.json`.

7. **Loop.** At most three rounds. **Clear the marker before the first round**:
   `rm -f demo/FAILED.md`. The marker describes the **last** verify loop, never a
   past one — a build that failed, was fixed and now passes must not leave a file
   on disk that `/wp-init`, `/wp-section` and `/wp-yolo` permanently refuse to
   build on, and a `/wp-yolo` run that wrote it must be able to re-enter its own
   Step 0 gate. Nothing else deletes it. Each round runs `/wp-demo-verify demo/` — the
   directory, so every page is walked — for the `impeccable detect` gate and the
   contact sheets. That command is the one place the detector and rubric
   contract is written; run it, do not restate it here. **Dispatch its critique
   as a subagent**, not inline: hand it only the sheet paths under
   `demo/.verify/`, the seven rubric lines, and the family's Avoid list from
   `demo/BRIEF.md ## Family`; ask for a pass or fail per rubric line with one
   sentence per failure, and separately for every Avoid item it can see on any
   sheet, named with the page — which is what goes into `demo/VERIFY.md`. An
   Avoid hit is a ship blocker (`SKILL.md`), fixed like a failed line. The
   context that wrote the markup and the brief cannot grade the render — that is
   the self-assessment the rubric exists to remove. Read `demo/VERIFY.md`, fix
   every failed line and repeat. After three rounds with failures, stop and write
   `demo/FAILED.md` before going to step 9 without recording. It names every
   failing rubric line, every outstanding `slop` finding at `warning` severity,
   every `dead-scroll`, `no-engine` and `container-noop` finding, and the round
   count reached. A craft build that failed verification is not a deliverable,
   and the only thing that made a previous one look like one was that nothing on
   disk said otherwise.
8. **Record.** Only for a passing build: append the build's row to
   `~/.claude/wp-builder/FINGERPRINTS.md` in the shape `fingerprint.md` defines,
   and write the same fields into `.wp-create.json` under `"fingerprint"`. A
   build that failed after three rounds records no fingerprint, in either place.
9. **Report.** The intended curve, the felt curve from `demo/VERIFY.md`, the
   diff, the detector summary, and what could not be verified. When
   `demo/FAILED.md` exists, the summary opens with the failure and its numbers —
   the count of failing rubric lines out of seven, and the outstanding finding
   count — before anything the build did well. A previous build disclosed "I ran
   2 of 3 rounds… did not re-grade independently" as the third of three caveats
   under a completion banner, and the client read it as a finished demo.
   Disclosure that has to be inferred is not disclosure.

A craft build is finished here. Steps 3 and 4 are the plain path: take Step 4's
header, footer and responsive requirements (step 6 above says so) and nothing
else from them — its single-file rule, its ban on external dependencies and its
`:root` token list all contradict a craft build — then write Step 4.9's
`demo/.demo-plan.json` from the composition plan and print the Step 5 summary,
listing every page written, not just `index.html`.

## Step 2.7: Page References (plain mode only)

Skip this step in craft mode — craft consults its reference servers at Step 2.6,
sub-steps 3.6 and 3.7, and the precedence ladder there governs both modes.

If the `inspo` MCP server is registered, consult it for page-level direction before
generating anything: one `recommend` with the brief from Step 2, then at most two
`search_screens`, then `get_screen` on the three to five references kept. A tool
result is re-read on every later turn, so a fourth search costs more than it finds.

Take composition and section ordering only. The exclusions in Step 2.6 sub-step 3.7
apply here unchanged: the colour table never becomes tokens, `get_reference_jsx` is
never called, nothing reaches `/wp-yolo --transcribe`, and inspo never chooses a
motion device.

Plain mode writes no `demo/BRIEF.md`, so the citations go at the top of
`demo/index.html` as an HTML comment — a `References:` line per reference, each
starting with `inspo:` and then the slug, then one sentence on what was taken.

If the server is not registered or every call fails, write
`References: inspo unavailable` in that comment and continue. Never stop the build on
an inspo error.

## Step 3: Invoke Skills

Apply these skills to guide your work:

- **wp-demo**: Follow the demo creation standards
- **wp-css-system**: Use CSS custom properties and the design system approach
- **wp-responsive**: Ensure all layouts work across breakpoints

## Step 4: Generate the Demo

Create the `demo/` directory if it does not exist.

Generate `demo/index.html` with the following requirements:

### Structure
- Single self-contained HTML5 file with all CSS embedded in a `<style>` block
- No external dependencies (no CDN links, no external CSS/JS), except the one Google Fonts `<link>` the wp-demo skill's skeleton carries — `/wp-init` Step 4.5 self-hosts it
- Semantic HTML5 elements (`<header>`, `<main>`, `<section>`, `<footer>`, `<nav>`, `<article>`)

### CSS Design System
Define CSS custom properties in `:root` with the token names in
`${CLAUDE_PLUGIN_ROOT}/skills/wp-css-system/references/tokens.md`, the set the wp-demo skill's
skeleton starts from: `--color-primary`, `--color-background`, `--color-text`,
`--spacing-md`, `--font-family-primary`, `--font-size-base`, `--radius-md`,
`--shadow-md`, `--transition-base`, `--container-max` and the rest of that file.

### Section Delimiters
Every section MUST be wrapped with clear HTML comment delimiters:
```html
<!-- ============ SECTION: Hero ============ -->
<section id="hero" class="hero">
    ...
</section>
<!-- ============ END SECTION: Hero ============ -->
```

These delimiters are critical — they are used by `/wp-section` to extract individual sections.

### Responsive Design
- Mobile-first CSS approach
- Breakpoints: 576px, 768px, 1024px, 1440px
- Hamburger menu for mobile navigation
- Flexible grids that collapse on small screens
- Appropriate font scaling

### Content
- Use **the client's real sentences from `demo/RESEARCH.md`** (`## What they
  actually say`) wherever it covers the section; realistic placeholder content
  relevant to the client's industry only where it does not
- Where no client image exists, use a placeholder `<img>` whose `src` is an inline SVG at the intended aspect ratio, with `width`, `height` and `alt` (no external image URLs)
- Include bilingual hints as HTML comments where applicable: `<!-- i18n: hero_title -->`

### Header
- Logo area (placeholder)
- Navigation with realistic menu items
- Language switcher (show configured languages)
- Mobile hamburger toggle

### Footer
- Logo, copyright, contact info, social media links, legal links
- Multi-column responsive layout

## Step 4.9: Record the Section Plan

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-demo-run/references/section-plan.md` now and follow
it — it is this step, not background. It covers `demo/.demo-plan.json` in both modes: its
shape, unique section names, and the slots craft mode records.

## Step 5: Print Summary

```
=== Demo Created ===
Files: <every page written — demo/index.html and each interior page>
Sections: <list of sections, per page>

Open in browser to preview. Share with client for approval.
Next: Use /wp-header, /wp-footer, /wp-section <name> to convert to WordPress.
To iterate: Run /wp-demo iterate
```
