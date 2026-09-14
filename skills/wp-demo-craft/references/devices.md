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

## Two kinds of motion, and only one of them has a budget

This distinction was missing, and its absence is why builds came out static while
passing every gate. One word — "motion" — covered two things with completely
different costs, and the ceiling written for the expensive one was applied to both.

**Scroll choreography costs page length.** `pin`, `pan`, `kinetic`, `wipe` and
`drift` scrub against a scroll range, which means the page must grow to give them
room. That growth is what the vh budget below meters, and the budget is correct: a
page carrying seven screens of scroll and one interaction is the failure it prevents.

**Element animation costs nothing.** A heading rising on its own view range, a list
staggering in, a bar growing from `scaleX(0)`, an icon drawing itself on with
`stroke-dashoffset`, a photograph easing in, a hover lift, a zoom on entry — none of
these lengthen the page by a single pixel. **They are not budgeted, not capped, and
not rationed.** A section with eight of them is not over budget; it is a section that
moves.

Read that as permission, because the rules previously read as prohibition. Every
gate in this skill punishes excess and, until recently, none punished absence — so an
agent optimising to pass gates minimised motion, correctly, and shipped pages whose
only animation was a single one-shot `reveal`. A measured build finished with a
quarter of its scroll budget unspent while reading as completely static, which is the
signature of a rule set that constrained the wrong axis.

**An entrance ends at or past `entry 100%`, never inside the entry phase.** This is
the rule that made three working animations read as none. `entry 0% entry 50%`
completes while the element is still grazing the bottom edge of the viewport — the
animation runs, `getAnimations()` reports a live `ViewTimeline`, the harness sees
motion, and the reader sees a section that was already finished when they arrived.
A measured build carried twelve of twelve selectors animating correctly and drew the
report "this section doesn't have any animation, not entrance or scroll one" about a
section with three of them. Nothing was broken; everything was over half a screen
early. `entry 100%` is the moment the element is fully in view, so an entrance that
ends there is still moving when it is first looked at. Keep the start — that is the
stagger — and let the end run past 100% for later items in a group.

**Amplitude has a floor too.** An 18–26px fade at the bottom edge of a 900px viewport
is not a subtle entrance, it is an invisible one. The library's `--motion-rise`
default is 44px for the same reason: below roughly 35px the movement is smaller than
the reader's own scroll increment and reads as a static element that happened to be
faint a moment ago.

**Two counts, not one.** The device budget counts `data-motion` attributes; it does
not count animated elements, and the two numbers are not close. One attribute per
element is correct and has been read alongside a per-page device figure as "this page
may contain fifteen animated things" — which is how a page ends up with thirteen of
its fifteen devices being the same 620ms fade. A page with fifteen devices and a
hundred and twenty animated elements is a normal page, not an extravagant one. Count
them separately or the second number silently inherits the first one's ceiling.

**Restraint is about scroll, never about life.** A page can be entirely restrained in
its scroll choreography — no pins, no scrub, one peak or none — and still fade, rise,
zoom, stagger and draw its icons throughout. Those are different decisions. A client
asking for a site that moves is asking for the second, and answering with a longer
page is answering a question nobody asked.

### Motion belongs in the composition, not beside it

An author animating a composition from outside is guessing at its internals, and a
guessed class name is a **silent no-op**: no match, no error, no animation, and no
gate that catches it. A real build wrote `.feature-zigzag__label` and
`.feature-zigzag__figure` against a composition whose elements are `__kicker`,
`__heading` and `__media`. Nothing failed. The motion simply did not exist, and it
was found only by enumerating every selector against the rendered DOM and counting
matches.

That is the argument for element motion living in each composition's own
`section.css`, which is where it now lives: the file that names the elements is the
file that animates them, so the names cannot drift apart. A composition that expects
to be animated from outside owes the author a documented list of its animatable
hooks — but preferring to carry its own motion is the better answer, and the one the
library takes.

The same silent-no-op family covers markup, not just CSS: a helper that emits a
block's class but not the inner wrapper its grid targets renders a single narrow
column, with no error anywhere. If a composition's layout depends on a wrapper, the
wrapper is part of the composition, never something the caller is trusted to add.

### Hover states: elevation, never a halo

A hover that adds an accent-tinted glow is a `slop` finding. A build gave its CTAs
`box-shadow: 0 10px 26px -10px color-mix(in oklab, var(--color-accent) 70%,
transparent)` and `impeccable detect` returned twelve "Glowing shadow accents" — on a
build whose own `DESIGN.md` said "no glowing button" in those words.

