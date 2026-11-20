# Architecture: why it is shaped this way

The rules live in `CLAUDE.md`; this is the reasoning and history behind them: why Polylang is the default, how the i18n seam works, how the two craft token vocabularies are joined, and what the store plugin owns.

## i18n

**New scaffolds default to `polylang`, and the reason is SEO.** The suffix model
serves both languages from one URL off `?lang=`/cookie/`Accept-Language`, so a
crawler only ever sees the primary language; `?lang=es` canonicalizes back to the
primary URL, there is no hreflang pair because there is only one post, and per-post
meta leaves Rank Math nowhere to store a translated title or description. `suffix`
is therefore offered as what it is — a language toggle for a site whose second
language does not need to be found — not as a way to build a bilingual site that
has to rank. Existing projects are untouched; the absent-line fallback stays
`suffix`.

The seam is a single file: `inc/i18n.php`. Templates call `prefix_get_field()`
and friends and never `get_field()` directly, so swapping that file switches the
whole theme's model with no template changes. The Polylang variants live in
`starter-theme/_i18n-variants/<template>.php` and are copied over `inc/i18n.php`
by `/wp-init`. They are kept OUT of the theme directories on purpose: a starter
carrying two definitions of the same function fatals the moment anything globs
`inc/*.php`, and `tests/checks/tailwind-starter.sh` refuses that state. The two
starters have different contracts (ten helpers vs four), so each variant
mirrors its own, and `tests/checks/wp-polylang.sh` asserts the pairing per
starter.

One deliberate crossover: under Polylang, ACF **options-page** fields keep their
`_<lang>` suffixes. Options are global — one set of values per site, not per
language — so Polylang's one-post-per-language model does not reach them and the
free plugin does not translate them. `wp-acf` therefore drops `_<lang>`
duplicates everywhere except the settings group.

The Polylang path is real code with real failure modes: translations join through the
`post_translations` taxonomy, so anything that writes translations must go through
`pll_save_post_translations` / `pll_save_term_translations`. `pll-lib.php` bridges `wp eval-file`'s
local `$args` into `$GLOBALS` — the scripts do not work without that require. PHP 7.4 floor:
no `match`, no union types.

`pll-lib.php` is also the one place in this repo where a test runs real shipped logic
instead of grepping a contract. Its top-level code is all `if (!defined(...))` guards that
call nothing from WordPress, and the ACF path walker and resolver inside it are pure array
manipulation, so `tests/checks/wp-polylang-nesting.sh` requires the file under bare PHP and
asserts on what the walker emits and where the resolver places a value. Keep those two
functions free of WordPress calls: `pllx_acf_write()` is the wrapper that reaches
`get_field()`/`update_field()`, and it stays in `pll-import.php`, which cannot be required
at all because it runs a whole import at top level.

## Craft token aliases

**The two token vocabularies are joined by aliases, not by a rename.** The
compositions' CSS speaks `--color-canvas` / `--color-ink` / `--font-display`; the
starter's speaks `--color-primary` / `--color-dark` / `--font-primary`; only
`--color-accent` is in both. `/wp-init` Step D4 writes the craft set into the
Tailwind `@theme` block from `demo/DESIGN.md` and then defines the starter's six
colour and two font tokens as `var()` aliases onto it, mapped **by role, not by
lightness** — on a dark craft palette `--color-light` correctly resolves to a
near-black canvas, because what the starter's CSS depends on is the contrast pair,
not the name. The table is appended to the theme's copied `DESIGN.md` under
`## Token aliases` so later agents read the mapping instead of guessing it.

### A store is a recorded decision

## Store

Behaviour that must survive a theme
switch lives in `plugins/store-kit/`, copied into the site by `bin/store-kit-sync.sh`: catalog
mode, and Stripe API keys supplied from `wp-config.php` — its webhook-secret constant only seeds
an empty field, so a secret Stripe rotates is saved to the database, and SEC-040 reports it.
