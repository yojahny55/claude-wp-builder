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

## The project's brief outranks this skill

Read the project's `.claude/CLAUDE.md` before the rules below, and treat anything
it records as a client decision as **binding over every default here**. This skill
is a floor for a build with no instructions. It is not an argument against
instructions the client actually gave.

That precedence was missing, and the cost of missing it is the reason this section
is first. A project whose `.claude/CLAUDE.md` carried, in `/wp-context`'s own
words, *"the client wants an impactful animated website — hero entrance,
scroll-reveal on section blocks, animated counters, animated step/timeline,
before/after score chart animation, hover micro-interactions"* shipped with one
animation and eleven pages of prose. Every item on that list was later reported as
missing by the person who had asked for it in the first place. Nothing had failed
to capture the direction; the direction was captured well, and these rules
overrode it, because nothing said they must not.

So: where the recorded brief asks for motion, graphics, density or a treatment
this skill discourages, **the brief wins and the discouragement does not apply.**
Say in `demo/BRIEF.md` which default the brief overrode and why. A rule here that
contradicts a recorded client decision is not a standard being upheld — it is a
build ignoring its client.

The two spine rules below are the exception, and they are the only one: honest
copy and a verified render are not preferences a brief can trade away.

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
   ask only what the docs cannot answer. When `demo/RESEARCH.md` exists, each of
   person, pain and promise either
   **cites the `demo/RESEARCH.md` line and its source URL, or keeps the marker**
   — and the marker now means something, because there was an alternative.
3. **Grammar, then composition plan.** Landing on the default grammar
   requires one sentence in `demo/BRIEF.md` per grammar that was rejected
   (`references/uniqueness.md` §3) — impossible to write honestly when the
   default is not right, which is the whole mechanism. **No two pages of one
   demo may share their whole composition sequence**, and the home page's
   sequence may not be a superset of an interior page's (§2): two pages
   sharing a header and a footer is a site, two pages sharing their middle is
   a template. Pick one grammar from
   `references/grammars.md` — it decides what a section is, what the chrome is
   for and what the ending does, and compositions are chosen inside it, not
   instead of it. Then one row per section — section, role, composition, why,
   motion cost, the domain signal that justified it, citing the brief
   constraint from domain classification, or writing "no domain signal" when
   none applies (this is what makes the classification bind on the plan instead
   of sitting unread); and the research signal — what `demo/RESEARCH.md`'s
   `## Signals` says this sector does at this point in the page, and whether
   this row follows it or breaks it — or "no research signal" when none
   applies — from the role table in `compositions/README.md`
   (`references/compositions.md`). That row format is stated in these same terms
   `/wp-demo` Step 2.6 uses on purpose — do not restate it a third way. Sum the
   motion cost before building and hold it under the budget in `devices.md`.
4. **Build** from the compositions, the tokens and the real copy. Before the first section, record the
   **signature move** in `demo/BRIEF.md` — one bespoke interaction that
   exists on this site alone, not a parameter change to a library device
   (`uniqueness.md` §4) — and the **world preamble** chosen from
   `worlds.md`, pasted verbatim into every image prompt so separately
   generated plates look like one shoot. The hero is layered by default:
   `hero-depth.md`.
5. **Loop** until the rubric passes or three rounds are spent
   (`references/verify.md`).
6. **Record** the seven-dimension fingerprint row, only for a passing build
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
- Anything on the chosen family's **Avoid list**, read from `demo/BRIEF.md
  ## Family` (`references/families.md`). Verify reads every page against that
  list before the rubric; a hit is a fail, not a grade, because a brutalist page
  with one glass card is a page that chose two families, and a page that chose
  two chose none.

## References

Read `references/taste.md` (the floor), then `design-md.md`, `feel.md`,
`compositions.md`, `grammars.md`, `devices.md`, `fingerprint.md`, `verify.md`.

Then the three that decide whether this build resembles the last one:
`uniqueness.md` (the template trap, the signature move, the aesthetic
families) with `families.md` (what each family does and forbids),
`hero-depth.md` (layering is the baseline, not a polish pass) and `worlds.md`
(one style preamble, prepended verbatim to every image prompt by
`image-gen.mjs`).

Those three were absent for several releases while every constraint file was
present, and the shape of what shipped followed exactly: builds that obeyed
every rule, resembled each other, and were reported as "all the pages are
almost the same thing". A skill made only of floors produces the floor.
