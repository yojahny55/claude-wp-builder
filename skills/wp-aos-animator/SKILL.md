---
name: wp-aos-animator
description: WordPress AOS animation installer — audits, installs, enqueues, initializes, and seeds Animate On Scroll on every visual element across all PHP templates. Use when the user asks to add scroll animations, AOS, fade-in effects, entrance animations, or "make elements appear on scroll" in any WordPress theme.
---

# WP AOS Animator

Automates AOS (Animate On Scroll) implementation in WordPress themes. Covers the full pipeline: audit → install → enqueue → init → animate.

## Phases

Run these in order. Each phase depends on the previous one succeeding.

### Phase 1: Audit

Check if AOS is already present:

```
ls <theme>/vendors/aos/aos.js
ls <theme>/vendors/aos/aos.css
```

Check if enqueued in `functions.php`:
```
grep -n "aos" <theme>/functions.php
```

Check if AOS.init() exists in main JS:
```
grep -n "AOS.init" <theme>/assets/js/*.js
```

Report findings: what's present, what's missing.

### Phase 2: Install (if missing)

If `vendors/aos/` doesn't exist, download AOS:

```bash
cd <theme>/vendors/
mkdir -p aos
curl -sL "https://raw.githubusercontent.com/michalsnik/aos/v2.3.4/dist/aos.js" -o aos/aos.js
curl -sL "https://raw.githubusercontent.com/michalsnik/aos/v2.3.4/dist/aos.css" -o aos/aos.css
```

### Phase 3: Enqueue (if missing)

In `functions.php`, inside the `wp_enqueue_scripts` action, add:

```php
// AOS
wp_enqueue_style('aos-css', get_template_directory_uri() . '/vendors/aos/aos.css', array(), _RATIO_WEB_);
wp_enqueue_script('aos-js', get_template_directory_uri() . '/vendors/aos/aos.js', array('jquery'), _RATIO_WEB_, array('in_footer' => true, 'strategy' => 'defer'));
```

If AOS JS is already enqueued but CSS is missing, add just the CSS line right before the JS line. Put them together with a `// AOS` comment.

### Phase 4: Initialize (if missing)

In the theme's main JS file, add inside `$(document).ready(...)`:

```js
AOS.init({
  once: true,
});
```

If there's no `$(document).ready`, wrap it:
```js
$(document).ready(function () {
  AOS.init({
    once: true,
  });
});
```

### Phase 5: Animate templates

Scan every `.php` template in the theme root and `template-parts/` directory. For each file:

**Skip these elements:**
- `<html>`, `<head>`, `<body>`, `<meta>`, `<link>`, `<script>`, `<style>`, `<title>`
- Elements that already have `data-aos`
- Elements inside `<nav>` or `<header>` (they have their own animations)
- `role="presentation"` decorative elements
- Skip links (`<a class="skip-link">`)
- Screen reader text

**Animate these elements (when they lack data-aos):**
- `<h1>`, `<h2>`, `<h3>` — use `data-aos="fade-up-slow" data-aos-duration="1000"`
- `<p>`, section descriptions — use `data-aos="fade-up-slow" data-aos-delay="50" data-aos-duration="1000"`
- Buttons/CTAs — use `data-aos="fade-up-slow" data-aos-delay="20" data-aos-duration="1000"`
- `<img>`, image wrappers — use `data-aos="fade-up" data-aos-delay="150"`
- Cards, grid items — use `data-aos="fade-up" data-aos-delay="<?php echo ($index + 1) * 100; ?>"` when inside PHP loops
- Layout items, mosaics — use `data-aos="fade-up"` with staggered delays (100, 150, 200, 250...)
- Banner containers, CTA sections — use `data-aos="fade-up" data-aos-delay="200"`
- Footer columns, social icons — use `data-aos="fade-up" data-aos-delay="100"` with +100 increments per sibling

**Animation convention:**
| Element type | Animation | Typical delay |
|---|---|---|
| Hero titles, section headings | `fade-up-slow` + duration 1000 | 0 |
| Subtitles, descriptions | `fade-up-slow` + duration 1000 | 50 |
| Buttons, CTAs | `fade-up-slow` + duration 1000 | 20 |
| Images, illustrations | `fade-up` | 150 |
| Cards (looped with $index) | `fade-up` | `($index+1)*100` or `$index*150` |
| Layout grid items | `fade-up` | 100, 150, 200, 250... |
| Banner content | `fade-up` | 200 |
| Footer elements | `fade-up` | 100, 200, 300 |

### Edits approach

Work through templates one at a time. Use `Read` to see the file, then `Edit` with exact string matching. Make each edit atomic — one element at a time. Use unique surrounding context so the Edit tool finds the right match.

For `wp_get_attachment_image` calls that need animation, add data attributes to the 4th parameter array:
```php
// Before
echo wp_get_attachment_image($id, '', '', ['class' => '...']);
// After
echo wp_get_attachment_image($id, '', '', ['class' => '...', 'data-aos' => 'fade-up', 'data-aos-delay' => '100']);
```

### Parallelization

Phase 5 can be parallelized: spawn one agent per template file. Each agent gets a specific file path and the list of elements to animate from the audit. The main agent orchestrates and verifies.

## Verification

After all edits, run a quick sanity check:
```bash
grep -c "data-aos" <theme>/*.php <theme>/template-parts/*.php
```
Count should have increased from baseline (recorded in Phase 1).