Spec hover as **depth tinted to the canvas hue** — the shadow tokens — never as a
coloured halo around the element. The detector is strict here and it is right: an
accent glow is the single most reliable tell of a generated page.

### Driving a plain property off `--motion-p`

Inside a scrubbed section (`pin`, `pan`, `kinetic`, `wipe`, `drift`) the engine
publishes section progress as `--motion-p`, and any property can read it directly —
no timeline, no keyframe, no second device:

```css
.block__figure { scale: calc(0.94 + (var(--motion-p, 0) * 0.06)); }
```

It tracks the scrub exactly, and under reduced motion `--motion-p` freezes at 1, so
the element lands on its settled state for free. Use it for anything that should
follow the scrub rather than arrive once, in a section that already carries a
scrubbed device.

### One attribute, one device — and how to get past it

`data-motion` holds a single value. An element carrying `data-motion="reveal"`
cannot also carry `drift`, and the engine reads one name per element, so there is
no syntax for two.

That matters more than it sounds, because **every composition used to spend its
root attribute on `reveal`**. Adding any section-level device to a composed
section therefore meant *deleting* the composition's own motion first — so the
library's default foreclosed every alternative, and an author who wanted a
section to drift or pin had to break the composition to do it. No budget and no
rule caused that; one attribute did.

The way past it is not a second attribute. It is that **a composition carrying
element animation in its `section.css` does not need a root `reveal` at all** —
the children are already arriving on their own ranges, which is better motion
than one staggered block. Where that is true the root attribute is free, and a
build can spend it on `drift`, `parallax` or a pin without taking anything away.

So the order is: element motion first, root attribute second. A composition whose
`section.css` carries `view()` animation may drop `data-motion="reveal"` and its
`data-motion-stagger` when a build wants a section device there. Check the
composition's README, which says whether its element motion is self-sufficient.

One consequence worth stating, because it is the cost of the trade: a browser with
no `animation-timeline: view()` support gets no entrance animation from the CSS
path, and with the root `reveal` gone there is no GSAP path to fall back to
either. Content is still visible — every composition's `@supports not` block
lands on the finished state — it simply arrives without motion. That is the right
trade for a demo; it is worth knowing before making it for a production theme.

### How element animation is written

Per-element scroll-driven CSS in the composition's own `section.css`, the same
mechanism `utilities/motion.css` already uses for `reveal`:

```css
.block__heading {
  animation-name: rise;
  animation-timeline: view();
  animation-range: entry 0% entry 45%;
  animation-fill-mode: both;
}
.block__row:nth-child(2) { animation-range: entry 10% entry 55%; }
.block__row:nth-child(3) { animation-range: entry 20% entry 65%; }
```

Stagger with `animation-range` offsets per child rather than one root `reveal` with
`data-motion-stagger`.

**A stagger ladder goes out of order in four independent ways, and fixing one leaves
the other three.** All four have been measured in this library or the build that uses
it; none of them errors, and all four look correct in the source.

1. **Index by type, not by child position.** `:nth-child` is a fact about the
   parent's *other* children. `offer-table`'s plans are `<th>` preceded by a `<td>`
   corner cell, so every rung was off by one: measured on the shipped markup, plan 1
   received `entry 20%` — the rule written for plan 2 — and the `:nth-child(1)` rule
   for `entry 14%` matched nothing at all. The peer build hit the same thing from the
   other direction, by *adding* a `<span>` to a list three rounds after the ladder was
   written, which shifted every `<li>` one place. `:nth-of-type` counts `li` among
   `li` and cannot be shifted by a sibling of another type. The exception is a ladder whose
   children are *deliberately* of mixed type — a label, a link and a step in one flow
   — which has no type to count, so `:nth-child` is the only index available and is
   correct. The stylesheet cannot tell that case from the broken one, so the scan does
   not guess: the author writes `ladder-scan: allow-nth-child <selector> -- <why>` in a
   comment, and a marker with no reason after it is refused. The point is to record a
   judgement someone can check, not to provide a way to silence the scan.

