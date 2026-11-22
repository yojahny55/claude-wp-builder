# /wp-section — Step 7

`commands/wp-section.md` sends the run here at Step 7 when `is_contact_section = true`. Print this summary in place of the non-contact one; the `[basic only]` / `[tailwind only]` markers read as the command describes.

## Contents

- The contact summary

### For contact sections:
```
=== Section "Contact" Built ===
Files created/updated:
  - fields/contact.php (ACF field definitions)
  - template-parts/section-contact.php (template part)
  - assets/css/styles.css (Contact section CSS)                      [basic only]
  - components/<page-slug>.css or utilities/site.css (only if a rule was needed) [tailwind only]
  - <page-template>.php (added get_template_part call)
  - cf7/form-en.html (CF7 form markup — English)
  - cf7/form-es.html (CF7 form markup — Spanish)
  - cf7/email-admin-en.html (Admin email template — English)
  - cf7/email-admin-es.html (Admin email template — Spanish)
  - cf7/email-user-en.html (User confirmation — English)
  - cf7/email-user-es.html (User confirmation — Spanish)

CF7 Forms created:
  - Contact EN (ID: <id>)
  - Contact ES (ID: <id>)

Next: Run /wp-section <next-section> for the next section.
```
