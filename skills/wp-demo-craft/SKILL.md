---
name: wp-demo-craft
description: Defines the craft-mode design floor for client demos — demo/DESIGN.md tokens, demo/BRIEF.md with its feeling curve and one peak, the composition library and its role table, the data-motion device budget, the aesthetic family and its Avoid list, the signature move, the fingerprint gate against earlier builds, generated image plates, and the seven-line verify rubric with its static-page and dead-scroll findings. Use when a project records demo mode craft and a demo is built, rebuilt, audited or verified with /wp-demo, /wp-yolo, /wp-cinematic-demo, /wp-demo-verify or /wp-polish --craft. Not for plain-mode demos (wp-demo), AOS scroll animation (wp-aos-animator), or ACF fields and template parts (/wp-section).
user-invocable: false
---

# Demo Craft

Adapted from nateherkai/scroll-craft (MIT) for the feeling curve and the device kit, and
built around finished design as context — compositions to steer towards — rather than a
list of prohibitions. A build steered only by what it must not do has nothing to steer
towards: the version that tried shipped a 12,000px page whose first screen was an empty
dark field with the headline clipped mid-word.

## The project's brief outranks this skill

Read the project's `.claude/CLAUDE.md` before the rules below, and treat anything it records
as a client decision as **binding over every default here**. This skill is a floor for a
build with no instructions, not an argument against instructions the client gave. A project
whose brief asked for an animated site — counters, a timeline, a before/after chart — once
shipped with one animation, because these rules overrode the brief and nothing said they
must not.

So: where the recorded brief asks for motion, graphics, density or a treatment this skill
discourages, **the brief wins and the discouragement does not apply.** Say in
`demo/BRIEF.md` which default the brief overrode and why. The two spine rules below are the
only exception: honest copy and a verified render are not preferences a brief can trade away.

## When this applies, and who runs it

Any demo built in craft mode. `/wp-demo` records the decision as `demo mode` in
`.wp-create.json`; read it, do not re-derive it.

This skill holds the decisions and the artifacts. The step order and its gates are run by
`/wp-demo` Step 2.6 and `/wp-yolo` Step 2, and `/wp-demo-verify` runs the verify loop; read
the order of work below alongside whichever of them is running.

A **cinematic** build (`/wp-cinematic-demo`, the `wp-cinematic` agent) takes the brief rule,
the spine rules, `taste.md`, `feel.md`, `fingerprint.md` and the `impeccable` gate in
`verify.md`. The composition library, the device kit, the families and the image plates do
not apply there: the cinematic-scroll-kit owns video, scenes and their motion.

## Prerequisite

Craft mode needs a browser. Whichever command enters it runs
`node ${CLAUDE_PLUGIN_ROOT}/bin/demo-verify.mjs --probe` before writing markup, and only
exit 0 continues. A craft build is never made blind and never falls back to plain: an
unverified craft page is the one that reaches the client.

## The two spine rules

1. **Real content only.** Real copy, real names, real numbers or no numbers. An
   invented statistic is a liability, not a design element.
2. **One peak.** Visibly the largest change on the page, with a quieter section
   before it, and the most scroll room. Two peaks is none.

## The order of work

Copy this checklist into the build log and tick it as each artifact exists:

```
- [ ] 1. demo/DESIGN.md written, and checked against the fingerprint registry
- [ ] 2. demo/BRIEF.md: person, pain, promise, curve, peak, family and its Avoid list
- [ ] 3. grammar chosen; composition plan written; motion cost summed under budget
- [ ] 4. signature move and world preamble in BRIEF.md; every page built
- [ ] 5. verify loop passed (at most three rounds), or demo/FAILED.md written
- [ ] 6. fingerprint row recorded (passing builds only)
```

1. **`demo/DESIGN.md`** from the client docs, `designlang` on their site and named
   references, then the nearest catalogue matches for the gaps (`design-md.md`). The
   demo's `:root` is generated from it, so it is written before any markup. Check it
   against the registry now (`fingerprint.md`): a palette that fails the gate is cheap to
   change before the build and a rebuild after it.
2. **`demo/BRIEF.md`**: person, pain, promise, vibe words, references, the feeling curve,
   the peak sentence, and any authored silence so verification can tell it from dead
   scroll (`feel.md`); the chosen family under `## Family` with its Avoid list
   (`families.md`). Self-author it from the project docs, mark anything invented as
   "Self-authored, not interviewed", and ask only what the docs cannot answer. When
   `demo/RESEARCH.md` exists, each of person, pain and promise either **cites the
   `demo/RESEARCH.md` line and its source URL, or keeps the marker**.
