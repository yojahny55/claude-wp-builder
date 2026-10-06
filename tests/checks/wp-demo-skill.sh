#!/usr/bin/env bash
# wp-demo skill: the contract a demo page is written against, and the skeleton it is
# copied from.
#
# What drifted before this check existed: the skill gave plain-mode rules (token names,
# placeholder images, a styles.css destination) to every build without reading the
# recorded `demo mode`, so a craft build loaded two contradicting instruction sets; it
# disagreed with commands/wp-demo.md Step 4 on token names, fonts and images, so whichever
# file was read last won; its skeleton broke its own accessibility rules (no skip link, no
# id="main-content", a hamburger with no aria-expanded, .sr-only never defined); its footer
# used a .footer__tagline class /wp-seed never reads and a bare <p> copyright; and every
# demo copied from it inherited a hard-coded "(c) 2025".
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

s=skills/wp-demo/SKILL.md
k=skills/wp-demo/references/demo-skeleton.md
c=commands/wp-demo.md
for f in "$s" "$k" "$c"; do [ -f "$f" ] || fail "$f is missing"; done

# --- the recorded decision, not a guess -------------------------------------------
grep -Fq '"demo mode"' "$s" || fail "$s does not read the recorded demo mode before applying plain-mode rules"
grep -Fq 'absent' "$s" && grep -Fq 'means `plain`' "$s" \
  || fail "$s does not say an absent demo mode means plain"
grep -Fq 'design-md.md' "$s" || fail "$s does not send a craft build to design-md.md for its tokens"
grep -Fq 'assets/css/styles.css' "$s" \
  && fail "$s still extracts demo CSS into assets/css/styles.css, which no current starter has"
grep -Fq 'invoked automatically' "$s" \
  && fail "$s claims external skills are invoked automatically; nothing in this plugin invokes them"

# --- one default per topic, in the skill and in the command ------------------------
for f in "$s" "$k"; do
  grep -Fq 'placehold.co' "$f" && fail "$f uses an external placeholder service; /wp-seed imports every img[src] URL"
done
grep -Fq 'inline SVG' "$s" || fail "$s does not state the inline-SVG placeholder default"
grep -Fq 'inline SVG' "$c" || fail "$c Step 4 does not state the same placeholder default as the skill"
grep -Fq 'CSS background colors' "$c" \
  && fail "$c Step 4 still offers CSS background boxes as a second placeholder, which drops the <img> an ACF image field maps to"
grep -Fq 'Google Fonts' "$c" || fail "$c Step 4 bans every CDN link while the skill's skeleton loads Google Fonts"
grep -Eq -- '--color-bg\b|--font-heading\b|--font-body\b|--space-(xs|sm|md|lg|xl|2xl|3xl)\b' "$c" \
  && fail "$c names demo tokens wp-css-system does not define (tests/checks/wp-css-tokens.sh calls them non-canonical)"
grep -Fq 'wp-css-system/references/tokens.md' "$c" || fail "$c Step 4 does not take its token names from wp-css-system"
for t in --color-background --spacing-md --font-family-primary --transition-base; do
  grep -Fq -- "$t:" "$k" || fail "$k :root does not define $t"
done

# --- the skeleton keeps the skill's accessibility rules ----------------------------
grep -Fq 'href="#main-content" class="sr-only sr-only--focusable"' "$k" || fail "$k has no skip link"
grep -Fq '<main id="main-content">' "$k" || fail "$k's <main> is not the skip link's target"
grep -Eq 'class="header__hamburger"[^>]*aria-expanded="false"' "$k" || fail "$k's hamburger has no aria-expanded"
grep -Fq '.sr-only {' "$k" || fail "$k uses .sr-only without defining it"
grep -Fq ':focus-visible' "$k" || fail "$k defines no visible focus style"
grep -Fq 'header__lang' "$k" || fail "$k's header has no language switcher, which commands/wp-demo.md Step 4 requires"

# --- footer classes /wp-seed reads ------------------------------------------------
grep -Fq '`.footer__description`' commands/wp-seed.md && grep -Fq '`.footer__copyright`' commands/wp-seed.md \
  || fail "commands/wp-seed.md no longer maps .footer__description/.footer__copyright; re-check $k"
grep -Fq 'class="footer__description"' "$k" || fail "$k's footer tagline is not .footer__description, so /wp-seed skips it"
grep -Fq 'class="footer__copyright"' "$k" || fail "$k's copyright line has no .footer__copyright class, so /wp-seed skips it"
grep -q 'footer__tagline\|footer_tagline' "$s" "$k" && fail "the wp-demo skill still names footer_tagline/.footer__tagline, which no command reads"
grep -Eq '&copy; *(19|20)[0-9]{2}' "$k" && fail "$k hard-codes a copyright year that every copied demo inherits"
n=$(grep -c '<footer' "$k")
[ "$n" -eq 1 ] || fail "$k prints the footer $n times; two copies drift"

# --- the delimiter contract other commands parse -----------------------------------
# /wp-section, /wp-seed, /wp-polish and wp-normalize extract sections by these comments,
# and demo/.demo-plan.json joins on the name, so the pair and the verbatim name are the
# contract, not a style.
grep -Fq '<!-- ============ SECTION: Hero ============ -->' "$s" || fail "$s does not show the opening delimiter"
grep -Fq '<!-- ============ END SECTION: Hero ============ -->' "$s" || fail "$s does not show the closing delimiter"
grep -Fq 'verbatim join key' "$s" || fail "$s does not say the section name is a verbatim join key"
grep -Fq 'identical in both comments' "$s" || fail "$s does not require the same name in the opening and closing comment"
grep -Fq '`Header` and `Footer`' "$s" || fail "$s does not name the shared-chrome sections"
grep -Fq 'These delimiters are critical' "$c" || fail "$c no longer marks the delimiters as critical"

# --- description and loop ----------------------------------------------------------
desc=$(awk 'NR<=6 && /^description:/' "$s")
printf '%s' "$desc" | grep -q '[<>]' && fail "$s's description carries angle brackets"
printf '%s' "$desc" | grep -Fq 'wp-demo-craft' || fail "$s's description does not send craft requests to wp-demo-craft"
grep -Fq 'Run `/wp-demo-verify' "$s" && grep -Fq 'Stop when it reports no overflow' "$s" \
  || fail "$s does not loop on /wp-demo-verify with a stop condition"

echo PASS
