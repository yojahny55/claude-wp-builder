# /wp-section — Step 2

`commands/wp-section.md` sends the run here at Step 2 when `--hybrid` is set (given, or implied on a cinematic project with no `--target`). Follow it for the rest of the run; every other step stays as the command writes it.

## Contents

- What changes under `--hybrid`

## What changes under `--hybrid`

Under `--hybrid`, four things change and nothing else does:

1. **Fields** — `wp-acf` does not write `fields/<section>.php`. It appends one flexible-content
   **layout** named `<section>` (label `<Section Name>`) to the `trailing_sections` field in
   `fields/trailing-sections.php`, carrying the section's sub-fields under the normal
   `<section>_<element>` / `field_<section>_<element>` naming. If that file does not exist yet
   (init ran with `--no-hybrid`), create it with the `trailing_sections` flexible-content field
   attached to the front page, then add the layout.
2. **Template** — `template-parts/section-<section>.php` is rendered from inside the trailing
   `have_rows()` loop (see `starter-theme/__cinematic__/front-page.php`), so it reads its values
   with `get_sub_field('<field>')` — appending `_<lang>` for the secondary language the same way
   `prefix_get_field()` does — never `prefix_get_field()` / `get_field()`, which would resolve
   against the page, not the row.
3. **CSS** — the cinematic starter has no `assets/css/styles.css`; the CSS agent appends the
   section block to `assets/css/cinematic.css` under `/* ====== Section: <Name> ====== */`.
4. **Injection** — skip Step 6 entirely. The layout renders because the loop maps every
   `get_row_layout()` to `template-parts/section-<layout>.php`. Passing `--hybrid` with an explicit `--target` is a contradiction — error out
   and ask for one or the other.
