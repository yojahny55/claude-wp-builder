---
description: Replace real customer and user data in a cloned WordPress site with deterministic fakes
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, AskUserQuestion
argument-hint: "[--dry-run] [--keep-user=<login>]"
---

# WP Anonymize — Replace Real People In A Clone

`/wp-clone` brings a production database onto a development machine. Step 5.5 isolates the
seams a copy shares with its original — mail, cron, indexing — but the database it imported
holds live customer records from the moment the import finishes, and isolation does nothing
about that. This command is the separate, opt-in operation that `/wp-clone`'s report points
at.

**It is not a privacy guarantee.** It replaces the fields in a named catalog and reports
every table it did not examine. A clone that says *"these 14 tables were not looked at"* can
be handed to a contractor with an accurate idea of the risk; a clone that says *"anonymised"*
cannot. The difference between those two sentences is the whole point of this command, and
every step below exists to keep the second one from being printed.

## Step 0: Refuse to run on anything that is not a clone

This command destroys data irreversibly, and its only catastrophic failure is being pointed
at production. That gate comes before argument parsing, before validation, before anything.

```bash
bash -c "test -f wp-content/mu-plugins/00-clone-isolation.php && echo MARKER || echo NONE"
```

`00-clone-isolation.php` is written by `/wp-clone` Step 5.5 and by nothing else. It is a
must-use plugin, so it survives a plugin being deactivated and cannot be removed by an option
write — which is what makes it a usable marker and not just a hint.

On `NONE`, stop:

```
Error: this does not look like a clone.
wp-content/mu-plugins/00-clone-isolation.php is missing — that file is written by
/wp-clone Step 5.5 and marks a site as an isolated copy.

/wp-anonymize permanently rewrites user and customer records. It will not run
against a site it cannot prove is a clone.

If this really is a clone made before isolation existed, run /wp-clone's Step 5.5
against it first — a site worth anonymising is a site worth isolating.
```

**There is no `--force` past this gate, and adding one would be the defect.** Every other
refusal in this plugin takes an override because the operator can be right and the check
wrong. Here the cost of the check being wrong is a recoverable annoyance, and the cost of the
operator being wrong is a production site with its customers overwritten and no undo. Those
are not comparable, so this one does not get a flag. The escape hatch is to isolate the site,
which is the correct action anyway.

## Step 1: Validate the manifest, then parse arguments

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

Note the ordering: the clone gate in Step 0 runs **before** this. A site that is not a clone
is refused whatever its manifest says, because the manifest describes a project and the gate
answers a different question — whether this database is a copy or the original.

### Arguments

- **`--dry-run`** = count and report everything, change nothing. Prints the same report the
  real run prints, with `would change` instead of `changed`. Run this first on any clone
  you have not anonymised before.
- **`--keep-user=<login>`** = the account to leave alone (see Step 3). Defaults to the login
  currently in `.wp-create.json`'s admin record, or the site's first administrator.

Resolve the WP-CLI wrapper from `.wp-create.json` as every other command does, and hold it
as `$WP`.

## Step 2: Back up first, unconditionally

```bash
bash -c "mkdir -p ~/.wp-clone-backups"
bash -c "$WP db export ~/.wp-clone-backups/<project-slug>-$(date -u +%Y%m%dT%H%M%SZ)-pre-anonymize.sql"
```

Outside the project, for the reason `/wp-clone` Step 1.5 already gives: a backup under
`wp-content/` is reached by the next clone's `rsync` and by an `rm -rf` of the project.

**Unconditional, and not skippable by `--dry-run` skipping it.** A dry run changes nothing
and needs no backup; a real run takes one every time, including the second and third time it
is run on the same clone. This command has no undo, and "I already have a backup from
earlier" is a sentence people say about a file they deleted.

Report the path in the final summary. If the export fails, stop — an anonymisation that
proceeds past a failed backup is a one-way door someone opened by accident.

## Step 3: Decide which account survives

Anonymising every user locks the operator out of their own clone, so exactly one account is
preserved: `--keep-user`, or the resolved default.

Confirm it exists and is an administrator before changing anything:

```bash
bash -c "$WP user get <login> --field=roles"
```

If it does not exist, or is not an administrator, stop and say so rather than picking
another. Choosing a replacement silently is how an operator ends up locked out of a clone
whose backup they have not yet learned to need.

**The preserved account is named in the report, every time.** It still holds a real person's
email address — usually the operator's own, sometimes the client's — and a summary that lists
what was anonymised without listing what was deliberately not is a summary that overstates
what happened.

## Step 4: The catalog

These fields, and nothing outside them. The list is the contract: a field not named here is
not touched and is accounted for in Step 6.

**`wp_users`** — `user_email`, `user_nicename`, `display_name`, `user_url`.

`user_login` is deliberately **not** rewritten. It is the join key half the ecosystem uses
to recognise an account, it appears in log lines and in third-party tables this catalog does
not reach, and changing it breaks the login for every account an operator might need to
impersonate while debugging. A login is also far less identifying than an email address.
Named here because its absence otherwise reads as an oversight.

**`wp_usermeta`** — `first_name`, `last_name`, `nickname`, `description`, and every
`billing_*` and `shipping_*` key.

