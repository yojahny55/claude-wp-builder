# testimonial-pair

**Role:** testimonial. Two quotes, not a carousel and not five. Two can be read
in one glance and compared; more becomes a slider nobody advances.

**Port of:** Aceternity "spotlight", reproduced with the kit's own `spotlight`
device: the engine publishes `--motion-mx` / `--motion-my` on the section and the
composition spends them in a single radial gradient.
**Licence:** Aceternity UI is MIT. No code was copied; the effect is reproduced.
**Motion cost:** 0 vh added. Devices: `spotlight` on the section, `reveal` on the
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
