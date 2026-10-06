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

# Every token an example USES must be one the token reference DEFINES. The deny-list
# above only catches names that already shipped once; the agent's hero and values
# examples went on to use --color-white, --color-accent and --color-accent-dark, and the
# skill's own drop-shadow example --color-accent — none of them in tokens.md, so an agent
# copying the example emitted an undefined var(). Resolved by name against tokens.md.
# `--x` is the prose placeholder in "never emit a var(--x)"; `--motion-*` are written by
# the motion engine at runtime, not declared in :root.
tokens=skills/wp-css-system/references/tokens.md
defs=$(grep -oE '^[[:space:]]*--[a-z0-9-]+:' "$tokens" | tr -d ' :' | sort -u)
[ -n "$defs" ] || { echo "FAIL: $tokens defines no tokens — the resolution check below would judge nothing"; exit 1; }
for src in "$f" skills/wp-css-system/SKILL.md skills/wp-css-system/references/patterns.md; do
  used=$(grep -oE 'var\(--[a-z0-9-]+' "$src" | sed 's/^var(//' | sort -u || true)
  for v in $used; do
    case "$v" in --x|--motion-*) continue ;; esac
    printf '%s\n' "$defs" | grep -qx -- "$v" \
      || { echo "FAIL: $src uses var($v), which $tokens never defines — an agent copying the example emits an undefined custom property"; exit 1; }
  done
done

# The sample values are placeholders, and the reference must say so: without it a plain
# demo ships the sample green and gold as the client's palette.
grep -Fq 'The values are placeholders' "$tokens" \
  || { echo "FAIL: $tokens does not mark its sample palette and fonts as placeholders"; exit 1; }
grep -Fq 'the values there are placeholders' skills/wp-css-system/SKILL.md \
  || { echo "FAIL: wp-css-system SKILL.md still presents tokens.md's values as defaults to use"; exit 1; }

echo PASS
