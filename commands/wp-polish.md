---
description: Normalize any HTML into a plugin-compatible demo with section delimiters and BEM classes
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
argument-hint: "[path-to-html]"
---

# WP Polish — Demo Normalizer

Normalize any HTML file into a plugin-compatible demo with section delimiters, semantic HTML5, and BEM class naming. Works with external HTML (Figma exports, hand-coded, other tools) or existing demos that need structural cleanup.

## Step 1: Resolve Input Path

Check `$ARGUMENTS`:

- **If `$ARGUMENTS` is provided**: Use it as the path to the HTML file.
  - If the path points to a file **outside** `demo/`, create the `demo/` directory if needed, then copy the file to `demo/index.html`.
  - If the path points to a file **inside** `demo/` that is not `index.html` (e.g., `demo/pricing.html`), polish it in-place. The original will be preserved as `demo/original-<filename>` (e.g., `demo/original-pricing.html`).
- **If `$ARGUMENTS` is empty**: Default to `demo/index.html`. If the file does not exist, tell the user to provide a path or create a demo first with `/wp-demo`.

## Step 2: Preserve Original

- If polishing `demo/index.html`: save a copy as `demo/original.html` (overwrites if exists).
- If polishing a non-index file inside `demo/`: save as `demo/original-<filename>` (e.g., `demo/original-pricing.html`).

Read the file content into memory for analysis.

## Step 3: Analyze Structure

Parse the HTML to identify logical sections. Use these detection strategies in order:

1. **Existing delimiters**: Look for `<!-- ============ SECTION:` comments already present. Record these sections as-is.
2. **Semantic landmarks**: Identify `<header>`, `<footer>`, `<main>`, `<nav>` elements.
3. **Section tags**: Find all `<section>` elements and derive names from their `id`, `class`, or the first heading inside them.
4. **Heading-based splitting**: If no `<section>` tags exist, use `<h1>`-`<h3>` elements as section boundaries. The heading text suggests the section name.
5. **Div wrappers**: As a last resort, look for top-level `<div>` wrappers with distinct class names or IDs that suggest distinct content areas.

Build a section map and present it to the user:

```
Detected sections:
  1. Header (from <header> tag)
  2. Hero (from <section id="hero">)
  3. Services (from <h2>Our Services</h2>)
  4. About (from <section class="about">)
  5. Contact (from <section id="contact">)
  6. Footer (from <footer> tag)

Confirm these sections? You can rename or reorder them.
Type the section number to rename, or press Enter to confirm.
```

Wait for user confirmation. Allow renaming individual sections.

## Step 4: Insert Delimiters

For each confirmed section, wrap it with the standard comment delimiters:

```html
<!-- ============ SECTION: Name ============ -->
...content...
<!-- ============ END SECTION: Name ============ -->
```

Rules:
- **Include** `<header>` as `SECTION: Header` and `<footer>` as `SECTION: Footer` — the `/wp-header` and `/wp-footer` commands expect these delimiters.
- **Skip** sections that already have correct delimiters (detected in Step 3.1).
- **Preserve** all existing content within sections — do not rewrite or reorder HTML.
- Place opening delimiter on the line immediately before the section's opening tag.
- Place closing delimiter on the line immediately after the section's closing tag.

## Step 5: Normalize Structure

Apply minimal structural fixes:

### Semantic Tags
- If the site header uses `<div>` instead of `<header>`, change the tag to `<header>` (preserve all attributes and content).
- If the site footer uses `<div>` instead of `<footer>`, change the tag to `<footer>`.
- If content sections use `<div>` instead of `<section>`, change the tag to `<section>`.
- Wrap content sections (between header and footer, not including them) in `<main>` if not already present.

### BEM Class Naming
- **Only add classes to elements that have NO `class` attribute at all.**
- Leave any element that already has a `class` attribute completely untouched, even if the classes are not BEM.
- For elements without classes, derive BEM names from the section:
  - The section name (lowercased) becomes the block: `.hero`, `.services`, `.about`
  - Direct children get `__element` suffix based on their role:
    - Headings: `__title`, `__subtitle`
    - Paragraphs: `__text`, `__description`
    - Images: `__image`
    - Links/buttons: `__cta`, `__link`
    - Wrappers/containers: `__content`, `__inner`, `__grid`

## Scope Boundaries

This command performs ONLY structural normalization. It does NOT:

- **Touch CSS or `:root` variables** — the `/wp-section` agents handle CSS independently during WordPress conversion
- **Redesign layout, spacing, or typography** — preserve the original design intent
- **Add responsive breakpoints** — that's the demo author's or `/wp-demo`'s responsibility
- **Extract project metadata** — that's `/wp-init`'s job

If the HTML structure cannot be reliably parsed (e.g., severely malformed markup), report what was found and ask the user to manually identify sections rather than guessing.

## Step 6: Write Output

Write the modified HTML to the target file (`demo/index.html` or the in-place file for non-index demos).

## Step 7: Print Report

```
=== Demo Polished ===
Original: demo/original.html
Output:   demo/index.html

Sections found: 6
  - Header
  - Hero
  - Services
  - About
  - Contact
  - Footer

Changes:
  - Added 6 section delimiters (12 comments)
  - Converted 3 <div> tags to semantic equivalents
  - Added BEM classes to 14 elements
  - Wrapped content in <main> tag

Next: Run /wp-init to scaffold the project using this demo.
```
