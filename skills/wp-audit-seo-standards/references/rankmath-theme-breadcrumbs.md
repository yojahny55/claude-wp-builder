# Rank Math theme breadcrumbs (agent Step 12)

The code blocks of `wp-audit-rankmath` Step 12, 12a to 12d. `$WP` is the project WP-CLI wrapper.

### 12a. Add PHP Function

Read the theme's `functions.php`. Add the `prefix_breadcrumbs()` function from the `wp-audit-seo-standards` skill (Section 10, `references/breadcrumbs.md`). Replace `prefix_` with the actual function prefix from CLAUDE.md:

```php
function prefix_breadcrumbs() {
    if (is_front_page()) return;
    echo '<nav class="breadcrumbs" aria-label="Breadcrumb">';
    if (function_exists('rank_math_the_breadcrumbs')) {
        rank_math_the_breadcrumbs();
    } else {
        echo '<a href="' . esc_url(home_url('/')) . '">Home</a>';
        echo ' &raquo; ';
        if (is_singular()) { the_title(); }
        elseif (is_archive()) { the_archive_title(); }
        elseif (is_search()) { echo 'Search results'; }
        elseif (is_404()) { echo 'Page Not Found'; }
    }
    echo '</nav>';
}
```

### 12b. Add Breadcrumb Call to Templates

Edit the main template file (usually `header.php` or a layout partial). Insert the breadcrumb call after `</nav>` (main navigation) and before `<main`:

```php
<?php prefix_breadcrumbs(); ?>
```

### 12c. Add Breadcrumb CSS

Append breadcrumb styles to `assets/css/styles.css` using the CSS from the skill:

```css
/* Breadcrumbs */
.breadcrumbs {
    padding: 12px 0;
    font-size: 0.875rem;
    color: #6b7280;
}
.breadcrumbs a {
    color: #3b82f6;
    text-decoration: none;
    /* 24x24 target (WCAG 2.2 AA 2.5.8), a home icon included, without moving the text:
       the padding and the equal negative margin cancel out in the layout. */
    display: inline-block;
    padding: 4px;
    margin: -4px;
}
.breadcrumbs a:hover {
    text-decoration: underline;
}
.breadcrumbs .separator {
    margin: 0 0.5rem;
    color: #9ca3af;
}
```

### 12d. Enable Breadcrumbs in Rank Math

```bash
$WP eval "
\$opts = (array) get_option('rank-math-options-general', []);
\$opts['breadcrumbs'] = 'on';
update_option('rank-math-options-general', \$opts);
echo 'Breadcrumbs enabled.';
"
```
