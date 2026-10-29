- **Elementor fix playbook for adopted sites.** `/wp-audit` fixes on an Elementor site kept
  rediscovering the same facts: what stays in Elementor and what must be theme code, that
  `$WP elementor flush-css` (not `flush-cache`) follows every data edit, the Loop Grid
  pagination, `fetchpriority`, ARIA-role and thumbnail-link traps, and that heading changes
  restyle. `skills/wp-audit-standards/references/builder-elementor.md` now holds them, and
  `fix.md` and the a11y, UX and performance agents load it only when `stack.builder` is
  `elementor`.
