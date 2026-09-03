---
name: wp-demo-craft
description: Design floor, page grammars, scroll-motion device kit and anti-slop refuse list for premium demos. Read by /wp-demo in craft mode, /wp-yolo, /wp-cinematic-demo and /wp-demo-verify.
user-invocable: false
---

# Demo Craft

Adapted from nateherkai/scroll-craft (MIT), with the video-scrub devices removed
(those live in the cinematic path) and the token vocabulary changed to this
plugin's own.

## When this applies

Any demo built in craft mode, and every cinematic demo. `/wp-demo` records the
decision as `demo mode` in `.wp-create.json`; read it, do not re-derive it.

## The four spine rules

1. **Variety is the product.** A page uses at least **four device families**, and
   **never the same device** in two adjacent sections. Five sections that behave
   identically are one section shown five times.
2. **Structure is its own axis.** A different palette is not a different page.
   Pick a grammar from `references/grammars.md` before writing markup.
3. **The feeling comes before the sections.** Write the curve in
   `references/feel.md` first. A section list written first is always a list of
   things that happen.
4. **Real content only.** Real copy, real names, real numbers or no numbers.

## The brief

`demo/BRIEF.md` holds: brand rules; pain, person and promise; two or three named
references and what specifically to take from each; vibe words; aesthetic family;
assets already owned; the feeling curve; the peak as a friend-quotable sentence;
the "it's the site where ___" sentence; and any authored silence, so verification
can tell it from dead scroll. Self-author it from the project docs, mark anything
invented as "Self-authored, not interviewed", and ask only the questions the docs
cannot answer.

## Pre-build checks

- The grammar's bans hold.
- Four or more device families, and no family twice in a row.
- No two adjacent sections carry the same feeling.
- One peak, with visibly the largest span and a quieter section before it.
- The fingerprint gate passes against every registry row.

## Ship blockers

Never ship: a scroll cue or mouse icon; `01 / 06` counters; an eyebrow on every
heading; a visible em dash; centred copy in every section; the same device twice
in a row; no peak, or three; an ending that fades to nothing or simply becomes a
footer; a page with no signature move; a plan that clears fewer than four of the
six fingerprint dimensions; invented statistics; `transition: all`; animating
width, height, top or left; gradient text or neon glow; text baked into an image.

## References

Read `references/taste.md` before writing markup. Then `feel.md`, `grammars.md`,
`devices.md`, `fingerprint.md`. `verify.md` describes what `/wp-demo-verify`
measures.
