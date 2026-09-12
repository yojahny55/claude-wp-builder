---
description: Create a demo HTML mockup for client approval — responsive, section-separated, ready for WordPress conversion
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent
argument-hint: "[brief] [--craft|--plain] | iterate"
---

# WP Demo — HTML Mockup Generator

Create a standalone HTML demo for client approval that will later be converted section-by-section into WordPress templates.

## Step 1: Read Project Context

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
   plugin's own `node_modules`, then the project's, which is why installing here
   works; say first that this writes a `package.json` and a `node_modules/` into
   the WordPress project root). After the retry, **only exit 0 continues** —
   exit 2 means print what the probe said is missing (`playwright-core` or
   Chrome, with `npx playwright install chrome` as the fix), and any other exit
   code (127 for a missing `node`, or a crash) means print it verbatim. Either
   way **stop**. A craft build is never made blind and never falls back to plain;
   the user reruns once the browser exists.
1. **DESIGN.md.** Write `demo/DESIGN.md` per
   `${CLAUDE_PLUGIN_ROOT}/skills/wp-demo-craft/references/design-md.md`: client
   docs first; then `npx designlang@12 <url>` (major-version pinned for the reason
   `references/design-md.md` gives) on the client's current site — the URL the docs
   name, **or `research.site` from `demo/RESEARCH.md` when `confidence` is
   `confirmed`** — and on each reference URL the docs name (skip when there is
   neither); then two or three
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
3. **Brief.** Self-author `demo/BRIEF.md` from the project docs: person, pain,
   promise, vibe words, two or three named references and what to take from
   each, assets owned, the feeling curve (one line per section: emotion, then
   the on-screen cause), the peak as a friend-quotable sentence, "it's the site
   where ___", authored silence. When `demo/RESEARCH.md` exists, each of
   person, pain and promise either **cites the `demo/RESEARCH.md` line and its
   source URL, or keeps the marker** — and the marker now means something,
   because there was an alternative. Mark anything invented "Self-authored,
   not interviewed". Ask, in one pass, only what the docs cannot answer. Show
   the brief once and proceed on a yes.

   **3.5. Inventory the assets on disk.** List every image, SVG and font under the
   project's `docs/` with a role — `logo`, `hero`, `portrait`, `product`, `texture`,
   `font` — and write the list into `demo/BRIEF.md` under `## Assets on disk`. The
   build uses them; any file left unused is named there with the reason. The header
   chrome takes its logo from this list.

   A previous build set the wordmark as live text while a 400x400 transparent PNG of
   the client's real logo sat in `docs/`, and listed "transparent-PNG logo" as owed
   by the client in the same run. Nothing in the flow had told it the file existed.
4. **Classify the domain.** If `.wp-create.json` already has `"domain"` — a prior
   `/wp-demo` or `/wp-yolo` run against this same project recorded it — read it and
   move on; **do not re-classify**. The manifest is the shared source of truth, and a
   second run that re-derives the domain overwrites an operator's `name the domain
   directly` override with the match it already rejected. Otherwise, match the
   English-language material in **the client documents and `demo/RESEARCH.md`**
   (sections `## What they actually say` and `## Competitors`) against the
   keyword lists in
   `${CLAUDE_PLUGIN_ROOT}/skills/wp-demo-craft/references/domains/domains.csv`.
   A domain is matched when **two distinct keywords** from its list appear in the
   docs; below that, report `unclassified` and carry on without constraining
   anything, because a wrong category is worse than none. When more than one
   domain clears the threshold, the highest hit count wins; on an exact tie for
   the top count, report both names and proceed `unclassified` for the same
   reason. The lists are English-only: a docs set with no English-language
   material is `unclassified` **with that reason stated**, not silently, and the
   operator may name the domain directly instead of relying on the match. Record
   the result in `.wp-create.json` under `"domain"` as `name`, `score`, `matched`
   and `confidence`, recording in `matched` **which corpus produced each hit**
   — `docs` or `research` — so an operator can tell a category drawn from
   the client's own material from one drawn from a competitor's marketing
   copy. The threshold does not move: two distinct keywords are still
   required., so the decision is auditable and `/wp-yolo` reads it rather
   than re-deriving it. State the match and its score in one line.

   A matched domain does exactly two things. Its `page_pattern` and
   `considerations` both fold into the brief as stated constraints — never as a
   mapping onto this project's own section roles, which the catalogue's 77
   free-text patterns have no correspondence to. It **never touches tokens**:
   colour and type come from `demo/DESIGN.md` and the client's own material,
   never from a category. A low `confidence` value is reported alongside the
   match rather than hidden, and a build may ignore a weak match with a one-line
   reason.
