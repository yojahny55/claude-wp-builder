- **`wp-audit-rankmath` now runs on sonnet, and its long scripts moved to references.** The agent
  settles schema conflicts, title quality, the JSON-LD merge and the Polylang route, which is
  judgment rather than mechanical config, so it leaves the haiku tier (`/wp-yolo` model routing
  and the README follow). The code of Steps 5.5, 8.5, 12 and 15 now lives in
  `skills/wp-audit-seo-standards/references/rankmath-*.md`; the agent keeps each step's
  condition, rules and a pointer, and the checks that grepped those tokens now read the
  reference and require the pointer.
