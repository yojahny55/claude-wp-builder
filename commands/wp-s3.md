---
description: Runner for the wp-s3 skill — installs and configures S3 Uploads on a WordPress root, or reverses it with --revert
allowed-tools: Read, Grep, Glob, Bash, AskUserQuestion
argument-hint: "[/path/to/wordpress] [--revert]"
---

# WP S3 — Runner for the `wp-s3` Skill

This command is a **runner**, nothing more. `skills/wp-s3/SKILL.md` is the source of truth
for what putting a site's media on S3 involves — the constants it writes and why, the
staging checklist, the WooCommerce and Elementor follow-up, the known failures. This command
collects the connection details, dispatches the skill's bundled scripts, and reports.
**Dispatch, never reimplement**: a second copy of the procedure here is a second thing to
keep correct, and it will diverge from the skill the first time the skill is fixed.

It exists because the skill is `user-invocable: false` — as every skill in this plugin is —
so a user cannot reach it by typing its name. Skills inform; commands act. This is the
command.

`/wp-s3-media` is the separate runner for moving the media, and it is the next step after
this one.

## Step 0: Parse Arguments

**First: validate the project configuration.**

`${PROJECT_PATH}` is not an environment variable the way `${CLAUDE_PLUGIN_ROOT}` beside it is: it is the WordPress project root, the directory holding `.wp-create.json`, and you substitute the real path yourself — the one the user named, or the working directory when they named none — because an empty argument makes the validator print its usage line and exit `1`, which the table below then reads as "stop and report".

```bash
bash -c "node ${CLAUDE_PLUGIN_ROOT}/bin/wp-config.mjs validate '${PROJECT_PATH}'"
```

| Exit | Meaning | Do |
|---|---|---|
| `0` | valid | continue |
| `1` | invalid, or the generated context block disagrees with the manifest | stop and report the message verbatim |
| `2` | an older manifest can migrate | run `wp-config.mjs migrate '${PROJECT_PATH}'`, then continue |
| `3` | no manifest | this project was not created by `/wp-create`; stop and say so |

On exit 2, run the migration before continuing.

**Amending the exit `3` row above:** Exit `3` here falls through to the resolution order below
rather than stopping outright — this command targets any WordPress root, not only one created
by `/wp-create`.

`$ARGUMENTS` holds at most two values:

| Argument | Required | Description |
|----------|----------|-------------|
| `<wp-root>` | no | Absolute path to the WordPress root — the directory holding `wp-config.php` |
| `--revert` | no | Take the site back off S3 instead of configuring it |

**Resolution order for the target root:**

1. The path given in `$ARGUMENTS`, if any.
2. `wp_cli.path` or the path inside `wp_cli.wrapper` in `.wp-create.json`, when that file
   exists in the project root.
3. Otherwise ask for an explicit root. Do not guess.

Verify it before doing anything else:

```bash
test -f "<wp-root>/wp-config.php" && echo OK
```

If that fails, stop: "`<wp-root>` is not a WordPress root — no `wp-config.php` there. Pass
the directory that contains `wp-config.php`."

## Step 1: Read the Skill

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-s3/SKILL.md` in full before running anything. It
carries the requirements, what each constant is for, the staging checklist you will hand the
user in Step 5, and the known failures you will need if a step fails. Do not summarise it
back to the user — run it.

For a production site on AWS, also read
`${CLAUDE_PLUGIN_ROOT}/skills/wp-s3/references/aws.md`: the bucket, CloudFront and IAM work
happens before this command is useful, and the user may not have it yet.

## Step 2: The Blocking Question

Ask this **before** collecting anything else, because a "yes" changes the recommendation
rather than the configuration:

> Does this site sell **downloadable products**?

If yes, say plainly that paid downloads have no clean answer with this plugin — the skill's
"Known failures" explains why — and ask whether to continue, keep those files off S3, or
stop here. Do not configure anything until the user chooses.

## Step 3: Collect the Connection

Use `AskUserQuestion` for everything except the secret:

| Value | Notes |
|---|---|
| Bucket | May carry a prefix, as `bucket/site-prefix` |
| Region | On an S3-compatible server, whatever it was configured with — commonly `us-east-1` |
| Media URL | What visitors will load. `https://media.<domain>` on CloudFront, or `<endpoint>/<bucket>` |
| Endpoint | Empty on AWS. A URL for any S3-compatible server |
| Authentication | The server's IAM role, or an access key pair |

**The secret never goes in a flag, an argument, a file you write, or your own output.** Ask
the user to export it into the environment themselves, in their own terminal:

```
! read -rs S3_UPLOADS_SECRET_VALUE && export S3_UPLOADS_SECRET_VALUE
```

Then run the script in that same shell. If the secret is not in the environment and the
chosen authentication is a key pair, stop and ask again rather than working around it.

## Step 4: Run the Script

```bash
bash ${CLAUDE_PLUGIN_ROOT}/skills/wp-s3/scripts/s3-setup.sh --wp-root '<wp-root>' --bucket '<bucket>' --region '<region>' --bucket-url '<media-url>' --auth key --key '<access-key-id>'
```

Add `--endpoint '<url>'` for an S3-compatible server. For a server with an IAM role, use
`--auth instance` and drop `--key`.

The script backs up `wp-config.php` before editing it, writes `s3-config.php` at `0640`,
installs the mu-plugin, and refuses to finish if anything it generated does not parse. It
does **not** activate the plugin: say so, because a user who expects media in the bucket
after this step will think it failed.

For `--revert`:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/skills/wp-s3/scripts/s3-revert.sh '<wp-root>'
```

Read its final output to the user in full. The two things it cannot undo — Elementor's
stored URLs and WooCommerce's download settings — are printed there as ready commands.

## Step 5: Report

Report, in this order:

1. Whether `wp s3-uploads verify` passed. If WP-CLI was missing, give the user the command.
2. That the plugin is installed and **not** active, and that no media have moved.
3. The next step, verbatim: `/wp-s3-media upload <wp-root>`, dry run first.
4. The staging checklist from the skill, as a list the user can work through.

If a step failed, match the error against the skill's "Known failures" before improvising.
An `AccessControlListNotSupported` or `AccessDenied` on the first upload is a documented
case with a documented fix, not a configuration to start guessing at.
