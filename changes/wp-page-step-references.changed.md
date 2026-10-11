- **`/wp-page` reads each page type when it reaches it.** `commands/wp-page.md` was 19 KB, and
  every run paid for the dispatch prompts of all seven page types up front, though a run builds
  one. It is now a 10.8 KB map: the argument parse, the CSS agent routing, the `tailwind` prompt
  body and the generic and custom types stay, and five long types send the run to one file each
  in the new `wp-page-run` skill (blog, legal, 404, search, embed). No type's wording changed.
  The checks that read `/wp-page` now read it with its references expanded in place, and
  `tests/checks/wp-page-run.sh` fails when a reference is not pointed to at its type or not
  listed in the skill.
