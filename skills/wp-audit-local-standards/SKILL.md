---
name: wp-audit-local-standards
description: Local SEO audit reference — business-type and vertical detection, NAP consistency sources, LocalBusiness subtype selection, location-page quality gates and citation tiers, with the WordPress option and meta keys each check reads
user-invocable: false
---

# Local SEO Audit Standards

The `SEO-055` through `SEO-063` checks in `agents/wp-audit-seo.md` are the *what*. This
file is the *how* and the *why*: which signals decide a business type, which schema
subtype a vertical requires, and where a WordPress site actually stores each value.

Local SEO differs from the rest of the SEO audit in one structural way: **most of the
ranking surface is off-site** — the business profile, the reviews, the directory
listings. A code-only audit cannot see any of it. Everything below is scoped to what a
theme, its options and its rendered head can prove, and the checks say so explicitly
rather than reporting an absence as a pass.

---

## Applicability Gate

Run the local checks only when the site is a local business. Otherwise every check
reports `not_applicable` and none of them count toward the score.

A site is local when **any two** of these hold:

- A `LocalBusiness` node (or a subtype of it) exists in the rendered JSON-LD.
- A street address appears in the footer, the contact template or an options-page field.
- A `tel:` link exists outside a generic "call us" placeholder.
- Rank Math's local SEO module is active (`rank_math_modules` contains `local-seo`).
- The theme registers a location post type or an ACF location field group.

One signal alone is not enough: a `tel:` link in a footer is as common on a SaaS
brochure site as on a dentist's site.

---

## Business Type Detection

The type decides which checks apply. Getting it wrong produces false criticals — a
service-area business has no street address *by design*.

| Type | Signals | Checks that do NOT apply |
|------|---------|--------------------------|
| **Brick-and-mortar** | Street address in content, footer or schema; map embed with a pin; "visit us", "located at" | — (full set applies) |
| **Service-area (SAB)** | No visible street address; "serving <region>", "we come to you", "mobile service"; `areaServed` present without `address.streetAddress` | SEO-056 map embed, SEO-057 address parity |
| **Hybrid** | Both a physical address and service-area language | — (full set applies, plus `areaServed`) |

When signals are contradictory, report the type as `undetermined`, run only the checks
that are type-independent (SEO-055, SEO-058, SEO-060, SEO-061) and say so in the report.

---

## Industry Vertical Detection

The vertical decides the required schema subtype. Detect from template and content
signals; never from the client's name.

| Vertical | Detection signals | Required subtype |
|----------|-------------------|------------------|
| Restaurant | menu template or post type, dish names, reservations, "dine-in", "takeout" | `Restaurant` |
| Healthcare | "patients", appointments, insurance accepted, practitioner bios, HIPAA notice | `MedicalClinic`, `Dentist` or `Hospital` |
| Legal | "attorney", practice areas, bar admission, case results, "free consultation" | `LegalService` |
| Home services | service-area language, "free estimate", licensed/insured/bonded, 24/7 | subtype + `areaServed` |
| Real estate | listings, MLS references, agent bios, brokerage, "open house" | `RealEstateAgent` |
| Automotive | inventory, VIN, test drive, service department, "new/used/certified" | `AutoDealer` |

No vertical detected → generic `LocalBusiness` is correct, not a finding.

**Deprecated subtypes that still appear in older themes:** `Attorney` (use
`LegalService`), `VehicleListing` as a business type (use `AutoDealer`), bare
`MedicalBusiness` for a clinic (use the specific subtype). Flag these under SEO-058.

---

## Where WordPress Stores Each Value

A local audit reads five different places for what is conceptually one fact. The
discrepancies between them are the finding.

| Value | Source 1 — rendered | Source 2 — options | Source 3 — theme |
|-------|---------------------|--------------------|------------------|
| Business name | JSON-LD `name` | `wp option get blogname`; Rank Math `rank_math_titles` → `knowledgegraph_name` | options-page ACF field |
| Address | JSON-LD `address.*` | Rank Math local module option keys | footer template part, contact template |
| Phone | JSON-LD `telephone`; `tel:` href | options-page ACF field | footer template part |
| Opening hours | JSON-LD `openingHoursSpecification` | options-page repeater | — |
| Geo coordinates | JSON-LD `geo.latitude` / `geo.longitude` | options-page fields | map embed attributes |

Read options with WP-CLI, never by parsing PHP:

```bash
wp option get rank_math_titles --format=json
wp option get rank_math_modules --format=json
```

