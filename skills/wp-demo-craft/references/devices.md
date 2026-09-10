# The device kit

Adapted from nateherkai/scroll-craft (MIT).

The attribute contract, exactly as declared:

```
data-motion="reveal|pin|pan|wipe|kinetic|parallax|drift|tilt|magnet|spotlight"
data-motion-span="2.4"        pin and pan only, viewport heights
data-motion-cue="0.1 0.7"     from to [rampIn rampOut] in section progress
data-motion-rate="-0.6"       parallax plane rate; also tilt/magnet strength
data-motion-stagger="70"      ms between reveal children
data-motion-count="0 3,500"   real figures only, written as it should render
                              (one value counts from zero to that target)
data-motion-dir="up|down|left|right|iris"   wipe direction
data-motion-drift="#0A0806"   the page ground this section takes over
```

`data-motion="<name>"` drives reveal, pin, pan, wipe, kinetic, parallax, drift,
tilt, magnet and spotlight. `count` is the one exception: it is dispatched by
the presence of `data-motion-count` alone, an element does not also need
`data-motion="count"` set. The pointer devices (`tilt`, `magnet`, `spotlight`)
are set with `data-motion="tilt"` etc, same as the scroll-driven devices.

The rail inside a `pan` section is marked `data-motion-rail`; without it the
engine falls back to the section's first element child.

## The eight devices

### `reveal`

Opacity from 0 plus a 14px rise over 620ms ease-out, children staggered 30 to
80ms, trigger 12% inside the viewport, fires once. A fade with no rise reads
as a loading glitch; a rise past 24px reads as a slide.