**`wp_comments`** — `comment_author`, `comment_author_email`, `comment_author_url`, and
`comment_author_IP`. The IP matters: it is personal data under GDPR on its own, and it is the
field people forget because it does not look like a name.

**WooCommerce, when active** — order `_billing_*` and `_shipping_*` postmeta; and when HPOS
is enabled, `wp_wc_orders` (`billing_email`), `wp_wc_order_addresses` (every name, address,
email and phone column) and `wp_wc_customer_lookup`.

Detect HPOS rather than assuming it:

```bash
bash -c "$WP option get woocommerce_custom_orders_table_enabled"
```

A store on HPOS keeps addresses in `wp_wc_order_addresses` and **not** in postmeta, so a run
that only rewrites postmeta on an HPOS store reports a full pass having changed nothing that
mattered. Check both, rewrite whichever exists, and report which one was found.

## Step 5: Replacement — deterministic, and into a reserved TLD

Each real value maps to a fake derived from the record's own id, so the same person is the
same fake everywhere they appear:

```
user 482        → customer482@example.invalid / "Customer 482"
comment 7719    → commenter7719@example.invalid
order 10043     → its customer's mapping, not a fresh one
```

**Deterministic, because a clone exists to reproduce a bug.** Random per-row values would
break every relationship the bug lives in — the same customer across three orders would
become three customers, and "this only happens for repeat buyers" stops being reproducible.

**`example.invalid`, because RFC 2606 reserves `.invalid` and it can never resolve.** Mail is
already captured by the isolation mu-plugin, but that is one layer, and the whole reason this
command exists is that a single layer is what the operator is relying on today. An address in
a reserved TLD cannot reach a real person even if the plugin is deleted, the site is moved,
or the database is imported somewhere with no isolation at all — which is exactly what
happens to a clone that gets handed on.

Addresses, phone numbers and postcodes take fixed placeholder values, not generated ones.
Plausible fake addresses invite someone to believe the data is still real enough to test
shipping rules against; an obvious placeholder does not.

**Preserve totals, dates, statuses and quantities.** They carry no identity and they are the
substance of what a store clone is for. An anonymiser that also flattens order values has
destroyed the thing it was protecting.

Under `--dry-run`, count the affected rows per table and print the report without executing a
single write.

## Step 6: Report every table that was not examined

```bash
bash -c "$WP db query 'SELECT table_name, table_rows FROM information_schema.tables WHERE table_schema = DATABASE()' --skip-column-names"
```

Subtract the catalog's tables. Everything remaining is listed by name with its row count,
under a heading that says what the list means:

```
Not examined — 14 tables, 41,209 rows:
  wp_postmeta (28,441)   wp_options (1,203)   wp_wc_download_log (72)
  wp_actionscheduler_actions (6,918)   wp_crm_contacts (411)   …
  → Anonymised means the catalog above, and nothing else. It does not mean this
    database is clean. A plugin storing customers in its own table is in this list.
```

**This block is not optional and is never collapsed.** It is the difference between a report
an operator can act on and a report that grants false confidence. The failure mode this whole
command guards against is someone reading "anonymised" and handing the database to a
contractor, and the only thing standing between those two events is this list being printed
in full, including on a run where everything succeeded.

Sort it by row count descending: the large unexamined table is the one worth a second look,
and a name buried alphabetically in the middle is a name nobody reads.

## Step 7: Verify, and fail loudly on residue

Re-query every catalog field for anything still carrying the source site's email domain or a
non-`.invalid` address:

```bash
bash -c "$WP db query \"SELECT COUNT(*) FROM wp_users WHERE user_email NOT LIKE '%@example.invalid'\" --skip-column-names"
```

Expect the preserved account and nothing else. Any other residue is a **failure**, reported
as one:

```
=== ANONYMISATION INCOMPLETE ===
  wp_users             3 rows still carry a real email address
  wp_wc_order_addresses  118 rows still carry a real email address

The catalog did not reach these. Do not treat this database as anonymised.
Restore from ~/.wp-clone-backups/<file> if you need the original.
```

Do **not** print the success summary in the same run. A command that reports success while
leaving customer records in place is the defect shape of every fix in v1.20.0 — a command
that completes, reports success, and ships something wrong — and it is worse here than
anywhere else, because the report is the only thing the operator will remember when they
decide who to send the database to.

## Step 8: Report

```
=== Anonymised ===
Backup            ~/.wp-clone-backups/client-demo-20260919T161145Z-pre-anonymize.sql
Users             903 anonymised, 1 preserved (admin "yojahny" — still a real address)
Comments          1,204 anonymised (author, email, url, IP)
Orders            1,284 addresses anonymised (HPOS: wp_wc_order_addresses)
Preserved         order totals, dates, statuses, quantities — no identity, and the
                  reason the clone exists

Not examined — 14 tables, 41,209 rows:
  wp_postmeta (28,441)   wp_options (1,203)   …
  → Anonymised means the catalog above, and nothing else.

Verification      0 rows carry a real email address outside the preserved account
```

Then, once — not as a warning buried in the block above:

```
This database is safer than it was. It is not certified clean, and nothing here can
certify it. What was examined is listed; what was not is listed too.
```
