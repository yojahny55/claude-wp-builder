# EnvSync recipes

Rules for the `wp envsync` CLI of the `ix-wp-envsync` plugin, learned the expensive way.
Read-only commands (`env list`, `--dry-run`) are always safe; anything that writes to a remote
environment needs the operator's explicit confirmation for that run.

## Token handling

The token is written by the operator into the gitignored `.wp-create.local.json`, never typed
or pasted into the chat, and never put in a command line that lands in the transcript. Before
anything uses it, run `git check-ignore .wp-create.local.json` and stop if it does not print
the path. If a token has appeared in the chat, say so and recommend rotating it.

## Recipe 1: pull by scope when `/hash/files` fails

A full pull compares file hashes through `/hash/files`. It fails when the remote has orphan
folders (directories the file index cannot walk). Do not retry the full pull. Split it:

1. `wp envsync pull <env> --only=db` for the database.
2. `wp envsync pull <env> --only=uploads` for media.
3. Code that is in git does not need pulling; for a specific folder use `--paths=<dir>`.

Report which scopes succeeded; a partial pull is a result, not an error to hide.

## Recipe 2: push only what is missing (no baseline)

Without a baseline, `push` refuses and asks for `--force`. `--force` overwrites everything
that differs, so it is never the first move to "just add what is absent".

1. Generate the dry-run first: `wp envsync push <env> --dry-run`.
2. From it, list what `--force` would overwrite and count how many files and rows already
   exist at the destination. Show both numbers.
3. Ask for explicit confirmation with those numbers on screen.
4. Narrow before forcing: prefer `--only=<scope>` plus `--exclude-tables=<list>` or
   `--paths=<list>`, and exclude the files that differ instead of forcing blindly.
5. Only then, and only if the remaining overwrite set is intended, add `--force`.

## Recipe 3: volatile options and tables

`wp_options` changes by itself (transients, cron, Action Scheduler), so a saved plan
(`--plan=<file>`) goes stale and is rejected. Either exclude the volatile tables/options
before saving the plan, or plan and apply in the same invocation. When a plan is rejected,
plan again; do not edit the plan file.

## After a sync

Re-run the dry-run: it should be empty for the scope just synced. Record nothing about the
token in any file that is committed.