**Bilingual sites.** Under the `suffix` strategy the options-page fields carry their
`_<lang>` suffixes — `business_address_en` — and **both** variants must be checked.
This is the deliberate crossover documented in `wp-contributing`: options are global, so
Polylang's per-post model does not reach them, and options-page fields keep their
suffixes under *both* i18n strategies. An address that is correct in one language and
stale in the other is a real NAP discrepancy, not a translation artifact.

---

## NAP Consistency

NAP is Name, Address, Phone. The check compares the three sources above pairwise and
reports each disagreement separately — a phone that differs between schema and footer is
a different defect from an address that differs between two languages.

Normalize before comparing, or the check reports noise:

- Phone: strip spaces, hyphens, parentheses and a leading `+`; compare the digits.
- Address: collapse whitespace, lowercase, strip trailing punctuation; treat common
  abbreviations as equal (`St.` / `Street`, `Ave` / `Avenue`).
- Name: strip legal suffixes (`S.L.`, `Inc.`, `Ltd.`) before comparing; report a bare
  suffix difference as INFO, not WARNING.

Absent NAP is more severe than inconsistent NAP: a local business whose address appears
nowhere in the rendered HTML fails SEO-057 at WARNING even when the schema is perfect,
because the schema alone gives a human visitor nothing.

---

## Citation Tiers

Off-site, so the audit can only detect *references* to these from the site itself —
badges, links and `sameAs` entries. Report what is present; never assert that a missing
reference means a missing listing.

- **Tier 1 (general):** the business profile itself, Yelp, the Better Business Bureau,
  Facebook, Apple Maps, Bing Places.
- **Tier 2 (authority):** chamber of commerce, local press, industry associations.
- **Vertical directories:** per-industry listing sites appropriate to the vertical
  detected above.

The `sameAs` array in the Organization or LocalBusiness node is the one citation signal
a code-only audit *can* verify, which is why SEO-060 anchors on it.

---

## Location-Page Quality

Multi-location sites fail in one characteristic way: templated pages that differ only in
the city name. Search engines treat these as doorway pages.

**The swap test.** Take two location pages, exchange the city names, and read them. If
both still make sense, the pages carry no location-specific content and SEO-062 fires at
WARNING. This is a judgment call the agent makes by reading, not a ratio it computes.

Quality gates by page count, applied before the audit spends effort:

| Location pages | Action |
|----------------|--------|
| 1–29 | Audit each one |
| 30–49 | Audit a sample of 10, report the sample size in the finding |
| 50+ | Audit a sample of 10 and report the total at INFO; a full walk is manual-only |

**URL structure.** Subdirectories (`/locations/<city>/`) consolidate authority better
than subdomains. A store locator whose individual locations have no crawlable URL of
their own — rendered entirely client-side — is a CRITICAL finding: those pages do not
exist for a crawler.

**Schema per location.** Each location page carries its own `LocalBusiness` node with a
unique `@id`, linked to the site-wide Organization through `branchOf`. A single shared
`@id` across locations collapses them into one entity.

---

## Schema Properties

Required by Google for a local rich result:

- `name`
- `address` as a `PostalAddress` with `streetAddress`, `addressLocality`,
  `postalCode` and `addressCountry`

Recommended, and each one its own INFO finding when absent:

- `telephone`, `url`, `image`
- `geo` with `latitude` and `longitude` — **at least five decimal places**; three
  decimals places the pin roughly a hundred metres off
- `openingHoursSpecification`
- `priceRange` — under 100 characters
- `areaServed` for service-area and hybrid businesses
- `aggregateRating` **only when real review data backs it**

`aggregateRating` invented by a theme, or carrying placeholder values, is a CRITICAL
finding under SEO-063: it is structured-data spam and risks a manual action. The
starter theme must never ship one.

Schema is not a ranking factor. It earns rich results and gives AI systems parseable
business data. Word the findings that way; a report claiming schema lifts rankings is
wrong and the client will eventually be told so.

---

## What This Audit Cannot See

Every local report ends with this list. Omitting it implies a completeness the audit
does not have:

- Business-profile completeness, categories, posts and photos
- Review count, rating, velocity and owner responses
- Actual local-pack or map position, which varies by the searcher's location
- Citation accuracy on third-party directories
- Profile insight metrics

These need the business-profile account or a paid rank tracker. Say which, so the client
knows what the gap costs to close.

---

## Attribution

The business-type and vertical taxonomies, the swap test and the citation tiering are
adapted from the MIT-licensed `claude-seo` project by AgriciDaniel
(<https://github.com/AgricIDaniel/claude-seo>). The WordPress mapping, the i18n rules,
the severity assignments and the check codes are this plugin's own.
