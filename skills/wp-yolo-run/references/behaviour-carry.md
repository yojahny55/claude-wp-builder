# /wp-yolo — Step 4.6

`commands/wp-yolo.md` sends the run here at Step 4.6. Follow it in order; nothing in it is optional background.

Enumerate the demo's scripts before writing anything:

```bash
ls demo/js/*.js demo/**/*.js 2>/dev/null
grep -rho 'src="[^"]*\.js"' demo/*.html | sort -u
```

Then account for **every** one:

- **Shared chrome** (nav, drawer, language pill, sticky rails) → the chrome
  module the header/footer build already created.
- **Section behaviour** (carousels, galleries, listboxes, filter panels,
  accordions, tabs, share menus) → one module per behaviour in
  `assets/js/src/sections.js`, each binding to nothing when its markup is
  absent, so any page can load the one bundle.
- **Duplicated-in-every-page code.** A demo with no shared footer copies the
  same block into all eleven page scripts. It belongs in the theme once, not
  eleven times — check the top of each page script before assuming a script is
  page-specific.
- **Deliberately NOT ported:** anything the server now owns. Client-side
  filtering, client-side pagination and client-side facet counts fought a real
  `WP_Query` for the same state — the facets, sort lists and pager are real
  links now. Say so in the module's header comment so the omission is not read
  as an oversight and "restored" later.
- **User-visible strings** inside the ported JS go through the theme's
  translation helper and ride on the localized data object. A string frozen
  into the bundle cannot be translated and cannot be edited by the client.
- **Guard every lookup.** The demo knows its own markup exists; a WordPress page
  does not — no menu assigned, an empty repeater, a missing `aria-controls`
  target. An unguarded dereference throws and takes the rest of the bundle with
  it.

**A script is not the only thing that can be missing.** `demo/.demo-plan.json`'s
`inert[]` is the demo's own list of controls it faked — a language switcher that is two
`href="#"` links, a search box that filters nothing — each with the `needs` line saying
what wiring it takes here. Read it as a worklist: every entry is either built in this
step (or by the chrome build, for a `pages: ["*"]` entry) or carried into the Step 6
Review list by name. It exists because a faked control has no script to enumerate, so
the walk above cannot see it: on one build the switcher was wired only because a
normalize agent happened to file it among forty-eight `review[]` entries, which is luck
and does not scale to the next demo whose fake control sits further down the page.

Verify in a real browser before Step 5, one page per behaviour: click a
carousel arrow, open a listbox, open the filter drawer, open the gallery, and **use
every `inert[]` entry** — a switcher that still goes nowhere is the one defect in this
step that renders perfectly. A console with zero errors is not evidence — dead code
logs nothing.