3. **Grammar, then the composition plan.**
   1. Pick one grammar (`grammars.md`). Landing on the default grammar requires one
      sentence in `demo/BRIEF.md` per grammar rejected (`uniqueness.md` §3).
   2. Classify the domain, once. If `.wp-create.json` already has `"domain"`, use it.
      Otherwise a row of `references/domains/domains.csv` matches when two distinct
      keywords from its list appear in the client documents or `demo/RESEARCH.md`; the
      highest count wins, and a tie or no match is `unclassified`. Record the result under
      `"domain"`. A match folds its `page_pattern` and `considerations` into the brief as
      constraints, and never touches tokens.
   3. Write one row per section, every page, in the format `compositions.md` gives —
      including the domain signal that justified the choice (or "no domain signal") and
      the research signal (or "no research signal") — choosing from the role table in
      `compositions/README.md`.
   4. Read the per-page sequences down the plan: **no two pages of one demo may share
      their whole composition sequence**, and the home page's may not be a superset of an
      interior page's (`uniqueness.md` §2).
   5. Sum the motion cost and hold it under the budget in `devices.md`.
4. **Build** from the compositions, the tokens and the real copy. Before the first
   section, record the **signature move** in `demo/BRIEF.md` (`uniqueness.md` §4) and the
   **world preamble** chosen from `worlds.md`, which `image-gen.mjs` prepends verbatim to
   every plate prompt. The hero is layered by default (`hero-depth.md`).
5. **Loop** until the rubric passes or three rounds are spent (`verify.md`).
6. **Record** the fingerprint row, only for a passing build (`fingerprint.md`).

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
  ## Family` (`families.md`). Verify reads every page against that
  list before the rubric; a hit is a fail, not a grade, because a brutalist page
  with one glass card is a page that chose two families, and a page that chose
  two chose none.

## References

Read each file when its moment comes, not all of them up front. Paths are under
`${CLAUDE_PLUGIN_ROOT}/skills/wp-demo-craft/`.

| File | What it holds | Read when |
|---|---|---|
| `references/taste.md` | The taste floor: spacing, type, colour, depth, cards, UI motion, copy | Before writing any markup |
| `references/design-md.md` | `demo/DESIGN.md`: source order, motion tokens, the token names `:root` is generated onto | Step 1 |
| `references/design-md/INDEX.md` | One row per catalogue brand: industry, tone, display face, accent | Step 1, when the client's material leaves gaps; then read only the two or three rows chosen |
| `references/fingerprint.md` | The registry, the seven dimensions, the 4-of-7 gate, the same-client rule | Step 1 against the palette, step 3 against the plan, step 6 to record |
| `references/feel.md` | The feeling curve, the peak, the tell-someone sentence, pacing, the cold feel check | Step 2, and again after the verify harness |
| `references/families.md` | The seven aesthetic families: reads as, earned by, type, palette, surfaces, motion, Avoid list | Step 2, when choosing the family |
| `references/grammars.md` | The page grammars and what each forbids | Step 3.1 |
| `references/uniqueness.md` | The template trap, the within-build rule, the default-grammar burden, the signature move | Step 3, before the plan; §4 before the build |
| `references/domains/domains.csv` | Product categories: keywords, landing-page pattern, considerations; provenance and what was refused in `references/domains/README.md` | Step 3.2 |
| `references/compositions.md` | How to choose a composition, the plan row format, when to deviate | Step 3.3 |
| `compositions/README.md` | The role table with each composition's motion cost, and the composition contract | Step 3.3, and its previews before choosing |
| `references/devices.md` | The `data-motion` contract, element motion, the devices, the cue contract, the budget | Step 3.5 and whenever a section moves |
| `references/hero-depth.md` | Layered heroes: planes, compositing assets, mobile art direction | Step 4, when building a hero |
| `references/worlds.md` | Eight world preambles for generated plates | Step 4, when any slot gets a generated plate |
| `references/image-prompt.md` | The plate prompt skeleton, the `SUBJECT` line, and how `image-gen.mjs` is run | Step 4, when writing a plate's prompt |
| `references/verify.md` | The round structure, measuring a moving page, the rubric, the machine findings | Step 5 |
