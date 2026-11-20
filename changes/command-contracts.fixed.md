- **Commands now declare what they use, in an order that refuses before it asks.** `/wp-init`
  validated the manifest and stopped on `demo/FAILED.md` only after it had asked the template,
  custom-fields and i18n questions, and could dispatch to `/wp-cinematic-init` first; both
  refusals now come before any question or dispatch. `/wp-init` and `/wp-polylang` declare
  `AskUserQuestion` and `/wp-demo-verify` declares `Agent`. Argument hints list the flags the
  bodies accept (`/wp-yolo`, `/wp-init`, `/wp-section`, `/wp-demo-verify`,
  `/wp-responsive-check`, `/wp-contribute`). The five `/wp-cinematic-*` commands move from
  `name:`/`arguments:` to the standard frontmatter, `/wp-cinematic-demo` takes `--no-hybrid`
  like the rest, and `/wp-cinematic-init` no longer points at a nonexistent `--update-kit`.
  `tests/checks/command-frontmatter.sh` and `tests/checks/wp-init-order.sh` pin all of it.
