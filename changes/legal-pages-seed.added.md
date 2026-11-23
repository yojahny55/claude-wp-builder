- **`/wp-page legal` creates the legal pages.** It used to generate the Legal Page template
  and stop, so a site went to `/wp-finalize` with no Privacy Policy, Terms or Cookie Policy
  page. It now drafts the three from what the project records, leaving every fact it does not
  have as `[[pending: …]]`, and `skills/wp-page-run/scripts/legal-pages.php` creates them as
  drafts on the template. WordPress's own unfilled privacy draft is filled; a page someone
  already wrote under one of the slugs is never touched; nothing is published.
