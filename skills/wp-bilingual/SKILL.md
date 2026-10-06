---
name: wp-bilingual
description: The suffix i18n model — one page carries every language, with ACF/SCF fields duplicated as _lang suffixes (hero_title_es) and resolved by prefix_get_field(), prefix_t() and prefix_e(), plus language detection, the language cookie, the switcher and menus. Use when the project's .claude/CLAUDE.md records the suffix i18n strategy, or records no strategy at all. Not for Polylang projects; those use wp-polylang.
user-invocable: false
---

# Bilingual / Multilingual i18n System

This skill defines ONE of the plugin's two translation methodologies: the **ACF/SCF _suffix pattern**. One set of pages, one set of fields, with suffixed duplicates for secondary languages.

> **Which one applies to a project is a decision, not a default.** `/wp-init`
> asks, and records the answer as **i18n strategy** in the project's
> `.claude/CLAUDE.md`. Read that line before assuming this skill applies.
>
> | Answer | Model | Skill |
> |---|---|---|
> | `suffix` | one page, fields duplicated as `_es` | this one |
> | `polylang` | one page **per language**, joined by translation groups | `wp-polylang` |
>
> The two never mix in one project. If the project says `polylang`, stop
> reading here and use the `wp-polylang` skill instead — the field naming,
> the menu registration and the helper behaviour all differ. An earlier
> version of this line claimed the plugin supported no Polylang at all, which
> stopped being true when `/wp-polylang` shipped.

## Which helpers exist depends on the starter

The two starters ship different suffix contracts. Read `Template:` in the project's
`.claude/CLAUDE.md` and call only the helpers that template defines — a call to one it does
not define is a fatal error on the page.

| `Template:` | Helpers in `inc/i18n.php` | Source |
|---|---|---|
| `tailwind` (and legacy `basic`) | `prefix_get_current_lang()`, `prefix_get_field()`, `prefix_get_repeater()`, `prefix_get_sub_field()`, `prefix_t()`, `prefix_e()`, `prefix_is_lang()`, `prefix_get_translations()`, `prefix_get_lang_url()` | `${CLAUDE_PLUGIN_ROOT}/starter-theme/__tailwind__/inc/i18n.php` |
| `cinematic` | `prefix_current_lang()`, `prefix_b( $en, $es )`, `prefix_setting( $name )` — plus `prefix_get_sub( $name )` in `inc/scenes-renderer.php` for scene sub-fields | `${CLAUDE_PLUGIN_ROOT}/starter-theme/__cinematic__/inc/i18n.php` |

Everything from "Translation Helper Functions" down describes the `tailwind` contract. On
`cinematic`, a literal is `prefix_b( 'English', 'Español' )` (it allows `br`, `em`, `strong`,
`i`, `b` and `span` through `wp_kses`), an options-page value is `prefix_setting( 'site_logo' )`
(tries `site_logo_es` on a Spanish request), and there is no `prefix_get_field()`. The
cinematic layer knows `en` and `es` only, and reads the `?lang=` parameter and the cookie but
never sets the cookie.

## Reference files

