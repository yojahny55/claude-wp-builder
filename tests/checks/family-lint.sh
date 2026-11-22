#!/usr/bin/env bash
# bin/family-lint.mjs: the measurable part of a craft family's Avoid list, reported, never enforced.
#
# Runs the lint on a scratch demo that holds each finding next to the look-alikes it must
# leave alone (backdrop-filter: none, a pill, an 8px radius, a radius with no border, an
# accent repeated in a second shade, a desaturated grey, a dot-directory), and asserts the
# exact findings, the var() resolution, the @media and style="" reads, and that it exits 0
# with findings: the evaluator decides, the lint never blocks. Then greps /wp-demo and
# families.md for the hand-off to the critique.
#
# FAMILY_LINT overrides the tool path, so a mutated copy can be checked against this file.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/lib/assert.sh
require_tool node

tool=${FAMILY_LINT:-bin/family-lint.mjs}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

run() { set +e; out=$(node "$tool" "$@" 2>&1); rc=$?; set -e; }
count() { printf '%s\n' "$out" | grep -Ec -- "$1" || true; }
has() { [ "$(count "$1")" -gt 0 ] || fail "$2 (output was: $out)"; }
hasnt() { [ "$(count "$1")" -eq 0 ] || fail "$2 (output was: $out)"; }

