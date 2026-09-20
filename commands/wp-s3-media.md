---
description: Runner for the wp-s3 skill — moves wp-content/uploads between a site and its bucket, and verifies that it moved
allowed-tools: Read, Grep, Glob, Bash, AskUserQuestion
argument-hint: "<upload|download> [/path/to/wordpress] [--dry-run]"
---

# WP S3 Media — Runner for the `wp-s3` Skill

This command is a **runner**, nothing more. `skills/wp-s3/SKILL.md` is the source of truth
for how media move to and from a bucket — the exclusions, why neither direction may
overwrite, and why an exit code is not evidence that the transfer happened. This command
dispatches the skill's bundled script and reports what it said. **Dispatch, never
reimplement**: a second copy of the transfer logic here is a second thing to keep correct,
and it will diverge from the skill the first time the skill is fixed.

It exists because the skill is `user-invocable: false` — as every skill in this plugin is —
so a user cannot reach it by typing its name. Skills inform; commands act. This is the
command.

`/wp-s3` configures the site and must have run first: this command reads the connection out
of the `s3-config.php` that it wrote.

## Step 0: Parse Arguments

`$ARGUMENTS`:

| Argument | Required | Description |
|----------|----------|-------------|
| `upload` \| `download` | yes | `upload` sends the local library to the bucket; `download` brings the bucket to disk |
| `<wp-root>` | no | Absolute path to the WordPress root. Defaults as in `/wp-s3` |
| `--dry-run` | no | Transfer nothing; report what would move |

If the direction is missing, ask — do not assume. `upload` before activating the plugin is
the migration; `download` is for cloning to an environment that does not use S3, or for
going back. They are not symmetric in consequence, and guessing wrong on a site whose local
library is stale is how a good copy gets buried under an old one.

Verify the root and its configuration:

```bash
test -f "<wp-root>/wp-config.php" && test -f "<wp-root>/s3-config.php" && echo OK
```

If `s3-config.php` is missing, stop: "This site is not configured for S3 yet. Run `/wp-s3
<wp-root>` first."

## Step 1: Read the Skill

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-s3/SKILL.md` in full before running anything —
specifically "The transfer verifies itself", which is what you are dispatching and what you
will have to explain if it fails. Do not summarise it back to the user — run it.

## Step 2: Dry Run First, Always

```bash
bash ${CLAUDE_PLUGIN_ROOT}/skills/wp-s3/scripts/s3-media.sh <direction> '<wp-root>' --dry-run
```

Show the user what it plans to move, and how much. On a first migration, count it against
the local library so a wildly smaller number is caught before the real run rather than
after:

```bash
find '<wp-root>/wp-content/uploads' -type f | wc -l
```

## Step 3: Run It

```bash
bash ${CLAUDE_PLUGIN_ROOT}/skills/wp-s3/scripts/s3-media.sh <direction> '<wp-root>'
```

A non-zero exit means something is missing on the other side. Report the script's own error
line verbatim; it distinguishes the cases — the client could not connect, it reported an
error while exiting `0`, or the comparison afterwards found files missing or of the wrong
size — and they have different causes. A `Note:` line about files that already existed is
not one of them: neither direction may replace a file, so that line is the tool doing what
it was told.

When the transfer itself failed, the comparison still ran and its output is above the
error: report **both**, because the comparison is what says how much reached the other
side and therefore what a second run has left to do.

**On a server with an IAM role** the script stops with no key pair to sign with, and prints
the two ways forward. Read them to the user and let them choose; do not pick one, and never
write credentials anywhere to get past it.

## Step 4: Report

1. Direction, source and target.
2. `Verified: nothing left to transfer.` — quote it, or quote the failure.
3. For an `upload` that was the migration: the next step is activation, which this command
   does not do:
   ```bash
   cd <wp-root> && wp plugin activate S3-Uploads && wp s3-uploads enable
   ```
4. For a `download` that was part of going back: point at `/wp-s3 --revert`, which sequences
   the rest correctly.

Nothing in the bucket is ever deleted by this command, in either direction. If the user
wants objects removed, say that it has to be done deliberately, against the bucket, with the
site checked first.