2. **One phase keyword per ladder.** `entry X%` and `cover X%` are not comparable.
   The entry phase spans `min(elementH, viewportH)` of scroll and the cover phase
   spans `viewportH + elementH`, so `entry 100%` sits at `min(h,vh) / (vh+h)` of
   cover — measured at exactly that value across eight element/viewport pairs,
   anywhere from **cover 11.8%** to **cover 47.1%**. A ladder that switches unit part
   way up is therefore ordered correctly on the page it was written against and
   inverts on the next one, by an amount nobody can know while writing it. Because
   `entry` percentages may exceed 100, a `cover B%` endpoint converts to
   `entry (100 + B)%` and the ordering becomes arithmetic again.

3. **A rung past the last written index falls back to `normal`**, which on a view
   timeline is `cover 0%` to `cover 100%` — a range with no relation to the stagger.
   See "past the last written range" in the compositions.

4. **Rungs on `view()` each build a timeline from their own box.** A row of items
   with different body lengths gives every rung a different timeline, so a monotonic
   set of ranges still fires out of order. This is the shared-timeline rule above,
   arriving as a stagger bug instead of as a disagreement between two readouts.

The first three are asserted by `tests/checks/lib/ladder-scan.py`. The fourth is not
visible in one file.

### Measuring motion: two readouts, and they answer different questions

Every measurement mistake made while writing these rules — on both sides of the
review — was the same mistake, made four times: reading the rendered value when the
question was about the timeline.

| reading | what it is | use it for |
|---|---|---|
| `animation.currentTime` | where the timeline is, raw, before the timing function | is this ladder in order? |
| the computed property | what the reader actually sees, after the ease | does this look arrived? |

`getComputedStyle(el).getPropertyValue('--x')` and `getBoundingClientRect()` both go
through `animation-timing-function`. Two consequences, both of which produced a wrong
number that looked plausible:

- **Eased readings are not progress.** Measuring the `entry`-to-`cover` conversion by
  reading an animated custom property put `entry 100%` at "cover 52.8%" where the
  true value is 30.8% — the default `ease` distorted both sides. Setting
  `animation-timing-function: linear` made all eight measurements match the
  arithmetic exactly. Ordering conclusions survive an ease, because a monotonic
  function preserves order; percentages do not.
- **`getBoundingClientRect()` returns the transformed box.** An element mid-`scale`
  reports its scaled size, so a row of nodes animating `scale: 1 → 1.08` measured 44,
  43.8, 43.3 and 42.6px and every junction looked several pixels out. Both were
  artefacts. Use `offsetWidth`/`offsetHeight` for layout, or inject
  `* { animation: none !important }` before measuring geometry.

### An override can conceal what it overrode

A project override that *flattens* a ladder — giving every rung the same range —
makes a broken ladder unobservable, because "all correct" and "all identical" look
the same on a screenshot. Measured on the build using this library: an override
collapsed two plan columns onto one range, so `offer-table`'s off-by-one could not
appear there, and the cost of the override was the stagger itself, unnoticed for
several rounds.

So an override is two hazards, not one. It can silently fail to apply — a patch
appended *above* the rules it means to replace loses on source order at equal
specificity, and nothing errors — and it can silently succeed at hiding the defect
underneath it. The only reliable signal in either direction is the computed value
read back off the live element, which is also what found the off-by-one: the
stylesheet says what was written, never what applied. The attribute contract gives a section **one** device; rich
motion is many elements moving on their own timelines inside one section, and the
attribute cannot express that while CSS does it trivially.

Four ways this fails silently, all of them worth knowing before you write it.

**Each one carries the measurement that produced it, and that is a rule about this
list rather than a courtesy.** A silent-failure rule is by definition one nobody has
cause to test: the advice is followed, nothing breaks, and the stated reason is never
exercised. So a wrong reason survives indefinitely and is only found when someone
reasons *forward* from it to a new case. Two of the four below had reasons that were
wrong in exactly that way — one said a duration hijacks the animation when it is
inert, one said the element falls back to its `from` value when it falls back to its
un-animated value — and both had been read many times without anyone noticing,
because the advice attached to them was fine. A rule with a number beside it can be
checked by the next reader in the time it takes to disbelieve it. A rule without one
is a claim.


1. **Longhands only.** The `animation` shorthand resets `animation-timeline` to
   `auto`, which silently reverts the element to a time-based animation that runs
   once on load and never tracks the scroll. Measured: two elements given identical
   longhands, one of them then "tidied" into `animation: sweep 2s` on a later line --
   the shorter rule a maintainer writes on purpose. At one scroll position the first
   read `timeline=ViewTimeline, --v=74.2409` and held that value with the page still;
   the second read `timeline=DocumentTimeline, --v=27.651` and ran on to 87.2776 over
   the next 1.2s without the page moving at all.
