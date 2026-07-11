#!/usr/bin/env bash
# The wp-css agent must teach the canonical design-token vocabulary (the one the
# wp-demo + wp-css-system skills and the starter :root actually define), not a
# private set that resolves to undefined var(--x) in generated CSS.
set -euo pipefail
f=agents/wp-css.md

# Known-wrong token names that previously shipped in the agent's examples and caused
# undefined custom properties in generated section CSS.
bad='(--color-bg\b|--color-bg-alt\b|--color-text-muted\b|--font-heading\b|--font-body\b|--text-(xs|sm|base|md|lg|xl|2xl|3xl|4xl)\b)'
hits=$(grep -oE "$bad" "$f" | sort -u || true)
if [ -n "$hits" ]; then
  echo "FAIL: wp-css agent references non-canonical token names:"; echo "$hits"; exit 1
fi

# The agent must carry the token-integrity rule (never emit an undefined var).
grep -q 'Never emit an undefined' "$f" \
  || { echo "FAIL: wp-css agent missing the undefined-var integrity rule"; exit 1; }

echo PASS
