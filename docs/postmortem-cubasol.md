# Postmortem — Cubasol

What the Cubasol build (52 commits, one external web audit, one `.claude/CLAUDE.md`
full of scar tissue) says about this plugin and about the `figma-to-demo` skill.

Only defects with a **traceable root cause in a tool** are listed. Design changes,
client decisions and content the client still owes are excluded — those are not bugs.

Evidence: `git log` on the Cubasol repository, its uncommitted audit-remediation
diff, and `docs/auditoria/informe-2026-08-31.md` (166/244 criteria, 38 failures).

---

## A. Fixed in this branch

| # | Defect | Cost on Cubasol | Root cause | Fix |
|---|---|---|---|---|
| A1 | SVG uploads granted to every media uploader | stored XSS available to the Author role | `starter-theme/__tailwind__/inc/theme-setup.php` added the mime unconditionally | gated on `unfiltered_html` |
| A2 | `<main>` nested inside `<main>` | invalid document on 6 templates; removed by hand mid-build | `header.php` opens `<main>` **and** six templates open their own | the six no longer open one |
| A3 | ACF field groups invisible in the dashboard | "Undefined array key ID"; groups stayed PHP-local | bootstrap passed `acf_prepare_field_group_for_export()` straight to `acf_write_json_field_group()`, which reads the `ID` the former strips | `$export['ID']` restored before the write |
| A4 | Every Tailwind utility compiled to nothing | whole chrome build rendered unstyled until diagnosed | v4 discovers sources by walking up to the git root, which does not reach a theme under `wp-content/themes/` | explicit `@source` in `main.css` |
| A5 | All 36 translation twin fields dead | client fills a tab the front end never reads | starter hardcodes `_es` twins (English-primary assumption) while `get_field()` appends the **non-default** language suffix | `/wp-init` now rewrites the suffix, with a verifying grep |
| A6 | `_` in an arbitrary Tailwind variant is an escaped space | 22 occurrences, 3 commits, **3 focus indicators that never once appeared** | undocumented | `wp-tailwind-system`: rule + table + two grep gates in Verify |
| A7 | Quotes inside an arbitrary variant truncate the class | one dead rule, one wrong-looking pill | undocumented | same section |
| A8 | Unlayered CSS beats `@layer utilities` | base rules overrode the markup; CF7's sheet beat every theme rule | undocumented | same section |
| A9 | Fixed `h-`/`w-` from a one-language demo | 7 card shells clipped in English; 3 controls stranded whitespace | undocumented | same section |
| A10 | `post_author = 0` | recurring across projects | `wp post create` / `wp media import` default | `wp-cli-patterns`: pattern + end-of-run sweep |
| A11 | `default_value` on an options field | seeded values and client edits invisible behind `acf-options-for-polylang` | undocumented | `wp-acf` rule 14 |
| A12 | An options page is one global store | Spanish value printed on the English page | undocumented | `wp-acf` rule 15 |
| A13 | An object with no Polylang language is invisible | province terms and seeded posts vanished from the front end | undocumented | `wp-polylang` + sweep command |
| A14 | Translating a proper-noun taxonomy | slugs became `matanzas-en` in shareable URLs; the importer flipped 14 terms `es`→`en` and emptied every Spanish facet | undocumented | `wp-polylang`: do not register such a taxonomy |
| A15 | `post_type_archive_title()` is not translatable | English visitor got a Spanish `<title>` | undocumented | `wp-polylang` + filter recipe |
| A16 | The demo's JavaScript was never ported | carousels, gallery, listboxes and the filter drawer all **dead** on delivery; the parity gate passed 66/66 because it measures geometry at rest | `/wp-yolo` ports chrome JS and nothing else, and never enumerates `demo/js/*.js` | new Step 4.6 "Behaviour carry" |
| A17 | `/wp-yolo` re-run destroys the build | project CLAUDE.md carries a hand-written "never run this again" warning | no gate | Step 1 refuses on an already-built theme; `--force` to override |
| A18 | Rank Math active but unconfigured shipped | the audit's #1 finding: no canonical on archives, 0 JSON-LD, no meta — after `/wp-finalize` passed | `/wp-finalize` never checks it | new runtime checks 7–11 (author, SEO configured, `href="#"`, one `<h1>`, no mobile overflow) |
| A19 | `rank_math_registration_skip` unset | Rank Math loads **no** frontend and **no** sitemap; presented as a `/page-sitemap.xml` 404 | configuring via WP-CLI skips what the wizard would set | `wp-audit-rankmath` Step 1.5 |
| A20 | CPTs missing from sitemap, Titles & Meta, metabox | under Polylang only | Rank Math snapshots post types on `pll_init`, before theme CPTs exist | same step: re-take on `init` 99 |
| A21 | CF7 could not be made to match the demo | one large commit of trial and error | undocumented | `wp-cf7`: "Making CF7 look like the demo" (dequeue, `display:contents`, autop, `<button>` not `[submit]`, growing panel) |

## B. Fixed in `figma-to-demo`

| # | Defect | Cost | Fix |
|---|---|---|---|
| B1 | The design's orange veil rebuilt as a CSS background layer | 3 commits; wrong on all three cards (veil too heavy, visible seam); PNGs up to 1546K where a flat webp is 104K | export the composited node flat at 2x, convert to webp |
| B2 | Designer's portrait crops shipped but never referenced | mobile `cover`-cropped the landscape photo — a zoomed bell tower instead of the scene; 2 commits | every supplied crop must be wired into its media query; name the ones the designer did not supply |
| B3 | Mobile override kept two-layer comma syntax over a single image | photo stretched and offset 35px | covered in B2's bullet |
| B4 | Fixed heights/widths sized for one language | 7 clipped card shells, 3 stranded controls | `min-height` / `width: fit-content` + `min-width` |
| B5 | Hover-only feedback | selected filters and open pills were invisible on touch; 3 commits | selected/open state gets its own paint below the tablet breakpoint |
| B6 | Chrome drift across pages | fixed rail on 5 of 13 pages; no shared footer, so the rail was duplicated at the top of eleven page scripts | one shared chrome partial, one `shared.js` |
| B7 | Markup contradicting its own script | pager drew 3 chips for 12 cards while the script paged by 9 | decide it in the demo |
| B8 | Broken CSS shipped | `.icon-mail--gray{color:undefined}` | grep for `undefined`/`NaN`/`null` before handover |
| B9 | Mocks indistinguishable from features | forms posting to `"#"`, client-side filtering | mark them in the HTML |
| B10 | `:nth-child` margins inside a `gap` grid | one card 33px out of line in every eventos row | rhythm comes from `gap` |
| B11 | Accessibility never checked | brand orange **3.07:1** on white across 78 elements, search icon **2.59:1**, 52 touch targets under 24px, no `<h1>` | contrast/target/`<h1>` checks, and report a design that fails them |

## C. Known, not fixed here

| # | Item | Why not |
|---|---|---|
| C1 | Starter `assets/js/src/index.js` still carries dead `.menu-toggle` / `.mobile-menu` boilerplate | one dead listener, removed in a minute by any build; not worth a starter change on its own |
| C2 | `/wp-yolo`'s parity gate measures geometry at rest, so it cannot see dead JavaScript, wrong colours or broken behaviour | A16's browser pass covers it for now; a behaviour smoke-check in the gate is the real fix |
| C3 | The audit's remaining code findings — `srcset`/`loading="lazy"` coverage, 65ch measure, required-field marks, link underlines, `x-default` hreflang, gzip/`Cache-Control` | these belong to the `wp-audit-*` agents, which were never run on Cubasol; verify they are covered there before adding anything |
