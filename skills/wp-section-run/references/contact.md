# /wp-section — Step 5

`commands/wp-section.md` sends the run here at Step 5 (the two-phase dispatch for a contact section). Follow it in order; nothing in it is optional background.

### For CONTACT sections: Two-Phase Dispatch

**File ownership** above holds here unchanged: `wp-template` writes
`template-parts/section-contact.php`, and on `tailwind` `wp-tailwind` in author mode
edits it afterwards. That is why Agent 3 sits in a different phase on each path — on
`basic` it writes a file nobody else touches, on `tailwind` it edits the file Phase 2
has not produced yet.

**Phase 1:** Launch three agents IN PARALLEL (two on `tailwind` — see Agent 3):

#### Agent 1: wp-acf

(Same prompt as non-contact above)

#### Agent 3 (routed by template): wp-css or wp-tailwind

Follow the "CSS agent routing" table above — the same table governs both dispatch
blocks. Dispatch `wp-css` or `wp-tailwind` in author mode (never both) using the
same prompt as non-contact above.

**On `basic`, `wp-css` runs here, in Phase 1.** It writes `assets/css/styles.css`, which
no other agent in this flow touches.

**On `tailwind`, `wp-tailwind` does NOT run here.** It edits
`template-parts/section-contact.php`, which Phase 2's `wp-template` has not written yet;
dispatched in Phase 1 it would either find no file or race the one being written. It runs
in Phase 3 below instead.

#### Agent 4: wp-cf7

> Generate CF7 contact forms and branded email templates for the contact section.
>
> **Project context:**
> - Function prefix: `<prefix>`
> - Languages: `<languages from CLAUDE.md>`
> - Theme directory: `<theme path>`
> - WP-CLI wrapper: `<$WP from .wp-create.json>`
>
> **Demo HTML for the contact section:**
> ```html
> <paste extracted section HTML here>
> ```
>
> Parse the demo form fields, generate CF7 form markup per language, create branded HTML email templates (admin notification + user confirmation), save all files to `cf7/` directory, and create the forms via WP-CLI.
>
> Return the form IDs as your final output in this exact format:
> ```
> FORM_ID_EN=<id>
> FORM_ID_ES=<id>
> ```
> (Only include ES line if bilingual)

Wait for all Phase 1 agents to complete. Extract form IDs from wp-cf7 output.

**Phase 2:** Launch wp-template agent with form IDs:

#### Agent 2: wp-template

> Generate `template-parts/section-contact.php` in the theme directory.
>
> [standard wp-template prompt — same field naming convention, escaping rules, BEM classes, semantic HTML, etc.]
>
> **IMPORTANT — CF7 Form Integration:**
> This is a contact section with CF7 forms. The form IDs are:
> - English form ID: `<FORM_ID_EN>`
> - Spanish form ID: `<FORM_ID_ES>` (if bilingual)
>
> Render the CF7 form in the template using language detection:
> ```php
> <?php
> $form_id = prefix_is_lang('es') ? <FORM_ID_ES> : <FORM_ID_EN>;
> echo do_shortcode('[contact-form-7 id="' . $form_id . '" html_class="contact__form"]');
> ?>
> ```
>
> For monolingual sites (no Spanish), use the form ID directly:
> ```php
> <?php echo do_shortcode('[contact-form-7 id="<FORM_ID_EN>" html_class="contact__form"]'); ?>
> ```
>
> When the project keeps the form in the settings page (`contact_form_shortcode` and its
> language twin) instead of fixed IDs, render it with the starter's
> `prefix_contact_form()` and wrap the whole section in its result:
> `$form = prefix_contact_form(); if ( '' !== $form ) { … echo $form; … }`. It returns
> `''` when the referenced form (numeric id, hash or title) no longer exists or CF7 is
> inactive, so a deleted or re-imported form drops the section instead of printing CF7's
> "Not Found" notice on the page. Never `do_shortcode()` the option directly.

**Phase 3 (`tailwind` only):** once Agent 2 has returned, dispatch `wp-tailwind` in author
mode with Agent 3's prompt from the non-contact block above, naming
`template-parts/section-contact.php` as the file it edits. On `basic` there is no Phase 3
— `wp-css` already ran in Phase 1.
