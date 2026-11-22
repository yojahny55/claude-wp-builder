#!/usr/bin/env bash
# tests/mutation.sh is a tool, and a tool that always says "killed" is worse than none. Run
# it on a throwaway repo with one check that detects the deleted token and one weak check that
# does not (its token is on a second line too), and assert 1 killed, 1 survived, exit 1 and
# an untouched tree. Independent of the real checks, so editing them cannot break this.
set -euo pipefail
here=$(cd "$(dirname "$0")/../.." && pwd)
fail() { echo "FAIL: $*"; exit 1; }
fx=$(mktemp -d)
trap 'rm -rf "$fx"' EXIT
cd "$fx"
git init -q .
mkdir -p commands tests/checks
printf 'intro\nstrong-token here\n' > commands/a.md
printf 'intro\nweak-token here\nweak-token again\n' > commands/b.md
for spec in strong:a:strong-token weak:b:weak-token; do
  IFS=: read -r name f tok <<<"$spec"
  cat > "tests/checks/$name.sh" <<EOF
#!/usr/bin/env bash
set -euo pipefail
cd "\$(dirname "\$0")/../.."
need() { grep -Fq -- "\$2" "\$1" || { echo "FAIL: \$1 lacks \$2"; exit 1; }; }
need commands/$f.md "$tok"
echo PASS
EOF
done
git add -A && git -c user.email=t@t -c user.name=t commit -qm fixture
before=$(git status --porcelain=v1 -uall; sha256sum commands/*.md tests/checks/*.sh)

rc=0
out=$(bash "$here/tests/mutation.sh" -r "$fx" -c "strong.sh weak.sh" 2>&1) || rc=$?
[ "$rc" -eq 1 ] || fail "expected exit 1 (one survivor), got $rc:
$out"
grep -F 'mutants: 1 killed, 1 survived' <<<"$out" >/dev/null || fail "unexpected summary:
$out"
grep -E '^killed +strong.sh' <<<"$out" >/dev/null || fail "strong check not reported killed:
$out"
grep -E '^SURVIVED +weak.sh' <<<"$out" >/dev/null || fail "weak check not reported as survivor:
$out"
after=$(git status --porcelain=v1 -uall; sha256sum commands/*.md tests/checks/*.sh)
[ "$before" = "$after" ] || fail "mutation.sh changed the target tree"

# A check that fails unmutated must be skipped, not counted as killed.
cat > tests/checks/broken.sh <<'EOF'
#!/usr/bin/env bash
need() { grep -Fq -- "$2" "$1" || exit 1; }
need commands/a.md "strong-token"
exit 1
EOF
rc=0
out=$(bash "$here/tests/mutation.sh" -r "$fx" -c "broken.sh" 2>&1) || rc=$?
grep -F 'broken.sh (fails unmutated' <<<"$out" >/dev/null || fail "unmutated failure not skipped:
$out"
grep -F '0 killed' <<<"$out" >/dev/null || fail "a broken check was counted as killed:
$out"
echo PASS