5. **Grammar, then composition plan.** Pick one grammar from
   `${CLAUDE_PLUGIN_ROOT}/skills/wp-demo-craft/references/grammars.md` — it
   decides what a section is, what the chrome is for and what the ending does.
   Then open
   `${CLAUDE_PLUGIN_ROOT}/skills/wp-demo-craft/compositions/README.md` and look at
   each candidate's `preview-1440.png` and `preview-390.png`. One row per
   section of the curve: section, role, composition, why, motion cost,
   the domain signal that justified it, citing the brief constraint from
   sub-step 4, or writing "no domain signal" when none applies; and the
   research signal — what `demo/RESEARCH.md`'s `## Signals` says this
   sector does at this point in the page, and whether this row follows it
   or breaks it — or "no research signal" when none applies. The two are
   different axes: the domain signal constrains page pattern and
   considerations, while the research signal is what lets a build
   deliberately not look like its competitors. This is
   what makes sub-step 4's classification bind on the plan instead of
   sitting unread. Mark exactly one row as the peak (`data-motion-peak`).
   Sum the cost and hold it under the
   budget in `${CLAUDE_PLUGIN_ROOT}/skills/wp-demo-craft/references/devices.md`,
   which owns the pin caps, the per-index total and the interior-page rule. When
   the docs name no reference and the Landing Gallery MCP is connected, pull
   four screenshots for the page kind first; when it is not, say so and choose
   from the previews alone.

   **5.5. Image plan.** Craft builds only, and only when the composition plan
   includes a composition that declares an image slot (`hero-split`,
   `hero-bleed`, `feature-zigzag`). Skip in one line otherwise.

   Then decide whether to generate, in this order. **Neither `GEMINI_API_KEY`
   nor `OPENAI_API_KEY` is set in the environment** — generate nothing, say so
   in one line, and go to step 6. No question is asked, because there is
   nothing to spend and nothing to decide, so a project that never opts in
   behaves exactly as it does today. Otherwise, **`.wp-create.json` already has
   `"image provider"`** — read it and use it; a value of `"none"` records an
   earlier decline and is handled exactly like the no-key branch above:
   generate nothing, say so in one line, go to step 6, and do not ask again.
   Otherwise, **a key is set, gaps exist to fill, and the line is absent** —
   ask once, offering the provider matching whichever key is present —
   `google/gemini-3.1-flash-image` for `GEMINI_API_KEY`, or `gpt-image-2.5-flare`
   (faster, cheaper) / `gpt-image-2.5-sunburst` (higher quality) for
   `OPENAI_API_KEY` — and recommending `google/gemini-3.1-flash-image` when both
   keys are present, because Google offers all three of the library's crops
   (4:5, 3:2, 4:3) exactly while OpenAI's three fixed sizes make every one of
   them inexact. Write the
   operator's answer into `.wp-create.json` as `"image provider":
   "<vendor>/<model>"` on a yes, or `"image provider": "none"` on a decline —
   a decline then goes to step 6 exactly like the no-key branch above — so no
   later run re-asks.

   Write `demo/.image-plan.json` from this step's own composition table and
   step 3.5's asset inventory:

   ```json
   {
     "provider": "google/gemini-3.1-flash-image",
     "sections": [{"page": "index", "section": "hero", "composition": "hero-bleed"}],
     "assets_on_disk": [{"path": "docs/logo.png", "role": "logo"}]
   }
   ```

   Then run the planner, which makes no network call and needs no key:

   ```bash
   node "${CLAUDE_PLUGIN_ROOT}/bin/image-gen.mjs" plan --demo demo/
   ```

   It fills in `gaps[]` — one per image slot, each with the aspect and size read
   off that composition's own `<img>` tag — and `unused_assets[]`.

   For each gap set **exactly one of `prompt` or `use`**; the script refuses a
   plan where a gap has both or neither, before it issues any request. Set `use`
   to a path from `unused_assets[]` when a real client file belongs in that slot
   — a real asset always wins and is never generated. Otherwise write a `prompt`
   from the brief: the person, the pain, the vibe words, the domain, and
   **the vocabulary from `demo/RESEARCH.md`'s `## Signals`** — its "use"
   terms and none of its "avoid" terms — not a generic stock description.
   A plate built from sector filler looks like the sector it was meant to
   stand out from.
   The script does not match assets to slots itself,
   on purpose: the asset roles (`logo/hero/portrait/product/texture`) and the
   composition roles (`hero/proof/feature/...`) are different vocabularies, and
   `feature-zigzag` has two slots of identical role, so any automatic mapping
   would be invented.

   Show the table the planner printed and ask once. **Costs are estimates, not a
   bill.** A yes on that table is the authorisation for the whole plan; do not
   ask again per image. On a no, edit the prompts in `demo/.image-plan.json` and
   re-run `plan` — an edited prompt changes its hash, so it regenerates rather
   than serving the previous plate.

   On a yes:

   ```bash
   node "${CLAUDE_PLUGIN_ROOT}/bin/image-gen.mjs" run --demo demo/
   ```

   **The key comes from the environment and nowhere else.** It is never pasted
   into chat, never written into `.wp-create.json`, never echoed into a log or
   into the demo. With plates to generate and no key set, the script exits 3
   having written nothing and billed nothing, and names the variable to export
   (`GEMINI_API_KEY` or `OPENAI_API_KEY`). That is a stop, not a fallback: there
   is no placeholder path, and step 6's `{{`-blocker still refuses the page.

   Exit 4 means some slots failed while others succeeded. Plates already
   generated are kept and will not be re-billed on the next run.

   Append a `## Generated images` section to `demo/BRIEF.md`, summarised from
   the `gen-<hash>.json` sidecars on disk, naming the model, the date, the
   estimated total, and — for Google — that every plate carries an invisible
   SynthID watermark identifying it as AI-generated. Entries filled from `use`
   are real client files: list them separately, never as generated.
