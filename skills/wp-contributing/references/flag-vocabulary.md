# Command flag vocabulary

A flag name means the same thing in every command that takes it. Flags that already shipped
are **not renamed**: a rename breaks the people and scripts that use them. This file fixes
the meaning for new commands and lists the historical exceptions, so nobody has to
rediscover them from the command text.

## Contents

- Canonical meanings
- Historical exceptions
- Rule for a new command

## Canonical meanings

| Flag | Canonical meaning | Commands that carry it today |
|---|---|---|
| `--yes` | Skip a question the command would otherwise ask. Never skips a backup or a production gate. | `/wp-update` (skips "which updates") |
| `--force` | Replace or overwrite what already exists (a built theme, a seeded row, an icon, a client-edited value). The safety net, such as a backup, still runs. | `/wp-yolo` (discard the current build), `/wp-favicon` (replace the chosen icon), `/wp-cinematic-seed` (overwrite scene rows), `/wp-woo-setup` (take back values the client changed) |
| `--dry-run` | Report what would change; write nothing. | `/wp-anonymize`, `/wp-s3-media`, `/wp-cinematic-seed` |
| `--resume` | Continue an interrupted run from its recorded state instead of starting over. | `/wp-yolo` only |

`--force-adopted` is a different flag: it lets a command run against a site `/wp-adopt`
registered rather than one this plugin built. It never implies `--force`.

## Historical exceptions

- `/wp-clone --force` does not overwrite: it proceeds when the destination already holds a
  WordPress site, and the backup is still taken. It means "I know what is there".
- `/wp-seed --force-fields` is the field-level form of `--force`: it overwrites field values
  the client edited, not records.
- `--yes` exists only on `/wp-update`; the other commands ask through `AskUserQuestion`
  and have no flag to skip the question.
- `--dry-run` is missing from most commands that write. Absence is not a statement that a
  command is safe to run blind.

## Rule for a new command

1. Use the canonical name when the meaning fits. Do not coin `--overwrite`, `--yes-to-all`
   or `--simulate`.
2. A flag that skips a confirmation is `--yes`; a flag that overwrites is `--force`. A command
   that needs both takes both, and `--force` never implies `--yes`.
3. A flag that skips a backup or a production gate does not exist. State in the command that
   the gate runs under `--yes` and `--force`.
4. Document the flag in the command's argument table with its canonical meaning, and add an
   exception here before shipping one that departs from it.
