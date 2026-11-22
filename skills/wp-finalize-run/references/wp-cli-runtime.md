# /wp-finalize — Check 7: WP-CLI Runtime Validation

`commands/wp-finalize.md` sends the run here at Check 7: WP-CLI Runtime Validation. Follow it in order; nothing in it is optional background.

## Contents

- 1-6. Pages, menus, ACF values, permalinks, PHP errors, plugins
- 7. Every post has an author
- 8. An installed SEO plugin is configured
- 9. No placeholder links
- 10. One `<h1>` per page
- 11. No horizontal overflow on a phone
- 12. Contact and social settings left empty (report only)

Read `wp_cli.wrapper` and run runtime checks:

1. **Pages exist with correct templates:**
   ```bash
   $WP post list --post_type=page --format=table
   ```
   Verify each page referenced in `front-page.php` `get_template_part()` calls has a corresponding WordPress page.

2. **Menus assigned to locations:**
   ```bash
   $WP menu location list --format=table
   ```
   Verify all registered locations have menus assigned — the list depends on the
   `i18n strategy`: `primary-<lang>`, `footer-<lang>` per language under
   `suffix`; bare `primary`, `footer` under `polylang`.

3. **ACF fields return values:**
   For each section's field file in `fields/`, extract the primary field name and verify:
   ```bash
   $WP eval "echo get_field('<section>_title', 'option') ? 'OK' : 'EMPTY';"
   ```

4. **Permalinks work:**
   ```bash
   $WP rewrite flush
   ```

5. **No PHP errors:**
   ```bash
   $WP eval "error_reporting(E_ALL); echo 'Clean';"
   ```
   Also check `wp-content/debug.log` for recent errors.

6. **All plugins active:**
   ```bash
   $WP plugin list --status=active --format=table
   ```
   Compare against `plugins.installed` in manifest.

7. **Every post has an author.** `wp post create` and `wp media import` leave
   `post_author` at 0, which renders fine and breaks the author schema, the
   admin column and `the_author()`. Menu items are exempt: `wp menu item add-*`
   creates them with no author too, and nothing ever displays one for them.
   ```bash
   $WP db query "SELECT COUNT(*) FROM $($WP db prefix)posts WHERE post_author = 0 AND post_status != 'auto-draft' AND post_type != 'nav_menu_item';"
   ```
   Must be 0.

8. **An installed SEO plugin is actually configured.** An active-but-unconfigured
   Rank Math emits **no** canonical on archives, no meta description, no JSON-LD
   and — with `rank_math_registration_skip` unset — no sitemap and no frontend
   at all. The site looks finished and ships with its whole SEO layer missing;
   one delivery went out that way and the gap was found by an external audit.
   ```bash
   $WP option get rank_math_options --format=json >/dev/null 2>&1 || echo "Rank Math NOT configured"
   $WP eval "echo get_option('rank_math_registration_skip') ? 'skip-ok' : 'REGISTRATION FLAG MISSING';"
   curl -s "$SITE/<a-cpt-archive-slug>/" | grep -o 'rel="canonical"' | wc -l   # must be 1
   curl -s "$SITE/" | grep -o 'application/ld+json' | wc -l               # must be >= 1
   ```
   Configure it with `/wp-audit` (the `wp-audit-rankmath` agent) rather than the
   plugin's wizard, so the settings live in a re-runnable seed file.

9. **No placeholder links in the delivered markup.** `href="#"` renders as a
   link, announces as a link, and goes nowhere:
   ```bash
   curl -s "$SITE/" | grep -o 'href="#"' | wc -l
   ```
   Any hit is either a real destination the client still owes — list it in the
   report as **content pending**, with the field that holds it — or markup that
   should not be a link at all.

10. **One `<h1>` per page.** A demo often draws the hero title as a styled
    `<div>`, and the conversion keeps it:
    ```bash
    curl -s "$SITE/" | grep -o '<h1' | wc -l   # must be exactly 1
    ```

11. **No horizontal overflow on a phone.** A carousel track sized in absolute
    units (`auto-cols-[22.9375rem]`) overflows a 360px viewport and scrolls the
    whole document sideways. Measure, at 360px, per page template:
    `document.documentElement.scrollWidth <= window.innerWidth`.

12. **Contact and social settings left empty (report only).** A demo with no
    Instagram link or phone number leaves those settings empty, and the header,
    footer or contact section then renders nothing in their place: the element is
    absent, not flagged, and the client never learns it was theirs to fill. List
    every empty one. A `_<lang>` variant is skipped when its base exists: it falls
    back to the base, so the base is the one that decides.
    ```bash
    $WP eval '
    $names = array_column(acf_get_fields("group_settings") ?: array(), "name");
    if (!$names) { echo "UNKNOWN group_settings has no fields\n"; return; }
    foreach ($names as $n) {
      if (!preg_match("/^(social_[a-z0-9_]+|contact_email|contact_phone|header_phone|business_address)$/", $n)) continue;
      if (preg_match("/^(.+)_[a-z]{2}$/", $n, $m) && in_array($m[1], $names, true)) continue;
      $v = get_field($n, "option");
      if ($v === null || $v === false || $v === "" || $v === array()) echo "PENDING $n\n";
    }'
    ```
    Each `PENDING` line goes in the report under **Content pending**, with the
    field name, beside the links item 9 found. An `UNKNOWN` line or a non-zero exit
    means nothing was checked: report the item as **not checked**, never as an
    empty list. This item never turns Check 7
    into a FAIL: the value is the client's to supply, not a defect in the build.

**PASS** if all runtime checks succeed. **FAIL** with details.