6. **Build.** Create `demo/` if absent and write `demo/index.html` plus
   **one file per page in the agreed page set** (`about.html`, `services.html`,
   `contact.html` — whatever the docs and the curve named). Interior pages are
   built here, not left for later: an index alone is half the failure this mode
   exists to fix, and step 7 walks the whole directory. Every page carries the
   header and footer chrome from Step 4 (logo, nav, language switcher, hamburger
   at mobile, footer columns) and Step 4's responsive breakpoints; ignore Step
   4's single-file, no-CDN, `:root` token and placeholder-content clauses, which
   are the plain path.
   Generate `:root` from `demo/DESIGN.md` onto the token names in
   `${CLAUDE_PLUGIN_ROOT}/skills/wp-demo-craft/references/design-md.md` — the
   craft tokens (`--color-canvas`, `--color-ink`, `--font-display` and the rest),
   which are what every composition's CSS already uses, not plain mode's
   `--color-primary` set. The section delimiters are the ones plain mode uses,
   unchanged, because `/wp-section` reads them either way.
   Emit this **on every page this step writes** — `index.html` and each interior
   page alike, since each carries its own `<style>` — immediately before that
   page's `:root` block and in the same `<style>`:

   ```css
   @property --container-max { syntax: "<length>"; inherits: true; initial-value: 1280px; }
   ```

   `var(--container-max, 1280px)` guards a token that is *absent*. It does not
   guard one that is present and malformed — `wide`, an empty string — because
   `var()` substitutes the bad value and `calc()` is then invalid at
   computed-value time, which unsets `padding-inline` to `0` at every viewport,
   phones included. `@property` makes an invalid value fall back to
   `initial-value` instead. Where `@property` is unsupported the rule is ignored
   and the `1280px` fallback still covers the absent case, so it needs no
   `@supports` guard.
   Copy each chosen composition's `section.html` and `section.css`, fill the
   `{{slots}}` with real copy and real assets — an image slot fills from that
   gap's own `result.file` in `demo/.image-plan.json`, keyed by that gap's own
   `slot` field, not a fixed string: `feature-zigzag`'s two gaps use
   `feature_1_image_src` and `feature_2_image_src`, for example — **no page may ship with a
   `{{` left in it**: several slots fill `alt` and `aria-label` attributes, where
   an unsubstituted marker is read out verbatim by a screen reader and never
   appears on screen for anyone to notice — keep the delimiters and the BEM
   block. Motion comes from `data-motion-*` attributes only. Inline the contents of
   `${CLAUDE_PLUGIN_ROOT}/starter-theme/__tailwind__/assets/js/src/motion.js` in a
   `<script type="module">` block (`motion.js` uses `export function initMotion`,
   so a plain non-module `<script>` throws `SyntaxError: Unexpected token 'export'`
   and silently disables all motion), after loading GSAP and ScrollTrigger from
   `https://cdnjs.cloudflare.com` with pinned versions. Any bespoke effect goes
   in its own `<script id="signature">` block so `/wp-init` can lift it to
   `assets/js/signature.js`.
   Inline `${CLAUDE_PLUGIN_ROOT}/starter-theme/__tailwind__/assets/css/src/tailwindcss/utilities/motion.css`
   into a `<style>` block in the same step. It is the CSS half of the engine and
   carries the `reveal` device wherever the browser supports scroll-driven
   animation; without it, a demo in a modern browser reveals nothing, because
   `motion.js` yields that device to the stylesheet.
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
   `demo/.verify/` and the seven rubric lines, and ask for a pass or fail per line
   with one sentence per failure, which is what goes into `demo/VERIFY.md`. The
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
`:root` token list all contradict a craft build — then print the Step 5 summary,
listing every page written, not just `index.html`.

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
- No external dependencies (no CDN links, no external CSS/JS)
- Semantic HTML5 elements (`<header>`, `<main>`, `<section>`, `<footer>`, `<nav>`, `<article>`)

