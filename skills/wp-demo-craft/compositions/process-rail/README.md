# process-rail

**Role:** process. A horizontal rail of steps travelling sideways while the frame
holds still. The heading is the first item on the rail, not a title above it,
which is what buys the overflow the device needs without widening the cards.

**Port of:** Aceternity "sticky scroll reveal", rewritten as the kit's `pan`
device. The original swaps a pinned panel as you scroll; this keeps the pin and
moves the content, which reads the same and costs one device instead of two.
**Licence:** Aceternity UI is MIT. No code was copied; the effect is reproduced.
**Motion cost:** 1.0 vh added. `data-motion-span="2.0"` on a section that is
`2 * 100vh` tall: two viewport-heights of scroll for one viewport-height of
section, so the page grows by one. This is the only composition in the library
that costs anything, and a page may carry one of it.

**Pick when:** the offer is a sequence and the client keeps explaining it in
order. Skip when there are fewer than three steps; a two-item rail travels almost
nothing and reads as a pin that failed.

**Slots:** kicker, title, lede, then `step_N_n` (`01`, `02`, ...), `step_N_title`,
`step_N_body` (25 to 45 words) for three to five steps.

**Notes:** the height and the sticky frame are CSS, not engine: `data-motion-span`
only records the number for `/wp-demo-verify`. Travel is
`rail.scrollWidth - frame.clientWidth`, so with four steps at 22rem plus a 26rem
intro the rail overflows a 1440px frame by roughly a viewport; if a build drops to
three steps, widen the intro rather than the cards. Under
`prefers-reduced-motion` the engine turns the rail into a native horizontal
scroll region, so the section un-pins and the frame stops clipping.
