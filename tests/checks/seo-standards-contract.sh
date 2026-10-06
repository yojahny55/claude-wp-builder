#!/usr/bin/env bash
# wp-audit-seo-standards states several contracts with a known wrong form, and none had a pin:
#   - Rank Math silently discards per-category noindex unless tax_category_custom_robots is
#     'on' in the same write (the WRONG/CORRECT pair);
#   - Lighthouse link-text reads innerText, so a display:none suffix fails again;
#   - a sitemap that 404s or returns HTML is the two unset wizard flags;
#   - the breadcrumb trail stops on a 404; titles stop at 60 characters, descriptions run 70-160.
# The skill also carried two bulk description seeds that disagreed with each other and with
# its own priority order, a 14-step setup list that had drifted from the agent that runs it,
# an English literal inside a translatable suffix, and "title formula" beside "title template"
# for one setting. This pins the rules, the one seed, and the wording.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

k=skills/wp-audit-seo-standards/SKILL.md
refs=skills/wp-audit-seo-standards/references
g=$refs/audit-gotchas.md
s=$refs/seeding-commands.md
b=$refs/breadcrumbs.md
for f in "$k" "$g" "$s" "$b"; do [ -r "$f" ] || fail "$f is missing or unreadable"; done
grep -Fq '[references/audit-gotchas.md](references/audit-gotchas.md)' "$k" || fail "$k does not name references/audit-gotchas.md"

# §14 -- the gate and the per-term key are written together, in the CORRECT block.
correct=$(awk '/\/\/ CORRECT/{on=1} on{print} on && /^```$/{exit}' "$g")
grep -Fq "tax_category_custom_robots'] = 'on'" <<<"$correct" || fail "$g CORRECT block does not set the custom-robots gate"
grep -Fq "tax_category_robots_' . \$term_id" <<<"$correct" || fail "$g CORRECT block does not set the per-category robots key"
wrong=$(awk '/\/\/ WRONG/{on=1} on && /\/\/ CORRECT/{exit} on{print}' "$g")
grep -Fq 'tax_category_custom_robots' <<<"$wrong" && fail "$g WRONG block sets the gate, so it no longer shows the failure"
grep -Fq 'saved in the same `update_option` call' "$k" || fail "$k does not say the gate and the key are written together"

# §13 -- display:none is named only as the failure.
grep -Fq 'NOT `display:none` or `visibility:hidden`' "$g" || fail "$g does not name display:none as what fails link-text"
grep -Fq 'never `display:none`, which innerText skips' "$k" || fail "$k does not say why display:none fails link-text"
grep -Fq "esc_html( 'about ' . \$context )" "$g" && fail "$g writes an English literal into a translatable suffix"
grep -Fq "sprintf( __( 'about %s', 'theme-slug' ), \$context )" "$g" || fail "$g link-text suffix is not translatable"

# §15 -- the two flags behind a 404 or HTML sitemap, in the rule and in the validator.
for flag in rank_math_registration_skip rank_math_is_configured; do
  grep -Fq "$flag" "$k" || fail "$k lost the $flag sitemap flag"
  grep -Fq "get_option('$flag'" "$g" || fail "$g validator no longer reads $flag"
done
grep -Fq 'stop when it prints only' "$g" || fail "$g sitemap validator has no fix-and-re-run loop"

# §16 and §17.
grep -Fq "'application/ld+json'" "$g" || fail "$g lost the theme JSON-LD conflict detection"
grep -Fq 'Titles stop at 60 characters; descriptions run 70 to 160' "$k" || fail "$k lost the title and description limits"
grep -Fq "mb_strlen(\\\$" "$g" || fail "$g length validator no longer uses mb_strlen"
for n in '> 60)' '> 160)' '< 70)'; do
  grep -Fq "$n" "$g" || fail "$g length validator lost the $n bound"
done

# The breadcrumb trail stops on a 404.
grep -Fq 'is_404()' "$b" || fail "$b lost the is_404() guard"

# One bulk description seed, following the stated priority order.
# Single-quoted: the bash block in the reference escapes its dollars, so the file holds a literal \$.
seed='update_post_meta(\$p->ID, '"'"'rank_math_description'"'"', \$desc)'
n=$(grep -cF "$seed" "$s" || true)
[ "$n" -eq 1 ] || fail "$s carries $n bulk description seeds; one, following SKILL.md §7, is the contract"
bulk=$(awk '/^### Bulk Seed via WP-CLI/{on=1} on' "$s")
grep -Fq "preg_match('/<p[^>]*>" <<<"$bulk" || fail "$s bulk seed skips the first-paragraph step of the priority order"

# The agent owns the setup order; the skill no longer carries a second, drifting copy.
grep -Fq '## 12. SEO Seeding Sequence' "$k" && fail "$k carries a second copy of wp-audit-rankmath's step order"
grep -Fq "\`wp-audit-rankmath\`'s Steps 1 to 15" "$k" || fail "$k does not hand the setup order to wp-audit-rankmath"
grep -Fq 'stop when the titles print' "$k" || fail "$k verification has no stop condition"

# One term for one setting, and the wrapper is defined.
grep -Eq 'Title Formulas|\| Formula \|' "$k" "$s" && fail "the SEO skill calls title templates formulas again"
grep -Fq '`$WP` throughout is the WP-CLI wrapper' "$k" || fail "$k uses \$WP without saying what it is"

# llms.txt and AI-crawler policy are the GEO skill's, and the description says so.
grep -Eq '^description: .*Not for llms\.txt, AI-crawler rules in robots\.txt or the Content-Signal header \(wp-audit-geo-standards\)' "$k" \
  || fail "$k description still claims llms.txt and AI-crawler work"

echo "PASS: the Rank Math contracts are pinned, with one seed, one term and one owner for the setup order"
