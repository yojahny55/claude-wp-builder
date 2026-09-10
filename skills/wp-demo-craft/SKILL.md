---
name: wp-demo-craft
description: Reference-first design floor for premium demos: a client DESIGN.md, a composition library, a motion budget and a render-verified loop. Read by /wp-demo in craft mode, /wp-yolo, /wp-cinematic-demo and /wp-demo-verify.
user-invocable: false
---

# Demo Craft

Adapted from nateherkai/scroll-craft (MIT) for the feeling curve and the device
kit; rebuilt in v2 around finished design as context rather than a list of things
to avoid. v1 was a thousand lines of prohibition with no example of a good
section anywhere in it, and it shipped a 12,000px page whose first screen was an
empty dark field with the headline clipped mid-word. A build steered only by what
it must not do has nothing to steer towards.

## When this applies

Any demo built in craft mode, and every cinematic demo. `/wp-demo` records the
decision as `demo mode` in `.wp-create.json`; read it, do not re-derive it.

## Prerequisite

Craft mode needs a browser. Whichever command enters it — `/wp-demo` Step 2.6 or
`/wp-yolo` Step 2 — runs
`node ${CLAUDE_PLUGIN_ROOT}/bin/demo-verify.mjs --probe` before writing markup,
and only exit 0 continues. A craft build is never made blind and never falls back to
plain: an unverified craft page is the one that reaches the client.

## The two spine rules

1. **Real content only.** Real copy, real names, real numbers or no numbers. An
   invented statistic is a liability, not a design element.
2. **One peak.** Visibly the largest change on the page, with a quieter section
   before it, and the most scroll room. Two peaks is none.

## The order of work

1. **`demo/DESIGN.md`** from the client docs, `designlang` on their site and
   named references, then the nearest catalogue matches for the gaps
   (`references/design-md.md`). The demo's `:root` is generated from it, so this
   file is written before any markup. Check it against the registry before
   building, not after (`references/fingerprint.md`): a palette that fails the
   gate is cheap to change now and a rebuild later.
2. **`demo/BRIEF.md`**: person, pain, promise, vibe words, references, the
   feeling curve, the peak sentence, and any authored silence so verification can
   tell it from dead scroll (`references/feel.md`). Self-author it from the
   project docs, mark anything invented as "Self-authored, not interviewed", and
   ask only what the docs cannot answer.
3. **Grammar, then composition plan.** Pick one grammar from
   `references/grammars.md` — it decides what a section is, what the chrome is
   for and what the ending does, and compositions are chosen inside it, not
   instead of it. Then one row per section — section, role, composition, why,
   motion cost, and the domain signal that justified it, citing the brief
   constraint from domain classification, or writing "no domain signal" when
   none applies (this is what makes the classification bind on the plan instead
   of sitting unread) — from the role table in `compositions/README.md`
   (`references/compositions.md`). That row format is stated in these same terms
   `/wp-demo` Step 2.6 uses on purpose — do not restate it a third way. Sum the
   motion cost before building and hold it under the budget in `devices.md`.
4. **Build** from the compositions, the tokens and the real copy.
5. **Loop** until the rubric passes or three rounds are spent
   (`references/verify.md`).
6. **Record** the fingerprint row, only for a passing build
   (`references/fingerprint.md`).

## Ship blockers

Never ship: content hidden behind a scroll trigger in the first viewport; a page
over the motion budget in `devices.md`, which owns the pin caps, the total and
the interior-page rule and is the only place they are written down; a hardcoded
hex where a token exists; invented statistics; a `slop` finding from
`impeccable detect`; a build that failed the rubric after three rounds.

- A placeholder image, a placeholder logo, or the words "pending", "placeholder"
  or "TBD" in rendered text. Spine rule 1 covers copy; this covers everything
  else the reader sees. A build once rendered "HERO PHOTOGRAPH PENDING" as its
  hero's primary visual and passed "First paint complete", which asks only that a
  primary visual be present.

## References

Read `references/taste.md` (the floor), then `design-md.md`, `feel.md`,
`compositions.md`, `grammars.md`, `devices.md`, `fingerprint.md`, `verify.md`.
