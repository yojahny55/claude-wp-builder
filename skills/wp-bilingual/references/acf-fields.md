# ACF field definitions for a suffix site

The rules these follow — which fields get a `_<lang>` duplicate, and which language the
editor-facing strings are written in — are in `../SKILL.md`.

## Contents

- Field Organization
- Repeater Subfields

When defining fields in `fields/*.php` for a bilingual site (see wp-theme-standards for the field loader / Local JSON model — `fields/*.php` is a one-time bootstrap seed, `acf-json/*.json` is the dashboard-editable source of truth):

## Field Organization

Use **Tab fields** to organize languages in the admin UI.

```php
// English Tab
array(
    'key'       => 'field_hero_tab_en',
    'label'     => 'English',
    'type'      => 'tab',
    'placement' => 'top',
),
array(
    'key'          => 'field_hero_title',
    'label'        => 'Hero Title',
    'name'         => 'hero_title',
    'type'         => 'text',
    'required'     => 1,
),
array(
    'key'          => 'field_hero_description',
    'label'        => 'Hero Description',
    'name'         => 'hero_description',
    'type'         => 'textarea',
    'required'     => 1,
),

// Spanish Tab
array(
    'key'       => 'field_hero_tab_es',
    'label'     => 'Espanol',
    'type'      => 'tab',
    'placement' => 'top',
),
array(
    'key'          => 'field_hero_title_es',
    'label'        => 'Hero Title (ES)',
    'name'         => 'hero_title_es',
    'type'         => 'text',
    'instructions' => 'Leave empty to use English version.',
    'required'     => 0,
),
array(
    'key'          => 'field_hero_description_es',
    'label'        => 'Hero Description (ES)',
    'name'         => 'hero_description_es',
    'type'         => 'textarea',
    'instructions' => 'Leave empty to use English version.',
    'required'     => 0,
),
```

## Repeater Subfields

Inside repeaters, add suffixed subfields for each translatable text subfield.

```php
array(
    'key'        => 'field_services',
    'label'      => 'Services',
    'name'       => 'services',
    'type'       => 'repeater',
    'sub_fields' => array(
        array(
            'key'   => 'field_service_icon',
            'label' => 'Icon',
            'name'  => 'icon',
            'type'  => 'image',
        ),
        array(
            'key'   => 'field_service_title',
            'label' => 'Title (EN)',
            'name'  => 'title',
            'type'  => 'text',
        ),
        array(
            'key'          => 'field_service_title_es',
            'label'        => 'Title (ES)',
            'name'         => 'title_es',
            'type'         => 'text',
            'instructions' => 'Leave empty to use English version.',
        ),
        array(
            'key'   => 'field_service_description',
            'label' => 'Description (EN)',
            'name'  => 'description',
            'type'  => 'textarea',
        ),
        array(
            'key'          => 'field_service_description_es',
            'label'        => 'Description (ES)',
            'name'         => 'description_es',
            'type'         => 'textarea',
            'instructions' => 'Leave empty to use English version.',
        ),
        array(
            'key'   => 'field_service_link',
            'label' => 'Link',
            'name'  => 'link',
            'type'  => 'url',
            // No _es version — URLs are typically language-neutral
        ),
    ),
),
```
