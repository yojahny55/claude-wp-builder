# testimonial-pair

**Role:** testimonial. Two quotes, not a carousel and not five. Two can be read
in one glance and compared; more becomes a slider nobody advances.

**Port of:** Aceternity "spotlight", reproduced with the kit's own `spotlight`
device: the engine publishes `--motion-mx` / `--motion-my` on the section and the
composition spends them in a single radial gradient.
**Licence:** Aceternity UI is MIT. No code was copied; the effect is reproduced.
**Motion cost:** 0 vh added. Devices: `spotlight` on the section, nothing on the
grid. They are on different elements on purpose: an element carries one
`data-motion` value, and the spotlight has no scroll behaviour to give the quotes.

**Pick when:** two clients said something specific and are willing to be named.
Skip when the quotes are "great service, highly recommend"; an unattributed
compliment is worse than no section.

**Slots:** kicker, title, then per quote `quote_N` (20 to 45 words, one specific
claim), `quote_N_cite` (the URL the quote came from, for the `cite` attribute),
`name_N`, `place_N`.

**Notes:** the section declares its own `--motion-mx: 0.28` / `--motion-my: 0.3`
fallbacks, so the light is somewhere chosen before the first `pointermove` and on
every device that never sends one. The gradient lives inside
`(hover: hover) and (pointer: fine)`, per `devices.md`.

**Element motion:** self-sufficient, and the grid carries **no** `data-motion`.
A `reveal` there would `gsap.set()` opacity and y onto the quotes, which already
animate themselves — the collision rule in `../../references/devices.md`.
The children arrive on their own `view()`
ranges in `section.css`, so the root `data-motion="reveal"` is redundant here and
may be dropped to free `data-motion` for a section-level device (`drift`,
`parallax`, a pin). See "One attribute, one device" in
`../../references/devices.md`.
