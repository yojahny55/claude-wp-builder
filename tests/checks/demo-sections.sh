#!/usr/bin/env bash
# /wp-section --list: bin/demo-sections.mjs lists a demo's sections and reports delimiter defects.
#
# Runs the tool on scratch projects and asserts what it prints and how it exits: the slug,
# line range and built state of each section, header/footer routed to their own commands,
# a prose comment that only looks like a delimiter left alone, and each delimiter defect
# (never closed, stray END, mismatched END, nested, duplicate, page with none) exiting 1.
# Then greps the command for the List mode contract.
#
# DEMO_SECTIONS overrides the tool path, so a mutated copy can be checked against this file.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/lib/assert.sh
require_tool node

tool=${DEMO_SECTIONS:-bin/demo-sections.mjs}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# run DIR [ARGS...]: sets $out and $rc.
run() { set +e; out=$(node "$tool" "$@" 2>&1); rc=$?; set -e; }
has() { [ "$(printf '%s\n' "$out" | grep -Ec -- "$1")" -gt 0 ] || fail "$2 (output was: $out)"; }
hasnt() { [ "$(printf '%s\n' "$out" | grep -Ec -- "$1")" -eq 0 ] || fail "$2 (output was: $out)"; }

# --- a clean project with a theme -------------------------------------------------------
p=$tmp/ok
mkdir -p "$p/demo" "$p/wp-content/themes/acme/template-parts"
printf '{"theme":{"slug":"acme"}}\n' > "$p/.wp-create.json"
: > "$p/wp-content/themes/acme/template-parts/section-hero.php"
cat > "$p/demo/index.html" <<'HTML'
<!-- Section intro, not a delimiter -->
<!-- ============ SECTION: Header ============ -->
<header></header>
<!-- ============ END SECTION: Header ============ -->
<!-- ============ SECTION: Hero ============ -->
<p>hero</p>
<!-- ============ END SECTION: Hero ============ -->
<!-- ============ SECTION: Our Team ============ -->
<!-- ============ END SECTION: Our Team ============ -->
<!-- ============ SECTION: Constructor ============ -->
<!-- ============ END SECTION: Constructor ============ -->
HTML
printf '<!-- SECTION: scene-1 -->\n<div></div>\n<!-- END SECTION -->\n' > "$p/demo/about.html"

run "$p"
[ "$rc" = 0 ] || fail "a clean demo must exit 0, got $rc"
has '^demo/index\.html \(4 sections\)' 'index.html must list exactly 4 sections (the prose comment is not one)'
has 'Hero +hero +lines 5-7 +built$' 'Hero must show slug hero, lines 5-7 and built'
has 'Our Team +our-team +lines 8-9 +not built$' 'a two-word name must slug to our-team and show not built'
has 'Header +header +lines 2-4 +by /wp-header$' 'Header must be routed to /wp-header'
has 'Constructor +constructor +lines 10-11 +not built$' 'a name shared with an Object.prototype member must still get its built check'
has 'scene-1 +scene-1 +lines 1-3 ' 'a cinematic END SECTION with no name must close the open section'
hasnt 'intro' 'a comment without the colon must not be read as a section'
has '^No delimiter defects\.$' 'a clean demo must say so'
# index.html is listed before about.html.
[ "$(printf '%s\n' "$out" | grep -n '^demo/' | sed -n 1p)" = "3:demo/index.html (4 sections)" ] \
  || fail "index.html must be listed first (output was: $out)"

run "$p" --page about
[ "$rc" = 0 ] || fail "--page about must exit 0, got $rc"
hasnt 'index\.html' '--page about must list only about.html'

run "$p" --json
[ "$rc" = 0 ] || fail "--json must exit 0, got $rc"
printf '%s' "$out" | node -e 'const r=JSON.parse(require("fs").readFileSync(0,"utf8"));if(r.defects!==0||r.pages[0].sections[1].built!==true)process.exit(1)' \
  || fail "--json must be parseable and carry defects=0 and built=true for hero"

# --- no theme: built is unknown, not "not built" -----------------------------------------
mkdir -p "$tmp/notheme/demo"; cp "$p/demo/index.html" "$tmp/notheme/demo/"
run "$tmp/notheme"
[ "$rc" = 0 ] || fail "a demo without a theme must still exit 0, got $rc"
has 'Hero +hero +lines 5-7 +\?$' 'without a theme the built column must be ?'

