#!/usr/bin/env bash
# /wp-seed declared `_<prefix>_seeded_content` "the marker every seeded record carries" and
# stated that re-running is safe -- while Phase 2 ran `wp post create`, Phase 3 ran
# `wp media import` and Phase 6 ran `wp menu create` unconditionally, with no lookup and no
# marker written. A second run produced a duplicate of every page, attachment and menu, and
# the command said that was fine. Six seed checks existed and none of them covered a re-run.
#
# What this pins is the shape of the fix, not its wording: each creating phase must resolve
# before it creates, the three-way rule must keep its untouchable middle row, and the marker
# must be written by the same command that creates the record.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

f=commands/wp-seed.md
[ -f "$f" ] || fail "$f is missing"

need() { grep -Fq "$1" "$f" || fail "$f $2"; }

# The shared rule, and the row that must not soften. An unmarked record is either the
# client's work or predates seeding; both are unrecoverable from the demo if overwritten.
need 'Resolve before you create' 'has no shared resolution rule for the writing phases'
need 'Leave it exactly as it is' 'does not say an unmarked record is left untouched'
need 'never create a second record beside it' \
  'does not forbid creating a duplicate beside a conflicting record -- the duplicate this rule exists to prevent, wearing a different hat'

# A create that succeeds while its marker does not leaves a record this project can never
# recognise again: the next run reads it as client-owned and can never touch it.
need 'Write the marker in the same command that creates the record' \
  'does not require the marker to be written atomically with the create'

# An unchanged re-run has to be observable, or "re-running is safe" stays a claim.
need 'Preview before writing' 'has no plan step before the writing phases'
need 'An unchanged re-run prints' 'does not say what an unchanged re-run looks like'

# Each phase names what it resolves records BY. These differ per phase for reasons the
# prose gives (a title is edited, a filename is rewritten on collision, a menu name is not
# unique), so a phase silently losing its key is a phase back to creating blind.
need 'Resolve by slug' 'Phase 2 does not resolve pages by slug'
need 'Resolve by source identity' 'Phase 3 does not resolve attachments by their source'
need 'Resolve by name' 'Phase 6 does not resolve menus by name'

# Reusing the page ID is the point of resolving at all: menu items, page_on_front and
# page_link fields already point at it.
need 'keeps its ID and is updated in place' \
  'does not say a resolved page keeps its ID -- re-creating it silently breaks every reference'

# wp menu create does not refuse a duplicate name, so this one cannot be inferred.
need 'never refuses a duplicate name' 'does not warn that wp menu create accepts a duplicate name'

# Menu items are the one record where update-in-place does not work, and the reason has to
# travel with the exception or it reads as an inconsistency and gets "fixed".
need 'emptied of its seeded items before this run adds its own' \
  'does not state how an existing menu is refilled'
need 'keep any the client added' 'does not preserve client-added menu items when refilling a menu'

# A conflict the operator never sees is a page that silently never gets seeded again.
need 'Left alone — the client owns these' 'the Seed Report does not report conflicts'

# The deliberate ceiling, stated where someone would otherwise read the dedup as complete.
need 'not by the bytes' 'does not state that media dedup is by source, not by content hash'

echo "PASS: every writing phase resolves before it creates, and the ownership rule holds"
