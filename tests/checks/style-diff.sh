#!/usr/bin/env bash
# A tag swap or a reset class added to an element (`.btn-reset { color: inherit; font: inherit }`)
# beat the utility classes already on it and turned a white 26px icon into a black 18px one. No
# value was edited, nothing else moved, and a screenshot diff could not see it. The procedure
# ("measure computed styles before and after") existed only as prose, so it was done on one
# hand-picked element or not at all. bin/style-diff.mjs measures every element; two untouched
# baselines are needed because carousels and sliders differ between any two loads.
# This check runs the tool on a file:// fixture, asserts it catches the regression and ignores
# the noise, and pins the docs that must point at it.
set -uo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
tool=bin/style-diff.mjs
[ -f "$tool" ] || fail "$tool is missing"

for f in skills/wp-audit-run/references/fix.md skills/wp-finalize-run/references/parity-visual.md; do
  grep -Fq 'bin/style-diff.mjs' "$f" || fail "$f does not point at $tool"
  grep -Fq -- '--noise' "$f" || fail "$f does not tell the reader to take two baselines (--noise)"
done
grep -Fq 'style-diff.mjs' README.md || fail "README bin table has no style-diff.mjs row"
ls changes/*style-diff*.added.md >/dev/null 2>&1 || fail "no changes/ fragment for the tool"

# Behavior needs a browser; without one, say so rather than pass silently.
core=${PLAYWRIGHT_CORE:-}
if [ -z "$core" ] || [ ! -d "$core" ]; then
  echo "SKIP: no PLAYWRIGHT_CORE, the fixture half of style-diff did not run"; echo "PASS (docs half)"; exit 0
fi
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
page() { # $1 = element markup
  cat > "$tmp/p.html" <<HTML
<!doctype html><title>t</title><style>.i{color:#fff;font-size:26px;background:#000}.r{color:inherit;font:inherit}.c{width:100px;background:red}</style>
<body>$1<div class="c" id="rnd"></div><script>document.getElementById('rnd').style.height=(20+Math.floor(Math.random()*40))+'px'</script>
HTML
}
snap() { node "$tool" snapshot --out "$tmp" --label "$1" --urls "file://$tmp/p.html" >/dev/null 2>&1 || fail "snapshot $1 failed"; }
page '<span class="i">x</span>'; snap b1; snap b2
page '<button class="i r">x</button>'; snap after
out=$(node "$tool" diff "$tmp/b1.json" "$tmp/after.json" --noise "$tmp/b1.json" "$tmp/b2.json"); rc=$?
[ "$rc" = 1 ] || fail "a tag swap that changed colour and size exited $rc, not 1"
printf '%s' "$out" | grep -Fq 'color: rgb(255, 255, 255) -> rgb(0, 0, 0)' || fail "the colour change was not reported"
printf '%s' "$out" | grep -Fq 'fontSize: 26px -> 16px' || fail "the font-size change was not reported"
printf '%s' "$out" | grep -Fq 'noisy, excluded' || fail "the random-height element was not set apart as noise"
printf '%s' "$out" | grep -Fq 'nth-child(2)' && printf '%s' "$out" | sed -n '/STYLE diffs/,/SIZE diffs/p' | grep -Fq 'nth-child(2)' \
  && fail "the noisy element was reported as a style diff"
# Same page against itself: clean, exit 0.
node "$tool" diff "$tmp/b1.json" "$tmp/b1.json" >/dev/null || fail "identical snapshots did not exit 0"
echo "PASS: style-diff reports a tag-swap regression, sets noise apart and exits 1/0"
