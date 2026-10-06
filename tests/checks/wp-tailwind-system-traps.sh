#!/usr/bin/env bash
# wp-tailwind-system: the rules a later edit could silently reverse, and the script calls
# an agent copies. What shipped wrong:
#   - references/breakpoints.md banned `max-[<n>px]:` in its heading and then marked
#     `max-[769px]:hidden` as the RIGHT conversion, and said `max-[759px]` is `≤ 759` when
#     Tailwind compiles every max-* variant as `<`;
#   - references/components.md and cross-engine.md called `bin/theme-template-check.mjs`
#     and `bin/css-contour-lint.mjs` by a bare relative path, which exits 127 from the
#     user's project (and the widget gate exits 2 without a theme dir);
#   - Verify ran the convention check before any compile, where its markup rule is skipped
#     and it passes having checked nothing, and never ran theme-template-check.mjs.
set -uo pipefail
# `q "$text" <grep flags> <pattern>`: a here-string, never `printf | grep -q`. Under
# pipefail an early-exiting `grep -q` hands printf a SIGPIPE and the pipeline returns 141,
# which silently flips an assertion either way.
q() { local s=$1; shift; grep -q "$@" <<<"$s"; }
cd "$(dirname "$0")/../.." || { echo "FAIL: cannot cd to the repository root"; exit 1; }
fail() { echo "FAIL: $*"; exit 1; }

dir=skills/wp-tailwind-system
skill=$dir/SKILL.md
bp=$dir/references/breakpoints.md
for f in "$skill" "$bp" "$dir/references/components.md" "$dir/references/cross-engine.md"; do
  [ -f "$f" ] || fail "$f is missing"
done
flat() { tr '\n' ' ' < "$1" | sed 's/  */ /g'; }

# 1. Breakpoints: the form the file forbids is never the one it marks right.
#    In every html fence, a `<!-- right…` comment and the markup up to the next comment
#    or the fence end must carry no arbitrary max-[…] variant.
right=$(awk '/^```html/{f=1; next} /^```/{f=0; r=0} f && /<!-- *right/{r=1; next} f && /<!--/{r=0} f && r' "$bp")
[ -n "$right" ] || fail "$bp marks no conversion as right — the examples lost their direction"
q "$right" -F 'max-[' && fail "$bp marks an arbitrary max-[…] variant as the right conversion, the form its own heading forbids: $(printf '%s\n' "$right" | grep -F 'max-[' | head -1)"
q "$(flat "$bp")" -E 'becomes a `--breakpoint-\*` stop set to `N\+1`' \
  || fail "$bp does not state the default: a demo's max-width N becomes a --breakpoint-* stop at N+1"
q "$(flat "$bp")" -F 'only for the one-off width' \
  || fail "$bp does not confine the arbitrary max-[N+1px]: form to a one-off width"
grep -Fq '`max-[759px]` is `≤ 759`' "$bp" \
  && fail "$bp says max-[759px] is ≤ 759 — Tailwind compiles every max-* variant as width < N"
grep -Fq 'references/breakpoints.md' "$skill" || fail "$skill no longer links references/breakpoints.md"

# 2. Every plugin script the skill or its references name is rooted at the plugin.
bare=$(cat "$skill" "$dir"/references/*.md | grep -oE '.{0,22}bin/[a-z-]+\.(sh|mjs)' | grep -v 'CLAUDE_PLUGIN_ROOT}\?/bin/' || true)
[ -z "$bare" ] || fail "a script is called by a bare relative bin/ path, which exits 127 from the user's project: $bare"
grep -Fq 'theme-template-check.mjs" <theme-dir> --rule widgets' "$dir/references/components.md" \
  || fail "components.md calls the widget gate without a theme directory — the script exits 2"

# 3. Verify compiles first, then runs every check, including theme-template-check.mjs.
v=$(awk '/^## Verify/{f=1; next} f && /^## /{exit} f' "$skill")
[ -n "$v" ] || fail "$skill has no ## Verify section"
rb=$(printf '%s\n' "$v" | grep -n 'bin/tailwind-rebuild.sh' | head -1 | cut -d: -f1)
nc=$(printf '%s\n' "$v" | grep -n 'bin/tailwind-native-check.sh' | head -1 | cut -d: -f1)
[ -n "$rb" ] && [ -n "$nc" ] && [ "$rb" -lt "$nc" ] \
  || fail "Verify does not compile (tailwind-rebuild.sh) before the convention check — without dist/main.css its markup rule is skipped and it passes"
q "$v" -F '/bin/theme-template-check.mjs" <theme-dir>' \
  || fail "Verify does not run theme-template-check.mjs, the check that catches a utility missing from the compiled CSS"
q "$v" -Ei 'exit 0' || fail "Verify states no exit codes, so a non-zero exit reads as noise"
q "$v" -F '=\"' && fail "Verify's quote grep still escapes the quote (grep warns on a stray \\\")"

echo PASS
