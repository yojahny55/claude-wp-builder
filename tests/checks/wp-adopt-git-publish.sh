#!/usr/bin/env bash
# /wp-adopt opt-in git publish: a hand-built publish of a real store copied wp-config.php into the
# working copy because an rsync --include preceded --exclude (rsync filters are first-match), and
# line-ending churn hit hundreds of files without `* -text`. The step must stay opt-in, keep the
# wp-config guard and the exclude-first rule, and must not tell the model to edit the site's .gitignore.
set -euo pipefail
cd "$(dirname "$0")/../.."
f=commands/wp-adopt.md
fail() { echo "FAIL: $*"; exit 1; }
for t in '## Step 6 (opt-in): Publish to a git remote' 'git ls-remote' 'first match wins' \
  "git ls-files | grep -E '(^|/)wp-config'" "--exclude='/wp-config*'" 'DB_PASSWORD|DB_USER'  '* -text' '/wp-content/*' 'git_publish' 'pre-receive' \
  '.codebase-memory' 'Secret scan' 'Default **no**' 'Do not edit `.gitignore` yourself'; do
  grep -Fq -- "$t" "$f" || fail "$f lost: $t"
done
grep -Fq 'git_publish' docs/commands.md || fail "docs/commands.md does not document git_publish"
! grep -Eq 'echo .*>> *\.gitignore|edit the site.s \.gitignore' "$f" || fail "step tells the model to edit the site .gitignore"
grep -Fq 'publishes an adopted site to a git remote' CHANGELOG.md || fail "changelog entry missing"
echo PASS
