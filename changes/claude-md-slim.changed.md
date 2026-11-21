- **`CLAUDE.md` is down from 805 lines to about 245.** It loads into every session, and the
  history behind each rule was paid for on every task. The testing detail, the architecture
  reasoning and every known ceiling moved verbatim to `docs/testing.md`,
  `docs/architecture.md` and `docs/known-ceilings.md`, and `CLAUDE.md` keeps the rules, the
  recorded-decision lines and a pointer to each. The `bin/` list now names every script, and the
  fixed counts of compositions, roles and audit checks are gone in favour of their source of
  truth. The checks that read the moved text follow it, and the zero-occurrence controls now
  read both files, so they cannot pass on a file that no longer holds the text;
  `tests/checks/claude-md-budget.sh` holds the size cap.
