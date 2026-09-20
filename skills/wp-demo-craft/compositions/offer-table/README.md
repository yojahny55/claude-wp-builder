# offer-table

**Role:** offer. A real `<table>`, because a price list is tabular data and three
cards side by side are a table that lost its row headers. Comparing across a row
is the job, and only a table does it.

**Port of:** none.
**Licence:** plugin (MIT).
**Motion cost:** 0 vh added. Devices: none on the block — the head, the plans
and the footnote each arrive on their own `view()` range in `section.css`.

**Pick when:** the client sells named tiers with the same features priced
differently. Skip when there is one price, or when the price is "it depends";
either of those is a paragraph, not a table.

**Slots:** kicker, title, lede, table_caption, then per plan `plan_N_name`,
`plan_N_price`, `plan_N_note`, `plan_N_cta`/`plan_N_href`, and per row
`row_N_label` plus one cell per plan. footnote for the terms that would otherwise
become invented small print.

**Notes:** two plans, not three. Three plan columns plus a row-label column need
more width than a phone has, so the table would scroll sideways on every 390px
screen; two fit without one, and `.offer-table__scroll` stays as a safety net for
long labels. Add a third `<col>`, a third `<th>` and a third cell per row if the
client genuinely has three, and accept the scroll. The lead column is marked by a 1px accent rule across
its top and a `--color-surface` ground carried by the `<col>` element, with no
"Most popular" badge anywhere: the rule says which one they mean without
shouting it.

**Element motion:** self-sufficient, and the root carries **no** `data-motion`.
The children arrive on their own `view()` ranges in `section.css`, so a root
`reveal` would not add motion — it would take it away. `reveal` does
`gsap.set(kids, {opacity, y})` on exactly these elements, which is a second
writer on the properties the CSS is already animating, and the two resolve
differently in a demo and in a theme: the demo wins that race and the theme
loses it, freezing each child at its keyframe's start value. This composition
shipped with that attribute and the defect reached a client's every interior
page. `data-motion` here is free for a section-level device (`drift`,
`parallax`, a pin) — see "One attribute, one device" and the collision rule in
`../../references/devices.md`.
