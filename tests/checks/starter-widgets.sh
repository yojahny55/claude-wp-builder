#!/usr/bin/env bash
# Tabs, accordions and directory filters were hand-written per template on a real build:
# its tabs.js only moved the underline marker (no aria-selected, no panel switch), and two
# of its three directories had no results count and no "clear filters". The tailwind
# starter now owns one module per widget, and the builders must use it.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

js=starter-theme/__tailwind__/assets/js/src
for m in tabs accordion directory-filter; do
  [ -f "$js/$m.js" ] || fail "$js/$m.js is missing"
  grep -Eq "^import \{ init[A-Za-z]+ \} from './$m.js';" "$js/index.js" || fail "$js/index.js does not import ./$m.js"
done
grep -Fq 'initTabs();' "$js/index.js" && grep -Fq 'initAccordions();' "$js/index.js" \
  && grep -Fq 'initDirectoryFilters();' "$js/index.js" || fail "$js/index.js imports a widget module it never starts"

# Tabs switch state, not just the marker.
for n in "setAttribute('aria-selected'" "classList.toggle('is-active'" "panel.hidden = !on" \
    "'ArrowRight'" "'ArrowLeft'" "'Home'" "'End'" "[data-tab-label]" "marker.style.width"; do
  grep -Fq -- "$n" "$js/tabs.js" || fail "tabs.js lacks: $n"
done
# Accordion: groups scoped per container, single by default, standalone folds open.
for n in "closest('[data-accordion]')" "'single'" "setAttribute('aria-expanded'" "declared === null ? !group" "is-open"; do
  grep -Fq -- "$n" "$js/accordion.js" || fail "accordion.js lacks: $n"
done
grep -Fq 'data-accordion="single|multiple"' skills/wp-tailwind-system/SKILL.md \
  || grep -Fq 'data-accordion="single\|multiple"' skills/wp-tailwind-system/SKILL.md \
  || fail "wp-tailwind-system does not document the accordion group modes"
# Directory filter: count line, clear, URL reload, hidden when unfiltered.
for n in "data-count-template" "data-count-template-one" "[data-filter-clear]" "count.hidden = !filtered" \
    "searchParams.delete(name)" "window.location.assign" "directory-filter:reset" "never be a public query var"; do
  grep -Fq -- "$n" "$js/directory-filter.js" || fail "directory-filter.js lacks: $n"
done

# The builders use the modules, and say why the GET name matters.
grep -Fq 'directory-filter.js' commands/wp-cpt.md || fail "/wp-cpt does not build its filter bar on directory-filter.js"
grep -Fq 'public query var' commands/wp-cpt.md || fail "/wp-cpt does not forbid a public query var as a filter GET name"
grep -Fq '[data-directory]' agents/wp-template.md || fail "wp-template does not route every directory through [data-directory]"
grep -Fq 'accordion.js' commands/wp-section.md || fail "/wp-section does not point tabs/accordions at the starter modules"
grep -Fq '## Tabs, accordions and directory filters come from the starter' skills/wp-tailwind-system/SKILL.md \
  || fail "wp-tailwind-system does not document the widget modules"
for k in directory_count directory_count_one directory_clear directory_empty directory_search directory_all; do
  grep -Fq "'$k'" starter-theme/__tailwind__/inc/i18n.php || fail "inc/i18n.php has no $k string"
  grep -Fq "'$k'" starter-theme/_i18n-variants/__tailwind__.php || fail "the polylang i18n variant has no $k string"
done

echo PASS