### CSS Design System
Define CSS custom properties in `:root` for:
- Colors: `--color-primary`, `--color-secondary`, `--color-accent`, `--color-dark`, `--color-light`, `--color-text`, `--color-text-light`, `--color-bg`, `--color-bg-alt`
- Typography: `--font-heading`, `--font-body`, `--font-size-base`, `--font-size-sm`, `--font-size-lg`, `--font-size-xl`, `--font-size-2xl`, `--font-size-3xl`, `--font-size-4xl`
- Spacing: `--space-xs`, `--space-sm`, `--space-md`, `--space-lg`, `--space-xl`, `--space-2xl`, `--space-3xl`
- Layout: `--container-max`, `--container-padding`
- Effects: `--radius-sm`, `--radius-md`, `--radius-lg`, `--shadow-sm`, `--shadow-md`, `--shadow-lg`, `--transition`

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
- Include placeholder images using CSS background colors or SVG placeholders (no external image URLs)
- Include bilingual hints as HTML comments where applicable: `<!-- i18n: hero_title -->`

### Header
- Logo area (placeholder)
- Navigation with realistic menu items
- Language switcher (show configured languages)
- Mobile hamburger toggle

### Footer
- Logo, copyright, contact info, social media links, legal links
- Multi-column responsive layout

## Step 5: Print Summary

```
=== Demo Created ===
Files: <every page written — demo/index.html and each interior page>
Sections: <list of sections, per page>

Open in browser to preview. Share with client for approval.
Next: Use /wp-header, /wp-footer, /wp-section <name> to convert to WordPress.
To iterate: Run /wp-demo iterate
```