- [references/i18n-helpers.md](references/i18n-helpers.md) — where the implementation lives
  (the starter's `inc/i18n.php`, never a copy), why detection runs in its order, the cookie and
  its `init` hook, the fallback rules, adding a string or passing strings to JavaScript, and a
  switcher template. Read when changing `inc/i18n.php` or building the switcher; templates only
  need the calls shown below.
- [references/acf-fields.md](references/acf-fields.md) — complete field definitions for a
  suffix site: language tabs and suffixed repeater subfields. Read when writing
  `fields/*.php` for a project on this model.

---

## Core Concept: The _suffix Pattern

For every translatable ACF/SCF field, the **primary language** (typically English) uses the base field name. Each **secondary language** gets a duplicate field with a language suffix appended.

| Primary Field (EN) | Spanish Field | French Field |
|---|---|---|
| `hero_title` | `hero_title_es` | `hero_title_fr` |
| `hero_subtitle` | `hero_subtitle_es` | `hero_subtitle_fr` |
| `cta_button_text` | `cta_button_text_es` | `cta_button_text_fr` |
| `service_description` | `service_description_es` | `service_description_fr` |

### Rules

- Primary language fields have **no suffix** and are always required
- Secondary language fields have `_<lang>` suffix and are **optional** (fall back to primary if empty)
- This applies to text, textarea, WYSIWYG, and any content field
- Non-translatable fields (images, URLs, numbers, booleans) do NOT get duplicated
- ACF field instructions for secondary fields name the PRIMARY language, and are written in it:
  *"Leave empty to use the English version"* on an English-primary project, *"Dejar vacío para
  usar la versión en español."* on a Spanish-primary one. Read which language is primary from
  `.claude/CLAUDE.md`; the tables above use an English-primary project as their example, not as
  the rule. Every other string the editor reads — group titles, tab and field labels,
  `button_label`, `message` — follows the same rule. Field `name`s and `key`s do not: they are
  meta keys, and translating one orphans the rows already stored under the old name. See
  "Editor Language" in `agents/wp-acf.md`.

---

## Configuration Constants

Define supported languages and the default at the top of `inc/i18n.php`.

```php
// Define supported languages
define('PREFIX_SUPPORTED_LANGS', array('en', 'es'));
define('PREFIX_DEFAULT_LANG', 'en');
```

---

## Language Detection

Language is detected using a strict priority chain. The first match wins.

**Priority: URL parameter > Cookie > Browser Accept-Language > Default**

### The language cookie

A switcher link carries `?lang=es`. The **first** call to `prefix_get_current_lang()` on that
request sees the parameter and sets the `prefix_lang` cookie (path `/`, 365 days), so later
requests need no parameter. Its result is cached for the rest of the request, so no later call
sets the cookie.

That first call must happen **before any output**, or `setcookie()` fails — the header can no
longer be sent once `<!DOCTYPE html>` has gone out, and the choice silently lasts one page.
Including `i18n.php` early does not achieve this; calling the function does. The starter hooks
`prefix_get_current_lang()` on `init` for exactly this reason. Keep that hook, and never let a
template be the first caller.

---

## Translation Helper Functions

Each helper's implementation is the starter's `inc/i18n.php` (the table above); below is how
templates call them.

### prefix_get_field() -- Auto-Translating Field Getter

This is the **primary function** for retrieving any ACF/SCF field. It checks the current language, tries the suffixed field first, and falls back to the primary field.

**Usage in templates:**

```php
<h1><?php echo esc_html(prefix_get_field('hero_title')); ?></h1>
<p><?php echo wp_kses_post(prefix_get_field('hero_description')); ?></p>

<!-- With post ID -->
<?php $logo = prefix_get_field('site_logo', 'option'); ?>

<!-- With specific post -->
<?php $title = prefix_get_field('custom_title', $post->ID); ?>
```

### prefix_get_repeater() -- Repeater Field Translation

Translates specific subfields within a repeater while leaving non-translatable subfields (images, URLs) untouched.

**Usage:**

```php
// Services repeater: translate 'title' and 'description', keep 'icon' and 'link' as-is
$services = prefix_get_repeater('services', array('title', 'description'));

foreach ($services as $service) : ?>
    <div class="service-card">
        <img src="<?php echo esc_url($service['icon']['url']); ?>" alt="">
        <h3><?php echo esc_html($service['title']); ?></h3>
        <p><?php echo esc_html($service['description']); ?></p>
    </div>
<?php endforeach;
```

### prefix_get_sub_field() -- Sub-field Translation Inside Loops

Used inside `have_rows()` loops (repeaters, flexible content) to get translated subfield values.

**Usage inside have_rows():**

```php
<?php if (have_rows('team_members')) : ?>
    <?php while (have_rows('team_members')) : the_row(); ?>
        <div class="team-member">
            <h3><?php echo esc_html(prefix_get_sub_field('name')); ?></h3>
            <p><?php echo esc_html(prefix_get_sub_field('bio')); ?></p>
        </div>
    <?php endwhile; ?>
<?php endif; ?>
```

### prefix_t() and prefix_e() -- Static UI String Translation

For hardcoded UI strings (navigation labels, button text, form labels) that do not come from ACF fields.

**Usage:**

```php
<!-- In templates -->
<a href="#services"><?php prefix_e('nav_services'); ?></a>
<button><?php prefix_e('btn_learn_more'); ?></button>

<!-- When you need the raw string (e.g., for attributes) -->
<a href="#" aria-label="<?php echo esc_attr(prefix_t('nav_schedule')); ?>">
```

`prefix_t()` returns the key itself when no language has an entry for it, never `''` — so
`prefix_t( $key ) ?: $default` never reaches `$default`. Compare against the key instead.

### prefix_is_lang() and prefix_get_current_lang()

Convenience helpers for language checks. There is no per-language alias; pass the code.

**Usage:**

```php
<?php if (prefix_is_lang('es')) : ?>
    <p class="notice"><?php prefix_e('notice_spanish_only'); ?></p>
<?php endif; ?>
```

---

## Static Translations Array

Every hardcoded UI string is a key in `prefix_get_translations()`, mapping each language code
to its text. Adding one, and passing strings to JavaScript (there is no separate JavaScript
helper), are in `references/i18n-helpers.md`.

---

## Language Switcher URL Generation

`prefix_get_lang_url( $lang )` returns the current URL with `?lang=` replaced, built with
`remove_query_arg()` and `add_query_arg()`. A switcher template is in
`references/i18n-helpers.md`.

---

## Menu Locations: Per-Language Pattern

Register separate menu locations for each language. This allows admins to create fully localized menus in wp-admin.

### Registration

```php
function prefix_setup() {
    register_nav_menus(array(
        'primary-en' => __('Primary Navigation (EN)', 'theme-slug'),
        'primary-es' => __('Primary Navigation (ES)', 'theme-slug'),
        'mobile-en'  => __('Mobile Navigation (EN)', 'theme-slug'),
        'mobile-es'  => __('Mobile Navigation (ES)', 'theme-slug'),
        'footer-en'  => __('Footer Navigation (EN)', 'theme-slug'),
        'footer-es'  => __('Footer Navigation (ES)', 'theme-slug'),
    ));
}
add_action('after_setup_theme', 'prefix_setup');
```

### Usage in Templates

Select the menu location dynamically based on the current language.

```php
<?php
$lang = prefix_get_current_lang();

wp_nav_menu(array(
    'theme_location' => 'primary-' . $lang,
    'container'      => false,
    'fallback_cb'    => 'prefix_nav_fallback',
    'items_wrap'     => '%3$s',
    'walker'         => new Prefix_Nav_Walker(),
));
?>
```

The pattern is: `<location>-<lang>` (e.g., `primary-en`, `primary-es`, `mobile-en`, `mobile-es`).

---

## ACF Field Creation Rules

When defining fields in `fields/*.php` for a bilingual site (see wp-theme-standards for the field loader / Local JSON model — `fields/*.php` is a one-time bootstrap seed, `acf-json/*.json` is the dashboard-editable source of truth):

Use **Tab fields** to organize languages in the admin UI.
Inside repeaters, add suffixed subfields for each translatable text subfield.

Both, as full field definitions: `references/acf-fields.md`.

---

## Critical Rule: Templates ALWAYS Use prefix_get_field()

Templates must **NEVER** call `get_field()` directly. Always use the translation-aware wrapper.

```php
// WRONG — bypasses translation system
$title = get_field('hero_title');

// CORRECT — auto-translates based on current language
$title = prefix_get_field('hero_title');
```

This rule applies everywhere:
- `prefix_get_field()` instead of `get_field()`
- `prefix_get_sub_field()` instead of `get_sub_field()`
- `prefix_get_repeater()` instead of raw `get_field()` on repeaters
- `prefix_t()` / `prefix_e()` instead of hardcoded strings

The only place `get_field()` is called directly is **inside** the helper functions themselves.

---

## Setting the HTML lang Attribute

`header.php` prints `<html <?php language_attributes(); ?>>` and nothing else on that tag.
`language_attributes()` reads the site locale, which on a suffix site is the primary language
on every request, `?lang=es` included. Both starters' `inc/i18n.php` therefore filter it, so
the attribute follows the request (WCAG 3.1.1). The `tailwind` form (`cinematic` calls
`prefix_current_lang()`):

```php
add_filter('language_attributes', function ($output) {
    return preg_replace('/lang="[^"]*"/', 'lang="' . esc_attr(prefix_get_current_lang()) . '"', $output);
});
```

Never add a second `lang="…"` after `language_attributes()` on the `<html>` tag. A browser keeps
the first of two duplicate attributes, which is the site locale, so the second one changes
nothing.

---

## File Structure

The i18n system is one file, `inc/i18n.php`, required from `functions.php` before the field
loader's `acf/init` hook runs (field definitions may call its helpers). What it defines is the
table at the top of this skill.

---

## Summary Checklist

- [ ] `PREFIX_SUPPORTED_LANGS` and `PREFIX_DEFAULT_LANG` constants defined
- [ ] Language detection follows priority: URL param > cookie > browser > default
- [ ] Cookie set with 365-day expiry on language switch, by a first call made on `init`
- [ ] `prefix_get_field()` used in ALL templates (never raw `get_field()`)
- [ ] `prefix_get_repeater()` used for repeater fields with translatable subfields specified
- [ ] `prefix_get_sub_field()` used inside `have_rows()` loops
- [ ] `prefix_t()` / `prefix_e()` used for all static UI strings
- [ ] All secondary ACF fields have the `_<lang>` suffix and an instruction written in the primary language (see Rules)
- [ ] Tab organization per language in ACF field groups
- [ ] Menu locations registered per language: `<location>-<lang>`
- [ ] Language switcher uses `remove_query_arg` / `add_query_arg`
- [ ] HTML `lang` attribute follows the request through the `language_attributes` filter
