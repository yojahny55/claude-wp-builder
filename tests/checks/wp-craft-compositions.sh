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
# (one function builds both), needs no browser, and none of the first three survives it.
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

# Every viewport-width ramp left in a composition is a deliberate choice
# (a full-bleed hero's display type) and must say so on its own line or the line
# directly above, because a per-FILE check lets one justified vw green-light every
# other vw in that file — process-rail alone carried 7 on 7 separate lines, and a
# per-file grep would let one comment excuse six forgotten conversions. The marker
# is one of two literal phrases, "viewport on purpose" or "not cqi"; reword
# either on one side only (this comment or the CSS) and the check silently
# stops meaning anything. The second phrase exists because one ramp CANNOT be
# cqi: a rule that itself declares container-type never matches a container
# query against the container it establishes, so cqi there resolves against
# the viewport while reading as if it tracked the block.
#
# The pattern covers the whole family, not the one spelling `vw`: `dvw`, `svw`
# and `lvw` are the same unit with a viewport-sizing variant, `vi` is its
# logical alias in horizontal writing modes, and `vmin`/`vmax` resolve to the
# width on one orientation or the other. Pinned to the literal `vw` this loop
# passed a `6dvw` / `6vmin` ramp dropped into a composition with no comment at
# all — measured, rc=0 — which is the exact defect it was written to stop, and
# `dvw` is the spelling a mobile-aware author reaches for first. The trailing
# class stops `vi` matching inside a longer identifier.
#
# Viewport HEIGHT (`vh`, `dvh`, `svh`, `lvh`, `vb`) is deliberately not gated:
# `container-type: inline-size` gives a block-axis query nothing to resolve
# against, so there is no container-relative unit to convert those to, and the
# library's sixteen of them are structural (a pinned frame is one screen tall
# by definition). Requiring a justification comment on each would be noise, not
# an assertion.
VW_FAMILY='[0-9.](d|s|l)?(vw|vi|vmin|vmax)([^a-zA-Z]|$)'
for cssf in skills/wp-demo-craft/compositions/*/section.css; do
  while IFS=: read -r lineno _; do
    prevno=$((lineno - 1))
    prev=""
    [ "$prevno" -ge 1 ] && prev=$(sed -n "${prevno}p" "$cssf")
    cur=$(sed -n "${lineno}p" "$cssf")
    case "$cur$prev" in
      *"viewport on purpose"*) ;;
      *"not cqi"*) ;;
      *) fail "$cssf:$lineno keeps a viewport-width ramp (vw/dvw/svw/lvw/vi/vmin/vmax) without recording why it is viewport-relative (marker must be on this line or the line above)" ;;
    esac
  done < <(grep -nE "$VW_FAMILY" "$cssf")
done

# An element NEVER matches a container query against the container it establishes
# itself, and the same is true of `cqi`: in a rule that declares container-type,
# cqi resolves against the small-viewport fallback, so it tracks the SCREEN while
# reading as if it tracked the block. Measured in a fixed 480px box, a root
# `gap: clamp(3rem, 6cqi, 6rem)` computed 96px at a 1920 viewport and 48px at 800
# — viewport-relative behaviour wearing a container-relative unit, which is worse
# than the `vw` it replaced because it no longer looks like a bug. This is the
# assertion the vw-justification loop above cannot make: that loop only sees vw,
# and this defect has no vw in it. Comments are stripped first, because the one
# legitimate case documents itself by naming cqi in prose.
#
# Every container-query unit, not the one spelling `cqi`: `cqw`, `cqb`, `cqh`,
# `cqmin` and `cqmax` resolve against the same small-viewport fallback in that
# rule and reintroduce the identical defect. Pinned to `cqi` this loop passed a
# `6cqw` ramp inside the rule declaring `container-type` — measured, rc=0 — and
# `cqw` is already in the library's active vocabulary (process-rail uses
# `100cqw`), so it is the spelling a copy-paste lands on.
for cssf in skills/wp-demo-craft/compositions/*/section.css; do
  perl -0pe 's{/\*.*?\*/}{}gs' "$cssf" \
    | awk -v f="$cssf" '
        /\{/ { block=""; inblock=1 }
        inblock { block = block $0 "\n" }
        /\}/ {
          if (inblock && block ~ /container-type/ && block ~ /[0-9.]cq(i|b|w|h|min|max)([^a-zA-Z]|$)/)
            print "SELFCQI " f
          inblock=0
        }' \
    | while read -r _ badfile; do
        fail "$badfile puts a container-query ramp (cqi/cqb/cqw/cqh/cqmin/cqmax) in the same rule that declares container-type, so it resolves against the viewport rather than the block it appears to measure"
      done
