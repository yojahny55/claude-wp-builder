---
description: Restore a WordPress site from a /wp-backup folder, verifying checksums first and the site URL after
allowed-tools: Read, Bash, AskUserQuestion
argument-hint: "<backup-dir> [/path/to/wordpress] [--dry-run] [--yes] [--wrapper <cmd>]"
---

# WP Restore — put a backup back, and prove it

Runs `bin/wp-restore.sh`. The command asks; the script enforces. It overwrites the site's
database (and uploads, when the backup carries them), so nothing runs before the plan is shown.

**First: validate the project configuration.**

`${PROJECT_PATH}` is not an environment variable the way `${CLAUDE_PLUGIN_ROOT}` beside it is: it is the WordPress project root, the directory holding `.wp-create.json`, and you substitute the real path yourself — the one the user named, or the working directory when they named none — because an empty argument makes the validator print its usage line and exit `1`, which the table below then reads as "stop and report". The path travels as a positional argument, never inside the `-c` string: write it in single quotes, and a path that holds a single quote gets each one written as `'\''`.

```bash
bash -c 'node "$1/bin/wp-config.mjs" validate "$2"' _ "${CLAUDE_PLUGIN_ROOT}" '${PROJECT_PATH}'
```

| Exit | Meaning | Do |
|---|---|---|
| `0` | valid | continue |
| `1` | invalid, or the generated context block disagrees with the manifest | stop and report the message verbatim |
| `2` | an older manifest can migrate | run `wp-config.mjs migrate '${PROJECT_PATH}'`, then continue |
| `3` | no manifest | this project was not created by `/wp-create`; stop and say so |

On exit 2, run the migration before continuing.

## Step 1: Resolve

`<backup-dir>` is a folder written by `/wp-backup` (it holds `backup.json`). The project is the
path argument, else the current directory, with a valid `.wp-create.json`.

## Step 2: Show the plan

```bash
bash "${CLAUDE_PLUGIN_ROOT}/bin/wp-restore.sh" '<project-path>' '<backup-dir>' --dry-run
```

This verifies every sha256 in `backup.json` and prints what would change, touching nothing.
Exit `1` here (a checksum does not match) means the backup is damaged: stop, restore nothing.
If the plan warns that `DB_NAME` differs, say so prominently: the backup came from another database.

## Step 3: Ask

Unless `--yes` was passed, use `AskUserQuestion` to confirm, showing the plan from Step 2. Offer
"restore" and "cancel". On a `DB_NAME` mismatch the question must name both databases. This
step is the only gate; do not skip it because the user "obviously" wants a restore.

## Step 4: Restore

```bash
bash "${CLAUDE_PLUGIN_ROOT}/bin/wp-restore.sh" '<project-path>' '<backup-dir>' --yes
```

`--wrapper "<cmd>"` supplies the WP-CLI wrapper when the project has no manifest (the same flag
as `/wp-backup`'s script; `/wp-update`'s rollback uses it). It is handed on to the pre-restore copy.

(`--yes` is passed only after the answer above, or when the user gave it.) The script takes a
`pre-restore` copy first, imports, swaps uploads, then checks, against the backup, `option get siteurl`,
the post count (exactly equal: `wp_posts` is replaced whole) and the table count (at least as many:
the dump only drops and recreates its own tables, so a table the site gained since the backup, such
as a plugin installed later, survives the import; fewer tables means the import did not complete). Exit `0` is restored and verified; exit `1` after the import means verification failed
and the message names the pre-restore copy to go back to with `/wp-restore`; exit `2` means the
site could not be measured.

## Step 5: Report

The last stdout line is the pre-restore copy: print it, and say it is the undo.