2. **A duration on a scroll-driven animation is inert.** It does not override the
   range and the element does not play through on its own clock — this file said it
   did, and measured against it does not: two rules identical but for `animation-duration:
   auto` against `2s`, sampled at six scroll positions, produced the same value at
   every one (13.165, 79.0622, 95.4148, 99.9709, 100, 100). The duration is recorded
   in the timing and ignored. Leave it off anyway, because writing one teaches the
   next reader that it does something.
3. **`animation-fill-mode: both`.** Without it the element renders its *un-animated*
   value outside the range — not the keyframe's `from` value, which is the easy thing
   to assume and is wrong. Measured on keyframes running `10` to `90` against a
   property whose `initial-value` is `0`, both elements sitting past their range and
   reporting `finished`: with the fill mode, `--v=90`, the end state held; without it,
   `--v=0`. Not `10`. So the fallback is whatever the element would compute with no
   animation at all, which for a rise is the offset position and for an opacity fade
   is invisible.
4. **A time-based loop near scroll-driven CSS needs `animation-timeline: auto` and
   `animation-range: normal` stated.** A scroll timeline is inherited by anything a
   broader rule hands it to — `motion.css` gives descendants of a `reveal` section
   their own `view()` — and a looping animation that lands on one does not loop. It
   reports `playState: "finished"` and sits at its start value forever: measured, an
   infinite 2s sweep inside such a subtree read `timeline=ViewTimeline, duration=2000,
   finished, --v=0` and never moved, while the same rule stating `auto`/`normal` ran
   on the `DocumentTimeline` and swept 54.5 → 6.0 with the page held still. No error,
   no warning, a still picture. This is the shorthand trap arriving from the opposite
   direction: there a load animation inherits `view()` and snaps to its end state,
   here a loop inherits `view()` and never starts.

**Use `translate`, `scale` and `rotate`, never `transform`.** The engine writes
`transform` for `parallax`, `magnet` and cue rise, and `reveal` writes it on every
child — so a keyframe of yours that also writes `transform` does not compose with
that, it replaces it, and whichever declaration lands last wins. The individual
properties compose with `transform` instead of overwriting it, which removes the
whole collision class rather than warning about it: a `view()` zoom on a parallaxed
bed simply works.

    /* wrong: races the engine */      transform: translateY(22px);
    /* right: composes with it */      translate: 0 44px;

**Restate every `animation-*` longhand when you re-target an element in a later
rule.** This is the shorthand trap in reverse and it is worse, because nothing looks
wrong. A second rule that sets only `animation-name` leaves `animation-timeline`
exactly as the first rule left it — so an element given `view()` earlier, then
re-pointed at a load animation, silently runs that load animation on the scroll
timeline. Measured on a real build: `anim=ns-pushin :: timeline=view()`, which turned
a set of drifting banners into banners that zoomed on scroll. One element, one
animation rule, all longhands together.

**Two elements that display the same value share a named timeline; `view()` is
only safe when each element's progress is its own business.** `view()` builds a
timeline from **each element's own box**, so two elements carrying identical
`animation-range` declarations do not have identical progress — they have the
progress their own boxes earn, and a box 200px higher in the card is further
along. Measured on a gauge whose needle and figure read one score, at one scroll
position: needle `-31.38%`, figure `-13.64%`. The needle had finished its travel
while the number still read its start value; on screen, an arrow pointing at 850
beside a figure showing 300, in the same frame.

Nothing reports this. Every probe says both elements have a live `ViewTimeline` on
the range they asked for, because they do. It is the same species as a counter that
parses to `NaN`: each part is working and the composite is wrong, so it is caught by
a reader and not by a harness.

The fix is one timeline on the nearest shared ancestor:

```css
.gauge__frame  { view-timeline-name: --gauge-tl; view-timeline-axis: block; }
.gauge__needle,
.gauge__num    { animation-timeline: --gauge-tl; animation-range: entry 18% cover 52%; }
```

Both then report the same `currentTime`, and the two readouts agree arithmetically
rather than by hope. Any composition where a bar and its percentage, a scale and its
marker, or a meter and its figure describe one quantity has this shape.

**There are two coupling mechanisms, and which one you need depends on what drives
the value.** The mistake is identical in either case — declaring the same intent on
two elements and assuming that makes them one animation — and so is the way it
fails, silently and only on screen.

