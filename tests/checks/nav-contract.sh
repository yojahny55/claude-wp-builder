#!/usr/bin/env bash
set -euo pipefail
s=skills/wp-theme-standards/SKILL.md
grep -qi 'nav.*class contract\|nav-class contract\|Navigation class contract' "$s" || { echo "FAIL: no nav contract in wp-theme-standards"; exit 1; }
for c in 'nav__menu' 'nav__item--has-children' 'nav__link' 'nav__submenu' 'nav__toggle'; do
  grep -q "$c" "$s" || { echo "FAIL: contract missing .$c"; exit 1; }
done
grep -qi 'baseline\|align-items' "$s" || { echo "FAIL: contract missing dropdown baseline-alignment rule"; exit 1; }
grep -q 'nav-class contract\|nav contract\|wp-theme-standards' agents/wp-template.md || { echo "FAIL: wp-template does not reference the contract"; exit 1; }
grep -q 'nav-class contract\|nav contract\|wp-theme-standards' agents/wp-css.md || { echo "FAIL: wp-css does not reference the contract"; exit 1; }
echo PASS
