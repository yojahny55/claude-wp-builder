- **`wp-agentic-surfaces` follows the BLOCKED contract.** Without a readable `.claude/CLAUDE.md`
  that records the function prefix and theme path it stops and returns `BLOCKED: <reason>`
  plus the files it touched, instead of guessing a prefix into `inc/agentic.php`.
  `agent-contracts.sh` now includes it in the BLOCKED list.
