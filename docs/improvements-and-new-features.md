# Claude WP Builder: improvements and new features

Reviewed on September 15, 2026, against local commit `213ff6c` (plugin version
`1.18.0`, with subsequent unreleased changes).

This document helps the maintainer and contributors decide what to build next.
It is based on a source review of the commands, agents, helper scripts, starter
themes, profiles, tests, backlog, and build postmortem. It does not certify a live
WordPress installation. All additions below are proposals; proposed command names,
flags, and paths are not available interfaces.

The strongest next product addition is a WooCommerce store workflow. Before shipping
it, strengthen required-plugin handling, repeatable seeding, and functional testing.
Those improvements also benefit every existing website build.

Priority means **P1: recommended next**, **P2: follow after the foundations**, and
**P3: explore when a client needs it**. Effort is relative: **S** is a focused change,
**M** spans several contracts or scripts, **L** spans a workflow with integration
tests, and **XL** needs multiple milestones. These are planning estimates, not
delivery commitments.

Suggested order: I01–I03 for clearer contracts and reliable setup; I05–I07 for
repeatable content and verification; N01 for the first store pilot. I04 can develop
alongside those foundations. N03 and N06 are useful smaller product additions.

## 1. Improvements to current features

The project already has a substantial feature set. These capabilities should be
extended and verified rather than counted as entirely new work:

| Existing capability | Evidence in the repository | Opportunity |
|---|---|---|
| Environment creation, adoption, and cloning | [wp-create](../commands/wp-create.md), [wp-clone](../commands/wp-clone.md) | Stronger dependency handling and isolated local clones |
| Multi-page demo conversion and custom post types | [wp-yolo](../commands/wp-yolo.md), [wp-cpt](../commands/wp-cpt.md) | Resume, selective rebuilds, and predictable content updates |
| Tailwind and cinematic starters | [starter-theme](../starter-theme/), [wp-init](../commands/wp-init.md) | Add capabilities without duplicating whole starters |
| Page, media, field, and menu seeding | [wp-seed](../commands/wp-seed.md) | Explicit ownership and safe repeated runs |
| Polylang and field-suffix language strategies | [wp-polylang](../commands/wp-polylang.md), [i18n variants](../starter-theme/_i18n-variants/) | Deeper field structures and translation review |
| Browser screenshots, motion checks, and conversion comparisons | [wp-demo-verify](../commands/wp-demo-verify.md), [tailwindify-parity](../bin/tailwindify-parity.mjs) | Functional scenarios and persistent visual baselines |
| Delivery checks and security, SEO, accessibility, performance, and GEO audits | [wp-finalize](../commands/wp-finalize.md), [wp-audit](../commands/wp-audit.md) | Track individual findings and changing check coverage |

### I01. Reconcile the backlog and contributor documentation

**P1 · S.** Make planning reflect what is already implemented.

[BACKLOG.md](../BACKLOG.md) still marks multi-page support, CPT generation, media
import, field seeding, menu creation, and Tailwind build integration as new.
The corresponding commands already describe these workflows. Screenshot generation
and comparison also have existing implementations, although they do not cover every
visual regression use case.

Review each backlog entry against its implementation and checks. Mark it delivered,
partially delivered, or still open, and describe the remaining gap. Update stale
contributor guidance: [CLAUDE.md](../CLAUDE.md) omits the executable `bin/*.mjs`
helpers from its initial architecture summary, and
[CONTRIBUTING.md](../CONTRIBUTING.md) still names the removed `__starter__` directory.

**Completion check:** each open backlog item identifies a missing behavior and links
to its owning files. Existing features are not presented as unstarted projects.

### I02. Enforce plugin-profile requirements and compatibility

**P1 · M.** A selected profile should produce a usable setup or explain what blocks it.

The [built-in profiles](../templates/profiles/) distinguish required and optional
plugins. However, [wp-create](../commands/wp-create.md), Step 4.10 and its failure
table, say to skip missing plugins and continue without distinguishing those cases.
This becomes especially problematic when WooCommerce defines the purpose of the site.

