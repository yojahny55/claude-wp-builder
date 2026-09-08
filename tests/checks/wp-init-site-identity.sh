#!/usr/bin/env bash
set -euo pipefail
# /wp-init collected a one-sentence site description and threw it away: nothing ever
# wrote `blogname` or `blogdescription`, so every scaffolded site shipped WordPress's
# "Just another WordPress site." in its <title>, its feeds and every SEO preview -- and
# an adopted site kept the previous project's name. /wp-finalize's Layer 2 gate marks
# both options `critical`, so the gate failed on every project by construction.
#
# Assert the write exists in /wp-init, that the tagline is actually gathered (both the
# demo-first path and the interactive one), and that the gate it feeds still reads those
# two options -- a check that only greps wp-init would go green while wp-finalize drifts.
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

init=commands/wp-init.md
final=commands/wp-finalize.md
for f in "$init" "$final"; do test -f "$f" || fail "$f missing"; done

# 1. /wp-init writes both options.
grep -Fq 'option update blogdescription' "$init" \
  || fail "$init never sets blogdescription -- scaffolded sites keep \"Just another WordPress site.\""
grep -Fq 'option update blogname' "$init" \
  || fail "$init never sets blogname -- an adopted site keeps the previous project's name"

# 2. The value it writes is actually gathered. All three entry paths must reach it, and
#    each is asserted on wording only that path can satisfy -- a bare `**Tagline**` grep
#    is answered by the manifest exception below and would go green with Step 1's prompt
#    list deleted.
grep -Fq -- '- **Tagline** (one sentence describing the site)' "$init" \
  || fail "$init's Step 1 prompt list no longer asks for a Tagline -- Step 9 would write an empty blogdescription"
grep -Fq '| Tagline |' "$init" \
  || fail "$init's demo-extraction table lost its Tagline row -- the demo-first path skips Step 1's prompt"
grep -Fq "ask Step 1's **Tagline** question on its own" "$init" \
  || fail "$init's .wp-create.json Pre-Step drops back to 'Skip Step 1 entirely' -- the manifest carries no tagline, so that path writes an empty one"

# 3. The old dead-end wording must be gone, not merely joined by the new one. It named a
#    field that was collected and never used, and its survival means a second, unwired path.
if grep -Fq -- '- **Brief description**' "$init"; then
  fail "$init still lists the old **Brief description** field, which no step consumes"
fi

# 4. The gate this feeds still reads both options. Search the whole file, not a heading.
grep -Fq 'option get blogdescription' "$final" \
  || fail "$final no longer verifies blogdescription -- nothing catches an empty tagline"
grep -Fq 'option get blogname' "$final" \
  || fail "$final no longer verifies blogname"

echo PASS