| the value is driven by | couple with |
|---|---|
| the reader's scroll position | one `view-timeline-name` on the nearest common ancestor |
| a clock | identical timing longhands on both, one keyframe domain |

**Scroll-scrubbing a readout has a cost worth naming before you choose it: it is
motionless whenever the reader is.** A gauge driven by scroll position is a still
picture in every screenshot, and on any page somebody is reading rather than
scrolling. That is right for a value the reader is *navigating* — a scale whose
marker they move by scrolling — and wrong for a value that should simply be alive,
which belongs on a clock and loops. One build shipped the scroll version and drew
"but why doesn't it move" from the operator; the fix was not better coupling but a
7s alternating document timeline, coupled by mechanism two.

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

**The two paths differ above the fold, and the CSS one is the intended behaviour.**
The CSS range is `entry 0% entry 40%`, so an element already fully inside the
viewport when the page loads is past its entry range: `animation-fill-mode: both`
lands it on the end state with no animation. The JS path has no such notion and
animates it in. A hero therefore fades in on a browser without scroll-driven
animation and is simply *there* on one that has it. Not a bug to fix — the rubric
line "First paint complete" grades the first screen as it lands, and a first screen
that lands finished scores better than one still assembling itself. Do not add a
`cover`-range rule or a JS above-the-fold check to make them match; make the JS path
the one that is odd.

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

**It meters viewport-heights of added scroll, and nothing else.** It does not cap how
many things move, how many elements animate, or how alive a page feels — see "Two
kinds of motion" above. Element animation contributes zero to every number in this
paragraph. A build that trimmed a fade because of this budget misread it.

A pin outside the peak is capped at span 2.0. The one element marked
`data-motion-peak` may reach span 3.0. Interior pages never pin — an about page that
opens on a title and a divider and then holds them for two screens is not
restraint, it is an empty page with a long fuse.

**Interior pages have a floor as well as a ceiling, and the floor is the one that
gets missed.** "Never pin" says what an interior page may not do; on its own it has
been read as permission to do nothing, which produces eleven pages carrying a
one-shot `reveal` and three hover devices. Hover is not motion on a touch screen,
and a `reveal` above the fold does not animate at all on the CSS path — so a page
whose entire motion budget is `reveal` plus pointer devices is a static page that
measures as animated. Every interior page therefore carries **at least one
scroll-reactive device that is not `reveal`**: `drift`, `count`, `parallax` at a low
rate, `pan`, or `cascade`. All of them cost 0 vh except `pan`, so the budget is
never the reason a page has none. The index adds at most four
viewport-heights beyond its section count in total; the role table in
`compositions/README.md` lists each composition's cost, so the sum is arithmetic
done before the build, not a surprise measured after it. Seven screens of scroll
carrying one interaction is what a page looks like when nobody added up.

### `pan`

Travel is `scrollWidth - innerWidth`, so measure the overflow: a rail
narrower than the viewport travels zero and the section becomes a motionless
pin. Aim for at least half a viewport of overflow. Roughly one viewport-height per
item, plus one.

**`pan` needs five items or more.** With three content-sized cards the rail cannot
overflow a 1440 viewport at all, so the device travels zero and pins a section that
never moves — pick `reveal` or `cascade` for a short set instead. Widening the cards
to force overflow makes the cards wrong to fix the device, which is backwards.

**Do not put the heading in the rail.** It was once suggested here as the way to buy
travel without widening cards, and it buys the travel by panning the section's own
label off the left edge: the section is then unlabelled for several hundred pixels of
scroll, which an independent evaluator flagged unprompted on a build that followed this
advice exactly. A heading is what tells a reader what they are looking at while they
look at it. Keep it outside the rail and let a short set use a different device.

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

**Two counters, and which one is a mistake depends on what the figure is.**
`data-motion-count` fires once on arrival and then tweens on a clock, so it is
right for a figure that simply counts up when the reader gets to it and wrong for
a figure that is a readout of something else moving — a clock and a scroll
position are never in sync, so the number and the thing it describes disagree
through the whole scrub. A figure that must track motion is animated as a
property and read back:

```css
@property --score { syntax: "<integer>"; inherits: false; initial-value: 300; }
.gauge__num        { counter-reset: score var(--score); }
.gauge__num::after { content: counter(score); }
```

`counter-reset` goes on the **element**, never on the pseudo that reads the
counter; the pseudo-scoped version computes and is not worth trusting across
engines. Animate `--score` on the shared timeline above, not on `view()`.

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