- Validate profile structure, duplicate slugs, dependencies, and incompatible choices.
- Stop dependent build steps when a required plugin cannot be installed or activated.
- Record optional failures as a degraded setup with an actionable reason.
- Record resolved plugin versions and a tested compatibility range; make upgrades
  deliberate rather than silently treating the installed stack as interchangeable.
- Treat licensed plugins as explicitly supplied dependencies, with installation
  status separate from whether a license is available.

**Completion check:** an unavailable required plugin blocks the dependent workflow;
an unavailable optional plugin produces a warning; the manifest matches active plugins.

### I03. Unify configuration validation and credential handling

**P1 · M.** Reduce contradictory project settings and make configurations portable.

[wp-audit](../commands/wp-audit.md) already recognizes `manifest_version: 2` and
reconciles installed software. The manifest example in
[wp-create](../commands/wp-create.md) does not include that version, while decisions
such as the template and language strategy also live in generated `.claude/CLAUDE.md`.
The creation manifest includes a database password.

Introduce a shared JSON Schema, validator, and migration helper used by creation,
initialization, seeding, auditing, and cloning. Define which file owns each setting,
generate readable context from it, and report conflicting edits. Preserve legacy
fallbacks through explicit migrations and keep unknown future-version files intact.

Separate shareable project settings from local credentials. Resolve secrets from the
local environment or a restricted, ignored file; redact them from reports. Replace
fixed sample admin credentials in generated setups with per-project credentials.

**Completion check:** malformed or conflicting configuration fails before a build;
an older manifest migrates without losing settings; exported reports contain no secrets.

### I04. Add resumable builds and selective updates

**P1 · L.** Recover interrupted work and reduce the cost of changing one page.

[wp-yolo](../commands/wp-yolo.md), Steps 1 and 3, explicitly states that it has no
resume entry point. Its existing rerun refusal protects completed work, and `--force`
deliberately rebuilds over it. That protection should remain while a resume path is added.

Persist completed stages, input hashes, output hashes, dependencies, and the plugin
version in a build-state file. A proposed resume mode would continue verified stages
without regenerating the reviewed normalization manifest. A selective-update mode
would rebuild changed sections and their dependents after showing the affected files.

Track files edited after generation and present conflicts before replacing them.
Use snapshots of affected files and a record of database mutations; a Git checkpoint
alone cannot restore seeded database content.

**Dependencies:** I03 and I05.

**Completion check:** interrupt a fixture build after the header, resume it without
rewriting that header, then change one section and rebuild only the affected outputs.
An editor's manual change must be detected.

### I05. Make content seeding repeatable and aware of editor changes

**P1 · M–L.** Allow content updates without duplicate pages, attachments, or menus.

[wp-seed](../commands/wp-seed.md) already imports media and fills fields. Its page
and menu examples primarily create objects, without a general persistent identity
and ownership contract. The Polylang workflow already demonstrates hash-based reuse
that can inform this improvement.

Assign stable source identities to pages, media, menu items, and seeded records.
Store their WordPress IDs and last imported values. Reuse known objects, deduplicate
media by source identity and content hash, and distinguish source changes from edits
made in WordPress. Resolve URLs after their destination objects exist.

Add a preview showing what will be created, updated, skipped, or conflicted. An
unchanged rerun should do nothing. Replacing editor-owned values or removing content
should be a separate, explicit operation.

**Completion check:** seed the same fixture twice with unchanged object counts and
IDs. Edit a field in WordPress, change the demo, and verify that the conflict is shown.

### I06. Extend visual verification into functional verification

**P1 · L.** Catch interfaces that look correct but do not work.

