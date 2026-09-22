---
name: wp-audit-ux-standards
description: Usability criteria for a WordPress site — forms and data entry, navigation and task flow, links, interactive feedback, legibility and visual identity. Holds the UX-NNN catalog, the page-level vs site-level split, the applicability rules that keep a score honest, and which owner each fix belongs to. Read by the wp-audit-ux agent and by /wp-audit when it scores.
user-invocable: false
---

# Usability standards

Six auditors cover security, SEO, accessibility, performance, WordPress standards and
GEO. Between them they answer whether the code is safe, findable, compliant, fast, idiomatic
and legible to an agent. None of them answers whether a person can use the site.

That is not a gap in one of them. A form that marks no field as required is valid HTML,
escapes correctly, loads fast and passes WCAG; the site is simply harder to use than it
needs to be, and nothing in the audit says so. These are the criteria that say so.

## What this is not

- **Not accessibility.** Contrast, focus order, ARIA, keyboard traps and target size belong
  to `wp-audit-a11y` and stay there. Where the two touch — a link that is distinguishable
  only by colour is both — the accessibility code wins and the usability catalog does not
  restate it. Two codes for one defect inflate every count.
- **Not performance.** Core Web Vitals, budgets and Lighthouse belong to
  `wp-audit-performance`.
- **Not an opinion about taste.** Every criterion below has a pass condition somebody else
  could check and reach the same answer. "The hero could be stronger" is not a finding.

## The catalog

Codes are `UX-NNN`. The numbers are the criteria's own, zero-padded, so `UX-006` and
`UX-046` sort the way a reader expects and a ledger written this release still matches one
written next release. **Numbers are never reused**: a retired criterion leaves a hole.

Each row carries the owner its fix belongs to, in the four-way split `/wp-audit` Step 8.5
defines — `code` travels with the commit, `setting` does not, `content` needs somebody to
write a text, `manual` needs judgement. The owner is a property of where the fix lands, not
of whether the audit could apply it.

### A. Forms and data entry

Applicability: **a site with no form and no data entry marks this whole category N/A.**
`UX-011` needs an action with consequences; `UX-037` and `UX-038` need the site to ask for
personal data or an account.

| Code | Check | How to detect | Passes when | Severity | Owner |
|---|---|---|---|---|---|
| UX-001 | Required and optional fields are distinguishable | `required`/`aria-required`, label text, or a visible mark; check it is not colour alone | the distinction is visible and survives colour blindness | WARNING | code |
| UX-002 | Field size matches the expected value | `size`, `maxlength`, `cols`/`rows`, rendered width against the datum | a postcode field is not as wide as an address | INFO | manual |
| UX-010 | Focus lands in the first field | `autofocus`, or JS that focuses on load | the first relevant field takes focus, and no page steals focus where it should not | INFO | code |
| UX-011 | Consequential actions confirm first | a confirm step before delete, pay, or an irreversible send | the consequence is stated before it happens | WARNING | code |
| UX-012 | Success is reported | a success message, a confirmation page, a toast | the user is told the action worked, not left at a silent reload | WARNING | code |
| UX-013 | Invalid fields are highlighted and explained | error states, `aria-invalid`, a message tied to the field | the error is visible on the field and says how to fix it | WARNING | code |
| UX-016 | Forms validate before submitting | `type`, `pattern`, `min`/`max`, `required`, or JS validation | plainly invalid input does not reach the server | WARNING | code |
| UX-024 | Error messages say what to do | read the message text | "Enter an email like name@domain.com", not "Error 3" | WARNING | content |
| UX-035 | Focus moves to the first field in error | JS that focuses the first invalid field after submit | the user lands on what they must fix | INFO | code |
| UX-037 | No unnecessary registration | walk the key flows | nothing demands an account for a task that does not need one | WARNING | manual |
| UX-038 | The privacy policy is easy to find | a link in the footer and beside any form asking for personal data | reachable from where the data is asked for | WARNING | content |

### B. Navigation and task flow

