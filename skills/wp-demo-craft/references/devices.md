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

1. A hero cue needs the **greet** form, or the landing screen has no
   headline.
2. The last section's cue must hold.
3. **Only the last** section may hold. A one-value cue on a middle section
   stays lit through the whole un-pin slide.

The plateau is the point: a triangle cue touches full opacity for a single
instant. Every act publishes `--motion-p` so anything the kit does not cover
can be driven from CSS with `calc()`.

Reduced motion keeps the opacity that carries comprehension and drops every
position change (`prefers-reduced-motion`).

## Video scrub is not in this kit

Video scrub belongs to `/wp-cinematic-demo` and the cinematic-scroll-kit, not
to this device kit.
