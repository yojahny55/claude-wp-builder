# /wp-seed — Phase 6.5

`commands/wp-seed.md` sends the run here at Phase 6.5 (placeholder pages for `page_link` options fields). Follow it in order; nothing in it is optional background.

## Contents

- Creating and marking the placeholder pages
- The re-run rule
- The template-side `page_link` guard

For each such field currently empty, or resolving to a post that is not
`publish`:

1. Create a page in **publish** status (`wp post create … --post_author=$AUTHOR`, like every
   create in this command) whose body visibly states, in its own
   language, that the text is a generic placeholder pending review — never
   silently ship boilerplate as if it were the client's real copy.
2. Mark it with `_<prefix>_seeded_content` (the marker every seeded record carries)
   plus `_<prefix>_seed_placeholder`, so a later run can tell it
   apart from a page the client has since written for real.
3. Point the field at the new page: `update_field('<field>', get_permalink(<id>), 'option')`.
4. Under `i18n strategy: polylang`, create and publish one page per
   configured language, join them with `pll_save_post_translations()`, and
   set each language's own field (see "One deliberate crossover" in
   `skills/wp-contributing/SKILL.md` — options-page fields keep their
   `_<lang>` suffix under Polylang). Under `suffix`, write the `_<lang>`
   field directly.

**Re-running is safe.** A field whose target page still carries the marker
meta is free to be rewritten; the marker meta is gone — because the client
edited the page — the page is left exactly as it is, even if the field
already pointed somewhere else. This is the same idempotency rule as ACF
field seeding elsewhere in this command: never overwrite a client's own
work, only ever a previous run's own placeholder.

Templates that print one of these fields must not merely check for a
non-empty value: a `page_link` field keeps pointing at its page after that
page is unpublished or trashed, and WordPress then serves that URL as a 404
with nothing to say so. Confirm `agents/wp-template.md`'s `page_link` guard
(the options-page fields section under "i18n Helper Functions") is what the
generated header/footer actually calls before printing one of these links.
