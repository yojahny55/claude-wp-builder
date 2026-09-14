# Hero depth

Ported from [nateherkai/scroll-craft](https://github.com/nateherkai/scroll-craft)
`references/hero-depth.md` (MIT), adapted for demo heroes built from the
composition library.

## Layering is the baseline, not a polish pass

**A beautiful full-screen photograph with one parallax transform and some text
fades can still feel flat.** Design a memorable spatial relationship in the hero
from the beginning rather than waiting to be asked for more depth. This is a
standing preference, and its absence is why a build whose brief said "impactful"
shipped a single image with a fade over it and satisfied nobody.

This applies to the hero, not to every section of every page. Honour an explicit
static direction when the brief gives one; a working surface such as a dashboard
does not need an invented marketing hero.

## Plan the depth before generating assets

- Identify the **background, focal subject, foreground** and any atmospheric
  layers. Name what moves independently, what overlaps, and what must stay
  physically connected.
- Give the visitor a clear visual payoff during a short scroll sequence: the
  camera moves into a scene, the headline recedes behind a subject, a second
  beat appears, the scene settles into the next section.
- **Layering must change perceived depth.** Several stacked elements moving as
  one image do not meet this rule. Use visibly different translation or scale
  rates, real occlusion, and near/far relationships. Neighbouring planes differ
  by 10–30%; copy always travels at 1×.
- Keep the opening composition compelling and the full headline readable. Do not
  sacrifice comprehension to prove a subject can cover text.

## Preparing compositing assets

Use supplied photography where it exists, and `bin/image-gen.mjs` where it does
not. For a photographic scene:

1. **Create a clean background plate** with the subject removed and the space
   behind it rebuilt. Otherwise the moving cutout exposes a duplicate person or
   an empty hole.
2. **Isolate the subject into a genuine alpha cutout.** Inspect the alpha
   channel — a generated checkerboard or a white backdrop is not transparency.
3. **Preserve framing, scale, lighting, colour and camera perspective.**
   Separately generated layers need measured alignment even when the prompt asked
   for identical placement.
4. **Keep shared contact points anchored.** A person stays on the rock, a product
   on its plinth, a wheel on the road. Shared translation plus a common
   contact-point pivot supports different layer scales without making the subject
   float.
5. **Inspect cutout edges** against contrasting backgrounds and through the
   motion. Remove matte halos, jagged edges, clipped fabric and foreground seams.

Atmosphere can occupy both a rear and a front plane. It should create separation,
not obscure the subject or wash out the frame.

## Choreograph restrained motion

- One coherent camera idea. **Premium is controlled movement and good timing, not
  constant movement everywhere.**
- Native sticky scrolling with independently transformed planes gives depth
  without WebGL or a video. Reach for heavier tools only when they improve the
  result.
- Essential copy and calls to action stay semantic HTML. Establish a deliberate
  layer order for typography, subject, foreground and atmosphere.
- Prefer compositable properties and one shared scroll-progress value. Do not
  re-render the page on every scroll tick.
- Pointer response is optional and must never be the only way to experience the
  hero. Never capture or lock the cursor.
- Honour reduced motion with a usable static composition — no extra pinned scroll
  space, no hidden essential content.
- **Load the scene's assets together** before switching from a complete poster
  fallback. A partial scene, a ghost subject or a broken hero when one layer
  fails is worse than no hero.

## Art-direct mobile separately

Do not merely shrink the desktop composition. Adjust crop, subject position,
contact-point pivot, type size, layer order, travel and scroll duration.
Typography may sit *above* the subject on mobile where it passes *behind* it on
desktop. Preserve depth without hiding the headline, pushing the subject
offscreen, or causing horizontal overflow.

**Scaling a wrapper is how a hero overflows a phone.** A scale on the frame moves
its border box; a scale on the image inside it does not. A measured build took 23
blocking overflow findings at 390px from one wrapper scale of 1.14 — `scrollWidth`
395 against a 390 viewport. Scale the image, rise the frame.
`html { overflow-x: clip }` is the backstop, and it is `clip` rather than
`hidden` because `hidden` makes the root a scroll container and kills the sticky
header.

## Acceptance

Inspect the actual opening, an intermediate scroll position, the final hero
transition, and the mobile composition. Check:

- Distinct layers visibly move at different rates.
- No duplicate subjects, holes, cutout halos, floating contact points or abrupt
  seams.
- The opening headline is readable, and the scroll produces a clear change in
  what the visitor sees or understands.
- The scene resolves cleanly into the next section.
- Mobile and motion-off states remain complete and usable.

**A green build is not proof the visual effect is good.** If visual verification
could not be performed, say so rather than claiming it was checked.
