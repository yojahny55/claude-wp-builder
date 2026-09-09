#!/usr/bin/env bash
# Compositions are the craft skill's positive examples: what a good section looks
# like, rendered. Each one must be convertible (delimiters, data-motion contract,
# tokens only) and honest about where its effect came from.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

r=bin/composition-preview.mjs
[ -f "$r" ] || fail "$r is missing"
[ -x "$r" ] || fail "$r is not executable"
node --check "$r" || fail "$r is not valid JavaScript"
grep -Fq '_preview.md' "$r" || fail "$r does not render against _preview.md"
grep -Fq 'preview-1440.png' "$r" || fail "$r does not write preview-1440.png"
grep -Fq 'preview-390.png' "$r" || fail "$r does not write preview-390.png"
grep -Fq 'motion.js' "$r" || fail "$r does not load the plugin's motion engine"
grep -Fq 'process.exit(2)' "$r" || fail "$r does not exit 2 with no browser"

c=skills/wp-demo-craft/compositions
[ -f "$c/README.md" ] || fail "$c/README.md (the role table) is missing"
grep -Eq '^\| role \| composition \| motion cost' "$c/README.md" || fail "$c/README.md has no role table"
n=0
for d in "$c"/*/; do
  name=$(basename "$d")
  for f in section.html section.css README.md preview-1440.png preview-390.png; do
    [ -f "$d/$f" ] || fail "$name is missing $f"
  done
  n=$((n+1))
  grep -Fq '<!-- ============ SECTION:' "$d/section.html" || fail "$name/section.html has no section delimiter"
  grep -Fq '<!-- ============ END SECTION:' "$d/section.html" || fail "$name/section.html has no end delimiter"
  grep -Eq "class=\"$name" "$d/section.html" || fail "$name/section.html block is not scoped under .$name"
  grep -Eq '#[0-9a-fA-F]{3,8}\b' "$d/section.css" && fail "$name/section.css has a hex literal; tokens only"
  grep -Fq 'style="' "$d/section.html" && fail "$name/section.html has an inline style attribute; all styling lives in section.css"
  grep -Fq 'transition: all' "$d/section.css" && fail "$name/section.css uses transition: all"
  grep -Fq '—' "$d/section.html" && fail "$name/section.html has an em dash in visible copy"
  grep -Fq '<script' "$d/section.html" && fail "$name/section.html has a script tag; motion is data-motion only"
  # ease-in as a complete keyword only. taste.md bans ease-in on UI because it
  # delays the moment the eye is already on. The trailing guard is there because
  # '-' is a word boundary, so a bare \bease-in\b also matches inside the
  # different keyword ease-in-out and would fail a file that never used ease-in.
  grep -Eq '\bease-in\b($|[^-])' "$d/section.css" && fail "$name/section.css uses ease-in; never ease-in on UI"
  # Every img declares its box, or the page reflows when the photograph lands.
  while IFS= read -r img; do
    [[ "$img" == *width=* && "$img" == *height=* ]] \
      || fail "$name/section.html has an img without both width and height: $img"
  done < <(tr '<' '\n' < "$d/section.html" | grep '^img ' || true)
  # Every device is one devices.md actually defines; a typo is a silent no-op.
  while IFS= read -r kind; do
    case "$kind" in
      reveal|pin|pan|wipe|kinetic|parallax|drift|tilt|magnet|spotlight) ;;
      *) fail "$name/section.html uses data-motion=\"$kind\", which devices.md does not define" ;;
    esac
  done < <(grep -o 'data-motion="[a-z]*"' "$d/section.html" | cut -d'"' -f2 | sort -u)
  grep -Fq '{{' "$d/section.html" || fail "$name/section.html has no {{slot}} markers"
  grep -Eqi '^\*\*Port of:\*\*' "$d/README.md" || fail "$name/README.md does not state what it ports (or 'none')"
  grep -Eqi '^\*\*Licence:\*\*' "$d/README.md" || fail "$name/README.md does not state the origin licence"
  grep -Eqi '^\*\*Motion cost:\*\*' "$d/README.md" || fail "$name/README.md does not state its motion cost"
  grep -Fq "| $name |" "$c/README.md" || fail "$c/README.md role table has no row for $name"
  # A composition that hides its own copy before scroll fails the first-paint rule.
  grep -Eq 'data-motion="kinetic"' "$d/section.html" && [[ "$name" == hero-* || "$name" == page-head ]] \
    && fail "$name uses kinetic on a first-viewport composition; heroes use reveal"
done
[ "$n" -ge 13 ] || fail "expected at least 13 compositions, found $n"
# The regenerate command the library documents overwrites the previews in place, so
# the copy that made them has to be committed beside them.
[ -f "$c/fills.json" ] || fail "$c/fills.json (the preview copy) is missing"
node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$c/fills.json" \
  || fail "$c/fills.json is not valid JSON"
grep -Fq -- '--fill' "$r" || fail "$r has no --fill flag to apply $c/fills.json"
grep -Fq -- '--fill' "$c/README.md" || fail "$c/README.md documents a regenerate command that ignores fills.json"
# Interior page head never pins.
grep -Eq 'data-motion="pin"' "$c/page-head/section.html" && fail "page-head pins; interior pages have no pin"

echo PASS
