#!/usr/bin/env bash
# Defects found by a human on a finished 16-page build, every one of which
# returned HTTP 200 and looked plausible. Each line below pins the contract that
# would have caught one of them.
#
# These assert on prose, deliberately: this repo's contracts ARE prose, and the
# house style is a grep that fails when the wording defining a rule disappears
# (CLAUDE.md, "New behavior needs a check"). Where a rule names a code symbol —
# pt_page_default_rich_snippet, posts_page, sitemap_index.xml — the symbol is
# what gets pinned, because it survives an edit to the sentence around it. A
# heading rename does break these, and that is the intended cost: the rename
# becomes a deliberate act instead of a silent one.
set -euo pipefail
cd "$(dirname "$0")/../.."
cd "$(dirname "$0")/../.."

# These assert on prose, deliberately: this repo's contracts ARE prose, and the
# house style is a grep that fails when the wording defining a rule disappears
# (CLAUDE.md, "New behavior needs a check"). Where a rule names a code symbol —
# pt_page_default_rich_snippet, posts_page, sitemap_index.xml — the symbol is
# what gets pinned, because it survives an edit to the sentence around it. A
# heading rename does break these, and that is the intended cost: the rename is
# then a deliberate act rather than a silent one.

fail() { echo "FAIL: $1"; exit 1; }

r=agents/wp-audit-rankmath.md
a=agents/wp-acf.md
f=commands/wp-finalize.md
t=agents/wp-template.md
y=commands/wp-yolo.md
for x in "$r" "$a" "$f" "$t" "$y"; do test -f "$x" || fail "$x missing"; done

# D1 — options set, nothing emitted. Configuring is not evidence of output.
grep -q 'Step 1.6: Prove it emits' "$r" || fail "rankmath never verifies the front end emits"
grep -q 'application/ld+json' "$r" || fail "rankmath emit check does not look for JSON-LD"
grep -q 'sitemap_index.xml' "$r" || fail "rankmath emit check does not probe the sitemap"

# D2 — the score is a proxy; optimising it directly picks junk keywords.
grep -q 'Never pick the keyword that maximises the score' "$r" || fail "rankmath may still score-maximise keywords"

# D3 — every page claiming to be an Article.
grep -q "pt_page_default_rich_snippet'\] = 'off'" "$r" || fail "pages still default to the article rich snippet"

# E1 — a duplicate key makes one field vanish, and a grep cannot see it.
grep -q 'Verify key uniqueness by EXECUTION' "$a" || fail "wp-acf does not verify key uniqueness by execution"
grep -q 'do not audit PHP structure with a regular expression' "$a" || fail "wp-acf does not forbid the regex audit"

# E2 — archive fields located on the posts themselves: no screen ever offers them.
grep -q 'posts_page' "$a" || fail "wp-acf has no posts_page location rule"

# E3/E4 — a key that prints itself, and markup printed as text.
grep -q "Every \`t()\` / \`e()\` key resolves" "$f" || fail "wp-finalize does not check i18n keys resolve"
grep -q 'keys-defined.txt' "$f" || fail "wp-finalize key check has no defined-key source"
grep -q 'escaped markup the demo meant to render' "$f" || fail "wp-finalize does not sweep for escaped markup"
grep -q "Read the demo's value before choosing the escaper" "$t" || fail "wp-template still picks the escaper blind"

# F1 — agents dying on context before writing anything.
grep -q "Pass the section's line range" "$y" || fail "wp-yolo still hands whole demo pages to section agents"

echo PASS
