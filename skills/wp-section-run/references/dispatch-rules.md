# /wp-section — Step 5

`commands/wp-section.md` sends the run here at Step 5 (the field naming convention, GEO citability, the transcription overlay, CSS agent routing and file ownership). Follow it in order; nothing in it is optional background.

## Contents

- Field naming convention
- GEO citability
- Transcription mode overlay (`--transcribe`)
- CSS agent routing
- File ownership

### FIELD NAMING CONVENTION (include in ALL agent prompts):

```
Field names:    <section>_<element>     (e.g., hero_title, hero_image)
Repeaters:      <section>_<plural>      (e.g., services_cards, team_members)
Subfields:      <element> only          (e.g., title, description, icon — NO section prefix)
Field keys:     field_<section>_<element>
Group keys:     group_<section>
```

### GEO CITABILITY (include in the prompts that write section copy)

Generative engines score the copy as well as people. When an agent authors or rewrites
section text, apply the rubric in `skills/wp-audit-geo-standards/references/citability.md`:

- Open each section with a direct 1–2 sentence answer before any elaboration.
- Keep extractable passages to 134-167 self-contained words; one idea per passage.
- Phrase H2s as questions the content answers.
- Use a table whenever three or more things are compared.
- Name sources and dates inline, and prefer first-party numbers over adjectives.

---

### TRANSCRIPTION MODE OVERLAY (only when `--transcribe` is set)

When `--transcribe` is present (the `/wp-yolo` path), layer these instructions onto every
agent prompt below. When it is absent, skip this overlay entirely — the agents run their
normal design-system authoring path unchanged.

