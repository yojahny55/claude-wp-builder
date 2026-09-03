---
description: Normalize any HTML into a plugin-compatible demo with section delimiters and BEM classes
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
argument-hint: "[path-to-html] [--craft]"
---

# WP Polish — Demo Normalizer

Normalize any HTML file into a plugin-compatible demo with section delimiters, semantic HTML5, and BEM class naming. Works with external HTML (Figma exports, hand-coded, other tools) or existing demos that need structural cleanup.

### `--craft` (retrofit audit)

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-demo-craft/SKILL.md` and audit the existing
demo against the refuse list and the taste floor. Report findings as a list, each
naming the rule and the offending selector or line. **Do not add motion and do not
restructure the page**; converting a plain demo to craft is a rebuild, not a
polish. The existing backup behaviour at `demo/.prepolish/` is unchanged.

## Step 1: Resolve Input Path

This step resolves paths and decides nothing else. It creates no directories and it puts no
file anywhere, so the copy Step 2 takes really is the document as it stood before this
command ran.

Check `$ARGUMENTS`:

- **If `$ARGUMENTS` is provided**: use it as the path to the HTML file to polish — the
  **source document**.
  - If the path points to a file **outside** `demo/`, the polished output is destined for
    `demo/index.html`, and Step 6 creates `demo/` when it writes there. Do **not** copy the
    source over `demo/index.html` here. Step 6 puts the polished result at that path anyway,
    and doing it early destroys the page already sitting there before Step 2 has preserved
    anything at all.
  - If the path points to a file **inside** `demo/` that is not `index.html` (e.g.,
    `demo/pricing.html`), polish it in-place — source and destination are the same file.
    Step 2 preserves the pre-polish copy under `demo/.prepolish/` (e.g.,
    `demo/.prepolish/pricing.html`), never beside the demo pages.
- **If `$ARGUMENTS` is empty**: Default to `demo/index.html`, as both source and destination.
  If the file does not exist, tell the user to provide a path or create a demo first with
  `/wp-demo`.

## Step 2: Preserve the Source Document

Save a copy of the source document under `demo/.prepolish/` before anything is written:

1. Create `demo/.prepolish/` if it does not exist.
2. Copy the **source document** resolved in Step 1 — not the demo page its polished output
   is destined for — to `demo/.prepolish/<source-filename>`, keeping the source's own
   filename. Polishing `demo/index.html` writes `demo/.prepolish/index.html`; polishing
   `demo/pricing.html` writes `demo/.prepolish/pricing.html`; polishing an outside file
   `figma-v2.html` writes `demo/.prepolish/figma-v2.html`, even though the polished page
   lands at `demo/index.html`.
3. Write that copy **only if `demo/.prepolish/<source-filename>` does not already exist**. If
   it does, it is the copy kept by an earlier polish of that same source document and the
   only unpolished version left; copying the already-polished page over it destroys the
   original silently and irreversibly. Leave it untouched, and say so in Step 7's report.

Naming the copy after the **source** document, rather than after the demo page it becomes, is
what keeps item 3's never-overwrite rule honest. `/wp-polish figma-v1.html` followed by
`/wp-polish figma-v2.html` both end up at `demo/index.html`, but they are two different
documents. Named after the demo page, the second run would find `demo/.prepolish/index.html`
already there, keep it under item 3, and Step 7 would present figma-v1's unpolished markup as
the pre-polish version of figma-v2 — a preserved original of a document nobody asked about.
Named after the source, each document owns its own copy and neither can be labelled as the
other, and the rule now fires only where it was meant to: a re-polish of the *same* document.

Two source documents from outside `demo/` can still collide on a filename (`~/a/export.html`
and `~/b/export.html`). If `demo/.prepolish/<source-filename>` is already there but does not
match the source you were given, keep the stored file — it is some other document's only
unpolished version — take no new copy, and say so in Step 7's report. Nothing is lost: a
source from outside `demo/` is still sitting at the path the user named.

The backup lives in a dot-prefixed subdirectory on purpose. `/wp-seed` turns **every**
`.html` file it finds in `demo/` into a WordPress Page whose slug is the filename, so a backup written beside
the demo pages seeds a phantom page out of pre-polish markup — one per backup. Within a
single `/wp-yolo` run that never fires, because Step 5 runs `/wp-seed` (item 1) before
`/wp-polish` (item 4); the exposure is the *next* seed — a second `/wp-yolo` over the same
demo folder, a standalone `/wp-polish` followed by `/wp-seed`, or any manual re-seed after
a polish. `demo/.prepolish/` falls outside any non-recursive enumeration of `demo/`: shell
globbing, Python's `glob`, `ripgrep` and `fd` all skip dot-prefixed entries by default, and
`/wp-seed` states no glob of its own — `commands/wp-seed.md` says only that it processes
the `.html` files in `demo/`. The
exception is a recursive descent that does not honour the dot rule — `find demo -name
'*.html'` walks into `demo/.prepolish/` and returns the backups — so anything switching to
`find` must add `-not -path 'demo/.prepolish/*'` itself — and, on a demo folder
`/wp-yolo` has already converted, `-not -path 'demo/.original/*'` alongside it, because
Step 2.6 keeps its own backups there.

`demo/.prepolish/` is not `demo/.original/`: `/wp-yolo` Step 2.6 keeps the
pre-**conversion** plain-CSS copy of each page in `demo/.original/<slug>.html`, while
`demo/.prepolish/<source-filename>` holds the pre-**polish** copy, which on the Tailwind path
is an already-converted page. Two artifacts, two directories — restore from the one that
matches what you mean to undo, and never write either into the other.

Read the source document's content into memory for analysis.

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

Write the modified HTML to the destination Step 1 resolved (`demo/index.html` for a source
from outside `demo/`, or the in-place file for non-index demos), creating `demo/` if it does
not exist.

## Step 7: Print Report

```
=== Demo Polished ===
Pre-polish backup: demo/.prepolish/index.html (copy of demo/index.html)
Output:            demo/index.html

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

The backup line names the file Step 2 actually wrote or kept, and in parentheses the document
that file is a copy of — which is the source document, not necessarily the page at `Output:`.
If Step 2 kept an existing copy of the same source document, append ` (kept from an earlier
run)`; that copy is `<source-filename>` as it stood before its first polish, and no later run
replaces it. If Step 2 found the filename already taken by a *different* document and took no
copy, say that on the backup line instead of naming a backup for this run. Never present a
stored copy as the pre-polish version of a document it did not come from: the file at
`demo/.prepolish/<source-filename>` is a copy of `<source-filename>`, and of nothing else.
