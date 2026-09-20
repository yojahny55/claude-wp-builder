---
description: Translate an existing WordPress site into a second language using Polylang
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
argument-hint: "<source_lang> <target_lang>"
---

# /wp-polylang

Translate an existing site into a second language through Polylang. Run from the
WordPress root.

**Required skill:** read `skills/wp-polylang/SKILL.md` before doing anything. It
documents the data model and the API contract, and the failure mode this command
exists to avoid.

## Step 1: Parse arguments

`$ARGUMENTS` is `<source_lang> <target_lang>`, e.g. `es en`. Both are required;
error and exit if either is missing:

```
Error: source and target language are required.
Usage: /wp-polylang <source_lang> <target_lang>
```

One target language per run. For a third language, run the command again.

Confirm the working directory is a WordPress root — `wp-config.php` must be
present. If it is not, stop and say so.

Set `SCRIPTS="${CLAUDE_PLUGIN_ROOT}/skills/wp-polylang/scripts"`.

## Step 2: Ensure Polylang is installed

```bash
# Three states, not two: active, installed-but-deactivated, absent. `install` on an
# already-installed plugin is not a reliable activator, so try activation first.
wp plugin is-active polylang \
  || wp plugin activate polylang \
  || wp plugin install polylang --activate
```

## Step 3: Configure languages

```bash
wp eval-file "$SCRIPTS/pll-setup.php" <source_lang> <target_lang>
```

Creates whichever of the two languages Polylang does not already have configured,
using a sane predefined locale (`en` → `en_US`, `es` → `es_ES`, not Polylang's own
first-match, which is `en_AU` / `es_AR`). Succeeds silently — and prints
"Configured languages: …" either way — when both languages already exist, so it is
always safe to run.

Stop if it exits non-zero — it prints exactly what is wrong (Polylang not active,
an unrecognised language code, or source and target being the same language).

## Step 3.5: Routing — the three settings a wrong value breaks silently

Polylang's URL settings decide which language a request resolves to, and every
wrong value here fails by **serving the other language** rather than by erroring.

**Prefix both languages: `hide_default` must be `0`.** With the default language
unprefixed, `/` and `/es/` are the only two things distinguishing them — and a path
that exists in the default language with no Spanish-only slug to disambiguate falls
through to the default. Measured: `/es/` and `/es/blog/` both served English while
every inner Spanish page was correct, because the inner pages have localised slugs
and the front page and posts page have none.

This is a real decision, not a default to apply quietly: **every English URL moves
to `/en/…`**. Say so before setting it, because it changes every link a client may
already have shared, and it is the kind of change that has to happen before launch
rather than after.

```bash
$WP eval "
\$o = get_option('polylang');
\$o['hide_default'] = 0;   // prefix every language, including the default
\$o['force_lang']   = 1;   // language from the URL path
update_option('polylang', \$o);
"
```

**Then clear Polylang's language cache, or the site redirects to itself.** Polylang
caches each language's `home_url` on the language *term*, so after changing
`hide_default`, `force_lang` or a language slug, the default language still believes
its home is `/` — and `/` answers with a 302 to `/`. A browser reports a redirect
loop; `curl -I` shows one hop and looks survivable.

**`wp rewrite flush` does not clear it.** The cache is on the terms, not in the
rewrite rules, which is why this looks like a rewrite problem and does not respond
to the rewrite fix:

```bash
$WP eval "PLL()->model->clean_languages_cache();"
$WP rewrite flush
```

Run both, in that order, after **any** change to a language's slug or to the options
above.

**Verify by request, never by option.** Every one of these reports correct values in
the database while serving the wrong thing:

```bash
HOME=$($WP option get home)
for p in "/" "/en/" "/es/" "/es/blog/"; do
  printf '%s -> %s\n' "$p" "$(curl -o /dev/null -sk -w '%{http_code} %{redirect_url}' "$HOME$p")"
done
```

## Step 4: Export what needs translating

```bash
MANIFEST="$(mktemp -t pll-manifest-XXXXXX.json)"
wp eval-file "$SCRIPTS/pll-export.php" <source_lang> <target_lang> "$MANIFEST"
```

