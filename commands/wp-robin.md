---
description: Runner for the wp-robin skill — installs, configures and unsticks Robin Image Optimizer on a target WordPress root
allowed-tools: Read, Grep, Glob, Bash, AskUserQuestion
argument-hint: "[/path/to/wordpress]"
---

# WP Robin — Runner for the `wp-robin` Skill

This command is a **runner**, nothing more. `skills/wp-robin/SKILL.md` is the source of truth
for what fixing Robin Image Optimizer involves — the settings it applies, the queue repair,
the webp generation, the troubleshooting table. This command dispatches that skill and its
bundled script; it does not restate the procedure.
**Dispatch, never reimplement**: a second copy of the steps here is a second thing to keep
correct, and it will diverge from the skill the first time the skill is fixed.

It exists because the skill is `user-invocable: false` — as every skill in this plugin is —
so a user cannot reach it by typing its name. Skills inform; commands act. This is the command.

## Step 0: Parse Arguments

`$ARGUMENTS` is optional and holds at most one value:

| Argument | Required | Description |
|----------|----------|-------------|
| `<wp-root>` | no | Absolute path to the WordPress root — the directory holding `wp-config.php` (e.g. `/path/to/wordpress`) |

**Resolution order for the target root:**

1. The path given in `$ARGUMENTS`, if any.
2. `wp_cli.path` or the path inside `wp_cli.wrapper` in `.wp-create.json`, when that file
   exists in the project root:
   ```bash
   cat .wp-create.json
   ```
3. Otherwise leave it unset and let the script walk up from the working directory, which is
   what it does when `WP_ROOT` is empty.

If a path was given or resolved, verify it before doing anything else:

```bash
test -f "<wp-root>/wp-config.php" && echo OK
```

If that fails, stop: "`<wp-root>` is not a WordPress root — no `wp-config.php` there. Pass the
directory that contains `wp-config.php`."

## Step 1: Read the Skill

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-robin/SKILL.md` in full before running anything. It
carries the requirements (a MySQL/MariaDB client, one of ImageMagick / `cwebp` / PHP GD, and
optionally WP-CLI), the settings the script applies, what the output means, and the
troubleshooting table you will need in Step 4. Do not summarise it back to the user — run it.

## Step 2: Check Requirements

The script reports its own missing pieces, but checking first turns a mid-run abort into a
one-line message:

```bash
bash -c "command -v mariadb || command -v mysql"
bash -c "command -v convert || command -v cwebp || php -r 'echo function_exists(\"imagewebp\") ? \"gd\" : \"\";'"
```

If no database client is found, stop and say so. If no webp converter is found, report the
install line from the skill's troubleshooting table for the user's package manager and ask
whether to continue anyway (the queue repair still works; only webp generation is skipped).

## Step 3: Run the Fix

Run the skill's bundled script. It is the implementation — do not inline its logic here.

With an explicit target root:

```bash
bash -c "WP_ROOT='<wp-root>' bash ${CLAUDE_PLUGIN_ROOT}/skills/wp-robin/scripts/robin-fix.sh"
```

With auto-detection (no root resolved in Step 0, working directory is at or under the install):

```bash
bash -c "bash ${CLAUDE_PLUGIN_ROOT}/skills/wp-robin/scripts/robin-fix.sh"
```

The script is long-running on a large Media Library. Let it finish and keep its full output —
it reports every step, and Step 4 reads that output rather than re-deriving the state.

## Step 4: Report

Print the script's own summary, then interpret it against the skill:

- Plugin installed / activated, or the manual activation note when WP-CLI was absent.
- Settings applied, and which thumbnail sizes were discovered.
- Stuck items moved out of `processing`.
- Attachments registered, webp entries synced, and the final success / error / processing
  counts plus remaining orphans.

For anything non-zero in the error or orphan columns, quote the matching row of the skill's
troubleshooting table and the fix it names. Do not invent a fix that is not in the skill —
if the symptom is not covered there, say so and hand back the raw output.

Close with the next command when one applies: `/wp-debug media` if uploads still misbehave,
`/wp-audit --performance` to re-check image weight on the built site.
