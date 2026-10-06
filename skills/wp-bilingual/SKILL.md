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

## Reference files

- [references/i18n-helpers.md](references/i18n-helpers.md) — the full source of
  `prefix_get_current_lang()` and every translation helper, the static translations array,
  JavaScript translations, the language switcher URL helper, and what `inc/i18n.php`
  contains. Read when writing or repairing `inc/i18n.php` itself; templates only need the
  calls shown below.
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

The full detection function is in `references/i18n-helpers.md` § Language Detection.

### Important Notes on Cookies

- `setcookie()` MUST be called **before any HTML output** (before headers are sent)
- The `i18n.php` file must be included early in `functions.php`, before any template rendering
- Cookie path is `/` so it works across all pages
- Cookie lifetime: 365 days

---

## Cookie Persistence

When the user clicks a language switcher link (e.g., `?lang=es`), the cookie is set in the `prefix_get_current_lang()` function. Subsequent page loads read the cookie, so the URL parameter is only needed once.

```php
// Cookie is set when URL param is detected
setcookie('prefix_lang', $current_lang, time() + (365 * 24 * 60 * 60), '/');
```

---

## Translation Helper Functions

Each helper's implementation is in `references/i18n-helpers.md`; below is how templates call them.

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
<a href="#" aria-label="<?php echo esc_attr(prefix__('nav_schedule')); ?>">
```

### prefix_is_lang() and prefix_get_current_lang()

Convenience helpers for language checks.

**Usage:**

```php
<?php if (prefix_is_spanish()) : ?>
    <html lang="es">
<?php else : ?>
    <html lang="en">
<?php endif; ?>
```

---

## Static Translations Array

Define all hardcoded UI strings in a central translations function. Each entry is an associative array keyed by language code.

The full array, and the `prefix_get_js_translations()` subset passed to JavaScript through
`wp_localize_script()`, are in `references/i18n-helpers.md` § Static Translations Array.

---

## Language Switcher URL Generation

Use `remove_query_arg()` and `add_query_arg()` to build language toggle URLs.

The `prefix_get_lang_url()` helper and a switcher template are in
`references/i18n-helpers.md` § Language Switcher URL Generation.

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
- `prefix__()` / `prefix_e()` instead of hardcoded strings

The only place `get_field()` is called directly is **inside** the helper functions themselves.

---

## Setting the HTML lang Attribute

In `header.php`, set the document language dynamically.

```php
<!DOCTYPE html>
<html <?php language_attributes(); ?> lang="<?php echo esc_attr(prefix_get_current_lang()); ?>">
<head>
    <meta charset="<?php bloginfo('charset'); ?>">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <?php wp_head(); ?>
</head>
<body <?php body_class(); ?>>
```

---

## File Structure

The i18n system lives in a single file included early in `functions.php`, before the field loader's `acf/init` hook runs.

The `require` order and the list of what `inc/i18n.php` contains are in
`references/i18n-helpers.md` § File Structure.

---

## Summary Checklist

- [ ] `PREFIX_SUPPORTED_LANGS` and `PREFIX_DEFAULT_LANG` constants defined
- [ ] Language detection follows priority: URL param > cookie > browser > default
- [ ] Cookie set with 365-day expiry on language switch
- [ ] `prefix_get_field()` used in ALL templates (never raw `get_field()`)
- [ ] `prefix_get_repeater()` used for repeater fields with translatable subfields specified
- [ ] `prefix_get_sub_field()` used inside `have_rows()` loops
- [ ] `prefix__()` / `prefix_e()` used for all static UI strings
- [ ] All secondary ACF fields have `_<lang>` suffix and "Leave empty to use English version" instruction
- [ ] Tab organization per language in ACF field groups
- [ ] Menu locations registered per language: `<location>-<lang>`
- [ ] Language switcher uses `remove_query_arg` / `add_query_arg`
- [ ] HTML `lang` attribute set dynamically
