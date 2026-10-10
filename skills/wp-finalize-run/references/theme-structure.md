# /wp-finalize — Check 4: Theme Structure

`commands/wp-finalize.md` sends the run here at Check 4: Theme Structure. Follow it in order; nothing in it is optional background.

Verify required WordPress theme files and configurations:

1. **style.css** exists at theme root with proper headers (Theme Name, Version, Description, Author, Text Domain)
2. **index.php** exists (required WordPress fallback)
3. **screenshot.png** exists (theme preview image)
4. **SCF/ACF dependency:** Check `functions.php` or `inc/theme-setup.php` for SCF/ACF dependency notice or check
5. **register_nav_menus** is called in `inc/theme-setup.php` (`functions.php` on
   `cinematic`) — with per-language locations, hyphenated (`primary-<lang>`,
   `footer-<lang>`), under `suffix`, and with one
   bare location per name (`primary`, `footer`) under `polylang`. Those are the
   names `<prefix>nav_location()` in `inc/i18n.php` returns; grep the templates for
   a `theme_location` built by hand instead (`'primary-' .`, `'primary_' .`) — it
   renders nothing on the other strategy
6. **Brand surface — favicon / site icon.** Either a Site Icon is set
   (`$WP option get site_icon` is non-zero) or the theme itself emits a fallback:
   grep `functions.php`/`inc/theme-setup.php` for a `wp_head` callback that prints
   `rel="icon"`, guarded by `has_site_icon()` so it yields once the client sets one
   in Ajustes → General. A demo that ships its own `<link rel="icon">` on every
   page (check `demo/` or `demo-*/`) and a theme with neither is the specific
   thing this catches — a Tailwind/markup conversion can drop a `<link>` tag the
   HTML→PHP pass never re-emits, and the client is left with no icon at all
   (`/favicon.ico` then 302s instead of serving anything).
7. **Brand surface — login screen.** `wp-login.php` is the one page of the site
   that does not enqueue the theme's own stylesheet, so it stays WordPress's
   default grey screen with the wordpress.org logo unless something re-skins it —
   and it is the first screen the client sees every time they sign in. Check for
   a login-branding seed or plugin config: `inc/seed/*login*.php`, or
   `login_enqueue_scripts` / `login_headerurl` / `login_headertext` filters in
   `functions.php`/`inc/`. Absence is a finding, not a blocker — flag it as
   WARNING rather than FAIL, since some projects genuinely ship with the
   WordPress default by choice.

8. **Template contracts no build step enforces.** Run:
   ```bash
   node "${CLAUDE_PLUGIN_ROOT}/bin/theme-template-check.mjs" <theme-dir>
   ```
   It fails on:
   - any theme PHP file without the quoted `defined( 'ABSPATH' )` guard, `inc/seed/*.php`
     and `fields/*.php` included. The agents require it, and sixteen seed files shipped
     without it anyway;
   - on a compiled Tailwind theme, an HTML entity inside a class token, or a utility-shaped
     class with no selector in `assets/css/dist/*.css`. Such a class compiled to nothing,
     silently: a typo, an unsupported variant, `&quot;` inside an arbitrary variant, or a
     build that was never re-run;
   - `role="tab"`, `data-accordion-trigger` or `data-directory` markup without
     `./tabs.js`, `./accordion.js` or `./directory-filter.js` imported by
     `assets/js/src/index.js`.

   `CANNOT VERIFY` lines name classes built at runtime. They do not fail the check. Read
   each one and confirm its possible values appear in the templates or a `@source inline()`.
   Re-run `npm run build` before treating a missing-selector finding as a typo.

**PASS** if all present. **FAIL** listing missing items (item 7 reports WARNING, not FAIL, when absent;
item 8 reports WARNING, not FAIL, as the practices audit does for WP-016, WP-053 and WP-054, except an
unquoted `defined( ABSPATH )`, which is a PHP 8 fatal and FAILs).
