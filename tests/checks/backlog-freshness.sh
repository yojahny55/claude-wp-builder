#!/usr/bin/env bash
# BACKLOG.md must have been reconciled at least as recently as the newest release.
#
# #80 reconciled all forty items by hand against main. It went stale in a single day:
# three releases then shipped a clone anonymiser, resumable builds, a findings ledger, ACF
# nesting and a WordPress fixture, and not one of them appeared in the backlog. The file
# said 20 delivered when the number was 26.
#
# Nothing caught that, because nothing could: a backlog is prose about other prose, and
# every check here asserts a contract inside one file. The one mechanical fact available
# is a date -- the newest `## [x.y.z] - YYYY-MM-DD` heading in CHANGELOG.md against the
# `**Reconciled** on <date>` line in BACKLOG.md. If a release is newer than the last
# reconciliation, the backlog describes a version that no longer exists.
#
# What this cannot do is tell whether the reconciliation was any good. It checks that one
# happened. That is a much weaker claim than "the backlog is accurate", and the whole
# reason it is worth having: the failure mode was never a careless reconciliation, it was
# nobody remembering to do one.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

b=BACKLOG.md
c=CHANGELOG.md
for f in "$b" "$c"; do
  [ -f "$f" ] || fail "$f is missing"
  [ -r "$f" ] || fail "$f exists but cannot be read"
done

# `## [Unreleased]` carries no version number and is skipped by the pattern, which is what
# makes this a release-time gate rather than a commit-time one.
#
# The NEWEST version heading, whether or not it carries a date -- then require that it
# does. Searching straight for a dated heading would skip an undated newest release and
# silently judge the backlog against an older one, which passes while the backlog is stale
# relative to the release that actually shipped. Found by mutation: deleting the date from
# the top heading left this green.
newest=$(grep -m1 -E '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' "$c" || true)
[ -n "$newest" ] \
  || fail "$c has no release heading -- the freshness of $b cannot be judged against it"

release_line=$(printf '%s' "$newest" | grep -E '^## \[[0-9]+\.[0-9]+\.[0-9]+\] - [0-9]{4}-[0-9]{2}-[0-9]{2}$' || true)
[ -n "$release_line" ] \
  || fail "$c's newest release heading carries no date: $newest
  Every release heading is '## [x.y.z] - YYYY-MM-DD'. Without the date there is nothing to
  judge $b against, and skipping to the release below would compare it to the wrong one."

release_date=${release_line##*- }
release_version=$(printf '%s' "$release_line" | sed -E 's/^## \[([0-9.]+)\].*/\1/')

# `**Reconciled** on September 19, 2026 against ...` -- written for a reader, so it is
# parsed rather than reformatted into something a reader would not write.
recon_line=$(grep -m1 -E '^\*\*Reconciled\*\* on ' "$b" || true)
[ -n "$recon_line" ] \
  || fail "$b has no '**Reconciled** on <date>' line, so nothing records when it was last checked against main"

recon_human=$(printf '%s' "$recon_line" | sed -E 's/^\*\*Reconciled\*\* on ([A-Z][a-z]+ [0-9]{1,2}, [0-9]{4}).*/\1/')
[ "$recon_human" != "$recon_line" ] \
  || fail "$b's Reconciled line does not carry a '<Month> <D>, <YYYY>' date: $recon_line"

# `date -d` parses "September 19, 2026" on GNU date, which is what CI and every developer
# machine here runs. A platform without it should say so rather than silently pass.
recon_date=$(date -d "$recon_human" +%Y-%m-%d 2>/dev/null || true)
[ -n "$recon_date" ] \
  || fail "could not parse '$recon_human' as a date (GNU date required)"

if [ "$recon_date" \< "$release_date" ]; then
  fail "$b was last reconciled $recon_date, but $release_version shipped $release_date.
  The backlog describes a version that is no longer the newest one. Reconcile it against
  main and update the '**Reconciled** on' line -- a backlog that claims an item is open
  while the behaviour ships reads as a project that does not know what it has built."
fi

echo "PASS: $b reconciled $recon_date, newest release $release_version on $release_date"
