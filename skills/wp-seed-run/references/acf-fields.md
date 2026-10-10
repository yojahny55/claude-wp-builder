# /wp-seed — Phase 4

`commands/wp-seed.md` sends the run here at Phase 4 (Seed ACF Fields (Primary Language)). Follow it in order; nothing in it is optional background.

## Contents

- Before writing a field: whose value is in it?
- The three-way compare
- Preferred method: ACF's `update_field()` via `wp eval`
- Alternative method: Direct `wp_options` (faster for bulk, but coupled to ACF internals)
- Verification

**GEO citability.** When seeding copy that the demo did not supply — or tightening its
extractable passages — apply the rubric in `skills/wp-audit-geo-standards/references/citability.md`:
answer-first 1–2 sentence openings, 134-167-word self-contained blocks, question-based
H2s, a table for 3+ comparisons, and named sources/dates with first-party numbers.

### Before writing a field: whose value is in it?

Phase 1.5 answers who owns a **record**. This answers who owns a **value**, and they are
different questions with different answers. A page the seeder created is one it may update —
but a heading inside that page, retyped by the client in wp-admin, is theirs. `update_field()`
overwrites unconditionally, so re-seeding a record the seeder legitimately owns silently
reverts every edit made to it since the last run.

Telling an editor's edit from a source change needs one fact that is not in the database:
**what this command wrote last time.**

Record it as a digest map on the record itself:

```bash
bash -c "$WP post meta get <post_id> _<prefix>_seeded_digest --format=json 2>/dev/null"
```

```json
{ "hero_title": "3f786850e387550fdab836ed7e6dc881de23001b", "hero_cta_text": "89e6c98d92887913cadf06b2adb97f26cd7b5a" }
```

A digest, not the value: detecting *changed* is the whole requirement, and storing every
seeded string a second time doubles the content for a question a hash already answers.

Options-page fields are global — one set of values per site, not per record — so their map
lives in an option rather than post meta, the same crossover `wp-acf` already makes for
`_<lang>` suffixes.

### The three-way compare

For each field, compare the value now in WordPress, the digest of what was written last run,
and the value the demo supplies now:

| In WordPress | vs last run | vs demo | Do |
|---|---|---|---|
| matches last run | — | demo differs | **update**, and rewrite the digest |
| matches last run | — | demo identical | **skip** — nothing changed anywhere |
| **differs** from last run | the client edited it | — | **conflict** — leave the value, report it |
| no digest recorded | unknown provenance | — | treat as a **conflict**; do not overwrite |

The last row is the one that protects a project seeded before this map existed. A field with
no recorded digest might hold the client's work or last run's output, and nothing on disk can
say which — so it is not overwritten. That makes the first re-seed of an older project noisy
and correct, rather than quiet and destructive. Once a field is written with a digest, it is
known thereafter.

**A conflict is reported and left, never merged.** There is no safe automatic resolution: the
demo's value and the client's value are both deliberate, and picking either silently discards
work somebody did on purpose. Say which field, on which record, and what each side holds.

**Replacing an editor's value is a separate, explicit operation** — `--force-fields`, which
overwrites conflicts and says so per field. It is not implied by `--force` on any other
command, and it is never the default: the entire point of the digest is that a routine
re-seed cannot quietly undo an afternoon in wp-admin.

Report field-level outcomes in the Phase 1.5 preview, where record-level counts already
appear:

```
  fields    update 3, skip 18, conflict 2
            conflict: hero_title (page "Home"), contact_phone (options)
```

A client edit that happens to produce exactly the demo's value reads as no edit. That is
harmless — the stored value is what they wanted either way — and it is the only case the
digest cannot distinguish.

### Preferred method: ACF's `update_field()` via `wp eval`

This approach is storage-format-agnostic and works regardless of how ACF stores the data internally.

Every `update_field()` below is subject to the three-way compare above, and writes the
field's digest in the same step that writes the value. A value written without its digest is
indistinguishable from a client edit on the next run, and will be reported as a conflict
forever.

**Simple text fields (options page):**

```bash
bash -c "$WP eval \"update_field('hero_title', 'Building Digital Excellence', 'option');\""
bash -c "$WP eval \"update_field('hero_subtitle', 'We create websites that work', 'option');\""
bash -c "$WP eval \"update_field('hero_description', 'Full-service digital agency...', 'option');\""
bash -c "$WP eval \"update_field('hero_cta_text', 'Get Started', 'option');\""
bash -c "$WP eval \"update_field('hero_cta_link', '#contact', 'option');\""
```

**Image fields (use the attachment ID from Phase 3):**

```bash
bash -c "$WP eval \"update_field('hero_image', 42, 'option');\""
```

**Repeater fields:**

```bash
bash -c "$WP eval \"
\\\$rows = array(
  array('title' => 'Web Design', 'description' => 'Custom websites...', 'icon' => 43),
  array('title' => 'SEO', 'description' => 'Search optimization...', 'icon' => 44),
  array('title' => 'Branding', 'description' => 'Visual identity...', 'icon' => 45),
);
update_field('services_cards', \\\$rows, 'option');
\""
```

**Page-specific fields (post meta, not options page):**

```bash
bash -c "$WP eval \"update_field('about_hero_title', 'Our Story', <about_id>);\""
bash -c "$WP eval \"update_field('about_hero_description', 'Founded in 2010...', <about_id>);\""
```

### Alternative method: Direct `wp_options` (faster for bulk, but coupled to ACF internals)

Use only when the ACF API is unavailable or for bulk seeding performance:

```bash
# ACF stores options page fields in wp_options with 'options_' prefix
bash -c "$WP option update options_hero_title 'Building Digital Excellence'"
bash -c "$WP option update options_hero_image 42"

# Repeater fields use indexed subfields
bash -c "$WP option update options_services_cards_0_title 'Web Design'"
bash -c "$WP option update options_services_cards_0_description 'Custom websites...'"
bash -c "$WP option update options_services_cards_0_icon 43"
bash -c "$WP option update options_services_cards_1_title 'SEO'"
bash -c "$WP option update options_services_cards_1_description 'Search optimization...'"
bash -c "$WP option update options_services_cards_1_icon 44"
bash -c "$WP option update options_services_cards 2"  # total row count

# Page-specific fields use post meta
bash -c "$WP post meta update <about_id> about_hero_title 'Our Story'"
```

### Verification

After seeding primary language fields, verify a sample field was stored correctly:

```bash
bash -c "$WP eval \"echo get_field('hero_title', 'option');\""
```
