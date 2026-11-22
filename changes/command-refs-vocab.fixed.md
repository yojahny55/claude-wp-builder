- **Command cross-references, the craft gate, the model table and the flag vocabulary.**
  `/wp-update` and `/wp-polish` cited "Step 5.3", "Step 1.2" and "Step 3.1", which are list
  items, not headings, so a run looking for them found nothing; they now read "Step 5, item 3",
  and `tests/checks/step-refs-resolve.sh` fails on any `Step N.M` a command cites without a
  heading, and on an unqualified citation of another command's step. The craft gate no
  longer runs `npm i -D playwright-core` in the WordPress project on probe exit 2: it points
  `PLAYWRIGHT_CORE` at a copy already on the machine, and installs only after the user says yes.
  `/wp-yolo`'s model routing list now names every agent (it omitted `wp-audit-geo`,
  `wp-audit-ux`, `wp-agentic-surfaces` and `wp-research`), and `model-routing.sh` checks it
  against each agent's frontmatter. `skills/wp-contributing/references/flag-vocabulary.md` fixes
  what `--yes`, `--force`, `--dry-run` and `--resume` mean and lists the existing exceptions.
