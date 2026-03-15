---
description: Create a demo HTML mockup for client approval — responsive, section-separated, ready for WordPress conversion
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
argument-hint: "[brief or 'iterate']"
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
