#!/usr/bin/env bash
# No direct child of a `data-motion="reveal"` element may carry its own CSS
# animation. The device does gsap.set(kids, {opacity, y}) on exactly those
# elements, so a second writer on the same element is a race — and the demo
# wins it (motion.js inlined, runs before the start keyframe applies) while the
# theme loses it (initMotion at DOMContentLoaded, by which point it has). The
# element animates in the demo and freezes at the keyframe's start value in the
# theme: measured as a conversion block stuck at scale(0.88) on 16 pages, with
# /wp-demo-verify passing that same demo 66/66.
#
# Deeper descendants are fine; reveal never touches them.
#
# The reveal root is NOT always the section: faq-list, hero-bleed, hero-split,
# hero-type and testimonial-pair all carry the attribute on an inner wrapper.
# So the children are found relative to whichever element declares it, at that
# element's own indent + 1 level — not at a fixed depth from the file's top.
set -euo pipefail
cd "$(dirname "$0")/../.."

root=skills/wp-demo-craft/compositions
test -d "$root" || { echo "FAIL: $root missing"; exit 1; }

# The rule has to be written down too, or the next composition re-learns it.
grep -q 'Never animate a transform property on a direct child' \
  skills/wp-demo-craft/references/devices.md \
  || { echo "FAIL: devices.md no longer states the collision rule"; exit 1; }

python3 - "$root" <<'PY'
import os, re, sys

root = sys.argv[1]
bad = []
scanned = 0

for name in sorted(os.listdir(root)):
    d = os.path.join(root, name)
    html, css = os.path.join(d, 'section.html'), os.path.join(d, 'section.css')
    if not (os.path.isfile(html) and os.path.isfile(css)):
        continue
    lines = open(html).read().split('\n')
    sheet = open(css).read()

    # Every element declaring reveal, at any depth.
    roots = [(i, len(l) - len(l.lstrip()))
             for i, l in enumerate(lines)
             if 'data-motion="reveal"' in l]
    if not roots:
        continue
    scanned += 1

    kids = set()
    for start, indent in roots:
        for l in lines[start + 1:]:
            if not l.strip():
                continue
            here = len(l) - len(l.lstrip())
            if here <= indent:          # left the reveal root's subtree
                break
            if here != indent + 2:      # a grandchild, which reveal never touches
                continue
            m = re.search(r'class="([^"]+)"', l)
            if m:
                kids.update(m.group(1).split())   # every class, not just the first

    for cls in sorted(kids):
        # Any declaration block whose selector mentions this class — including
        # compound selectors like `.a.b` — and that sets a live animation.
        for sel, body in re.findall(r'([^{}]+)\{([^{}]*)\}', sheet):
            # A pseudo-element is its own box. gsap.set() writes the element's
            # own transform and opacity and never reaches ::before/::after, so
            # an animation declared there is not a second writer.
            sel_clean = re.sub(r'/\*.*?\*/', '', sel, flags=re.S)
            targets = [t for t in sel_clean.split(',') if '::' not in t]
            if not any(re.search(r'\.' + re.escape(cls) + r'(?![\w-])', t) for t in targets):
                continue
            for _, value in re.findall(r'animation(-name)?\s*:([^;]+)', body):
                # `animation: none` is the @supports / reduced-motion fallback
                # landing on the settled state — the opposite of a second writer.
                if value.strip().split()[0] == 'none':
                    continue
                bad.append(f"{name} — direct child .{cls} of a reveal root: "
                           f"{', '.join(t.strip() for t in targets)} "
                           f"{{ animation:{value.strip()} }}")

if scanned == 0:
    print("FAIL: no composition declares data-motion=\"reveal\" — this check would be vacuous")
    sys.exit(1)

for b in bad:
    print("FAIL: " + b)
sys.exit(1 if bad else 0)
PY

echo "PASS"
