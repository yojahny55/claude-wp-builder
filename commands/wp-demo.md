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

1. **Brief.** Self-author `demo/BRIEF.md` from the project docs: brand rules;
   pain, person and promise; two or three named references and what specifically
   to take from each; vibe words; aesthetic family; assets already owned. Mark
   anything you invented as "Self-authored, not interviewed". Ask, in a single
   pass, only the questions the docs cannot answer. Show the brief once and
   proceed on a yes.
2. **Feeling curve.** One line per section: the emotion, then the on-screen cause.
   Adjacent sections that share a feeling mean one is filler. Name the peak as a
   sentence a visitor would say to a friend, and complete "it's the site where
   ___". Write all of it into `demo/BRIEF.md` before listing sections.
3. **Grammar and signature move.** Pick one grammar from `references/grammars.md`
   and one bespoke interaction that exists on this site alone.
4. **Fingerprint gate.** Read `~/.claude/wp-builder/FINGERPRINTS.md` (create it
   with a header row if absent). The plan must differ from every row on at least
   4 of the 6 axes. If it fails, change the plan, not the log.
5. **Score table.** Section, device, why. Check it against the pre-build list in
   the skill: four or more device families, no family twice in a row, one peak
   with the largest span and a quieter section before it.
6. **Build.** Same delimiters, `:root` tokens and BEM as plain mode. Motion comes
   from `data-motion-*` attributes only. Inline the contents of
   `${CLAUDE_PLUGIN_ROOT}/starter-theme/__tailwind__/assets/js/src/motion.js` in a
   `<script>` block, after loading GSAP and ScrollTrigger from
   `https://cdnjs.cloudflare.com` with pinned versions. The signature move goes in
   its own `<script id="signature">` block so `/wp-init` can lift it to
   `assets/js/signature.js`.
7. **Verify.** Run `/wp-demo-verify demo/index.html`. Fix what it finds, then
   report the intended curve, the felt curve and the diff.
8. **Record.** Append the build's row to `~/.claude/wp-builder/FINGERPRINTS.md`
   and write the same row into `.wp-create.json` under `"fingerprint"`.

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
