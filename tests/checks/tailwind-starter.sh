#!/usr/bin/env bash
# Guards against two bugs that shipped in the __tailwind__ starter:
#   1. a duplicate function declaration (fatal "Cannot redeclare")
#   2. a nonexistent @tailwindcss/typography pin (0.6.x does not exist; it is a 0.5.x package)
set -euo pipefail
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

echo PASS
