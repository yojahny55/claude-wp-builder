#!/usr/bin/env bash
# /wp-anonymize permanently rewrites user and customer records in a cloned database. It has
# no undo, and every property that makes it safe rather than merely useful is prose:
#
#   - it refuses to run on a site it cannot prove is a clone, with no override
#   - it backs up first, unconditionally
#   - it replaces into a reserved TLD, so a leaked clone still cannot reach anyone
#   - it names every table it did NOT examine
#   - residue after the run is a failure, not a footnote
#
# The last two are the ones that decay first, because both are extra output on a run that
# otherwise succeeded, and both are exactly what stands between "anonymised" and an operator
# handing a live customer database to a contractor. Delete either and the command still
# completes and still reports success.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

f=commands/wp-anonymize.md
[ -f "$f" ] || fail "$f is missing"
[ -r "$f" ] || fail "$f exists but cannot be read"

# Prose wraps, and grep -F matches within a line, so a needle spanning a line break misses
# silently and reports a present contract as absent. Flatten first.
flat=$(tr '\n' ' ' < "$f" | tr -s ' ')
# `--` terminates options: a needle starting with a dash is otherwise parsed by grep as one,
# which dies with a usage error instead of reporting a miss.
need() { printf '%s' "$flat" | grep -Fq -- "$1" || fail "$2"; }

cflat=$(tr '\n' ' ' < commands/wp-clone.md | tr -s ' ')
cneed() { printf '%s' "$cflat" | grep -Fq -- "$1" || fail "$2"; }

# ---------------------------------------------------------------------------
# 1. The gate. This is the only guard against the one catastrophic mistake, and it must
#    come before anything else and take no override.
# ---------------------------------------------------------------------------
need 'wp-content/mu-plugins/00-clone-isolation.php' \
  "the command does not key its clone check on the isolation mu-plugin, the only marker /wp-clone writes that survives a plugin being deactivated"
need 'Error: this does not look like a clone.' \
  "there is no refusal for a site that cannot be proved to be a clone"
need 'There is no `--force` past this gate, and adding one would be the defect.' \
  "the command does not rule out an override on the clone gate. Every other refusal here takes one, so a future author WILL add it unless the file says why this one is different"

# The asymmetry is the whole argument for a no-override gate, and an author who cannot see
# it written down reads the missing flag as an omission.
need 'the cost of the operator being wrong is a production site with its customers overwritten and no undo' \
  "the command does not state the asymmetry that justifies a gate with no override"

# ---------------------------------------------------------------------------
# 2. Backup. There is no undo; this is the only way back.
# ---------------------------------------------------------------------------
need '~/.wp-clone-backups' \
  "the command does not back up outside the project, where the next clone's rsync and an rm -rf of the project both reach"
need 'including the second and third time it is run on the same clone' \
  "the command does not require a backup on every run. A second run over an already-anonymised clone still destroys whatever the first one missed and then fixed by hand"
need 'an anonymisation that proceeds past a failed backup is a one-way door' \
  "the command does not stop when the backup export fails"

# ---------------------------------------------------------------------------
# 3. The preserved account. Anonymising every user locks the operator out; preserving one
#    silently overstates what the run accomplished.
# ---------------------------------------------------------------------------
need 'The preserved account is named in the report, every time.' \
  "the command does not require the preserved account to be reported. It still holds a real address, and a summary that omits it claims more than the run did"
need 'stop and say so rather than picking another' \
  "the command silently substitutes another account when --keep-user does not resolve, which is how an operator is locked out of a clone whose backup they have not yet needed"

# ---------------------------------------------------------------------------
# 4. Determinism and the reserved TLD. A clone exists to reproduce a bug; random per-row
#    values destroy the relationships the bug lives in. And a clone gets handed on, so the
#    replacement has to be unreachable even with no isolation at all.
# ---------------------------------------------------------------------------
need 'example.invalid' \
  "replacements do not land in a reserved TLD. A clone that is moved, or whose isolation plugin is deleted, can then still send mail to real customers"
need 'RFC 2606 reserves `.invalid`' \
  "the command does not say why the TLD is reserved, so a later edit swaps in a domain that looks tidier and can resolve"
need 'the same customer across three orders would become three customers' \
  "the command does not justify deterministic replacement, and random values are the obvious implementation for someone who has not thought about why the clone exists"
need 'Preserve totals, dates, statuses and quantities.' \
  "the command does not preserve the non-identifying order data that is the entire reason a store clone exists"

# ---------------------------------------------------------------------------
# 5. HPOS. A store on HPOS keeps addresses out of postmeta entirely, so a postmeta-only run
#    reports a full pass having changed nothing that mattered -- a silent, total failure.
# ---------------------------------------------------------------------------
need 'woocommerce_custom_orders_table_enabled' \
  "the command does not detect HPOS, so on an HPOS store it rewrites postmeta that holds no addresses and reports success"
need 'reports a full pass having changed nothing that mattered' \
  "the command does not state the HPOS failure mode, which is silent and total rather than partial"

# ---------------------------------------------------------------------------
# 6. The not-examined list. The feature. An explicit catalog is only honest if what it
#    excludes is printed.
# ---------------------------------------------------------------------------
need 'Not examined' \
  "the command does not report the tables it did not examine, which turns an explicit catalog back into a claim about the whole database"
need 'This block is not optional and is never collapsed.' \
  "the not-examined list may be omitted or summarised. It is the only thing between a green report and someone handing a live customer database to a contractor"
need 'It does not mean this database is clean.' \
  "the report does not disclaim what anonymised means"
need 'A plugin storing customers in its own table is in this list.' \
  "the not-examined list does not name the case that actually bites -- a third-party table the catalog cannot know about"

# ---------------------------------------------------------------------------
# 7. Residue. A command that reports success while leaving customer records in place is the
#    exact defect this plugin spent a release removing.
# ---------------------------------------------------------------------------
need 'ANONYMISATION INCOMPLETE' \
  "there is no failure report for residue left behind after the run"
need 'Do **not** print the success summary in the same run.' \
  "residue can be reported alongside a success summary, and the summary is what the operator remembers when they decide who to send the database to"
need 'Do not treat this database as anonymised.' \
  "the residue report does not tell the operator what to conclude from it"

# ---------------------------------------------------------------------------
# 8. The dry run. Anyone running this for the first time on a real clone needs a way to see
#    what it would touch before it touches it.
# ---------------------------------------------------------------------------
need '**`--dry-run`**' \
  "the command has no dry run, so the first way to learn what it changes is to have changed it"
need 'without executing a single write' \
  "the dry run is not stated to be read-only"

# ---------------------------------------------------------------------------
# 9. /wp-clone has to point at it. The operator learns a database holds real customers at
#    the end of a clone; that is the moment the pointer is worth anything, and it is the
#    only moment they are looking.
# ---------------------------------------------------------------------------
cneed '/wp-anonymize' \
  "/wp-clone never mentions /wp-anonymize. Its report is where an operator is told the database holds real customer records, and a remedy named anywhere else is one they will not find"

echo "PASS: /wp-anonymize gate, backup, reserved-TLD replacement, not-examined list and residue failure are all pinned"
