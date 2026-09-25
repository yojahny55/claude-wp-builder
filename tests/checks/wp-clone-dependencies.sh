#!/usr/bin/env bash
# /wp-clone transfers the database and wp-content/uploads/ and nothing else -- no plugin
# files, no theme files. The imported database names the source site's active plugins and
# its active theme, none of which are on disk unless /wp-create's profile happened to
# install the same ones, so WordPress deactivates each missing plugin on load and falls back
# off the missing theme. Steps 6.4 and 6.5 noticed afterwards and "warned the user": a
# warning with nothing actionable attached, issued after the site was already broken.
#
# The inventory fixes that by asking the SOURCE while the SSH session is still open, and by
# splitting the answer into groups that differ in what the operator can actually do. This
# pins the split, the timing, and the refusal to guess.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

f=commands/wp-clone.md
[ -f "$f" ] || fail "$f is missing"
# `--` before the pattern: two needles here start with a dash (`--version=`,
# `-dependencies.md`) and grep parses those as options otherwise, failing with a usage
# error rather than reporting a miss -- a check that errors instead of asserting.
need() { grep -Fq -- "$1" "$f" || fail "$f $2"; }

need 'A3.5: Inventory Remote Dependencies' 'Path A has no dependency inventory'
need 'B3.5: Inventory Dependencies' 'Path B has no dependency inventory'

# The premise. If the prose stops saying what is NOT transferred, every downstream statement
# reads as a precaution rather than as the consequence it is.
need 'does not transfer plugins' 'does not state that plugin and theme files are never transferred'

# Timing. The inventory has to be taken while the source is reachable; afterwards the local
# database knows names and nothing else. Asserted by position, not just by wording.
inv=$(grep -n '^### A3.5: Inventory Remote Dependencies' "$f" | head -1 | cut -d: -f1 || true)
exp=$(grep -n '^### A4: Export Remote Database' "$f" | head -1 | cut -d: -f1 || true)
ups=$(grep -n '^### A7: Rsync Uploads' "$f" | head -1 | cut -d: -f1 || true)
[ -n "$inv" ] || fail "$f no longer declares A3.5 as a heading"
[ -n "$exp" ] || fail "$f no longer declares A4 as a heading"
[ -n "$ups" ] || fail "$f no longer declares A7 as a heading"
[ "$inv" -lt "$exp" ] && [ "$inv" -lt "$ups" ] \
  || fail "$f takes the inventory at line $inv, after the export ($exp) or the uploads sync ($ups) -- it must run while the SSH session is open and before the long transfers"
need 'while the SSH session is open' 'does not say why the inventory is taken during the SSH session'

# The three-way split, and the refusal to collapse it. Two groups would be a list; three is
# a decision, because the middle group is the one nothing local can fix.
need 'on WP.org — **recoverable**' 'does not mark WP.org plugins as recoverable'
need 'the clone is **incomplete** until someone supplies the files' \
  'does not say that a non-WP.org plugin leaves the clone incomplete'
need 'Never guess the third row' \
  'does not forbid guessing an unclassified plugin into one of the answerable groups'
need 'Unknown is a real answer' 'does not treat a failed classification as its own outcome'
need 'installs a *different* plugin which happens to share a slug' \
  'does not say what a wrong classification costs -- without it the guard reads as pedantry'

# The recoverable group is only useful if it carries the command AND the version. A bare
# name is a search; a pinned command is an action.
need '--version=' 'does not pin the recoverable install commands to the source versions'

# Silence for what is already installed, or the actionable part is buried.
need 'Already present locally' 'does not stay silent about plugins already installed'

# Persisted. The operator works through this list after the clone, once the site is up and
# visibly missing things -- by then the terminal has scrolled.
need '-dependencies.md' 'does not write the inventory to a file'
need 'only in the terminal is one the operator cannot act on tomorrow' \
  'does not say why the inventory is persisted'
# Needle within one line: the sentence wraps, and grep -F matches within a line.
need 'nothing generated here should end up' \
  'does not say why the inventory lives outside the project'

# Path B is weaker and must say so rather than presenting parity.
need 'Say that this list is weaker, and why' \
  'lets Path B present a database-derived inventory as equivalent to asking the source'

# 6.5 must reconcile, not re-report. A second undifferentiated warning reads as a new problem.
need 'Reconcile this list against the dependency inventory' \
  'lets Step 6.5 re-report missing plugins as a fresh discovery instead of reconciling with the inventory'
need 'Dependencies:' 'the clone summary does not carry the dependency counts'

# --- A plugin this repository ships is neither WordPress.org's nor the client's to supply. ---
need 'Bundled plugins first' 'does not check for a bundled plugin before asking WordPress.org'
need 'reinstall with `/wp-woo-setup`' 'does not tell the operator how a bundled plugin comes back'
b=$(grep -n 'Bundled plugins first' "$f" | head -1 | cut -d: -f1)
o=$(grep -n 'api.wordpress.org/plugins/info' "$f" | head -1 | cut -d: -f1)
[ -n "$b" ] && [ -n "$o" ] && [ "$b" -lt "$o" ] \
  || fail "$f asks WordPress.org before checking for a bundled plugin, so store-kit would read as unobtainable"

echo "PASS: dependencies are inventoried from the source, split three ways, and persisted"