Walks every translatable post type and taxonomy — posts, terms, registered
strings, and per-language menus — and writes only what is missing or stale into
`$MANIFEST`. Prints `Exported <n> item(s), skipped <n> already current.` Read the
reported item count **and the unassigned-language warning**, if any.

Zero items has two very different meanings and they must not be conflated:

- 0 items and 0 unassigned: the site is already current. Report that and skip to Step 7.
- 0 items with unassigned objects reported: nothing was exported because the content has
  no language assigned at all. That is not "already current", it is "nothing was
  translatable". Report the unassigned counts verbatim and say the site needs its source
  language assigned before this command can do anything. Do not report success.

## Step 5: Translate

Read `$MANIFEST`. Write `$MANIFEST.translated` with the **same structure**,
replacing only the values inside each item's `fields` and `acf`.

Rules:

- Leave `id`, `hash`, `kind`, `source_id`, `target_id`, `post_type`, `taxonomy`,
  `location` and `menu_id` exactly as they are. `pll-import.php` matches on them
  and rejects the file if they drift.
- Translate `post_title`, `post_content`, `post_excerpt`, term `name` and
  `description`, menu item labels (`item_<db_id>` keys), and string values.
- Translate slugs too — `post_name` and term `slug`. `/servicios/` becomes
  `/services/`. Use lowercase words joined by hyphens, no accents.
- Preserve HTML structure inside `post_content`. Translate the text between
  tags, never the tags, attributes, shortcode names or URLs.
- Leave a value unchanged when it is a proper noun or a brand name.
- Never invent content. If a source value is empty, the translation is empty.

Write the file as UTF-8 JSON.

## Step 6: Import

```bash
wp eval-file "$SCRIPTS/pll-import.php" "$MANIFEST.translated"
```

Takes a single argument — the translated manifest; source and target language
come from the manifest itself. Validates the whole file before writing anything.
If it reports validation errors, fix the translated manifest and run it again —
nothing was written.

Prints `Wrote <n> item(s): <n> post(s), <n> attachment(s), <n> term(s), <n>
string(s).` and `Fixed <n> parent-child relationship(s).`

**Once a string is imported, the theme's PHP table stops deciding what it says.**
`prefix_t()` asks `pll__()` first and only falls back to the table when Polylang
returns the argument unchanged (see the Polylang variant of `inc/i18n.php`), so a
string that made it into Polylang's store wins permanently. Correcting a typo in
the PHP — a missing accent in `crédito`, a wrong word — then changes **nothing on
the page**, and the edit looks like it did not save.

Fix it in both places, in this order: correct the table so a fresh install is
right, then re-import (or edit under **Languages → Strings**) so the live site is.
A build lost a round to this, correcting 27 Spanish strings in the file and
watching every page keep the old wording.

The same applies to anything else this command imports. The database is the live
answer; the theme's tables are the seed and the fallback.

## Step 7: Verify

```bash
wp eval-file "$SCRIPTS/pll-verify.php" <source_lang> <target_lang>
```

Prints `Audited posts=<n> terms=<n> menu_items=<n> unassigned=<n> for <source> ->
<target>`, then either every failure (exit 1) or `PASS — 0 failures, <n>
warning(s).` (exit 0).

If it exits non-zero, report every failure verbatim. Do not describe the run as
successful when the verifier rejected it.

Warnings are not failures. "Same title as its source" is expected for brand
names and short labels.

## Step 8: Report

```
Polylang translation: <source> -> <target>

  Exported:    <n> item(s)
  Written:     <n> item(s)
  Verifier:    PASS (<n> warning(s))

  Posts:       <n>
  Terms:       <n>
  Menu items:  <n>

<any verifier warnings, verbatim>
```

Delete the manifest files when the run succeeds; keep them when it fails, and
say where they are.

## Notes

- Re-running is safe and cheap: unchanged content is skipped by hash, so a
  second run costs no tokens for anything already current.
- A run interrupted part way is resumed by running the command again. Hashes are
  recorded only after successful writes.
- WooCommerce products and their attribute taxonomies translate with free
  Polylang. The paid addon is only needed for cart, checkout and account page
  mapping, which this command does not touch.
