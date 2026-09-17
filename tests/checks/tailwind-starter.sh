#!/usr/bin/env bash
# Guards against bugs that shipped in the __tailwind__ starter:
#   1. a duplicate function declaration (fatal "Cannot redeclare")
#   2. a nonexistent @tailwindcss/typography pin (0.6.x does not exist; it is a 0.5.x package)
#   3. the Spanish Translations settings tab registered unconditionally instead of gated on
#      the project's configured languages, plus the unquoted-bareword regression a quoting
#      bug in that same gate left behind.
#   4/5. base/reset.css duplicated what Preflight already sets (box-sizing: border-box,
#      img { max-width: 100% }) as plain, unlayered CSS. Preflight sets both inside its
#      OWN `base` layer already; the duplicate outranked every utility regardless, and
#      cost a button rendered at a fraction of its design size and a slider arrow
#      clamped to its button's width on a real build that started from this starter.
#      The starter also never restored `cursor: pointer`, which Preflight does NOT set —
#      Tailwind v4 leaves every button on the UA default (`default`), not `pointer`.
set -euo pipefail
cd "$(dirname "$0")/../.."
dir=starter-theme/__tailwind__

# 1. No PHP function name declared more than once across the theme's inc/ + root PHP.
# Match `function name(` anywhere (a space after `function` excludes `function_exists`).
dupes=$(grep -rhoE 'function[[:space:]]+[a-zA-Z0-9_]+[[:space:]]*\(' "$dir" --include='*.php' \
  | sed -E 's/.*function[[:space:]]+([a-zA-Z0-9_]+).*/\1/' | sort | uniq -d || true)
if [ -n "$dupes" ]; then
  echo "FAIL: duplicate PHP function declaration(s) in $dir: $dupes"; exit 1
fi

# 2. The typography dependency must be a real 0.5.x pin, never 0.6.x.
if grep -Eq '"@tailwindcss/typography":\s*"\^?0\.6' "$dir/package.json"; then
  echo "FAIL: @tailwindcss/typography pinned to nonexistent 0.6.x"; exit 1
fi
grep -Eq '"@tailwindcss/typography":\s*"\^?0\.5\.' "$dir/package.json" \
  || { echo "FAIL: @tailwindcss/typography 0.5.x pin missing"; exit 1; }

# 3. The settings page must gate the Spanish tab on language, not register it unconditionally.
sf="$dir/fields/settings.php"
grep -Fq "in_array( 'es', __STARTER___SUPPORTED_LANGS" "$sf" \
  || { echo "FAIL: settings.php does not language-gate the Spanish Translations tab"; exit 1; }
# Guard against the bareword regression (unquoted array keys / string) from a quoting bug.
if grep -Eq 'settings_group\[fields\]|in_array\( es,' "$sf"; then
  echo "FAIL: settings.php has unquoted bareword array key / string (quoting regression)"; exit 1
fi

# 4. main.css imports every base/components/utilities file WITH its cascade layer.
# A bare @import leaves the whole file unlayered, and unlayered CSS beats every
# Tailwind utility regardless of specificity or source order.
main="$dir/assets/css/src/tailwindcss/main.css"
[ -f "$main" ] || { echo "FAIL: $main missing"; exit 1; }
# The pattern ends in `"\s*;`, so it only matches an import whose closing quote is
# followed straight by the semicolon — one with no layer() between them.
if grep -Eq '@import\s+"\./base/[^"]+"\s*;' "$main"; then
  echo "FAIL: $main imports a base/ file with no layer() — it sits outside every cascade layer and outranks any utility"; exit 1
fi
grep -Eq '@import\s+"\./base/reset\.css"\s+layer\(base\)\s*;' "$main" \
  || { echo "FAIL: $main does not import base/reset.css as layer(base)"; exit 1; }
grep -Eq '@import\s+"\./components/buttons\.css"\s+layer\(components\)\s*;' "$main" \
  || { echo "FAIL: $main does not import components/buttons.css as layer(components)"; exit 1; }
for u in animations motion wordpress; do
  grep -Eq "@import\\s+\"\\./utilities/${u}\\.css\"\\s+layer\\(utilities\\)\\s*;" "$main" \
    || { echo "FAIL: $main does not import utilities/${u}.css as layer(utilities)"; exit 1; }
done

# 5. base/reset.css must not duplicate what Preflight already sets, and must restore
# `cursor`, which Preflight does not.
reset="$dir/assets/css/src/tailwindcss/base/reset.css"
[ -f "$reset" ] || { echo "FAIL: $reset missing"; exit 1; }
# Strip comments over the whole file (-0777 slurps it, so multi-line comments go too),
# non-greedy — the first `*/` closes a CSS comment, exactly as a browser reads it.
rbody=$(perl -0777 -pe 's{/\*.*?\*/}{}gs' "$reset" | tr -d '[:space:]')
if printf '%s' "$rbody" | grep -Eq '\*,\*::before,\*::after\{box-sizing:border-box;?\}'; then
  echo "FAIL: $reset duplicates Preflight's box-sizing:border-box — Preflight already sets it inside its own base layer, and a hand-written second copy has clamped a button to 62% of its design width"; exit 1
fi
if printf '%s' "$rbody" | grep -Eq 'img\{max-width:100%'; then
  echo "FAIL: $reset duplicates Preflight's img{max-width:100%} — a hand-written second copy has clamped a deliberately overhanging slider arrow to its button's width"; exit 1
fi
# Checked against the comment-stripped body, so a commented-out rule does not count.
grep -Fq 'cursor:pointer' <<<"$rbody" \
  || { echo "FAIL: $reset does not restore cursor:pointer — Preflight leaves every button on the UA default (default, not pointer)"; exit 1; }
grep -Fq 'input[type="submit"]' "$reset" \
  || { echo "FAIL: $reset's cursor rule does not cover input[type=submit] — Contact Form 7 and WordPress's own comment form render their submit this way, and button{cursor:pointer} never reaches it"; exit 1; }

echo PASS
