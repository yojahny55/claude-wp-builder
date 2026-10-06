# Taxonomies of proper nouns, and rewrite bases

Two URL gaps free Polylang leaves, and the filters that close them. The summary is in
`../SKILL.md`.

## Contents

- Do not translate a taxonomy of proper nouns
- Prefixing links into an untranslated taxonomy
- Rewrite bases are never translated, even when the taxonomy or CPT is
- How the two compose

## Do not translate a taxonomy of proper nouns

Registering a taxonomy with `pll_get_taxonomies` looks free and is not. Where the terms are proper
nouns — provinces, countries, brands, venue names — most of them are spelled identically in both
languages, so translating the taxonomy duplicates every term in order to relabel the one or two
that differ. Three things then go wrong:

1. **Slugs.** WordPress forces term slugs to be unique per taxonomy, so the translated copies can
   only be `matanzas-en`, `holguin-en`. An archive facet writes that slug straight into a URL the
   visitor shares.
2. **Import collision.** Because the "translated" name matches its source, an importer adopts the
   *existing* term as its own counterpart and flips its language — one project lost the province
   facet from every Spanish archive this way, with 14 terms silently reassigned from `es` to `en`.
3. **Counts.** A shared taxonomy's `get_terms()` count spans every object type registered to it;
   per-post-type facet counts must be recomputed.

Leave such a taxonomy **out** of `pll_get_taxonomies` so both languages share one clean term
list, and write the reason into `inc/post-types.php` — the next person will otherwise "fix" the
omission.

## Prefixing links into an untranslated taxonomy

A taxonomy left out of `pll_get_taxonomies` gets none of Polylang's own URL handling — no
language prefix on its rewrite rules, no prefix on `term_link()`. That is correct for the archive
itself, but every other page that links into it still needs those links to carry the current
language, or a visitor following one switches language mid-click. Two filters close that without
duplicating a single term: add the taxonomy's rule group to the set Polylang prefixes
(`pll_rewrite_rules`), and prefix the links the theme prints (`term_link`, via
`PLL()->links_model->add_language_to_link()`). Neither touches the **base** segment of the URL —
that is the next section.

## Rewrite bases are never translated, even when the taxonomy or CPT is

Free Polylang prefixes a translated post's or term's URL with the language and translates its
slug, but it never translates the static **rewrite base** — the literal path segment from a CPT's
or taxonomy's `rewrite => ['slug' => …]`, registered once in PHP for every language. A CPT
registered with `'rewrite' => ['slug' => 'lawyers']` still answers at `/en/lawyers/`, never at an
actual English base, because the base is not stored on any post or term: it is a literal in
`register_post_type()`/`register_taxonomy()`. No setting fixes this; it has to be built, in two
halves that must stay in step:

1. **Rules, so the translated URL resolves.** Register one extra rewrite rule per base, on top of
   the generated set, mapping the translated segment to the same query vars the original rule
   produces. Leave the source-language rules in place — the old URL keeps answering, and a 301
   can retire it later without a dead link in the meantime.
2. **Links, so the theme prints the translated URL.** The rules alone leave two working addresses
   for one page; every filter that can produce one of these permalinks (`post_type_link`,
   `post_type_archive_link`, `term_link`, and Polylang's own `pll_translation_url`) has to swap
   the base too, or the site keeps linking to the untranslated one.

**The base is chosen by the URL already in hand, never by who is reading.** Asking "what language
is the current visitor in" gets the link a page prints about *itself* right and every link built
about its *counterpart* wrong — the hreflang pair and the language switcher are built while the
reader is still on the source language, and are links INTO the target language. Symmetrically,
Polylang builds a page's source-language counterpart URL by stripping the prefix off the URL
already in hand, so a swap that depended on "current language" would hand Polylang a base that
exists in no language at all. Decide from the URL's own prefix: a URL that carries the language
prefix takes the translated base; a URL that does not takes the source one.

## How the two compose

They are independent layers. A taxonomy deliberately left untranslated still needs its prefix
added by hand (the two filters above), and if its base should read differently in the second
language too, the base swap runs on top of that — one layer adds the prefix, the other swaps what
comes after it, and neither replaces the other.
