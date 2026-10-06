#!/usr/bin/env bash
# Two AOS seams found by scrolling a real build past its first entrance, not by
# reading the AOS docs:
#   1. aos.css rewrites transition-property/-duration/-delay on any element that
#      still carries data-aos, for as long as the attribute stays — breaking a
#      hover-lift card's or a color-fading button's OWN transition long after the
#      entrance finished. The attribute must come off once the entrance settles.
#   2. AOS measures trigger points at DOMContentLoaded, before web fonts and images
#      reflow the layout, so a block that moves afterward can end up permanently
#      below a stale trigger with `once: true`. Must re-measure on `load`.
# A third seam: the first screen looked unanimated because its LCP-critical
# elements were skipped outright to protect LCP — the skill must say to animate
# them too, with a fast plain fade, not leave them out.
set -euo pipefail
# `q "$text" <grep flags> <pattern>`: a here-string, never `printf | grep -q`. Under
# pipefail an early-exiting `grep -q` hands printf a SIGPIPE and the pipeline returns 141,
# which silently flips an assertion either way.
q() { local s=$1; shift; grep -q "$@" <<<"$s"; }
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $1"; exit 1; }

f=skills/wp-aos-animator/SKILL.md
[ -f "$f" ] || fail "$f is missing"
# The install snippets (Phases 2-4) live in references/install.md, which SKILL.md must name;
# the seams below are judged over SKILL.md plus its references, wherever the snippet sits.
grep -Fq 'references/install.md' "$f" || fail "$f does not link references/install.md, so no agent reaches Phases 2-4"
corpus=$(cat "$f"; for r in skills/wp-aos-animator/references/*.md; do [ ! -f "$r" ] || cat "$r"; done)

q "$corpus" -F "removeAttribute('data-aos')" \
  || fail "$f: no removal of data-aos once the entrance settles (aos.css keeps rewriting the element's transitions otherwise)"
q "$corpus" -F "transitionend" || fail "$f: attribute removal is not tied to the entrance's own transitionend"

q "$corpus" -F "AOS.refresh()" || fail "$f: no AOS.refresh() call"
q "$corpus" -F "addEventListener('load'" \
  || fail "$f: AOS.refresh() is not re-run on window 'load' (DOMContentLoaded predates font/image reflow)"

grep -Eiq 'LCP candidate|LCP element' "$f" \
  || fail "$f: no guidance for the above-the-fold LCP element — must animate it, not skip it"
grep -Fq 'data-aos="fade" data-aos-duration="400"' "$f" \
  || fail "$f: no fast-fade pattern documented for the LCP element"

q "$corpus" -Ei 'prefers-reduced-motion' || fail "$f: no reduced-motion escape hatch"

# The "never animate" rule and its skip list, in SKILL.md where every Phase 5 subagent reads
# it. A transform makes a stacking context (a toolbar's dropdown paints under the next card)
# and a containing block that rewrites transition-property (a drawer that slides on
# translate jumps instead). Nothing pinned it, so an edit could drop it silently.
grep -Fq '**stacking context**' "$f" || fail "$f lost the stacking-context half of the never-animate rule"
grep -Fq '**containing block**' "$f" || fail "$f lost the containing-block half of the never-animate rule"
grep -Fq 'Anything that slides' "$f" || fail "$f's skip list no longer skips elements that slide on translate"
grep -Eq 'ancestor of a dropdown' "$f" || fail "$f's skip list no longer skips the ancestors of a dropdown"

# ---------------------------------------------------------------------------
# What the skill tells an agent to WRITE must work against AOS 2.3.4 and the starter.
# Each assertion below is a defect the skill shipped:
#   - the enqueue used `_RATIO_WEB_`, one client project's constant: undefined in any
#     other theme, so a fatal error on every front-end page under PHP 8;
#   - headings, paragraphs and buttons used `fade-up-slow`, which aos.css does not define
#     (they faded with no movement), and a button delay of 20, which matches no
#     `[data-aos-delay]` selector (aos.css ships 50..3000 in steps of 50 only);
#   - `curl -sL` saved a 404 page as aos.js and the next phase carried on;
#   - nothing kept AOS out of a craft or cinematic theme, which already ship a motion engine.
# The corpus is SKILL.md plus any reference file, so moving a snippet out of SKILL.md
# keeps it judged.
# ---------------------------------------------------------------------------

# 1. No foreign constant, no jQuery dependency. Every all-caps constant on an AOS
#    enqueue line is the theme's own placeholder (PREFIX_URI / PREFIX_DIR).
q "$corpus" -F '_RATIO_WEB_' && fail "$f: the enqueue still uses _RATIO_WEB_, a constant no other theme defines — a PHP 8 fatal"
enq=$(printf '%s\n' "$corpus" | grep -E "wp_enqueue_(style|script)\( *'aos-(css|js)'" || true)
[ -n "$enq" ] || fail "$f: no AOS enqueue lines found — the checks below would judge nothing"
foreign=$(printf '%s\n' "$enq" | grep -oE '\b[A-Z][A-Z0-9]*_[A-Z0-9_]+\b' | grep -Ev '^PREFIX_[A-Z]+$' | sort -u | tr '\n' ' ' || true)
[ -z "$foreign" ] || fail "$f: the AOS enqueue uses constants that are not the theme's PREFIX_ placeholder: $foreign"
q "$enq" -i 'jquery' && fail "$f: the AOS enqueue declares a jquery dependency; AOS has none"
q "$corpus" -F "array( 'aos-js' )" \
  || fail "$f: the main bundle is never made to depend on aos-js — deferred, it can run before AOS exists and the init module silently returns"

# 2. Only animation names aos.css 2.3.4 defines, on attributes and in the convention table.
known=' fade fade-up fade-down fade-left fade-right fade-up-right fade-up-left fade-down-right fade-down-left flip-up flip-down flip-left flip-right slide-up slide-down slide-left slide-right zoom-in zoom-in-up zoom-in-down zoom-in-left zoom-in-right zoom-out zoom-out-up zoom-out-down zoom-out-left zoom-out-right '
names=$( { printf '%s\n' "$corpus" | grep -oE "data-aos=\"[a-z-]+\"|'data-aos' => '[a-z-]+'" \
           | sed -E "s/.*[\"']([a-z-]+)[\"']$/\1/"
         # The convention table: the cell that OPENS with a backticked name is an animation.
         # (`|| true`: a skill with no such table must not abort the whole check under pipefail.)
         printf '%s\n' "$corpus" | grep -E '^\|' | awk -F'|' '$3 ~ /^ *`[a-z-]+`/ { print $3 }' | { grep -oE '^ *`[a-z-]+`' || true; } | tr -d '` '
       } | sort -u)
[ -n "$names" ] || fail "$f: no data-aos animation names found to judge"
for n in $names; do
  case "$known" in *" $n "*) ;; *) fail "$f: '$n' is not an AOS 2.3.4 animation — aos.css has no rule for it, so the element fades without the movement the name promises" ;; esac
done

# 3. Delays and durations are multiples of 50 between 50 and 3000.
vals=$(printf '%s\n' "$corpus" | grep -oE "data-aos-(delay|duration)=\"[0-9]+\"|'data-aos-(delay|duration)' => '[0-9]+'" | grep -oE '[0-9]+' || true)
[ -n "$vals" ] || fail "$f: no literal data-aos-delay/-duration values found to judge"
for v in $vals; do
  { [ "$v" -ge 50 ] && [ "$v" -le 3000 ] && [ $((v % 50)) -eq 0 ]; } \
    || fail "$f: data-aos delay/duration $v matches no aos.css selector (50..3000 in steps of 50) — a silent no-op"
done
q "$corpus" -F 'multiples of 50' || fail "$f: the multiples-of-50 constraint is not stated, so the next edit reintroduces a 20"
q "$corpus" -F 'min( $index, 5 )' || fail "$f: the looped card stagger is not capped"

# 4. The download fails loudly.
curls=$(printf '%s\n' "$corpus" | grep -E '^[[:space:]]*curl ' || true)
[ -n "$curls" ] || fail "$f: no curl download lines found"
q "$curls" -vE 'curl -[a-zA-Z]*f' && fail "$f: a curl download has no -f, so a 404 page is saved as the library"
q "$corpus" -F 'test -s' || fail "$f: the download is not verified non-empty before the next phase"

# 5. A re-run finds the existing init in the wp-scripts source directory.
q "$corpus" -E 'grep -rn "AOS\.init" <theme>/assets/js/|assets/js/src' \
  || fail "$f: the audit greps only assets/js/*.js, never the bundle source in assets/js/src/, so a re-run adds a second AOS.init"

# 6. The recorded motion decision gates the whole skill — in SKILL.md, before any phase acts.
flatf=$(tr '\n' ' ' < "$f" | sed 's/  */ /g')
q "$flatf" -F '`demo mode`' || fail "$f: never reads the recorded demo mode"
q "$flatf" -E '`demo mode: craft` \| \*\*Stop' || fail "$f: a craft build is not stopped before AOS is added"
q "$flatf" -E '`Template: cinematic` \| \*\*Stop' || fail "$f: a cinematic theme is not stopped before AOS is added"
cmd=commands/wp-aos-animator.md
grep -Fq 'Template: cinematic' "$cmd" || fail "$cmd does not stop on a cinematic theme"

echo PASS