[wp-yolo](../commands/wp-yolo.md), Step 4.6, already carries JavaScript and requires
browser interaction checks. The [reference-build postmortem](postmortem-reference-build.md)
records a case where geometry checks passed while controls were inactive.
[demo-verify](../bin/demo-verify.mjs) measures scrolling and layout, while
[tailwindify-parity](../bin/tailwindify-parity.mjs) compares computed styles during
CSS conversion. Build on these distinct checks.

- Record expected interactions during normalization: menus, accordions, tabs,
  galleries, filters, search, and forms. Distinguish demo simulations from real features.
- Run repeatable browser scenarios that assert state changes, keyboard access,
  navigation results, and translated messages.
- Extend the existing [CF7 checks](../agents/wp-cf7.md) to verify valid submission,
  rejected submission, and captured email delivery through a local mail sink.
- Save approved demo/theme screenshot pairs with matching fonts, content, viewports,
  and animation states. Report image differences with reviewable tolerances.
- Keep screenshot results separate from functional results and manual review.
  Include reduced motion and a motion-engine fallback scenario.

**Completion check:** an intentionally broken carousel, incorrect color, and failed
form delivery each fail the appropriate check. Baseline images change only through
an explicit review step.

### I07. Add automated CI and disposable WordPress integration fixtures

**P1 · L, delivered in stages.** Make regressions visible before a release.

The repository has many [contract and script checks](../tests/checks/), but the only
committed GitHub workflow is [PR-Agent review](../.github/workflows/pr-agent.yml).
The [Polylang live suite](../tests/checks/wp-polylang-live.sh) skips unless a site is
provided. Contract checks protect instructions; they cannot prove every generated
site or audit behaves correctly.

Start with a CI job for existing checks, documentation synchronization, PHP syntax,
and JavaScript syntax. Then provision disposable WordPress fixtures for seeding,
translation, and starter activation. Add intentionally broken sites with expected
audit findings, and browser artifacts for failed scenarios from I06.

Separate deterministic fixture validation from scheduled model-driven build
evaluations, whose cost and variability need their own budget. Pin the fixture stack
and maintain a small, explicit compatibility matrix. Optional integrations should
report skipped coverage clearly.

**Completion check:** a pull request that breaks a command contract, a real translation
operation, or an expected audit finding fails the relevant job with useful evidence.

### I08. Extend multilingual coverage and protect translation ownership

**P2 · L.** Support richer content structures and reduce translation rework.

The [Polylang field walker](../skills/wp-polylang/scripts/pll-lib.php) documents a
one-level nesting limit. The [importer](../skills/wp-polylang/scripts/pll-import.php)
also documents parent synchronization that can overwrite an editor's deliberate
target-language hierarchy. These are known limits, not evidence that basic translation
is missing.

Add recursive handling of supported groups, repeaters, and flexible-content fields,
including nested internal references. Define a policy for mapping image/file fields
to translated attachments. Track editor ownership of translated hierarchy and fields,
and introduce review states for machine translation, approved translation, and content
made stale by a source edit.

Keep the suffix and Polylang models explicit. For commerce, validate the complete
store integration described in N01 before promising multilingual checkout support.

**Completion check:** nested links resolve in the correct language, adding a third
language preserves existing groups, and importing again preserves approved edits.

### I09. Version audit checks and track individual findings

**P2 · M.** Make successive audit reports comparable.

[wp-audit](../commands/wp-audit.md) already tracks category coverage, freshness,
carry-over counts, and statuses such as `UNMEASURED`.
[CLAUDE.md](../CLAUDE.md) identifies the remaining limitation: a category having run
does not reveal whether checks added later have ever run on that project.

Give checks stable IDs and versions. Record findings by check, resource, evidence,
and status: new, still failing, resolved, accepted, or unmeasured. Reopen affected
coverage when a check changes. Emit a versioned JSON report plus readable Markdown
with links to browser evidence.

Attach project-specific performance budgets and asset-size reports to the existing
performance audit. Record measurement conditions so a change in test environment is
visible alongside any apparent improvement or regression.

