# wp-template — Wiring a demo control to real data

The `wp-template` agent reads this when the section has a search box, filter dropdown, pager, tabs, accordion, "see more" link or any control that selects data.

## Wiring a Demo Control to Real Data

A static demo control (a search box, a filter dropdown, a pager, a "see more" link) is only
coherent because it was built against the same handful of mock values its cards show. Before
turning any such control from decoration into something that queries real content:

- **Grep the demo section for `MOCK:` and `data-mock` first.** The demo-authoring tooling
  writes these on exactly the controls it knows are not backed by real behaviour — a search
  form with no endpoint, a pager over a fully-rendered list, a filter whose options are not
  drawn from any real taxonomy. A control carrying either marker is never wired as-is: either
  re-derive it from the real query (a search that actually searches, a filter whose options
  come from `get_terms()` on the records this section queries — Rule 12: build options from
  real data, never from the demo's `<option>` values), or drop the control and say so in
  your report. Shipping a search box that posts
  nowhere, a pager that pages nothing, or a client-side filter checked against mock values
  the real cards don't carry is worse than shipping no control — it reads as broken rather
  than as absent.
- **An optional "see more" / CTA URL control renders only when the field holds a real
  `http(s)://` or site-relative URL.** A demo placeholder like `href="#anchor"` or
  `href="#noticias"` is not a destination; printing the control anyway ships a dead link.
  Check the field truthy AND shaped like a URL before rendering the `<a>`, and omit the whole
  control — not just style it disabled — when it is not:

  ```php
  $more_url = prefix_get_field('news_more_url');
  if ($more_url && preg_match('#^(https?://|/)#', $more_url)) : ?>
      <a class="news__more" href="<?php echo esc_url($more_url); ?>" target="_blank" rel="noopener nofollow">
          <?php prefix_e('see_more'); ?>
      </a>
  <?php endif; ?>
  ```
- **Never hardcode an example person, office or address in the template** to stand in for a
  relation the demo shows but the project has not seeded yet — a practice area's "handled by"
  lawyer, a service's "offered at" branch. If the relation is real but not yet in the
  database, that is a seeding gap: report it so it gets seeded (`inc/seed/`), never paper over
  it with a name and address typed into the PHP. A template that queries the real relation and
  gets nothing back renders nothing for that slot; it does not invent an answer.
