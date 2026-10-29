#!/usr/bin/env bash
# /wp-adopt in-place git init: a hand-made init of a whole site root pushed a second branch nobody
# asked for. Behavior check in a temp dir: the .gitignore content, refusal on an existing repo,
# the secret guard, and that only the named branch reaches a bare remote.
set -euo pipefail
cd "$(dirname "$0")/../.."
root=$PWD
fail() { echo "FAIL: $*"; exit 1; }
need() { grep -Fq -- "$2" "$1" || fail "$1 lacks: $2"; }
need commands/wp-adopt.md 'Step 6b (opt-in)'
need commands/wp-adopt.md 'never created or pushed implicitly'
need commands/wp-adopt.md 'git-init'
need docs/commands.md 'git-init'
need templates/git/wordpress.gitignore 'wp-config*'

t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
wp() { node "$root/bin/wp-config.mjs" git-init "$t/site" "$@"; }
mkdir -p "$t/site/wp-content/"{uploads,cache,themes/x,ai1wm-backups} "$t/site/wp-admin"
echo '<?php' > "$t/site/index.php"; echo '<?php' > "$t/site/wp-config.php"; echo x > "$t/site/wp-content/uploads/a.jpg"
echo x > "$t/site/wp-content/themes/x/style.css"; echo x > "$t/site/.htaccess"; echo x > "$t/site/db.sql"
printf '/vendor/\n*.log\n' > "$t/site/.gitignore"
git init -q --bare "$t/remote.git"

wp --branch=dev --remote="$t/remote.git" --dry-run > "$t/dry.txt"
[ ! -e "$t/site/.git" ] || fail "dry run created .git"
[ "$(cat "$t/site/.gitignore")" = "$(printf '/vendor/\n*.log')" ] || fail "dry run edited .gitignore"

wp --branch=dev --remote="$t/remote.git" > "$t/init.txt"
ig="$t/site/.gitignore"
for r in '/vendor/' 'wp-config*' '.htaccess' '/wp-content/uploads/' '/wp-content/cache/' '/wp-content/ai1wm-backups/' '/wp-content/maintenance/' '*.sql' '*.sql.gz' '*.zip' '.wp-audit/' '.wp-create.local.json'; do
  [ "$(grep -Fxc -- "$r" "$ig")" = 1 ] || fail ".gitignore does not hold exactly one: $r"
done
[ "$(grep -Fxc -- '*.log' "$ig")" = 1 ] || fail "*.log duplicated"
grep -q 'files would be committed' "$t/init.txt" || fail "no summary"
git -C "$t/site" ls-files | grep -q . && fail "init staged files"
[ "$(git -C "$t/site" symbolic-ref --short HEAD)" = dev ] || fail "branch is not dev"

if wp --branch=dev --remote="$t/remote.git" 2>/dev/null; then fail "second init on a repo was not refused"; fi
mkdir "$t/site/sub"; if node bin/wp-config.mjs git-init "$t/site/sub" --branch=dev --remote="$t/remote.git" 2>/dev/null; then fail "init inside a repo was not refused"; fi

# secret guard: a wp-config backup that slipped past the ignore stops the commit
echo x > "$t/site/wp-content/wp-config-old.php"
sed -i '/wp-config/d' "$ig"
if wp --branch=dev --remote="$t/remote.git" --commit 2>/dev/null; then fail "commit with a secret-looking file was not refused"; fi
git -C "$t/site" rev-parse HEAD >/dev/null 2>&1 && fail "a commit exists after refusal"
echo 'wp-config*' >> "$ig"
# non-ASCII path with a key, and a nested repository, must stop the commit too
mkdir -p "$t/site/wp-content/año"; echo x > "$t/site/wp-content/año/server.key"
if wp --branch=dev --remote="$t/remote.git" --commit 2>/dev/null; then fail "non-ASCII secret was committed"; fi
rm -r "$t/site/wp-content/año"
mkdir -p "$t/site/wp-content/plugins/nested"; git init -q "$t/site/wp-content/plugins/nested"
git -C "$t/site/wp-content/plugins/nested" commit -q --allow-empty -m x
if wp --branch=dev --remote="$t/remote.git" --commit 2>/dev/null; then fail "nested repo was committed as a gitlink"; fi
rm -rf "$t/site/wp-content/plugins/nested"
# bad flags and a mismatched origin
if wp --branch=-x --remote=a 2>/dev/null; then fail "--branch=-x accepted"; fi
if wp --branch=dev --remote=-u 2>/dev/null; then fail "--remote=-u accepted"; fi
if wp --branch=dev --remote=other --commit 2>/dev/null; then fail "commit with a different origin accepted"; fi

wp --branch=dev --remote="$t/remote.git" --commit >/dev/null
git -C "$t/site" ls-files | grep -q wp-config && fail "wp-config was committed"
git -C "$t/site" branch --list master | grep -q . && fail "a second branch exists locally"
if wp --branch=dev --remote="$t/remote.git" --push 2>/dev/null; then fail "push without --yes was not refused"; fi
[ -z "$(git -C "$t/remote.git" branch --list)" ] || fail "remote got a branch before --yes"
git -C "$t/site" branch master
if wp --branch=dev --remote="$t/remote.git" --commit 2>/dev/null; then fail "second commit phase accepted"; fi
wp --branch=dev --remote="$t/remote.git" --push --yes >/dev/null
[ "$(git -C "$t/remote.git" branch --format='%(refname:short)')" = dev ] || fail "remote holds more than dev"
echo PASS
