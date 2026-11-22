# /wp-section — Step 6.7

`commands/wp-section.md` sends the run here at Step 6.7 when the section slug is `blog`,
`journal`, `news` or `posts`. Follow it in order, after Step 6.5 and before the summary.

A blog section on the front page lists posts that need an archive and a single view to open,
and `/wp-page blog` is what builds them.

## Contents

- When it is skipped
- Running /wp-page blog
- What the summary says

## When it is skipped

Check these in order. The first that holds skips the step; record its reason for the summary.
Never overwrite a template to get past one of them.

1. **`--no-blog-page` was passed.** Reason: `--no-blog-page`.
2. **`--transcribe` was passed.** That is the `/wp-yolo` section walk, and `/wp-yolo` runs
   `/wp-page blog` once itself, from `pages[role=blog]` in its build manifest (`commands/wp-yolo.md`,
   page step 8). Running it here too would build the blog templates twice, once per blog
   section. Reason: `the /wp-yolo walk runs /wp-page blog itself`.
3. **The project is cinematic** (`Template: cinematic`, with or without `--hybrid`). `/wp-page`
   routes its CSS for `basic` and `tailwind` only, and the cinematic starter has no
   `assets/css/styles.css`, so the blog styles would land in a file the theme never loads.
   Reason: `/wp-page blog has no cinematic CSS route`.
4. **The blog templates already exist.** `/wp-page blog` writes
   `template-parts/journal/content-journal-card.php`; when the theme already has that file, the
   blog was built before (by a previous `/wp-page blog` or a previous blog section).
   Reason: `blog templates already exist (template-parts/journal/content-journal-card.php)`.
5. **`archive.php` or `single.php` exists and the operator does not confirm.** `/wp-page blog`
   writes both without looking at what is there, and either may have been edited by hand since
   the theme was scaffolded (the Tailwind starter ships both). Name the file or files that
   exist and ask: `archive.php / single.php exist and /wp-page blog would overwrite them. Run it?
   [y/N]`. Anything but yes skips the step. Reason: `would overwrite <files>; not confirmed`.

## Running /wp-page blog

Otherwise, read `${CLAUDE_PLUGIN_ROOT}/commands/wp-page.md` and follow it with the arguments
`blog`, plus `--force-adopted` when this run was given it. Run it whole, its own guards and
summary included: this step does not reimplement any part of it.

When `/wp-page` stops on one of its gates, do not undo the section. The section is built; report
`/wp-page blog` as not run, with its message verbatim, so the operator can run it by hand.

## What the summary says

Step 7's summary carries one line for this step:

```
  - Blog templates: built by /wp-page blog
  - Blog templates: skipped (<reason>)
  - Blog templates: /wp-page blog stopped: <its message>
```