**Completion check:** adding a check to an existing category marks it unmeasured on
an older project, and fixing one issue resolves that issue without clearing others.

### I10. Make local clones isolated and reproducible

**P1 before commerce cloning · M–L.** Produce useful development copies of real sites.

[wp-clone](../commands/wp-clone.md) already imports databases and uploads, rewrites
URLs, and checks that WordPress loads. It does not define a general local-clone policy
for outbound mail, webhooks, payment settings, scheduled jobs, or customer data.

Add a clone plan with explicit source and destination identities, unique temporary
export paths, destination backup, and a plugin/theme dependency inventory. Apply local
mail capture, disabled production integrations, development indexing settings, and
opt-in anonymization of customer fixtures. Detect unavailable custom or licensed
plugins and report the incomplete environment.

**Completion check:** a store fixture clones without contacting production services;
URLs, theme assets, and required plugins are accounted for; re-running the workflow
does not confuse another clone's export or overwrite an unrelated destination.

## 2. New features

### N01. WooCommerce profile, theme integration, and store workflow

**P1 product priority · XL overall; ship a bounded pilot first.** Extend the builder
from content websites to stores while keeping approved demo HTML as the design source.

Only `starter` and `full` [plugin profiles](../templates/profiles/) are shipped, and
the [starter themes](../starter-theme/) are Tailwind and cinematic. There is some
WooCommerce awareness in translation and GEO agents, but no dedicated store-building
command, commerce profile, or storefront scaffold was found.

#### Proposed pieces

| Piece | Initial scope | Suggested location or integration |
|---|---|---|
| WooCommerce profile | Require WooCommerce and the selected field plugin; offer optional SEO and mail tooling; resolve dependencies | New `templates/profiles/woocommerce.json`, using I02 |
| Store template option | Shop, product category, product detail/gallery, cart, checkout, account, and order confirmation styling | Reuse `__tailwind__` with a proposed `starter-theme/_features/woocommerce/` overlay |
| Setup workflow | Store location, currency, units, page assignments, shipping zones, and merchant-provided tax configuration | Proposed `/wp-woo init`, recorded in the validated project configuration |
| Product seeding | Simple and variable products, categories, attributes, stock states, galleries, and sample promotions | Proposed `/wp-woo seed`, with stable IDs from I05 |
| Verification | Catalog navigation, variation selection, cart updates, checkout, account access, and test orders | Proposed `/wp-woo verify`, integrated with finalize/audit |

A profile installs dependencies. A template controls presentation. A working store
also needs data, configuration, and transaction checks; installing WooCommerce alone
does not complete this feature.

Offer “WooCommerce / Tailwind” in template selection while composing it from the shared
Tailwind base. This keeps improvements to navigation, typography, and accessibility
available to stores. The cinematic starter is outside the first store milestone.

#### Integration design

Keep the existing four-layer architecture: the commerce command orchestrates, a
commerce specialist generates integration code, a skill documents conventions, and
scaffolds/scripts provide repeatable output. Reuse the existing environment, media,
language, and reporting workflows.

Extend normalization so shop/product/cart/checkout/account pages have explicit roles.
Exclude those routes from generic page and CPT generation where WooCommerce owns them.
Products, prices, inventory, carts, and orders should use WooCommerce's data model;
custom fields remain appropriate for supplementary editorial content.

