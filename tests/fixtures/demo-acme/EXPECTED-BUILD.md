# Expected `/wp-yolo` Phase 2 Build Trace — demo-acme

Hand-traced build order for `/wp-yolo tests/fixtures/demo-acme` over
`EXPECTED-MANIFEST.json`, per `commands/wp-yolo.md` Step 4 ("Phase 2 — Build").
No agents were run; this is the order the orchestrator's documented steps
produce when read against this specific manifest.

## Phase 1 + checkpoint (for context, not build order)

1. `wp-normalize` dispatched against `tests/fixtures/demo-acme` → emits
   `demo/*.html` + `demo/.yolo-manifest.json` (== `EXPECTED-MANIFEST.json`).
2. Checkpoint (default mode, no `--yolo`): prints pages/sections/confidence,
   shared header/footer flags, `contentTypes[]`, and the `review[]` list above.
   User approves as-is (no edits needed for this trace).

## Phase 2 — Build, in the exact order `wp-yolo.md` Step 4 specifies

1. **`/wp-settings`** — logo "Acme Co", nav links, footer copyright text,
   contact email/message labels — derived from header/footer/contact content.

2. **CPTs first — `contentTypes[]` loop:**
   - `/wp-cpt team --from-demo team-teaser` — registers the `team` CPT
     (`has_archive: true`), fields (`photo`, `role`, `bio`; title = person name),
     `archive-team.php`, `single-team.php`, `template-parts/team/card.php`,
     the `team` teaser query-section (`template-parts/section-team.php` +
     `fields/section-team.php`, injected into `front-page.php`), and the seed
     helper `inc/seed/team.php` for the 6 `seed[]` entries.
   - **NO `--no-teaser`** here: `contentTypes[0].hasTeaser == true` AND a
     `kind: cpt-teaser` section (`team-teaser`, `cpt: team`) exists, so `/wp-cpt`
     OWNS and builds the teaser `template-parts/section-team.php` (named for the
     CPT `team`, not the manifest section name `team-teaser`).
   - **This step MUST complete before any section that queries `team`.**
     It runs before the home page's `team-teaser` section (step 5 below) and
     before `archive-team.php` is treated as "already built" in step 7 — both
     of which depend on the CPT being registered and its teaser/card templates
     existing first. Confirmed: CPT loop is step 2, home sections are step 5.

3. **`/wp-header`** — shared header (identical across all 5 pages, per
   `shared.header: true`, `headerDivergentPages: []`) → `header.php` +
   nav-walker + registered "primary" menu (Home/About/Team/Services/Contact).

4. **`/wp-footer`** — shared footer (identical across all pages,
   `shared.footer: true`, `footerDivergentPages: []`) → `footer.php`.

5. **Home page sections** (`pages[slug=index, role=home].sections[]`, in order):
   1. `hero` → `kind: static` → normal `/wp-section hero`
      (defaults: `--page index`, `--target front-page.php`).
   2. `about-teaser` → `kind: static` → normal `/wp-section about-teaser`.
   3. `team-teaser` → `kind: cpt-teaser`, `cpt: team` → **SKIPPED — NOT dispatched
      through `/wp-section`.** Its teaser `template-parts/section-team.php` was
      already built and injected into `front-page.php` by `/wp-cpt team` in step 2.
      Reported as "teaser for `team`, built by /wp-cpt".
   4. `services` → `kind: static` → normal `/wp-section services` (3 static cards).

6. **Inner pages** (`pages[role=inner]`: `about`, `services`, `contact`) — every
   inner section reads from its OWN demo page and injects into its OWN template,
   so each dispatch carries `--page <slug> --target page-<slug>.php`:
   - `/wp-page custom about` → sections `about-story`, `about-values` (both
     `kind: static`) → **`/wp-section about-story --page about --target page-about.php`**
     and **`/wp-section about-values --page about --target page-about.php`**. This is
     the C1 contract: without `--page about` the section would be sought in
     `demo/index.html` (not found → stall), and without `--target page-about.php`
     it would be injected into `front-page.php` instead of the About page.
   - `/wp-page custom services` → sections `services-detail`, `services-process`
     (both `kind: static`) → `/wp-section services-detail --page services --target page-services.php`
     and `/wp-section services-process --page services --target page-services.php`.
   - `/wp-page custom contact` → section `contact` → `kind: contact` →
     **`/wp-section contact --cf7 --page contact --target page-contact.php`** —
     routes through the CF7 form path (`<input type="email">` + `<textarea>`
     detected by `wp-normalize` as `kind: contact`), reading from `demo/contact.html`
     and injecting into `page-contact.php`.

7. **`cpt-archive` pages** (`pages[slug=team, role=cpt-archive]`):
   - `team.html` → **no `/wp-page custom team` run, no `page-team.php`, no WP
     Page created.** Its archive URL is `archive-team.php` with `has_archive`,
     already built by `/wp-cpt team` in step 2. Noted in the final report as
     "archive of `team`, built by /wp-cpt".

8. **Blog** — no `pages[role=blog]` entry in this manifest → step skipped.

9. **Mandatory system pages — always, regardless of demo content:**
   - `/wp-page 404` — the fixture has no 404 page; built anyway, synthesized
     from the shared header/footer/design tokens.
   - `/wp-page search` — the fixture has no search-results page; built anyway,
     same synthesis path.
   These run unconditionally per `wp-yolo.md` Step 4.9 — presence in the demo
   is irrelevant.

## Phase 3 — Seed & Finish (in order)

1. **`/wp-seed --exclude-slugs team`** — creates WP Pages for `about`, `services`,
   `contact` (matching `page-<slug>.php` templates) — **NOT** for `team`: it is a
   `cpt-archive` slug, so it is passed to `--exclude-slugs` and no WP Page is
   created (its URL comes from `has_archive`; a WP Page would collide with
   `archive-team.php`). Populates ACF fields, sideloads team member photos
   (`assets/team/*.jpg`) into media, and builds the primary nav menu.
   `/wp-seed` does **NOT** create CPT posts.
2. **Create CPT posts** — for `contentTypes[0]` (`team`), execute its seeder
   `inc/seed/team.php` (emitted by `/wp-cpt team` in Phase 2) via the WP-CLI
   wrapper (`$WP eval-file inc/seed/team.php`) to create the 6 `team` posts from
   `contentTypes[0].seed[]`. Primary language only. This is the executor the
   whole pipeline relies on for CPT content — neither `/wp-seed` nor `/wp-cpt`
   creates these posts on its own.
3. `/wp-finalize`
4. `/wp-polish`
5. `/wp-responsive-check`
6. `/wp-audit --all --security-level recommended`

## Assertions checked by this trace

- [x] `/wp-cpt team` runs before the home `team-teaser` section AND before
      `archive-team.php` is available (both step 2, ahead of steps 5 and 7).
- [x] `team.html` produces no `page-team.php` and no WP Page (step 7).
- [x] The `contact` section routes through `--cf7` (step 6, contact page).
- [x] `/wp-page 404` and `/wp-page search` both run despite neither existing
      in the fixture (step 9, unconditional).
