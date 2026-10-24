#!/usr/bin/env bash
# Fixed /tmp paths in snippets and scripts: two audits (or two sessions) on the same machine
# write the same /tmp/emitted, /tmp/site-text.txt or /tmp/geo-home.html, and one site's
# content ends up compared against another's with no error to say so. Snippets and scripts
# create their own directory with mktemp -d instead.
#
# Allowed literal /tmp/ mentions, by file, and why:
#   bin/wp-env-setup.sh                                     /tmp/x.conf is the input contract of vhost-install
#   skills/wp-create-run/references/env-templates.md        same contract, from the caller's side
#   skills/wp-environments/SKILL.md                         same contract, in the subcommand table
#   skills/wp-clone-run/references/verify.md                names a user-supplied dump path
#   skills/wp-audit-seo-standards/references/woocommerce-seo.md   explains why /tmp is not used
#   commands/wp-clone.md                                    example paths for user-supplied --sql/--uploads
set -uo pipefail
fail() { echo "FAIL: $1"; exit 1; }
cd "$(dirname "$0")/../.." || fail "cannot cd to the repository root"

allowed='^(bin/wp-env-setup\.sh|skills/wp-create-run/references/env-templates\.md|skills/wp-environments/SKILL\.md|skills/wp-clone-run/references/verify\.md|skills/wp-audit-seo-standards/references/woocommerce-seo\.md|commands/wp-clone\.md):'

hits=$(grep -rnI '/tmp/' agents skills commands bin | grep -Ev "$allowed") || true
[ -z "$hits" ] || fail "fixed /tmp/ path (use T=\$(mktemp -d); trap 'rm -rf \"\$T\"' EXIT):
$hits"

# The replacement must still be there where it was applied.
grep -Fq 'mktemp -d' agents/wp-audit-practices.md || fail "wp-audit-practices.md lost its mktemp -d"
grep -Fq 'mktemp -d' bin/wp-cinematic-encode.sh || fail "wp-cinematic-encode.sh lost its mktemp -d"
echo "PASS: no fixed /tmp paths"
