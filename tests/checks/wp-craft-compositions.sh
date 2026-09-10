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
# The CSS half of reveal lives in utilities/motion.css; motion.js yields that device
# to it wherever the browser supports scroll-driven animation (ten of the thirteen
# compositions use data-motion="reveal"), so a preview inlining motion.js without it
# renders reveal driven by neither engine. Anchored on the quoted path, not the bare
# substring 'motion.css' — that also appears unquoted in this file's own comment,
# which would still match after the real readFileSync call was deleted.
grep -Fq "utilities/motion.css'" "$r" \
  || fail "$r does not read utilities/motion.css, the CSS half of the reveal device"
# And it has to land inside the <style> block, not just be read and discarded.
grep -Fq '${motionCss}' "$r" \
  || fail "$r reads utilities/motion.css but never inlines it into the page's <style> block"
grep -Fq 'process.exit(2)' "$r" || fail "$r does not exit 2 with no browser"
# --container-max is used by all thirteen compositions. A var() the :root never
# defines is invalid at computed-value time, so padding-inline does not fall back
# to the shorthand beside it — it unsets, and every preview renders edge to edge.
# Anchored on the declaration inside :root, not the bare token name, which also
# appears in this file's own comment and in the _preview.md prose.
grep -Fq -- '--container-max:${t.container}' "$r" \
  || fail "$r does not write --container-max into the preview :root, so every composition's padding-inline is invalid and collapses to zero"
# Emitting the property is not the contract; emitting a LENGTH is. Delete the
# reader and keep the emission and the :root gains --container-max:undefined,
# which is invalid in calc() exactly like the missing token was — all 26 previews
# re-render edge to edge and the two greps above stay green. The other half of
# this pair (the front-matter value is a length) is in wp-craft-design-md.sh.
grep -Fq -- "container: p('spacing.container'" "$r" \
  || fail "$r no longer reads the content width out of _preview.md, so it emits --container-max:undefined"
# And the assertion that outlives all of them: the emitted :root itself. Every
# grep above reads source text, and source text has four recorded bypasses —
# comment the line out, rename the key, reassign after the read, add a duplicate
# key later in the object. `--tokens` prints the exact string the page embeds
# (one function builds both), needs no browser, and none of the four survives it.
# Its ceiling: it observes what previewTokens() and rootBlock() produce, not a
# later mutation of the token object at the render call site — the flag has
# already exited by then, and seeing that would take the render itself.
tokens="$(node "$r" --tokens)" \
  || fail "$r --tokens does not print the preview :root, so the emitted tokens cannot be asserted at all"
echo "$tokens" | grep -Eq -- '--container-max:[^;}]*[0-9](px|rem|em|ch|vw|vmin|%)' \
  || fail "$r emits a --container-max that is not a CSS length: $(echo "$tokens" | tr '\n' ' ')"

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
  # A composition is a section dropped into an arbitrary page context, so its
  # breakpoints key on its own container and never on the screen. Every root
  # declares the containment context, including the ones with no size query, so
  # all thirteen behave the same way in a narrow column. @media stays only for
  # (hover:hover)/(pointer:fine) and (prefers-reduced-motion) — user and device
  # conditions a container query cannot express.
  # Anchored to the root block (.$name { ... }), not the bare substring — moving
  # the declaration onto __inner, the exact mistake this task is about, would
  # still contain the substring but no longer sit inside the root's own braces.
  grep -Fq 'container-type: inline-size' <(sed -n "/^\.$name {\$/,/^}\$/p" "$d/section.css") \
    || fail "$name/section.css does not declare container-type: inline-size on its root selector (.$name), so it sizes to the viewport"
  # Catches every size-based form, not just the bare "@media (min-width"/"(max-width"
  # this used to require: "@media screen and (min-width…)", "@media only screen
  # and …", and range syntax "@media (width >= 900px)" all contain the word
  # "width" between @media and the block's opening brace, same as the plain form.
  # Neither protected query — (hover: hover) and (pointer: fine), prefers-reduced-motion —
  # contains "width", so both keep passing.
  grep -Eq '@media[^{]*\bwidth\b' "$d/section.css" \
    && fail "$name/section.css still uses a size-based media query; a section sizes to its container, not the screen"
  # The two checks above prove "no viewport query" but not "the breakpoint
  # survived" — deleting an @container block outright satisfies both. These nine
  # compositions carried a size breakpoint before the conversion; each must
  # still carry at least one.
  case "$name" in
    faq-list|feature-zigzag|footer-columns|footer-line|hero-split|hero-type|offer-table|proof-row|testimonial-pair)
      grep -Fq '@container' "$d/section.css" \
        || fail "$name/section.css lost its @container breakpoint; the conversion must keep it, not delete it" ;;
  esac
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

# Without a content-width token every composition pads by the gutter alone, so on
# a wide monitor content spans edge to edge. The token has to exist and the
# compositions have to use it; either alone is half a fix.
# In the token LIST, which is what a build generates :root from — pinned to the
# neighbour it is listed beside, not to `--container-max` alone with a trailing
# comma. The bare-name form is satisfied by any other paragraph in the file that
# happens to punctuate the token the same way, including the explanatory one this
# task added directly beneath the list; the two-token form is not.
grep -Fq -- '`--space-gutter`, `--container-max`,' skills/wp-demo-craft/references/design-md.md \
  || fail "design-md.md does not list --container-max in the token mapping, so a craft build has no content width to set"
# And the token needs a source. An undefined var() makes padding-inline invalid at
# computed-value time — it unsets rather than degrading — so a build that cannot
# find a container value anywhere has to be told what to write.
grep -Fq -- 'write `1280px`' skills/wp-demo-craft/references/design-md.md \
  || fail "design-md.md does not name the default content width, so a build with no client or catalogue value writes nothing"

# The per-composition half. Three failures this has to catch, each of which passed
# an earlier form of it:
#   - the declaration parked in a /* comment */, which constrains nothing;
#   - the declaration moved off the rule that carries the inline gutter onto a
#     leaf element, which proves the token appears in the file and nothing more;
#   - the var() with no fallback, which is the zero-padding-everywhere failure.
# So: strip comments, extract the ONE rule that legitimately owns the gutter, and
# require the fallback form inside it.
strip_comments() { perl -0pe 's{/\*.*?\*/}{}gs' "$1"; }
n=0
for f in skills/wp-demo-craft/compositions/*/section.css; do
  name=$(basename "$(dirname "$f")")
  # hero-split and hero-type put no padding on the root at all (it is a bare
  # grid holding 100dvh); process-rail's gutter lives on the rail because travel
  # is `rail.scrollWidth - frame.clientWidth`. The other ten carry it on the root.
  case "$name" in
    hero-split|hero-type) sel="$name"__inner ;;
    process-rail)         sel="$name"__rail ;;
    *)                    sel="$name" ;;
  esac
  strip_comments "$f" | sed -n "/^\.$sel {\$/,/^}\$/p" \
    | grep -Eq -- 'padding-inline:[^;]*var\(--container-max, *1280px\)' && n=$((n + 1))
done
[ "$n" -ge 13 ] \
  || fail "only $n compositions constrain content width against var(--container-max, 1280px) on the rule that carries their inline gutter, expected 13"

echo PASS
