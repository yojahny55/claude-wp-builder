# /wp-demo — Step 4.9

`commands/wp-demo.md` sends the run here at Step 4.9. Follow it in order; nothing in it is optional background.

## Contents

- Both modes, every run: `demo/.demo-plan.json`
- Its shape
- Write it while authoring, or do not write it
- Unique section names, and the slots craft mode records


**Both modes, every run, after the last page is written.** Write
`demo/.demo-plan.json` — the record of what this command *decided*, so `/wp-yolo`'s
normalize pass reads those decisions instead of re-deriving them from the markup:

```jsonc
{
  "generator": "wp-demo",
  "mode": "craft" | "plain",
  "at": "<ISO 8601 date>",
  "pages": [
    {
      "slug": "index",
      "role": "home" | "inner" | "cpt-archive" | "blog",
      "sections": [
        { "name": "<the delimiter's name, verbatim>",
          "kind": "static" | "contact" | "cpt-teaser",
          "cpt": "<string — only when kind is cpt-teaser>",
          "block": "<the section's unique BEM block>" }
      ],
      "cpt": "<string — only on a cpt-archive page>"
    }
  ],
  "contentTypes": [ { "name": "team", "teaserPage": "index", "archivePage": "team" } ],
  "inert": [
    { "selector": ".site-head__lang", "reason": "language switcher",
      "needs": "pll_the_languages", "pages": [ "*" ] }
  ]
}
```

`name` must match the page's `<!-- ============ SECTION: X ============ -->`
delimiter **verbatim** — it is the join key, and a plan whose names do not match
its own markup is discarded rather than trusted.

**`inert[]` is the demo's declared inventory of controls it fakes.** A mockup's
language switcher is two `href="#"` links with `aria-current` hardcoded on one of
them; a search box filters nothing; a pager is client-side and the server will own it
in the theme. **None of that is a defect in a demo** — it is a defect the moment a
builder reads the demo as a specification, which is exactly what `/wp-yolo` does. The
control is fine; what is missing is that nothing on disk says it is a mockup, so every
downstream reader has to rediscover it and only one of them will.

**A `<form>` with `action="#"` or no `action` is inert by the same test as a link with
`href="#"`, and it is the more consequential of the two.** A dead switcher announces
itself the moment someone clicks it; a dead contact form looks like it worked and
silently drops the lead. Demo forms reach this state while looking thoroughly wired — a
real consent checkbox, a real honeypot, a real preferred-language select, and an
`action` pointing at the page it sits on. Grep for `action` as well as `href` before
declaring the list complete. Where two pages carry byte-identical form markup, say so in
`needs` — they must render the *same* CF7 instance, or the build emits duplicate element
ids across two pages and two form records where the client expects one.

One entry per faked control: the `selector` that finds it, the `reason` a human reads,
`needs` — what wiring it takes at build time — and the pages it appears on (`["*"]`
for chrome). `/wp-demo-verify` Step 3.5 checks the *declaration* rather than the
control, so declaring one is the cheap path; `/wp-yolo` Step 4.6 and `/wp-header` read
the list as a worklist instead of hoping a `review[]` entry is noticed among forty-seven
others.

**Write it while authoring, or do not write it.** Backfilled by inspecting finished
markup it degrades into "controls we could not prove were wired", which is the guess
this file exists to remove. The demo's author is the only one who knows the difference
between *the demo fakes this* and *the build forgot this*.

**A section name is unique within its page**, therefore. The compositions ship
generic names in their delimiters (`Hero`, `Features`, `FAQ`), so a page using
`feature-zigzag` twice writes two sections called `Features`, which is a name that
addresses two things: the plan cannot join on it, `block` collides, and
`/wp-section Features` extracts whichever one it met first. Rename the second at the
point of use — `Features (integrations)`, or whatever it is actually about — in the
delimiter and in the plan alike.

Nothing here is an analysis result. A section is `contact` because this command
put a form in it, `cpt-teaser` because it built a teaser for a collection the
brief named and gave it a listing page, `static` otherwise; `block` is the class
this command already chose while writing the CSS; in craft mode the whole table is
the composition plan from Step 2.6 sub-step 5, one row per section. Do not infer
any of it from the finished HTML — if a value has to be re-read off the page, it
belongs in the manifest `wp-normalize` builds, not here.

**Craft mode also records the slots it filled**, as `sections[].slots[]`, because a
composition's slot names are already field-shaped names this command *chose* —
`feature_1_image_src` is not a guess anyone should have to re-derive from the finished
`<img>`. One entry each: `{ "name", "group": "fixed" | "<repeater name>", "computed": true|false }`.

Two of those keys carry the whole value, and both come from a build that got them wrong:

- **`group` distinguishes a repeater from a run of flat fields.** A chat-mock section
  with seven slots is not seven fields; it is one repeater whose rows differ by a
  `variant`. Slot names alone produce seven flat fields and a template that hardcodes
  their order, which no editor can then reorder or extend.
- **`computed: true` marks a value the markup derives rather than the author writing
  it** — an arc's `stroke-dasharray` encoding a band's share of a 300–850 scale, for
  instance. Offered as a field, it puts `0.5082 0.4918` in an admin box for a client to
  edit. It must reach the build as a fact about the markup, not as content.

Keys deliberately absent: field *values*, assets, `cssRules`, `fonts`,
`backgrounds`, `computed` dimensions. Those are read off the markup, by one agent, in
one place. A second copy here would be a second thing to keep true. The split is that
this command records what it *named*, and `wp-normalize` reads what the page *says*.

A section built by hand rather than from a composition has no slots to record; omit the
key for it and let normalize infer its fields as before.
