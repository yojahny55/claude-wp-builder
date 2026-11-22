# wp-template — Custom Nav Walker

The `wp-template` agent reads this when building the header or any navigation markup (a custom `Walker_Nav_Menu`).

## Custom Nav Walker

Nav markup/styles MUST follow the nav-class contract in the wp-theme-standards skill.

When generating custom navigation markup, extend `Walker_Nav_Menu`:

**A walker that overrides `start_el()` must re-apply the core filters `start_el()` would
otherwise have run.** `Walker_Nav_Menu::start_el()` is what calls `nav_menu_css_class`,
`nav_menu_item_id` and `nav_menu_link_attributes` — overriding the method replaces core's
implementation entirely, so a walker that reads `$item->classes` raw and never calls
`apply_filters()` itself silently drops every class, ID or link attribute any plugin, or
the theme's own "current menu item" logic, adds through those filters. This is not
theoretical: a build shipped exactly this, and the detail page for a record lost the
"you are here" highlight on its parent nav item the moment its `current-menu-item` class —
added via `nav_menu_css_class` — stopped surviving the walker.

```php
class Prefix_Nav_Walker extends Walker_Nav_Menu {
    public function start_el(&$output, $item, $depth = 0, $args = null, $id = 0) {
        // Re-apply the filters core's own start_el() would have run.
        $classes = (array) apply_filters('nav_menu_css_class', array_filter((array) $item->classes), $item, $args, $depth);
        $item_id = apply_filters('nav_menu_item_id', 'menu-item-' . $item->ID, $item, $args, $depth);
        // Dropdown parents carry the contract's has-children modifier.
        $has_children = in_array('menu-item-has-children', $classes, true);
        $li_class = 'nav__item' . ($has_children ? ' nav__item--has-children' : '');
        $output .= '<li' . ($item_id ? ' id="' . esc_attr($item_id) . '"' : '') . ' class="' . esc_attr(trim($li_class . ' ' . implode(' ', $classes))) . '">';
        $atts = apply_filters('nav_menu_link_attributes', array('class' => 'nav__link', 'href' => $item->url), $item, $args, $depth);
        $output .= '<a';
        foreach ($atts as $attr => $value) {
            $output .= ' ' . esc_attr($attr) . '="' . ($attr === 'href' ? esc_url($value) : esc_attr($value)) . '"';
        }
        $output .= '>';
        $output .= esc_html($item->title);
        $output .= '</a>';
        // Dropdown items emit a toggle control per the nav-class contract.
        if ($has_children) {
            $output .= '<button class="nav__toggle" aria-expanded="false" aria-label="' . esc_attr__('Toggle submenu', 'textdomain') . '"></button>';
        }
    }

    // Child <ul> MUST use .nav__submenu to match the contract (default is 'sub-menu').
    public function start_lvl(&$output, $depth = 0, $args = null) {
        $output .= '<ul class="nav__submenu">';
    }

    public function end_lvl(&$output, $depth = 0, $args = null) {
        $output .= '</ul>';
    }

    public function end_el(&$output, $item, $depth = 0, $args = null) {
        $output .= '</li>';
    }
}
```

Usage in templates:

```php
// The registered name depends on the i18n strategy: primary-en, primary-es, …
// under suffix, one bare 'primary' under polylang. prefix_nav_location() in
// inc/i18n.php returns the right one; a name built here renders nothing on
// the other strategy.
wp_nav_menu(array(
    'theme_location' => prefix_nav_location('primary'),
    'container'      => 'nav',
    'container_class'=> 'nav',
    'menu_class'     => 'nav__menu',
    'walker'         => new Prefix_Nav_Walker(),
));
```

The walker output MUST match the nav-class contract exactly: `.nav__menu` on the top-level
`<ul>`, `.nav__item` (+ `.nav__item--has-children` on dropdown parents) on each `<li>`,
`.nav__link` on anchors, `.nav__submenu` on the child `<ul>`, and `.nav__toggle` on the
dropdown control. A `menu_class` or submenu class that diverges from this leaves the header
CSS targeting selectors the walker never emits (dead selectors — the Layer-1 nav-contract
gate fails).