done

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

# process-rail's own comment calls the reduced-motion rail "a native scroll
# region", but under prefers-reduced-motion the frame was width: auto,
# overflow: visible, with no overflow-x anywhere — so the row overflowed the
# whole DOCUMENT (measured 2496 at a 1920 viewport) instead of scrolling inside
# the frame. Anchored to the media block AND the __frame rule specifically: a
# file-wide `grep -F 'overflow-x: auto'` would pass with the declaration
# sitting anywhere in the file, including outside prefers-reduced-motion (where
# it does nothing under normal motion) or on __rail/__step (which do not have
# the frame's constrained width, so overflow-x there clips nothing).
PR_CSS=skills/wp-demo-craft/compositions/process-rail/section.css
pr_media=$(sed -n '/^@media (prefers-reduced-motion: reduce) {$/,/^}$/p' "$PR_CSS")
[ -n "$pr_media" ] || fail "process-rail/section.css has no prefers-reduced-motion media block"
pr_frame_rule=$(printf '%s\n' "$pr_media" | grep -F '.process-rail__frame {')
[ -n "$pr_frame_rule" ] || fail "process-rail/section.css has no .process-rail__frame rule inside prefers-reduced-motion"
printf '%s\n' "$pr_frame_rule" | grep -Eq 'overflow-x:[[:space:]]*auto' \
  || fail "process-rail__frame has no overflow-x: auto inside prefers-reduced-motion, so the rail overflows the whole document instead of scrolling"
# overflow: visible is a shorthand for BOTH axes, so it resets overflow-x too.
# If overflow-x: auto is declared before that shorthand in the same rule, the
# shorthand wins by source order and silently undoes the fix while the grep
# above stays green — require the longhand strictly after the shorthand.
pr_shorthand_at=$(printf '%s' "$pr_frame_rule" | grep -boE 'overflow:[[:space:]]*visible' | head -1 | cut -d: -f1)
pr_longhand_at=$(printf '%s' "$pr_frame_rule" | grep -boE 'overflow-x:[[:space:]]*auto' | head -1 | cut -d: -f1)
if [ -n "$pr_shorthand_at" ] && [ -n "$pr_longhand_at" ]; then
  [ "$pr_longhand_at" -gt "$pr_shorthand_at" ] \
    || fail "process-rail__frame declares overflow-x: auto before the overflow: visible shorthand, so the shorthand resets it back to visible"
fi

# CSS corrects a `visible` axis to `auto` when the other axis is not visible, so
# `overflow: visible; overflow-x: auto` leaves overflow-y computing to `auto`,
# not the `visible` the shorthand appears to declare. Measured: overflow-y read
# back as `auto` at 390/768/1280/1920 before this was stated explicitly. Nothing
# overflows the frame vertically today, so it is inert — but a shadow, a badge or
# a focus ring that later grows past the frame would be silently clipped or given
# a second scrollbar, and the declaration that caused it would not be in the file.
printf '%s' "$pr_frame_rule" | grep -qE 'overflow-y:[[:space:]]*hidden' \
  || fail "process-rail__frame does not state overflow-y explicitly inside prefers-reduced-motion, so it computes to auto and can silently clip or scroll anything that grows vertically"