| Code | Check | How to detect | Passes when | Severity | Owner |
|---|---|---|---|---|---|
| UX-003 | Every page has an exit | a cancel/close/back control in modals and flows | the current task can be abandoned without being trapped | WARNING | code |
| UX-004 | Multi-step processes go back | the wizard or stepper pattern | a working Previous that keeps what was entered | WARNING | code |
| UX-017 | The home page links the important sections | the home's primary navigation | the key sections are one click from home | INFO | content |
| UX-020 | Search is visible on every page | `input[type="search"]`, a search form, a search icon | search is present and in the same place throughout | INFO | code |
| UX-021 | Home is reachable from everywhere | the logo or a Home link resolving to `/` on every template | consistent and visible on every page | WARNING | code |
| UX-025 | The user can tell where they are | breadcrumbs, an active section, a section title | the position in the hierarchy is identifiable | INFO | code |
| UX-036 | Navigation is ordered logically | read the menu order | frequency, task flow or theme — some order a person could name | INFO | manual |

`UX-020` is N/A on a site small enough that search adds nothing — say so rather than
failing it.

### C. Links

Applicability: no external links marks `UX-015` and `UX-028` N/A; no image used as a link
marks `UX-019` N/A.

| Code | Check | How to detect | Passes when | Severity | Owner |
|---|---|---|---|---|---|
| UX-014 | No broken internal links | collect every internal `href` and **follow it** | every internal link resolves | CRITICAL | code |
| UX-015 | No broken external links | the same, for external hosts | no 404 and no DNS failure | WARNING | content |
| UX-018 | Links are identifiable at rest | the `a` rule in its default state | recognisable without hovering, and not by colour alone | WARNING | code |
| UX-019 | Image links carry alternative text | `a > img` with no `alt`, or an empty `alt` with no other label | every image link tells a screen reader where it goes | WARNING | content |
| UX-027 | Link text matches its destination | compare the link text with the destination's `<title>`/H1 | the text predicts the page; no "click here" | INFO | content |
| UX-028 | Internal and external links are distinguishable | an icon, a stated `target="_blank"`, wording | the user knows they are leaving before they click | INFO | code |

**`UX-014` is followed, not inferred.** A link that looks internal and 404s is the finding;
a list of hrefs is not. When the links cannot be followed, report `UNMEASURED` with the
list, never `PASS`.

**One row per page, not per link.** Three broken links on `/contact/` are one finding,
`UX-014 : page:/contact/`, whose evidence lists all three with their status codes. A row per
link turns one bad footer into forty findings that are one fix, and it matches nothing the
suite emits — `/wp-audit` Step 7 merges on `check` + `resource`, so both sides have to count
the same way or the duplicate survives.

### D. Interaction and visual feedback

| Code | Check | How to detect | Passes when | Severity | Owner |
|---|---|---|---|---|---|
| UX-005 | Clickable things react to hover | `:hover` rules and `cursor` | every clickable element gives visible feedback | INFO | code |
| UX-008 | The current menu item is marked | `active`/`aria-current="page"` and the style behind it | the selected item is clearly different | WARNING | code |
| UX-009 | Action elements have room between them | margins, padding and the rendered target (below 24×24 fails per WCAG 2.5.8; 44×44 is AAA advice) | adjacent controls do not induce a wrong tap | WARNING | code |
| UX-026 | Button text names the action | read the button labels | "Save changes", not "OK" where OK is ambiguous | INFO | content |
| UX-030 | Icons match what they mean | compare each icon with its function | a magnifier searches, a cart buys | INFO | manual |
| UX-031 | Selected icons differ from unselected | the icon's active state | the selected state is unmistakable | INFO | manual |

### E. Legibility

`UX-045` (contrast) is deliberately absent: it is `A11Y-003`.

| Code | Check | How to detect | Passes when | Severity | Owner |
|---|---|---|---|---|---|
| UX-006 | Line length | measure the **rendered** characters per line, per breakpoint | ≤85 characters. 86–100 is a warning; over 100 fails | WARNING | code |
| UX-007 | Text blocks are 5–8 lines | the length of unbroken blocks | text is segmented rather than a wall | INFO | content |
| UX-032 | Typography is consistent site-wide | `font-family` and the type scale, compared across templates | one system, not one per template | WARNING | manual |

**`UX-006` is measured at every breakpoint and names the one that fails.** The same
paragraph with no `max-width` runs about 43 characters on a phone, 76 on a tablet and 142
on a desktop. A finding that does not name the screen cannot be acted on, and the inverse
case is real too — a theme that never reduces its type can overflow on mobile and not on
desktop. Report the longest line per breakpoint.

