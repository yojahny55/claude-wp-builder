# process-rail

**Role:** process. A horizontal rail of steps travelling sideways while the frame
holds still. The heading sits above the rail inside the held frame, so it labels
the steps for the whole travel; the overflow the device needs comes from five or
more steps, never from the heading or from wider cards (`devices.md`, `pan`).

**Port of:** Aceternity "sticky scroll reveal", rewritten as the kit's `pan`
device. The original swaps a pinned panel as you scroll; this keeps the pin and
moves the content, which reads the same and costs one device instead of two.
**Licence:** Aceternity UI is MIT. No code was copied; the effect is reproduced.
**Motion cost:** 1.0 vh added. `data-motion-span="2.0"` on a section that is
`2 * 100vh` tall: two viewport-heights of scroll for one viewport-height of
section, so the page grows by one. This is the only composition in the library
that costs anything, and a page may carry one of it.

**Pick when:** the offer is a sequence of five steps or more and the client keeps
explaining it in order. Under five, use `process-flow`: a shorter rail travels
almost nothing and reads as a pin that failed.

**Slots:** kicker, title, lede, then `step_N_n` (`01`, `02`, ...), `step_N_title`,
`step_N_body` (25 to 45 words) for five steps or more; copy a `<li>` per extra step.

**Notes:** the height and the sticky frame are CSS, not engine: `data-motion-span`
only records the number for `/wp-demo-verify`. Travel is
`rail.scrollWidth - frame.clientWidth`, so five steps at 22rem overflow a 1440px
frame by about 650px; each further step adds about 400px. Never widen the cards
or move the heading into the rail to buy travel. Under
`prefers-reduced-motion` the engine turns the rail into a native horizontal
scroll region, so the section un-pins and the frame stops clipping.