**Two paths, one device.** Where the browser supports `animation-timeline: view()`
**and** the user has not asked for reduced motion, this device runs from
`utilities/motion.css` and `motion.js` does not wire it; everywhere else —
including a reduced-motion reader on a browser that does support the feature —
`motion.js` runs it as before, and its own reduced-motion fallback sets the
arrived state explicitly rather than animating. The feature-query string is
identical in both places on purpose, and the JS guard tests the same
reduced-motion term the stylesheet's `@media (prefers-reduced-motion:
no-preference)` nesting uses, so the two paths cannot both decline the same
element. Three rules in the stylesheet fail silently if broken: the ruleset
never uses the `animation` shorthand (only longhands), because the shorthand
would reset `animation-timeline` back to `auto`; no `animation-duration` is
set; and `animation-fill-mode: both` is required.

**Stagger ceiling on the CSS path.** A per-child delay needs a per-child value and
composition markup forbids inline styles, so the CSS path carries the offset on
`nth-child` for the first eight children and shares the last offset beyond that.
A section relying on more than eight visibly ordered children should stay on a
scrubbed device.

**Maintaining the engine.** If the `gsap-scrolltrigger` and `gsap-performance`
skills are installed, read them before changing `motion.js`; they document the
scrub and refresh semantics this kit depends on. They are not required, and
nothing in the demo-authoring path should reference them: a demo author writes
`data-motion` attributes, never GSAP.

### `pin`

Minimum useful span is 1.2, because a pinned section's travel is
`max(height - viewport, 1)` and at span 1 every cue snaps between two scroll
notches. Cue windows overlap by roughly 15%.

`data-motion-span` only pins the number into the attribute contract and into
what `/wp-demo-verify` checks against; the engine reads it for that warning
but never sets a height and never turns on ScrollTrigger's `pin: true`. The
author's own CSS has to make the section actually tall and sticky: give the
section `height: calc(<span> * 100vh);` and give an inner wrapper
`position: sticky; top: 0; height: 100vh;`. That sticky wrapper is what holds
the frame in place while ScrollTrigger scrubs `--motion-p` against the
section's scroll range; a `pin` section without this CSS will not visually
pin, and `/wp-demo-verify` will report it as dead scroll.

**Budget.** This paragraph is the only place the budget is written down; `SKILL.md`
and `compositions/README.md` cite it rather than restate it, so it can be changed
here without leaving a stale copy behind.

A pin outside the peak is capped at span 2.0. The one element marked
`data-motion-peak` may reach span 3.0. Interior pages never pin — an about page that
opens on a title and a divider and then holds them for two screens is not
restraint, it is an empty page with a long fuse. The index adds at most four
viewport-heights beyond its section count in total; the role table in
`compositions/README.md` lists each composition's cost, so the sum is arithmetic
done before the build, not a surprise measured after it. Seven screens of scroll
carrying one interaction is what a page looks like when nobody added up.

### `pan`

Travel is `scrollWidth - innerWidth`, so measure the overflow: a rail
narrower than the viewport travels zero and the section becomes a motionless
pin. Aim for at least half a viewport of overflow; add the heading as the
first rail item rather than widening cards. Roughly one viewport-height per
item, plus one.

### `wipe`

`clip-path` from an edge, `iris` at most once per page. `clip-path` is
relative to the border box, so a wipe on type set below `line-height: 1`
shears ascenders and descenders; put the attribute on a wrapper.

### `kinetic`

The engine splits by words, not lines, characters approximately never: real
line-box splitting would need measuring rendered line boxes, which this kit
does not do. Reserve this device for short punch lines rather than wrapped
paragraphs, where a word-by-word reveal still reads as one deliberate beat.
Masks reserve room for descenders. Re-split after `document.fonts.ready`. One
kinetic heading per section, and it must be plain text: an element with any
child markup (`<a>`, `<em>`, `<br>`) is skipped rather than split, because the
split rebuilds the element from its words and would destroy that markup.

**Never on a hero headline.** The split masks every word until a scroll trigger
fires, so a visitor who never scrolls is shown a headline clipped mid-word. A
hero is `reveal`, which fades the section's direct children in on entry; at the
top of a page that is first paint, and it never re-hides on the way back up. A
cue does not rescue a kinetic hero either, for the reason below.

### `parallax`

Rate is in hundreds of pixels: total travel is `rate * 100`px. Usable range
0.3 to 1.5 inside a frame, 1 to 2 for a full-bleed bed. Never put body copy on
a parallax layer. Never set a `transform` transition on a parallaxed element.

### `count`

Only real, verified numbers; a concept or pre-launch brand has none, so it has
no counters. Ease-out hard over 1.2 to 1.8 seconds, fires once at half
visibility, `tabular-nums`, reduced motion writes the final value.

### `drift`

A property of sections, not a device. Three to five stops, all inside one
theme family. If several short sections can be part-way through at once,
paint opaque per-section grounds instead.

### Pointer devices

`tilt` 5 to 9 degrees, `magnet` 0.2 to 0.35 on the primary CTA only,
`spotlight` publishing `--motion-mx` / `--motion-my`. All gated to
`(hover: hover) and (pointer: fine)` and off under reduced motion. `magnet`,
`parallax` and cue rise all write `transform`, so they cannot share an
element.

## The cue contract

| `data-motion-cue` | Meaning |
|---|---|
| `"0.2"` | holds to the end |
| `"0.1 0.6"` | in, plateau, out |
| `"0 0.78 0"` | greet |
| `"0 1 0 0"` | greet and hold |

Three rules, each learned by shipping the bug:

1. **A cue only means something inside a scrubbed section.** `drive()` in
   `motion.js` is the only thing that reads cue nodes, and it runs only in the
   `pin|pan|kinetic|wipe|drift` branch — those are the devices with a continuous
   section progress for a cue to be a function of. On a `reveal` section a
   `data-motion-cue` is inert: it does nothing, and an attribute that does
   nothing is worse than none, because it tells the next author a mechanism is
   in place when it is not. Nothing in the composition library carries one.
2. The last section's cue must hold. Inside a pinned or panned section, copy
   that should be present from the first frame takes the **greet** form.
3. **Only the last** section may hold. A one-value cue on a middle section
   stays lit through the whole un-pin slide.

The plateau is the point: a triangle cue touches full opacity for a single
instant. Every act publishes `--motion-p` so anything the kit does not cover
can be driven from CSS with `calc()`.

Reduced motion keeps the opacity that carries comprehension and drops every
position change (`prefers-reduced-motion`). Under reduced motion `--motion-p` is
frozen at `1`, its end state, rather than tracking scroll: the seam is normally
driven into a `transform`, and a live value there would animate position through
exactly the rule this floor exists to enforce. Write the `calc()` so that
`--motion-p: 1` is the settled, fully arrived composition.

## The signature move

A build may invent one bespoke interaction that exists on that site alone, coded
in `assets/js/signature.js` and driven from `--motion-p`. v2 does not require one
— the composition library already gives a page its shape, and a required
signature move is how a page acquires an interaction nobody asked for — but when
the brief's tell-someone sentence points at an interaction, that interaction is
the signature move.

It is not a device-kit parameter change. A recoloured spotlight, a different tilt
angle, a new easing curve on kinetic lines, or more of an existing device (a
longer rail, a third wipe) do not count. A trace rail the scroll draws through
the page, a wordmark the pointer pulls apart, an SVG drawing that draws itself,
one control that regrades the whole page at once — those do. The test: describe
it to someone who has seen the other builds. If they cannot tell it apart from
something the kit already does, it is a parameter, not a move.

## Video scrub is not in this kit

Video scrub belongs to `/wp-cinematic-demo` and the cinematic-scroll-kit, not
to this device kit.