# --- each delimiter defect exits 1 and is named -------------------------------------------
defect() { # name, html, expected message regex
  local d=$tmp/d-$1
  mkdir -p "$d/demo"; printf '%b' "$2" > "$d/demo/index.html"
  run "$d"
  [ "$rc" = 1 ] || fail "defect $1 must exit 1, got $rc (output: $out)"
  has "DEFECT $3" "defect $1 must be reported as: $3"
}
defect unclosed  '<!-- SECTION: Hero -->\n<p></p>\n'                                              'line 1: "Hero" is never closed'
defect stray     '<!-- END SECTION: Hero -->\n'                                                     'line 1: END SECTION "Hero" closes no open section'
defect mismatch  '<!-- SECTION: Hero -->\n<!-- END SECTION: About -->\n'                            'line 2: END SECTION "About" closes "Hero"'
defect nested    '<!-- SECTION: Hero -->\n<!-- SECTION: About -->\n<!-- END SECTION: About -->\n'   'line 2: "About" opens inside "Hero"'
defect duplicate '<!-- SECTION: Hero -->\n<!-- END SECTION: Hero -->\n<!-- SECTION: hero -->\n<!-- END SECTION: hero -->\n' 'line 3: "hero" is declared twice'
defect sameslug  '<!-- SECTION: Our Team -->\n<!-- END SECTION -->\n<!-- SECTION: Our-Team -->\n<!-- END SECTION -->\n' 'line 3: "Our-Team" is declared twice on this page .same slug "our-team" as "Our Team" at line 1'
defect noslug    '<!-- SECTION: 団 -->\n<!-- END SECTION -->\n'                                    'line 1: "団" has no usable slug'
defect none      '<main><p>no delimiters</p></main>\n'                                              'no section delimiters: run /wp-polish'

# --- a directory named *.html is not a page ---------------------------------------------
mkdir -p "$p/demo/saved.html"
run "$p"
[ "$rc" = 0 ] || fail "a directory named saved.html must be skipped, not crash: got $rc ($out)"
rmdir "$p/demo/saved.html"

# --- nothing to read exits 2; bad usage exits 64 -------------------------------------------
mkdir -p "$tmp/nodemo"
run "$tmp/nodemo"; [ "$rc" = 2 ] || fail "no demo/ must exit 2, got $rc"
run "$p" --page missing; [ "$rc" = 2 ] || fail "a missing page must exit 2, got $rc"
run "$p" --page ../x; [ "$rc" = 64 ] || fail "--page with a path must exit 64, got $rc"
run "$p" --nope; [ "$rc" = 64 ] || fail "an unknown flag must exit 64, got $rc"

# --- a listing larger than a pipe buffer (64 KiB) arrives whole ---------------------------
mkdir -p "$tmp/big/demo"
awk 'BEGIN { for (i = 0; i < 3000; i++) printf "<!-- SECTION: S%d -->\n<!-- END SECTION -->\n", i }' > "$tmp/big/demo/index.html"
n=$(node "$tool" "$tmp/big" --json | node -e 'process.stdout.write(String(JSON.parse(require("fs").readFileSync(0,"utf8")).pages[0].sections.length))') \
  || fail 'a large --json listing piped to a reader must parse: the output was cut short'
[ "$n" = 3000 ] || fail "a large listing must carry all 3000 sections through a pipe, got $n"

# --- the command contract -----------------------------------------------------------------
cmd=commands/wp-section.md
ref=skills/wp-section-run/references/list-mode.md
need_token "$cmd" '## List mode (`--list`)' 'wp-section must keep its List mode section'
need_token "$cmd" 'references/list-mode.md` now and follow it' 'List mode must send the run to list-mode.md'
need_token "$ref" 'bin/demo-sections.mjs' 'list-mode.md must run bin/demo-sections.mjs'
need_token "$ref" 'no later step of the command runs' 'list-mode.md must end the run after listing'
need_token "$cmd" 'before the adopted-site guard' 'List mode must run before the adopted-site guard (it writes nothing)'
need_token "$cmd" '--list [--page <slug>]' 'the argument hint must name --list'
need_token "$cmd" '/wp-section --list' 'the usage examples must show --list'
# List mode must come before the guard in the file, since the command is read in order.
lm=$(grep -n '^## List mode' "$cmd" | cut -d: -f1); ag=$(grep -n '^## Adopted-site guard' "$cmd" | cut -d: -f1)
[ "$lm" -lt "$ag" ] || fail "List mode must precede the Adopted-site guard in $cmd"

echo PASS
