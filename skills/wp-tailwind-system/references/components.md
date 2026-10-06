# Cards and Starter Modules

From the `wp-tailwind-system` skill: two component contracts a template part must carry
exactly.

## Cards pin their footer with `mt-auto`, and the template part keeps it

A card in a row of cards has a footer (price, CTA, "read more") that sits on one line
across the row, whatever the length of each card's text. That is a flex chain, and every
link of it is a class the template part must carry:

```html
<ul class="grid md:grid-cols-3 gap-6">
  <li class="h-full">                                  <!-- grid cell stretches -->
    <article class="flex flex-col h-full ...">         <!-- the card is a column -->
      <h3>...</h3><p>...</p>
      <div class="mt-auto pt-6 flex items-center justify-between">  <!-- footer pinned -->
        <span>price</span><a href="...">CTA</a>
      </div>
    </article>
  </li>
</ul>
```

Drop any one class and the footers float at different heights. It does not show in a
single card, or in a demo whose mock texts are all the same length, so it survives a
review by eye. **Carry every layout utility from the demo section into the template part
(`flex`, `flex-col`, `h-full`, `mt-auto`, `grow`, `self-*`, `order-*`);
never re-derive the layout.** A wrapper the template part adds (the loop's `<li>`, a
`get_template_part()` boundary) must not break the chain: it gets `h-full` or `flex` too.

## Tabs, accordions and directory filters come from the starter's modules

The `__tailwind__` starter ships three behaviour modules in `assets/js/src/`, imported by
`index.js`. A section that shows tabs, an accordion or a directory filter writes the markup
contract in the module's header comment and **no script of its own**: a hand-made copy
drifts — tabs that move the underline and never switch a panel, a directory with no results
count and no "clear filters".

| Pattern | Markup hook | Module | Contract in short |
|---|---|---|---|
| Tabs | `[data-tabs]` > `role="tablist"` > `role="tab"` + `role="tabpanel"` | `tabs.js` | `aria-selected` + `is-active` on the selected tab, other panels `hidden`, arrows/Home/End, `[data-tabs-marker]` as wide as the active tab's `[data-tab-label]` |
| Accordion | `[data-accordion="single\|multiple"]` > `[data-accordion-trigger][aria-controls]` | `accordion.js` | FAQ list = `single` (the default); a trigger outside any group is a standalone fold that rests open and toggles on its own; state on `aria-expanded`, panel `hidden`, item `is-open` |
| Directory filter | `[data-directory]` with `[data-filter-text]`, `[data-filter="<key>"]`, `[data-filter-count]`, `[data-filter-clear]`, `[data-filter-item]` | `directory-filter.js` | count line from `data-count-template` (`{count}`), hidden while unfiltered; clear resets every control and reloads without the URL's filter parameters |

Style state from the attributes the modules set, never from `:focus`: the active tab is
`aria-selected:text-accent` (or `.is-active`), and the chevron rotates from the trigger with
`group` on the button and `group-aria-expanded:rotate-180` on the icon. Every visible string
(tab labels, the count templates, "clear filters", the empty message) goes through the
theme's i18n helper in the template: the modules contain no literals.

**A filter's GET parameter is never a public query var.** A CPT or taxonomy slug is one:
`?<slug>=x` makes WordPress query that object and answer with its archive or a 404 before
the template runs. Name the parameter something no registered type or taxonomy uses.

Run the module gate (the script's `widgets` rule) after writing the markup — it fails a
theme whose templates carry a hook without its module imported:

```bash
node "${CLAUDE_PLUGIN_ROOT}/bin/theme-template-check.mjs" <theme-dir> --rule widgets
```

Needs Node. Exit 0 = pass, 1 = a `FAIL:` line per finding (import the named module in
`assets/js/src/index.js` and run it again), 2 = usage (no theme directory given).
