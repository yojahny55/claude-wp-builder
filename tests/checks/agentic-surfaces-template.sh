#!/usr/bin/env bash
# wp-agentic-surfaces used to carry ~700 lines of PHP inside its markdown and rewrite them
# into the theme on every run. CI lints files, not PHP inside markdown, so the 7.4 floor the
# agent declares was never checked and each run could drift. The PHP is now one real file the
# agent copies and token-substitutes; this check pins that split.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

tpl=templates/agentic/agentic.php
agent=agents/wp-agentic-surfaces.md
[ -f "$tpl" ] || fail "$tpl is missing"
[ -f "$agent" ] || fail "$agent is missing"

# The template parses, and after substitution still parses (7.4 floor lives in CI; here
# whatever php is on the machine).
if command -v php >/dev/null 2>&1; then
  php -l "$tpl" >/dev/null || fail "$tpl does not parse"
  tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
  sed -e 's/__prefix__/demo/g' -e 's/__SITE_TYPE__/content/g' "$tpl" > "$tmp"
  php -l "$tmp" >/dev/null || fail "$tpl does not parse after token substitution"
fi

# The agent references and copies it.
grep >/dev/null -cF 'templates/agentic/agentic.php' "$agent" || fail "$agent does not reference $tpl"
grep >/dev/null -cF '\cp -f' "$agent" || fail "$agent does not copy the template with \\cp -f"

# The agent must not carry the PHP inline again: only the small functions.php snippet.
inline=$(awk '/^```php/{f=1;next} /^```/{f=0} f' "$agent" | wc -l)
[ "$inline" -le 40 ] || fail "$agent carries $inline lines of fenced PHP (max 40); put it in $tpl"

# Tokens: exactly the ones the template uses are the ones the agent documents.
in_tpl=$(grep -oE '__[A-Za-z]+__' "$tpl" | sort -u | tr '\n' ' ')
doc=$(sed -n '/^| Token | Replace with |/,/^$/p' "$agent" | grep -oE '`__[A-Za-z]+__`' | tr -d '`' | sort -u | tr '\n' ' ')
[ -n "$in_tpl" ] || fail "$tpl uses no tokens"
[ "$in_tpl" = "$doc" ] || fail "tokens differ: template uses [$in_tpl], agent documents [$doc]"

# No unsubstituted legacy placeholder in the template.
! grep -qF '<prefix>' "$tpl" || fail "$tpl still holds a <prefix> placeholder"

echo PASS
