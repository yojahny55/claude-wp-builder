- **`wp-template` reads its conditional sections from references.** The nav walker, carousel,
  CSS background, demo-control and archive ordering/pagination blocks moved from
  `agents/wp-template.md` to `skills/wp-theme-standards/references/template-*.md`, read only when
  a section needs them, cutting the agent from 44 KB to under 32 KB on every dispatch.
  `tests/checks/wp-template-references.sh` pins the pointers and the size budget.