For the classic PHP starter, declare WooCommerce support, preserve extension hooks,
and use limited, version-tracked template overrides. These follow WooCommerce's
[classic-theme integration guidance](https://developer.woocommerce.com/docs/theming/theme-development/classic-theme-developer-handbook).

Use the official Cart and Checkout blocks for the pilot. Validate extension support
and use supported block extension points: WooCommerce documents that some classic
PHP hooks do not apply to these blocks. Apply design tokens through supported styling
interfaces and avoid depending on private nested markup.
See [Cart and Checkout extensibility](https://developer.woocommerce.com/docs/block-development/extensible-blocks/cart-and-checkout-blocks)
and [block theming guidance](https://developer.woocommerce.com/docs/theming/block-theme-development/cart-and-checkout).

Use WooCommerce CRUD APIs for any order handling and verify High-Performance Order
Storage (HPOS). Direct order writes to WordPress post tables can target the wrong
storage. Declare compatibility for any generated companion extension only after testing.
See the [HPOS recipe book](https://developer.woocommerce.com/docs/features/orders/high-performance-order-storage/recipe-book/).

#### First milestone and expansion

Start with one language, one currency, simple and variable physical products, one
shipping configuration, and one selected gateway in test mode. Include empty cart,
out-of-stock, invalid coupon, checkout error, and order confirmation states in the
approved demo and implementation. Exclude cart, checkout, account, and session-specific
responses from shared page caching.

Keep payment credentials out of generated files and reports. Capture test emails
locally. Switching to live payments should be a separate launch action once the store
configuration and test results have been reviewed.

Add multilingual commerce in a second milestone. The note in
[wp-polylang](../commands/wp-polylang.md) describes limited product translation, but
Polylang's official guidance says Polylang or Polylang Pro alone is insufficient for
a multilingual shop: its WooCommerce add-on is required. Treat that as a dependency
and licensing decision, and verify stock, variations, checkout language, account
routes, and emails together. [Polylang compatibility FAQ](https://polylang.pro/documentation/support/faq/).

Later expansions can include downloadable products, subscriptions, bookings, wishlists,
and more gateways, each with its own dependency and compatibility checks.

**Dependencies:** I02, I03, I05, I06, and a disposable store fixture from I07.
I10 is required before validating clones of existing stores.

**Completion checks for the pilot:**

1. A fresh project builds the approved store demo and assigns every commerce route.
2. Re-seeding preserves product IDs and creates no duplicate products or attributes.
3. A shopper selects a variation, changes quantities, applies a valid coupon, and
   completes a test order; totals and stock changes match the configured fixture.
4. Failed payment and invalid checkout inputs produce usable, accessible recovery states.
5. Guest and account checkout paths work at mobile and desktop sizes; users cannot
   view another customer's order.
6. HPOS is enabled in the fixture, transactional email reaches the test inbox, and
   separate customer sessions never share cart or account content through caching.

### N02. Project presets for common website types

**P2 · M per preset.** Reduce repeated discovery and setup for common client projects.

Custom plugin profiles already exist. Extend them into optional project presets that
bundle a page map, content models, plugin choices, seeding fixtures, and relevant checks.
Build on the existing composition library and demo workflow; the client's approved
design continues to control visual output.

| Preset | Useful starting content | Distinct work to add |
|---|---|---|
| Agency / professional services | Services, team, case studies, testimonials, inquiry form | Relationships, archive/detail pages, and seeded navigation |
| Editorial / magazine | Categories, authors, articles, related content, newsletter form | Editorial templates and publication-oriented checks |
| Directory / real estate | Listings, locations, attributes, search, inquiry | Faceted queries and a clear boundary for external listing feeds |
| Appointments / events | Services or events, schedules, booking pages | Adapter for a selected booking provider and transaction tests |

Pilot the services preset first because it reuses the most existing functionality.
Choose booking or listing providers per project; licensing and feed access remain
explicit inputs.

**Dependencies:** I02, I03, and I05.

**Completion check:** selecting a preset generates a reviewable page/content plan and
a working fixture without duplicating the existing CPT or section builders.

### N03. Project status and guided next steps

**P2 · M.** Help users understand where a build stands across multiple sessions.

Add a proposed `/wp-status` that reads the project configuration, demo manifest,
build state, translation coverage, and verification reports. Show completed stages,
blocked stages, changed inputs, and the next applicable command with its reason.

[wp-debug](../commands/wp-debug.md) already diagnoses WordPress health. Reuse its
diagnostics when needed; this feature adds an overview of workflow progress. The first
version can be a terminal report, followed by an optional local HTML report.

**Dependencies:** I03; accurate resume information also needs I04.

**Completion check:** fresh, interrupted, and completed fixture projects show different,
correct next steps without modifying the site or treating old reports as current.

### N04. Optional block-editor starter

**P3 · L–XL.** Support clients who need to edit page composition in WordPress.

The current starters use PHP templates and custom fields. Add an opt-in block-theme
path with editable templates, patterns, and constrained design controls. WordPress
provides block templates and `theme.json` for shared colors, typography, and styles.
See the [template handbook](https://developer.wordpress.org/themes/templates/templates/)
and [global settings and styles](https://developer.wordpress.org/themes/global-settings-and-styles/).

Begin with a small brochure-site fixture: header, footer, hero, content, and contact
sections. Map approved demo tokens into editor settings and define which arrangements
the client may change. Evaluate the loss of exact layout control against the value
of editor flexibility before expanding to complex motion or commerce.

**Completion check:** an editor can change content and permitted section order without
code, while the untouched fixture matches its approved demo on mobile and desktop.

### N05. Deployment, backup, and rollback workflow

**P2 · XL.** Extend the lifecycle from a verified local build to a staged release.

[wp-clone](../commands/wp-clone.md) covers inbound copies. Add a proposed deployment
workflow with environment mapping, a release plan, backup references, a release artifact,
staging checks, and a separately approved production promotion.

Start with theme/assets deployment to one hosting target. Treat database changes as
explicit migrations and make release metadata available for rollback. For active stores,
preserve orders and customers: a staging database must not replace production data,
and restoring an old database is not a general release rollback strategy.

**Dependencies:** I03, I07, I09, and I10. Validate restoration on a disposable environment
before advertising rollback support.

**Completion check:** deploy to staging, detect a failing health check, restore the
previous code artifact, and retain content created after the previous release.

### N06. Client handoff and content guide

**P2 · S–M.** Turn existing technical reports into a useful delivery package.

Add a proposed `/wp-handoff` that produces an editing guide and delivery summary from
the actual site's fields, content types, menus, language strategy, and installed
integrations. Include screenshots, outstanding content, verification dates, and
maintenance responsibilities. Store projects also need product-editing and test-order
instructions based on their configured workflow.

Reuse finalize and audit outputs. Avoid claiming checks passed when they were skipped,
and omit credentials from the generated package.

**Completion check:** a client can locate and edit hero copy, navigation, a content
record, and a translation using the guide; reported limitations match the latest checks.

### N07. Portable site-functionality plugin

**P2 · L.** Keep business content available when a client changes themes.

The [CPT builder](../commands/wp-cpt.md) generates registration and seed helpers as
part of the theme workflow. Offer a generated companion plugin for content-type and
taxonomy registration, domain rules, and integration adapters. Presentation stays
in the theme; field placement needs an explicit ownership decision.

Pilot this on one services preset. Provide migration detection so existing sites
do not register the same types twice, and retain slugs, field keys, and content IDs.
Reuse the same separation for custom commerce behavior from N01.

**Completion check:** switching the pilot site's theme preserves registered content
types and editable records; reactivating the generated theme restores presentation
without migration or duplicate registration errors.

### N08. Figma component mappings into approved demo markup

**P3 · M for a pilot; L for a supported workflow.** Reduce repeated interpretation
when a client supplies a reusable design library.

Build on the existing [Code Connect draft](code-connect-draft.md), which is already
a proposal, not a shipped feature. Pilot mappings for a button, card, and navigation
component into canonical demo HTML with optional field hints. Keep demo review as
the boundary before WordPress generation.

Confirm the client's current Figma entitlement, component library, and publishing
access before scheduling the pilot. Use a small measured experiment before promising
broad design-to-code support.

**Completion check:** mapped components survive normalization and section generation,
and the pilot records fewer manual corrections or lower build effort than an equivalent
unmapped build. Stop expansion if the mappings cost more to maintain than they save.
