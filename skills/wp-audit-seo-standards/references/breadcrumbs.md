# Breadcrumbs

Part of the `wp-audit-seo-standards` skill; section numbers match its SKILL.md.

## 10. Breadcrumb Integration Code

### PHP Function

```php
function prefix_breadcrumbs() {
    // Not on the front page, and not on a 404: the trail says WHERE YOU ARE, and a
    // 404 is not a place. Rank Math builds an "Error 404" crumb for it, which only
    // restates the heading already on screen.
    if (is_front_page() || is_404()) return;
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

### Breadcrumb CSS

```css
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

### Enable Breadcrumbs in Rank Math

```bash
$WP eval "
\$opts = (array) get_option('rank-math-options-general', []);
\$opts['breadcrumbs'] = 'on';
update_option('rank-math-options-general', \$opts);
echo 'Breadcrumbs enabled.';
"
```