### F. Visual identity

Applicability: no images, tables or charts marks `UX-033` N/A. A single-page site marks
`UX-034` N/A, or reduces it to "the logo is present".

| Code | Check | How to detect | Passes when | Severity | Owner |
|---|---|---|---|---|---|
| UX-029 | The product's identity is present | `<link rel="icon">`, the logo, colour tokens, the type family | the brand is recognisable and consistent | WARNING | code |
| UX-033 | Images, tables and charts are sharp | rendered sharpness, `srcset`, modern formats | crisp on standard and high-density screens | INFO | code |
| UX-034 | The logo is in the same place on every page | compare headers across pages | one position throughout | WARNING | code |

## Page-level and site-level

Most criteria are answered **per page**, which is why a report is organised page by page.
Some can only be answered by comparing pages, and answering those once per page produces
the same finding N times and still does not say what changed between them.

- **Site-level** — `UX-029`, `UX-032`, `UX-034`, `UX-036`, `UX-038`, `UX-015`, `UX-028`.
  Evaluate once, comparing across the audited pages. When one reveals an inconsistency,
  name the pages it differs between.
- **Home only** — `UX-017`.
- **Everything else is page-level.** A criterion that fails on some pages and not others is
  reported on each page it fails on. That is not duplication: the fix is per template, and
  a single site-level row would hide which page is wrong.

The two carry different resources, and the resource is half of a finding's ledger identity:
a page-level finding is `page:/contact/`, a site-level one is `site`. Writing a site-level
finding with no resource at all leaves its identity to whatever the renderer falls back to,
which is not a contract anyone stated.

## Applicability, and why it changes the score

A site is not worse for lacking a feature it was never meant to have. Before scoring,
decide which criteria apply to **this** site:

- no form at all → category A is N/A
- no external links → `UX-015`, `UX-028`
- no images → `UX-019`, `UX-033`
- no account or personal data → `UX-037`, `UX-038`
- a single page → `UX-021`, `UX-034`, `UX-025`, and `UX-017` is reduced
- no long prose → `UX-006`, `UX-007`
- no icons → `UX-030`, `UX-031`

**N/A is excluded from the denominator and reported separately.** A score of 30/40 on the
criteria that applied is a measurement; 30/56 against a list including sixteen that never
applied is a number that punishes a site for its own shape.

**When in doubt, the criterion applies.** N/A means "this site genuinely lacks the thing
the criterion evaluates". It never means "this applies and is not implemented" — that is a
failure, and the difference is the whole point. A site with a form and no required marks
fails `UX-001`; a site with no form at all is N/A on it.

And a criterion whose applicability cannot be decided from what was measured is
`UNMEASURED`, with what would decide it. Not a pass.

## Measurement, not inference

Every finding carries what produced it: the selector, the `href` followed and its status
code, the measured characters per line and the breakpoint, the computed value. A criterion
answered from reading a template rather than loading a page is an inference, and it is
reported as one — `UNMEASURED` with the command or the URL that would settle it.

This is why `--suite` exists. Roughly two thirds of this catalog can be measured in a real
browser, and `templates/audit-suite/` measures them. Without it, the criteria that need a
rendered page are `UNMEASURED` and the ones a file scan can answer still run.

## The standard a fix has to meet

Every fix in the `code` column above is a visual change, and `UX-018`, `UX-005`, `UX-009`
and `UX-006` move layout. So a fix to one of these is only correct when it is evidenced the
same way a finding is:

- **Consent.** A change to how the site looks is the client's decision, not the audit's. A
  criterion that fails is reported; it is not quietly restyled into passing.
- **Equivalence, measured.** The computed values that were not the target of the fix are
  identical after it — `color`, `backgroundColor`, `fontSize`, `fontFamily`, `borderWidth`,
  `borderRadius`, and the element's box. A value that moved and was not meant to is a
  regression, whatever the finding says.
- **Coverage.** Desktop and mobile, and every element carrying the class — not the one the
  finding named.

A tag swap is not exempt, and it is the case that looks safest. The browser applies its own
styles to the new element, and a reset class added to compensate lands after the utilities
already in the sheet: one real change turned an icon from white to black and from 26px to
18px with no colour value edited.

`agents/wp-audit-ux.md` holds the procedure that satisfies this.
