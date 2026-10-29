# Elementor fix playbook (adopted sites)

Read this when `stack.builder` is `elementor` and a finding or a fix touches markup an
Elementor widget prints. When `stack.builder` is anything else, do not load it. It extends
the "Builder first" rule in `${CLAUDE_PLUGIN_ROOT}/skills/wp-audit-run/references/fix.md`;
it does not replace it.

## Contents

- Where each fix belongs
- After any edit to Elementor data or a render filter
- Widget traps and known false positives
- The measurement rule

## Where each fix belongs

The site owner's rule on these sites: whatever Elementor can do is done in Elementor
(widget settings, `_elementor_data`), not in theme code. Theme code is for what a widget
control cannot express.

| Fix | Belongs in | Owner | Why |
|---|---|---|---|
| Heading tag, alt text, link target, button text, spacing, colours of one widget | The widget setting in `_elementor_data` | `content` | The control exists; the edit travels with the editor, not the commit |
| Loop Grid pagination 404 | Widget setting `pagination_individual_handle = yes` | `content` | Links become `?e-page-<widget-id>=N` and stop 404ing |
| CSS for one widget that the theme sheet cannot beat | The widget's Custom CSS (Elementor Pro) or a selector of matching specificity | `content` / `code` | Elementor selectors are long; see the trap below |
| `aria-label` on a link inside a widget | JS or a render filter in the child theme | `code` | Custom attributes land on the widget wrapper `<div>`, not the inner `<a>` |
| `<main id="content">` landmark on a page with several root containers | `elementor/frontend/the_content` plus the `elementor/theme/before_do_*` / `after_do_*` hooks in the child theme | `code` | Elementor has no control that wraps several root containers |
| `fetchpriority`, `role`/ARIA fixes on Loop Grid markup, missing `width`/`height` on avatars | One output-buffer callback on `template_redirect` in the child theme | `code` | Elementor rewrites its output after the usual filters ran |
| Theme options after switching the parent theme for a child theme | `$WP option get theme_mods_<parent>` copied to `theme_mods_<child>` | `setting` | The switch drops `theme_mods_<parent>` |

A fix in the left column that the control cannot express (no hover state, one widget when
the defect is site-wide) goes to the theme, with the reason in the finding's `Method`.
Do not hard-code a widget ID in a theme filter when a class selects the same elements.

## After any edit to Elementor data or a render filter

1. **Before the edit:** export the post's `_elementor_data` to a JSON file outside the
   docroot (`$WP post meta get <post-id> _elementor_data > <out>/backups/<post-id>.json`)
   and record the path in the replay entry.
2. **Keep the list of edits.** Database edits do not travel with the commit and must be
   replayed on production by hand: append each to `<out>/replay.json` as it is applied
   (post ID, widget, setting, previous value).
3. **After the edit,** run `$WP elementor flush-css`. A render-filter change needs it too.
   `wp elementor flush-cache` does not exist; do not suggest it.
4. Re-measure the page (below) and re-run the check that produced the finding.

## Widget traps and known false positives

- **Optimized image loading re-adds `fetchpriority="high"`** in Elementor's own output
  buffer, so `wp_get_attachment_image_attributes` and content filters cannot remove it. A
  single `template_redirect` output-buffer callback in the child theme is the reliable
  seam; read the served HTML, not the filter result.
- **Loop Grid roles.** Loop Grid puts `role=list` on the grid and on `.swiper`, and
  `role=listitem` on each `<article>`. axe reports `aria-allowed-role` and
  `aria-required-children` for it. The same output-buffer callback is the fix.
- **`a.elementor-post__thumbnail__link`** (Posts and Archive widgets) repeats the title
  link and has no accessible name. The known fix is `aria-hidden="true"` on it; it already
  carries `tabindex="-1"`. Audits file it on every page, and one agent may call it a
  usability warning while another says it is not a keyboard defect: record it once, as one
  finding with this fix.
- **Heading tag changes restyle the element.** Changing `h3` to `h2` (or a widget's
  `title_tag`) can change weight (600 to 700) and colour through the kit's typography.
  Measure before and after and revert or compensate.
- **Theme CSS loses to Elementor's long selectors**, for example
  `.elementor-icon-list-items .elementor-icon-list-item .elementor-icon-list-text a`. Match
  the specificity or use the widget's Custom CSS; do not reach for `!important`.
- **Video widget `lazy_load` raised JS errors.** A facade (thumbnail plus play link) built
  by replacing the widget's `data-settings` worked.

## The measurement rule

Every fix here is `visual` in the sense of `fix.md`: a tag swap, a class change or a widget
setting can restyle the element with no value edited. Take two baselines and one
after-snapshot with `node ${CLAUDE_PLUGIN_ROOT}/bin/style-diff.mjs` at desktop and mobile,
on every element sharing the widget or class, and read the diff. A value that moved and was
not agreed is a regression: fix it before the next fix.
