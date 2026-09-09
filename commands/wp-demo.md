---
description: Create a demo HTML mockup for client approval — responsive, section-separated, ready for WordPress conversion
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
argument-hint: "[brief] [--craft|--plain] | iterate"
---

# WP Demo — HTML Mockup Generator

Create a standalone HTML demo for client approval that will later be converted section-by-section into WordPress templates.

## Step 1: Read Project Context

Read `.claude/CLAUDE.md` to get the project name, slug, industry, description, and languages. If the file does not exist, tell the user to run `/wp-init` first.

## Step 2: Get the Brief

Check `$ARGUMENTS`:

- **If `$ARGUMENTS` is "iterate"**: Read the existing `demo/index.html` file, then ask the user what changes they want. Apply changes and skip to Step 4.
- **If `$ARGUMENTS` is provided** (not "iterate"): Use it as the client brief.
- **If `$ARGUMENTS` is empty**: Ask the user for:
  - Client brief / description of what the site should look and feel like
  - Reference screenshots or URLs (optional)
  - List of sections to include (e.g., Hero, About, Services, Team, Testimonials, Contact)

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
   works). Still exit 2: print what the probe said is missing (`playwright-core`
   or Chrome, with `npx playwright install chrome` as the fix) and **stop**. A
   craft build is never made blind and never falls back to plain; the user reruns
   once the browser exists.
1. **DESIGN.md.** Write `demo/DESIGN.md` per `references/design-md.md`: client
   docs first; then `npx designlang <url>` on the client's current site and on
   each reference URL the docs name (skip when there is none); then two or three
   rows from `${CLAUDE_PLUGIN_ROOT}/skills/wp-demo-craft/references/design-md/INDEX.md`
   by industry and tone for the gaps, cited by domain. If `.wp-create.json` has
   `firecrawl_url` and a reference is a Refero Styles page, scrape it for its
   do/don't list. Record `"design_md": "demo/DESIGN.md"` in `.wp-create.json`.
   `firecrawl_url` is optional and set by hand (a self-hosted instance or the
   client's own); never ask for a key.
2. **Fingerprint gate.** Read `~/.claude/wp-builder/FINGERPRINTS.md` (create it
   with the v2 header row if absent). The DESIGN.md fails when any row shares the
   display family, the text family, and an accent hue within 15 degrees. Change
   the type pair or the accent, not the log.
3. **Brief.** Self-author `demo/BRIEF.md` from the project docs: person, pain,
   promise, vibe words, two or three named references and what to take from
   each, assets owned, the feeling curve (one line per section: emotion, then
   the on-screen cause), the peak as a friend-quotable sentence, "it's the site
   where ___", authored silence. Mark anything invented "Self-authored, not
   interviewed". Ask, in one pass, only what the docs cannot answer. Show the
   brief once and proceed on a yes.
4. **Grammar, then composition plan.** Pick one grammar from
   `references/grammars.md` — it decides what a section is, what the chrome is
   for and what the ending does. Then open
   `${CLAUDE_PLUGIN_ROOT}/skills/wp-demo-craft/compositions/README.md` and look at
   each candidate's `preview-1440.png` and `preview-390.png`. One row per section
   of the curve: section, role, composition, why, motion cost. Mark exactly one
   row as the peak (`data-motion-peak`). Sum the cost and hold it under the
   budget in `references/devices.md`, which owns the pin caps, the per-index
   total and the interior-page rule. When the docs name no reference, pull four
   screenshots from the Landing Gallery MCP for the page kind first.
5. **Build.** Generate `:root` from `demo/DESIGN.md` onto the plugin token names.
   Copy each chosen composition's `section.html` and `section.css`, fill the
   `{{slots}}` with real copy and real assets, keep the delimiters and the BEM
   block. Same delimiters and `:root` contract as plain mode. Motion comes from
   `data-motion-*` attributes only. Inline the contents of
   `${CLAUDE_PLUGIN_ROOT}/starter-theme/__tailwind__/assets/js/src/motion.js` in a
   `<script type="module">` block (`motion.js` uses `export function initMotion`,
   so a plain non-module `<script>` throws `SyntaxError: Unexpected token 'export'`
   and silently disables all motion), after loading GSAP and ScrollTrigger from
   `https://cdnjs.cloudflare.com` with pinned versions. Any bespoke effect goes
   in its own `<script id="signature">` block so `/wp-init` can lift it to
   `assets/js/signature.js`.
6. **Loop.** At most three rounds. Each round is `/wp-demo-verify demo/` — the
   directory, so every page is walked — which runs the `impeccable detect` gate
   and the walk and writes `demo/VERIFY.md`. That command is the one place the
   detector and rubric contract is written; run it, do not restate it here. Read
   `demo/VERIFY.md`, fix every failed line and repeat. After three rounds with
   failures, stop, report what still fails, and go to step 8 without recording.
7. **Record.** Only for a passing build: append the row
   `| client | display | text | accent | canvas | date |` to
   `~/.claude/wp-builder/FINGERPRINTS.md` and write the same fields into
   `.wp-create.json` under `"fingerprint"`. A build that failed after three
   rounds records no fingerprint, in either place.
8. **Report.** The intended curve, the felt curve from `demo/VERIFY.md`, the
   diff, the detector summary, and what could not be verified.

A craft build is finished here: skip Steps 3 and 4 (they describe the plain
single-file demo, which forbids the CDN and the motion this build needs) and
print the Step 5 summary.

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
- Use realistic placeholder content relevant to the client's industry
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
File: demo/index.html
Sections: <list of sections>

Open in browser to preview. Share with client for approval.
Next: Use /wp-header, /wp-footer, /wp-section <name> to convert to WordPress.
To iterate: Run /wp-demo iterate
```