- **wp-css:** append to its prompt the literal word **"transcribe"**, the `--css` source
  (the section's verbatim demo CSS — inline it, or tell the agent to read the given path),
  and the `--block` name. This activates wp-css **Transcription Mode** (see
  `agents/wp-css.md`): the demo CSS is the SOURCE OF TRUTH — copy its exact declared values
  and geometry, do NOT re-author, and scope every selector under `--block`.
- **wp-tailwind (tailwind path):** append the literal word **"transcribe"** here too, and
  state that the converted demo is the SOURCE OF TRUTH — the same mandate `wp-css` gets,
  because the job is the same one and only the notation differs. The utility classes on
  the converted demo ARE its declared values; carry them across character for character,
  do NOT re-author, and do not swap a utility for one you judge equivalent. Scope any
  `@apply` class under `--block`, exactly as `wp-css` scopes its BEM selectors. `wp-css`
  is not dispatched at all on this path.
- **wp-template (basic path):** instruct it to scope all BEM classes under the `--block`
  name (use `<block>__<element>` instead of `<section>__<element>`) so the transcribed
  CSS and the markup share the same unique block and parallel sections never collide.
- **wp-template (tailwind path):** there are no BEM classes to scope — the section HTML
  it is handed is already Tailwind-native, and it carries those utilities over
  unchanged. "Unchanged" is the whole contract, and it covers the element tree as much as
  the class attributes: every element the demo renders becomes an element in the template
  part, every class attribute is copied character for character, and every breakpoint
  variant (`max-md:`, `lg:`, `max-[1024px]:`) survives. Two sibling `<span>`s that swap at
  a breakpoint are two `<span>`s here, not one. Pass `--block` anyway, as the name for the
  section wrapper's own class, so the `@apply` promotion `wp-tailwind` may perform
  afterwards has a block to hang on.
- Because each section's `--block` is unique, parallel agents can never clash on a selector.
- **Fidelity covers markup and values, never a control's option set.** The demo's filters,
  selects and combos are coherent only because their options and their cards are the same
  mock values. Once the section is wired to real posts, those options become a claim about
  data: transcribing them literally is how a build ships a filter whose single value matches
  no record, so choosing it empties the grid. Tell `wp-template` to source every option from
  the real terms or field values, and to drop a control nothing backs — naming it in the
  summary, so the omission is reported rather than silent. The same carve-out covers the
  demo's empty-state and "no more results" strings: they are wording to translate and
  behaviour to re-derive from the real query, not constants to copy.

---

### CSS agent routing — read the template first

Read `Template:` from `.claude/CLAUDE.md`. When `Template:` is `tailwind`, dispatch
`wp-tailwind`; when it is `basic`, dispatch `wp-css`.

| Template | Agent 3 | Output surface |
|----------|---------|----------------|
| `basic` | `wp-css` | `assets/css/styles.css` (BEM + `:root` tokens) |
| `tailwind` | `wp-tailwind` in **author** mode | Utility classes in the markup; `@apply` rules only where the `wp-tailwind-system` ladder demands them |

Dispatch exactly one of the two. Never both — they write incompatible CSS systems.

**`--defer-promotion` suppresses Agent 3 on the `tailwind` path only.** When the flag is
set, do not dispatch `wp-tailwind`: `wp-template` has already written the section with
inline utilities, which is a complete and correct section — the `@apply` promotion is an
optimisation over the finished theme, and `/wp-yolo` Step 4.4 runs it once over every
template part after the walk. Report the section as built with promotion deferred so the
absence is not read as a missed dispatch. The flag never suppresses `wp-css` on `basic`:
there is no promotion step there and `wp-css` writes the section's only stylesheet, so
skipping it would ship an unstyled section.
Agents 1 (`wp-acf`) and 4 (`wp-cf7`) are identical on both paths. Agent 2
(`wp-template`) runs on both paths too, but its class-naming instruction differs — see
**File ownership** immediately below, which is the rule the rest of this command follows.

---

### File ownership — one writer per file, on both paths

| File | Written by | On `tailwind`, also edited by |
|------|-----------|-------------------------------|
| `fields/<name>.php` | `wp-acf` | — |
| `template-parts/section-<name>.php` | `wp-template` | `wp-tailwind`, class names only, afterwards |
| `assets/css/styles.css` | `wp-css` (`basic` only) | — |
| `components/…css`, `utilities/site.css`, `main.css` | — | `wp-tailwind` |

**`wp-template` owns `template-parts/section-<name>.php` on BOTH paths, and it is the only
agent that may create it.** It is the only agent carrying the ACF, escaping and i18n
contract — `prefix_get_field()`, the `?:` fallbacks, `esc_html()` / `esc_url()` /
`esc_attr()`, the `@package` header, the ABSPATH check. `agents/wp-tailwind.md` describes
none of them, so a section authored there ships with no ACF wiring, no escaping and no
i18n, and `/wp-finalize` then reports it as a bilingual failure.

What the `tailwind` path changes is the class system, not the owner: `wp-template` keeps
the Tailwind utility classes already on the section HTML it was handed — Step 2.6 of
`/wp-yolo` converted the demo before this walk, so they are there — instead of inventing
BEM names. Agent 2's prompt below carries that instruction.

**`wp-tailwind` in author mode runs AFTER `wp-template` returns, never beside it**, and
owns only four things: applying the `wp-tailwind-system` promotion ladder, creating the
`@apply` files the ladder demands, registering their `@import` in `main.css`, and renaming
the promoted groups inside the template part `wp-template` already wrote. Dispatched in
parallel with `wp-template`, the two write the same path and the last writer wins with no
error anywhere — and the loss is not symmetric, because `wp-tailwind` winning takes the
ACF wiring and the escaping with it.

The invariant, on both paths: **no section may ship without its ACF wiring and escaping,
and no section may ship on BEM class names in a Tailwind theme.**

The `tailwind` dispatch carries this line, verbatim, inside its quoted prompt — Agent 3's
block below already opens with it:

> Mode: **author**

`agents/wp-tailwind.md` gates Section Authoring Mode on that line and on nothing else. A
bare `author` anywhere else in the prompt — in prose, or inside an input path like
`demo/author.html` — selects nothing, so an ordinary demo page named after the word cannot
flip the mode by accident. Drop the line and the agent runs Demo Conversion Mode instead.

---