# A scroll container no keyboard can reach is not a fix, it is a different bug
# (WCAG 2.1.1) — but the scroll container only exists under reduced motion. At
# default motion the frame is overflow-x: hidden and pinned, so a tabindex/role
# in the MARKUP ships a dead tab stop and a named landmark on every craft build.
# The affordance therefore belongs to motion.js's reduced branch, which is the
# only place that knows which mode is live. Measured on the real composition
# with motion.js running: reduce -> Tab lands on the rail, role=region, name
# from the section's own <h2>, ArrowRight moves scrollLeft 0 -> 40; default ->
# no tabindex, no role, no name, Tab skips past the section entirely.
PR_HTML=skills/wp-demo-craft/compositions/process-rail/section.html
pr_frame_tag=$(grep -F 'class="process-rail__frame"' "$PR_HTML")
[ -n "$pr_frame_tag" ] || fail "$PR_HTML has no .process-rail__frame element"
printf '%s' "$pr_frame_tag" | grep -Eq 'tabindex=|role=|aria-label=' \
  && fail "$PR_HTML's .process-rail__frame carries a static tabindex/role/aria-label, which at default motion is a dead tab stop and a landmark on a region that cannot be scrolled"
M=starter-theme/__tailwind__/assets/js/src/motion.js
# Scoped to the reduced branch of the pan device, by its own brace range: the
# same three lines sitting in the else branch (or outside the if) would satisfy
# a whole-file grep while restoring exactly the defect above.
pan_reduced="$(awk '/if \(kind === .pan.\)/,/^    if \(kind === .reveal./' "$M" | awk '/if \(reduced\) \{/,/^        \} else \{/' | grep -v '^[[:space:]]*//' || true)"
[ -n "$pan_reduced" ] || fail "$M has no reduced-motion branch in the pan device, so the rail's keyboard affordance cannot be checked"
printf '%s' "$pan_reduced" | grep -Fq 'const scroller = ' \
  || fail "$M's pan/reduced branch no longer picks the box that actually scrolls, so the affordance lands on an element the arrow keys do not move"
printf '%s' "$pan_reduced" | grep -Fq 'tabIndex = 0' \
  || fail "$M's pan/reduced branch does not make the scroll region focusable, so a keyboard-only user cannot reach the steps past the fold under reduced motion"
printf '%s' "$pan_reduced" | grep -Fq "setAttribute('role', 'region')" \
  || fail "$M's pan/reduced branch does not expose the scroll region as a landmark"
# aria-labelledby onto the section's own heading, never a literal: a label
# written in the markup ships one language on a bilingual site, and an
# unsubstituted {{slot}} would be read out verbatim as the region's name.
printf '%s' "$pan_reduced" | grep -Fq "setAttribute('aria-labelledby', heading.id)" \
  || fail "$M's pan/reduced branch names the region with something other than the section's own heading"

# Nothing that becomes an accessible name may reach a reader as a raw {{slot}}.
# applyFills() leaves an unknown key in place (it warns on stderr and returns the
# match), so a slot with no fill renders literally in the committed previews and
# reads out as "open brace open brace nav label" in a screen reader.
fills=skills/wp-demo-craft/compositions/fills.json
for h in skills/wp-demo-craft/compositions/*/section.html; do
  comp="$(basename "$(dirname "$h")")"
  for slot in $(grep -oE '(aria-label|alt|title)="\{\{[A-Za-z0-9_]+\}\}"' "$h" | grep -oE '\{\{[A-Za-z0-9_]+\}\}' | tr -d '{}' | sort -u); do
    node -e 'const f=require("./"+process.argv[1]);const m=Object.assign({},f._shared,f[process.argv[2]]);process.exit(process.argv[3] in m?0:1)' \
      "$fills" "$comp" "$slot" \
      || fail "$h uses {{$slot}} as an accessible name and $fills has no value for it, so the preview and any half-filled build read the raw slot text out to a screen reader"
  done
done

echo PASS
