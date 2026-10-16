#!/usr/bin/env bash
# A full store optimization (Lighthouse mobile 28-55 -> 93-95) rested on lessons that no code
# re-derives: the lab must resemble production (HTTP/2, compression, median of 5) before a
# score means anything; a used-CSS subset must keep the cascade position and include the
# carousel base CSS (its omission looped carousels); contrast failures end in a proposal for
# approval, never a colour edit. This pins the two bin tools by behaviour and the prose that
# carries the rest, in both directions.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
has() { grep -Fq -- "$1" "$2" || fail "$2 lost: $1"; }

# contrast-propose.mjs: behaviour
if command -v node >/dev/null; then
  out=$(node bin/contrast-propose.mjs --pair '#d85c33:#ffffff' --pair '#000000:#ffffff')
  echo "$out" | grep -Fq '#d85c33 on #ffffff | 3.82 | 4.5 | #' || fail "contrast-propose did not propose a shade for a failing pair"
  echo "$out" | grep -Fq '#000000 on #ffffff | 21.00 | 4.5 | passes' || fail "contrast-propose changed a passing pair"
  # h2-proxy: refuses to start without a target (no hidden site-specific default)
  if node bin/h2-proxy.mjs 2>/dev/null; then fail "h2-proxy started without --target"; fi
fi
! grep -Eq 'BEGIN (RSA |EC )?PRIVATE KEY' bin/h2-proxy.mjs || fail "h2-proxy.mjs carries a private key"
has 'openssl' bin/h2-proxy.mjs
ls bin/*.pem 2>/dev/null && fail "a key or certificate is committed under bin/"

L=skills/wp-audit-standards/references/performance-lessons.md
for t in 'A local lab that resembles production' 'bin/h2-proxy.mjs' '5 runs, take the median' \
  'Used-CSS subset of a huge parent stylesheet' 'Never move the full sheet' 'base stylesheet **whole**' \
  'RangeError' 'Deferring stylesheets that touch nothing above the fold' '@font-face' \
  'PHP_INT_MAX' 'DOMContentLoaded' 'jQuery.migrateWarnings' '5 s after `load`' '$.ajaxPrefilter' \
  'currentSrc' 'Applying the full sheets at load raised TBT'; do has "$t" "$L"; done
has 'h2-proxy.mjs' skills/wp-audit-run/references/site-context.md
has 'Never drop a sheet by page type' agents/wp-audit-performance.md
has 'jQuery.migrateWarnings' agents/wp-audit-performance.md
has 'propose, never apply' agents/wp-audit-a11y.md
has 'contrast-propose.mjs' skills/wp-audit-run/references/browser-suite.md
has 'contrast-propose.mjs' templates/audit-suite/README.md
has '`h2-proxy.mjs`' README.md
has '`contrast-propose.mjs`' README.md
# the old claim that PERF-047 is auto-fixable must be gone
! grep -F 'PERF-047 | Render-blocking third-party CSS' agents/wp-audit-performance.md | grep -Fq '| Yes |' || fail "PERF-047 is still marked auto-fixable"

# Behaviour: a proposal must reach its ratio on the rounded hex that ships, and --json must
# survive a pipe (process.exit after console.log once cut it at 64 KiB).
cp=bin/contrast-propose.mjs
node "$cp" --pair '#e3fecc:#03b07d' --pair '#dd1a3a:#e3bb9e' --json \
  | node -e 'const o=JSON.parse(require("fs").readFileSync(0,"utf8"));process.exit(o.length===2&&o.every(r=>r.ok||r.after>=r.need)?0:1)' \
  || fail "contrast-propose proposed a shade below its required ratio"
args=(); for i in $(seq 1 600); do args+=(--pair "#$(printf '%06x' $((i*20011 % 16777215))):#ffffff"); done
node "$cp" "${args[@]}" --json | node -e 'JSON.parse(require("fs").readFileSync(0,"utf8"))' \
  || fail "contrast-propose --json is truncated through a pipe"
printf '%s' '{"violations":[{"id":"color-contrast","nodes":[{"target":["p"],"html":"<p>x</p>","any":[{"data":{"fgColor":"#e3fecc","bgColor":"#03b07d","expectedContrastRatio":4.5}}]}]}]}' > "${TMPDIR:-/tmp}/axe-native.$$.json"
node "$cp" --axe "${TMPDIR:-/tmp}/axe-native.$$.json" | grep -Fq '#e3fecc on #03b07d' || { rm -f "${TMPDIR:-/tmp}/axe-native.$$.json"; fail "contrast-propose cannot read raw axe-core results"; }
rm -f "${TMPDIR:-/tmp}/axe-native.$$.json"
grep -Fq "listen(PORT, '127.0.0.1'" bin/h2-proxy.mjs || fail "h2-proxy must bind loopback only"
! git grep -n '/srv/http/claude-wp-builder' -- agents commands skills >/dev/null 2>&1 || fail "a distributed doc names an absolute plugin path"
echo PASS
