- **Agent contracts stated once and enforced.** `wp-tailwind` now has a First Action block
  (author mode reads the project file; conversion mode may run with no project), and
  `wp-context` and `wp-normalize` document why they have none. The agents that read the
  project file return `BLOCKED: <reason>` plus touched files instead of guessing a prefix;
  auditors (security and usability included) keep their JSON and add a `"blocked"` key, which
  `/wp-audit` re-dispatches once and, if still blocked, names in the `INCOMPLETE` report. `wp-audit-aios` and `wp-audit-rankmath`
  say they write, and `wp-contributing` explains the `wp-audit-*` prefix. FAQ schema is
  seeded only for visible questions, with no rich-result promise, and the demo-craft devices
  reference says where GSAP comes from and points to its license.
- The normalize agent captures `cssRules` when the project file or its `Template:` line is
  absent, and the CSS agent's blocked rule no longer contradicts its own instruction to add
  missing `:root` definitions.