d=$tmp/demo
mkdir -p "$d/.verify" "$d/assets" "$d/node_modules/x"
cat > "$d/index.html" <<'HTML'
<html><head><style>
:root { --radius-card: 20px; --accent: #ff5a1f; --accent-deep: #e0480f; --ink: #111; --muted: #8a8f98; }
.nav { backdrop-filter: blur(12px); }
.nav--plain { backdrop-filter: none; -webkit-backdrop-filter: none; }
.card { border: 1px solid #ddd; border-radius: var(--radius-card); }
.btn { border: 1px solid var(--accent); border-radius: 999px; }
.avatar { border: 2px solid var(--ink); border-radius: 50%; }
.cell { border: 1px solid #000; border-radius: 8px; }
.tag { border-radius: 16px; background: var(--accent-deep); }
.flat { border: none; border-radius: 24px; }
@media (min-width: 768px) { .feature { border-width: 2px; border-style: solid; border-radius: 1rem; } }
</style></head><body>
<p style="color: #2563eb">second hue</p>
<div style="-webkit-backdrop-filter: blur(4px)">inline glass</div>
</body></html>
HTML
cat > "$d/assets/site.css" <<'CSS'
.panel { border: 1px dashed #ccc; border-radius: 14px; }
.subtle { border: 1px solid rgb(0 0 0 / .1); border-radius: 18px; }
.undone { border: 1px solid #ddd; border: none; border-radius: 20px; }
.flattened { border: 1px solid #ddd; border-radius: 20px; border-radius: 0; }
.nostyle { border-width: 2px; border-radius: 20px; }
.reset { border: 1px solid #ddd; border-width: 0; border-radius: 20px; }
.Cased { --Card-R: 22px; border: 1px solid #ddd; border-radius: var(--Card-R); }
.icon { fill: url(#f00); }
.wide { color: color(display-p3 1 0 0); }
.later { border-width: 2px; border-style: solid; border: none; border-radius: 20px; }
.local { --radius-card: 6px; border: 1px solid #ddd; border-radius: var(--radius-card); }
.ghost { border: 1px solid transparent; border-radius: 20px; }
.open3 { border: 1px solid #ddd; border-bottom: 0; border-radius: 20px; }
.four { border-width: 2px 2px 2px 2px; border-style: solid; border-radius: 20px; }
.p3 { --wide: color(display-p3 1 0 0); background: var(--wide); border-color: var(--wide); }
.recolored { border: 1px solid transparent; border-color: #ddd; border-radius: 20px; }
.reside { border: 1px solid #ddd; border-bottom: 0; border-bottom: 1px solid #ddd; border-radius: 20px; }
.oneside { border: 1px solid #ddd; border-left-style: none; border-radius: 20px; }
.pairs { border-style: solid; border-width: 2px 0; border-radius: 20px; }
.zero { border: 0 solid #000; border-radius: 20px; }
.mix { border: 1px solid color-mix(in srgb, #000 12%, transparent); border-radius: 20px; }
.logical { border-inline: 1px solid #ddd; border-block: 1px solid #ddd; border-radius: 20px; }
.noinline { border: 1px solid #ddd; border-inline: none; border-radius: 20px; }
.zeropt { border: 0pt solid #000; border-radius: 20px; }
.open { border: 2px solid #000; border-radius: 30px;
CSS
printf '.x { backdrop-filter: blur(3px); color: #00ff00; }\n' > "$d/.verify/skip.css"
printf '.y { backdrop-filter: blur(3px); }\n' > "$d/node_modules/x/lib.css"
printf '.z { backdrop-filter: blur(3px); }\n' > "$d/assets/vendor.min.css"

run "$d"
[ "$rc" = 0 ] || fail "findings must still exit 0 (the lint never blocks), got $rc ($out)"
has '^glass +index\.html:3 +\.nav$' 'backdrop-filter: blur() on .nav must be reported as glass at line 3'
has '^glass +index\.html:14 +\[style\]$' 'an inline -webkit-backdrop-filter must be reported at line 14'
[ "$(count '^glass ')" = 2 ] || fail "exactly 2 glass findings expected (none, dot-dirs, node_modules, .min.css skipped) (output was: $out)"
has '^rounded-card +index\.html:5 +\.card$' 'a var() radius of 20px on a bordered box must be reported'
has 'border-radius: 20px \(20px\) with border: 1px solid #ddd' 'the var() radius must be resolved to its value'
has '^rounded-card +index\.html:11 +\.feature$' 'a 1rem radius with border-width inside @media must be reported'
has '^rounded-card +assets/site\.css:1 +\.panel$' 'a linked .css file must be read'
has '^rounded-card +assets/site\.css:2 +\.subtle$' 'the 0 inside rgb(0 0 0 / .1) must not be read as a zero-width border'
has '^rounded-card +assets/site\.css:7 +\.Cased$' 'a custom property must be resolved with its own case'
has '^rounded-card +assets/site\.css:25 +\.open$' 'a block left open at the end of a file must still be read'
has '^rounded-card +assets/site\.css:14 +\.four$' 'four equal border-width values must count as a border all round'
has '^rounded-card +assets/site\.css:16 +\.recolored$' 'a later visible border-color must bring a transparent border back'
has '^rounded-card +assets/site\.css:17 +\.reside$' 'a side removed then set again must count'
has '^rounded-card +assets/site\.css:21 +\.mix$' 'transparent inside color-mix() is an input, not an invisible border'
has '^rounded-card +assets/site\.css:22 +\.logical$' 'border-inline plus border-block is a border all round'
hasnt '\.(oneside|pairs|zero|noinline|zeropt)$' 'border-left-style: none after the shorthand, border-width: 2px 0 or border: 0 solid removes a side'
hasnt '\.(undone|flattened|nostyle|reset|later|ghost|open3)$' 'a later border: none, border-radius: 0, border-width: 0 or border-bottom: 0, a transparent border, or a width with no style, must not report'
hasnt '\.local$' "a rule's own custom property must win over :root's (6px, not 20px)"
[ "$(count '^rounded-card ')" = 11 ] || fail "exactly 11 rounded-card findings expected (pill, circle, 8px, unbordered, cancelled left out) (output was: $out)"
has '^accents ' 'two saturated hues must be reported'
has '2 saturated hues: ' 'the accent finding must count hues, not shades (#ff5a1f and #e0480f are one hue)'
has '#2563eb at index\.html:13' 'the second hue must carry where it is'
hasnt 'saturated hues: .*(#8a8f98|#111|#ddd|#000|#f00)' 'greys and url(#id) references must never count as accents'
has '^1 colour in color\(\) not read' 'each color() value must be counted once where written, not once per var() use'
has '^14 findings in 2 files\. Report only' 'the summary must count findings and files and say it only reports'

run "$d" --json
[ "$rc" = 0 ] || fail "--json must exit 0, got $rc"
printf '%s' "$out" | node -e 'const r=JSON.parse(require("fs").readFileSync(0,"utf8"));const n=(k)=>r.findings.filter((f)=>f.rule===k).length;if(r.files!==2||r.unread!==1||n("glass")!==2||n("rounded-card")!==11||n("accents")!==1)process.exit(1)' \
  || fail "--json must carry files=2, unread=1 and 2 glass, 11 rounded-card, 1 accents ($out)"

# One accent, no glass, no rounded card: a clean report, still exit 0.
mkdir -p "$tmp/clean"
printf '<style>:root{--a:#ff5a1f}.b{color:#ff6a2f;border:1px solid #000;border-radius:4px}</style>\n' > "$tmp/clean/index.html"
run "$tmp/clean"
[ "$rc" = 0 ] || fail "a clean demo must exit 0, got $rc"
has '^0 findings in 1 file\.' 'one accent in two shades must give no finding'

# CSS Color 4 palettes: two oklch hues are two accents; one hue in lch and oklab shades is one.
mkdir -p "$tmp/ok4" "$tmp/ok1"
printf '<style>.a{color:oklch(0.7 0.2 30)}.b{background:color-mix(in oklab, oklch(0.6 0.2 250) 50%%, white)}.g{color:oklch(0.6 0.02 140)}</style>\n' > "$tmp/ok4/index.html"
run "$tmp/ok4"
has '^accents ' 'two oklch hues (one inside color-mix) must be reported as two accents'
has '2 saturated hues: ' 'a low-chroma oklch grey must not count as a hue'
printf '<style>.a{color:oklch(0.65 0.2 30)}.b{color:lch(55 70 35)}.c{color:hwb(25 10%% 10%%)}</style>\n' > "$tmp/ok1/index.html"
run "$tmp/ok1"
hasnt '^accents ' 'one hue written in oklch, lch and hwb must stay one accent'
printf '<style>.a{color:#ff0000}.b{color:oklch(0.63 0.257 29.2)}.c{color:#0000ff}.d{color:oklch(0.45 0.31 264)}.e{color:lab(54 81 70)}</style>\n' > "$tmp/ok1/index.html"
run "$tmp/ok1"
has '2 saturated hues: ' 'pure red and blue in hex, oklch and lab must be two hues, not four: hues are compared on one wheel'

# A report larger than a pipe buffer (64 KiB) must arrive whole.
mkdir -p "$tmp/big"
awk 'BEGIN { printf "<style>"; for (i = 0; i < 4000; i++) printf ".c%d{border:1px solid #ddd;border-radius:20px}", i; print "</style>" }' > "$tmp/big/index.html"
n=$(node "$tool" "$tmp/big" --json | node -e 'process.stdout.write(String(JSON.parse(require("fs").readFileSync(0,"utf8")).findings.length))') \
  || fail 'a large --json report piped to a reader must parse: the output was cut short'
[ "$n" = 4000 ] || fail "a large report must carry all 4000 findings through a pipe, got $n"

# A symlink back up the tree is read once and never loops.
mkdir -p "$tmp/loop/sub"; printf '.x{color:red}\n' > "$tmp/loop/a.css"; ln -s .. "$tmp/loop/sub/up"
run "$tmp/loop"
has '^0 findings in 1 file\.' 'a symlink loop must not duplicate files'

# Nothing to read exits 2; bad usage exits 64.
mkdir -p "$tmp/empty"
run "$tmp/empty"; [ "$rc" = 2 ] || fail "a directory with no .html/.css must exit 2, got $rc"
run "$tmp/missing"; [ "$rc" = 2 ] || fail "a missing path must exit 2, got $rc"
run; [ "$rc" = 64 ] || fail "no path must exit 64, got $rc"
run "$d" --nope; [ "$rc" = 64 ] || fail "an unknown flag must exit 64, got $rc"

# The hand-off: /wp-demo gives the report to the critique, which decides.
cmd=commands/wp-demo.md
fam=skills/wp-demo-craft/references/families.md
need_token "$cmd" 'node "${CLAUDE_PLUGIN_ROOT}/bin/family-lint.mjs" demo/' '/wp-demo must run the family lint before the critique'
need_token "$cmd" 'The lint only reports and always exits `0`' '/wp-demo must say the lint never blocks'
need_token "$cmd" "deliberate exception, and both go into \`demo/VERIFY.md\`" 'every finding must be answered in VERIFY.md'
need_token "$fam" '`bin/family-lint.mjs`' 'families.md must name the lint'
need_token "$fam" 'It reports and never blocks' 'families.md must keep the never-blocks rule'

echo PASS
