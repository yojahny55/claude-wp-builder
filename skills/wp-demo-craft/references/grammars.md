# Page grammars

A grammar is the page's organising logic: what a section is, what the chrome
is for, how the visitor knows where they are, and what the ending is. A
different palette is not a different page; pick a grammar before writing
markup. Do not blend two grammars in one page.

Each grammar below states what it **forbids**. The forbids are the point:
without them a build drifts back to the same default shape halfway through.

## 1. Layered landing

Parallax planes hero (far plane, mid plane, product, foreground), text
entering on viewport, stacked cards, counters on verified numbers.

**Forbids:** a static hero image; more than two consecutive image-left/text-right
zigzags; body copy on a moving plane.

Plane rates differ by 10 to 30 percent between neighbours; copy always
travels at 1x; every plane is solid below its silhouette; the section floor
fades to the page ground to hide the clip line.

## 2. Chaptered editorial

The page is a printed feature. Chapters are the unit, not sections: hard
ground cuts, a folio in the margin, a title-page hero, a colophon close.

**Forbids:** continuous ground drift; pinned crossfade type sections; a
magnetic CTA; centred hero copy.

## 3. Typographic poster

Type is the imagery. Media is minimal or absent, scale contrast does the job
photography would have done.

**Forbids:** photographic ground, scrims, cards of any kind, decorative
motion. The typography floor tightens here rather than lifting: at extreme
scale default tracking is a visible defect.

## 4. Gallery / catalog

Objects in a walkable collection, each labelled with a single label schema.
Museum labels, not marketing copy.

**Forbids:** a single hero claim; persuasion in the object labels; the
argument-shaped pinned section. Card copy is read cropped for most of its
life, so the label schema has to survive being half visible.

## 5. Split stage

Two columns held in tension for the whole page, resolved by scroll. The
divider is the chrome, the close is the collapse of the divider to one edge.

**Forbids:** full-bleed anything before the resolve; centred copy; a
symmetric close.

## 6. Rhythmic cutlist

Short hard-cut sections at speed. No pinning, no dwell, no crossfades.

**Forbids:** any section over about 1.4 viewport-heights; pinning entirely;
overlapping cue windows; slow easing.

When this grammar bans the device the peak wants, move the peak into the
fixed chrome layer instead of breaking the grammar. The bans are on what the
sections do, not on what the page can do.

## Routed elsewhere

**Filmic one-shot** and **continuous world** both require video scrub. They
are not offered here; they belong to the cinematic path, built by
`/wp-cinematic-demo` and the cinematic-scroll-kit.

**Live surface** (the page behaves like the running product) is not offered
here either. It depends on a real, operable surface computing real state, and
`taste.md`'s refuse list already bans a fake dashboard or a fake terminal
standing in for one. A concept product that cannot actually run its panels
does not get this grammar; pick another.
