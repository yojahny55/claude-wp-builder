---
description: Build the WordPress footer — pulling from settings page (logo, copyright, social, contact, legal)
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent
argument-hint: "[screenshot-path]"
---

# WP Footer — WordPress Footer Builder

Generate a WordPress footer that pulls all dynamic content from the theme settings/options page via ACF fields.

## Step 1: Read Project Context

Read `.claude/CLAUDE.md` to extract:
- **Function prefix** (e.g., `kairo_`)
- **Theme slug**
- **Languages** (primary + secondary)
- **Theme directory path**

If `.claude/CLAUDE.md` does not exist, tell the user to run `/wp-init` first.

## Step 2: Read Demo Footer

Read `demo/index.html` and extract the footer section (between `<!-- ============ SECTION: Footer ============ -->` delimiters, or the `<footer>` element).

Analyze:
- Number of columns and their content
- Logo presence and position
- Contact information (address, phone, email)
- Social media links
- Legal/policy links
- Copyright text
- Newsletter signup (if any)
- Footer navigation menu

## Step 3: Screenshot Reference (Optional)

If `$ARGUMENTS` provides a screenshot path, read the screenshot file for additional visual reference.

## Step 4: Dispatch wp-template Agent

Dispatch the **wp-template** agent with these instructions:

> Generate `footer.php` in the theme directory.
>
> The footer MUST pull ALL dynamic content from the settings/options page using the project's i18n helper functions. NEVER hardcode content.
>
> Required elements (include only those present in the demo):
>
> - **Footer logo**: `prefix_get_field('footer_logo', 'option')` with fallback to `prefix_get_field('site_logo', 'option')`
> - **Footer description/tagline**: `prefix_get_field('footer_description', 'option')`
> - **Contact info**:
>   - Phone: `prefix_get_field('contact_phone', 'option')`
>   - Email: `prefix_get_field('contact_email', 'option')`
>   - Address: `prefix_get_field('contact_address', 'option')`
> - **Social links** (repeater): `prefix_get_repeater('social_links', array('platform', 'url', 'icon'), 'option')`
> - **Legal links**: `prefix_get_field('legal_privacy_url', 'option')`, `prefix_get_field('legal_terms_url', 'option')`
> - **Copyright**: `prefix_get_field('footer_copyright', 'option')` with fallback to `© {year} {blogname}`
> - **Designer credit**: `prefix_get_field('footer_credit', 'option')` (optional)
> - **Footer navigation**: `wp_nav_menu()` with `'footer_' . prefix_current_lang()` location
>
> Close the file properly:
> ```php
>     <?php wp_footer(); ?>
> </body>
> </html>
> ```
>
> Follow BEM naming: `.footer__logo`, `.footer__contact`, `.footer__social`, etc.
> All output must be escaped. Match the demo layout structure.

## Step 5: Dispatch wp-acf Agent — Add Footer Fields to Settings Page

Dispatch the **wp-acf** agent with these instructions:

> Read `fields/settings.php` and ADD any project-specific footer fields to the **Footer tab** that are needed based on the demo design.
>
> The starter theme already includes basic footer fields (footer logo, brand text, copyright). Based on the demo, you may need to add:
> - Footer tagline or description text
> - Footer CTA section (text + button)
> - Newsletter signup heading/description
> - Footer column headings
> - Google Calendar embed code
> - Any other footer element the client should be able to edit
>
> For each new field:
> 1. Add the primary language field after the existing Footer tab fields (before the Contact tab)
> 2. Add the bilingual `_es` variant in the Spanish Translations tab
> 3. Follow the existing naming convention: `field_settings_footer_<element>`
>
> All fields use `'option'` as post ID. Instructions on Spanish fields: "Leave empty to use English version."

## Step 6: Dispatch wp-css Agent

Dispatch the **wp-css** agent with these instructions:

> Add footer CSS to `assets/css/styles.css`. Include:
>
> - Footer layout matching the demo (grid or flexbox columns)
> - Responsive: stack columns on mobile, side-by-side on desktop
> - Social links styling (inline list, icon sizing)
> - Contact info layout
> - Legal links (inline, separated)
> - Copyright bar (if separate from main footer)
> - Hover states for links
> - Use CSS custom properties from the design system
> - BEM naming convention
>
> Add the CSS within delimiter comments:
> ```css
> /* ============ FOOTER ============ */
> ...
> /* ============ END FOOTER ============ */
> ```

## Step 7: Print Summary

```
=== Footer Built ===
Files created/updated:
  - footer.php
  - assets/css/styles.css (footer CSS)
  - fields/settings.php (footer ACF fields in Footer tab)

Settings fields used:
  - footer_logo, footer_description
  - contact_phone, contact_email, contact_address
  - social_links (repeater)
  - legal_privacy_url, legal_terms_url
  - footer_copyright, footer_credit

Next: Run /wp-section <name> to build content sections.
```
