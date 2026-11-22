---
description: Take a verified backup of a WordPress site (database dump, optional uploads) outside the project, with sha256 sums
allowed-tools: Read, Bash
argument-hint: "[/path/to/wordpress] [--uploads] [--label <word>] [--out <dir>]"
---

# WP Backup — one verified copy, outside the project

Runs `bin/wp-backup.sh`, the single export every other command shares. It does not
reimplement the export: a second copy of it is a second thing to keep correct.

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

## Step 1: Resolve the project

Use the path in the arguments, else the current directory. It must hold a valid
`.wp-create.json` (the WP-CLI wrapper and project slug are read from it, never re-asked).

## Step 2: Back up

```bash
B=$(bash "${CLAUDE_PLUGIN_ROOT}/bin/wp-backup.sh" '<project-path>' [--uploads] [--label <word>] [--out <dir>])
```

Add `--uploads` when the user asks for media too (it can be large). The folder defaults to
`~/.wp-backups/<slug>/<UTC timestamp>[-<label>]/`, always outside the WordPress root, mode 700,
files 600. `wp-config.php` is never copied: it holds credentials.

The script checks the dump is non-empty and ends with its `Dump completed` footer, writes it
under a temp name and renames it only when complete, and runs `gzip -t` on the uploads archive.
Exit `1` means the copy was made but did not verify (the folder is already deleted); exit `2`
means the site could not be measured (no manifest, or the wrapper does not answer). Neither is
a backup: stop and say so.

## Step 3: Report

Print `$B` on its own line, the files with their sizes (from `backup.json`), and whether uploads
are in the copy. When `--uploads` was not passed, say plainly that uploads are NOT backed up.
Point at `/wp-restore "$B"` as the way back.
