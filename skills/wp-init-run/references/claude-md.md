# /wp-init — Step 7

`commands/wp-init.md` sends the run here at Step 7. Follow it in order; nothing in it is optional background.

Create `.claude/CLAUDE.md` at the **project root** (the directory containing `wp-content/`). Content:

```markdown
# <Project Name>

## Project Details
- **Theme slug:** <slug>
- **Function prefix:** <slug_with_underscores>_ (e.g., kairo_consulting_)
- **Template:** <tailwind|cinematic>
- **Custom Fields:** <SCF|ACF Pro>
- **i18n strategy:** <suffix|polylang>
- **Primary language:** <primary_lang>
- **Secondary language(s):** <secondary_langs>
- **Industry:** <industry>
- **Description:** <description>

## Theme Directory
<full-path-to-theme>

## Conventions
- All PHP functions prefixed with `<prefix>`
- ACF field names: `<section>_<element>` (e.g., `hero_title`)
- ACF repeater names: `<section>_<plural>` (e.g., `services_cards`)
- ACF repeater subfields: `<element>` only, no section prefix
- ACF field keys: `field_<section>_<element>`, group keys: `group_<section>`
- If `basic`: CSS class naming: BEM — `.block__element--modifier`
- If `tailwind`: CSS: Tailwind utility classes; component styles use `@apply` in `assets/css/src/tailwindcss/components/`
- If `tailwind`: Colors/fonts: Defined in `@theme` block in `assets/css/src/tailwindcss/main.css`
- If `tailwind`: Build: `npm run preview` for development, `npm run build` for production
- Template parts: `template-parts/section-<name>.php`
- Use `<prefix>get_field()` for bilingual fields, never raw `get_field()`
- Use `<prefix>get_repeater()` for bilingual repeaters
- Use `<prefix>e()` for translated static strings

## Workflow
1. `/wp-demo` — Create a demo HTML mockup for client approval
2. `/wp-header` — Build header.php from the demo
3. `/wp-footer` — Build footer.php from the demo
4. `/wp-section <name>` — Build each section (ACF fields + template + CSS)
Or: `/wp-yolo <demo-folder>` — build the whole site from an existing HTML demo in one pass.
5. `/wp-page <type>` — Generate page templates (blog, generic, legal, 404)
6. `/wp-settings` — Extend the settings/options page
7. `/wp-responsive-check <url>` — Validate responsive design
8. `/wp-finalize` — Pre-delivery checklist
```

**If `.wp-create.json` manifest exists**, also add the following section to the generated CLAUDE.md (after `## Conventions`):

```markdown
## WP-CLI
- Wrapper: `<wp_cli.wrapper from manifest>`
- Always use this wrapper for all wp commands
- Environment: <environment.type from manifest>
```

**If this is a demo-first project** (demo existed before init), add the following to the generated CLAUDE.md:

After the `## Project Details` section, add:

```markdown
## Demo
- **Source:** Existing demo (unpolished copy preserved at demo/.prepolish/index.html)
- **Sections:** <comma-separated list of detected sections>
- **Colors:** <extracted color values>
- **Fonts:** <extracted font families>
```

And in the `## Workflow` section, replace:
```
1. `/wp-demo` — Create a demo HTML mockup for client approval
```
With:
```
1. ~~`/wp-demo`~~ — Demo already exists, skip to /wp-header
```
