---
name: wp-finalize-run
description: "The check detail of the /wp-finalize run, split out of commands/wp-finalize.md so the command stays a short map — bilingual coverage, theme structure, the WP-CLI runtime validation, the GEO and agent-readiness report, and the three demo-parity layers (static, WP-CLI, measured visual parity). Use when /wp-finalize reaches a check that names one of these reference files, or when changing how a /wp-finalize check behaves. Not for the audit agents' own checks (wp-audit-standards) or the GEO catalog itself (wp-audit-geo-standards)."
user-invocable: false
---

# /wp-finalize check detail

`commands/wp-finalize.md` owns the order of the run, the short checks and the report format. Each
check that needs more than a few paragraphs keeps its heading and entry condition there and sends
the run to one file here. The command reads the file at that check, not before, so a project
without `.wp-create.json` or a demo never pays for the WP-CLI validation or the parity layers.

These files are the check itself, not background reading. When the command says to read one,
read it whole and follow it in order.

## References, by check

| Check | File | Covers |
|---|---|---|
| Check 2, Bilingual Coverage | [references/bilingual.md](references/bilingual.md) | The per-strategy i18n checks: Polylang and field-suffix coverage, untranslated strings, language-switcher presence |
| Check 4, Theme Structure | [references/theme-structure.md](references/theme-structure.md) | Required theme files and headers, menu locations per strategy, favicon, login branding |
| Check 7, WP-CLI Runtime Validation | [references/wp-cli-runtime.md](references/wp-cli-runtime.md) | Runtime checks against the live site when `.wp-create.json` exists: pages, menus, options, authors |
| Check 8, GEO and agent-readiness | [references/geo.md](references/geo.md) | The report-only GEO and agent-readiness scan |
| Demo-parity gate, Layer 1 | [references/parity-static.md](references/parity-static.md) | Static comparison of the demo against the theme: tokens, fonts, backgrounds, collisions |
| Demo-parity gate, Layer 2 | [references/parity-wpcli.md](references/parity-wpcli.md) | The WP-CLI layer when WordPress is reachable: content and media parity |
| Demo-parity gate, Layer 3 | [references/parity-visual.md](references/parity-visual.md) | Measured visual parity with `claude-in-chrome`: computed styles, hard and soft deltas |

## Changing a check

Edit the reference file, not the command, unless the check order or a check's entry condition
changes. A check that guards a check's wording reads the command with these files expanded in
place (`tests/checks/lib/expand-command.sh`); `tests/checks/wp-finalize-run.sh` asserts that every
file here is named both in this table and at its heading in `commands/wp-finalize.md`.
