#!/usr/bin/env bash
# The store layer: a demo's store pages (pages[role=store]) carry their look into the
# `Section: Store demo` of the theme's assets/css/store.css. This pins:
#   - /wp-yolo sends item 7 to skills/wp-yolo-run/references/store-layer.md, which installs the
#     base with /wp-woo-setup --store-theme (straight to its Step 6.6 on a recorded store) and
#     dispatches wp-css in store layer mode;
#   - wp-css's store layer mode: reads store.css instead of styles.css, writes below the
#     marker only, translates demo elements through the selector reference, never copies a
#     demo class;
#   - the selector reference names a WooCommerce selector and a probe for every row (the probes
#     run on a real store in store-theme-integration.sh);
#   - the two bash blocks of the reference, run as written: "written already?" and the verify
#     block's seven outcomes, plus the repair it prescribes for BASE CHANGED.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/lib/assert.sh

yolo=commands/wp-yolo.md
ref=skills/wp-yolo-run/references/store-layer.md
agent=agents/wp-css.md
sel=skills/wp-woocommerce/references/store-selectors.md
woo=commands/wp-woo-setup.md
tpl=templates/store/store.css
for f in "$ref" "$sel" "$tpl"; do [ -f "$f" ] || fail "$f is missing"; done

need_token "$yolo" '`${CLAUDE_PLUGIN_ROOT}/skills/wp-yolo-run/references/store-layer.md` now and follow it'
need_token "$ref" 'Run `/wp-woo-setup --store-theme`.'
need_token "$ref" '`.claude/CLAUDE.md` records `**Template:** tailwind`'
need_token "$ref" 'store.tier'
need_token "$ref" 'The prompt says **"store'
need_token "$ref" '`demo/.original/<slug>.html`'
need_token "$ref" 'store layer kept from an earlier run'
need_token "$woo" '**`--store-theme` on a recorded store goes straight to Step 6.6.**'
need_token "$woo" 'skip Steps 2 to 6.5, run Step 6.6, then report'
need_token "$agent" '## Store Layer Mode (when dispatched by /wp-yolo for the demo'
need_token "$agent" 'When the dispatch says **"store layer"**'
need_token "$agent" 'return `BLOCKED: store.css is not installed`'
need_token "$agent" '**Write only below the `Section: Store demo` line.**'
need_token "$agent" 'skills/wp-woocommerce/references/store-selectors.md'
need_token "$agent" 'Never copy a demo class'
need_token "$agent" 'never guessed onto a nearby selector'
need_token skills/wp-woocommerce/SKILL.md 'references/store-selectors.md'
need_token skills/wp-yolo-run/SKILL.md '(references/store-layer.md)'
need_token BACKLOG.md 'tests/checks/store-demo-layer.sh'

# The selector reference: five surfaces, every row a selector and a known probe.
require_tool python3
python3 - "$sel" <<'PY' || exit 1
import re, sys
text = open(sys.argv[1]).read()
def die(msg):
    print("FAIL: " + msg); sys.exit(1)
for h in ("## Shop (`store: shop`)", "## Product (`store: product`)", "## Cart (`store: cart`)",
          "## Checkout (`store: checkout`)", "## My account (`store: account`)"):
    if h not in text:
        die(f"store-selectors.md has no '{h}' table")
rows = [r for r in re.findall(r'^\| (.+?) \| `(.+?)` \| (\S+) \|$', text, re.M)]
if len(rows) < 30:
    die(f"store-selectors.md has {len(rows)} selector rows; the tables lost rows")
for elem, selector, probe in rows:
    if probe not in ("html", "js", "—"):
        die(f"row '{elem}' has probe '{probe}'; use html, js or —")
    if not re.search(r'\.[A-Za-z]', selector):
        die(f"row '{elem}' names no class: {selector}")
if "float: none; width: auto; margin: 0" not in text:
    die("store-selectors.md lost the float-grid trap")
PY

# The two bash blocks of the reference, as written, and bin/store-layer-check.mjs behind them.
require_tool node
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
block() { awk -v h="$1" '$0 ~ h {f=1} f&&/^```bash$/{g=1;next} g&&/^```$/{exit} g' "$ref" \
  | sed -e "s#<theme>#$tmp/theme#g"; }
block '^## 2[.] Written already' > "$tmp/written.sh"
block '^## 4[.] Verify' > "$tmp/verify.sh"
grep -F -- '--state' "$tmp/written.sh" >/dev/null || fail "could not extract the 'written already?' block"
grep -F 'store-layer-check.mjs' "$tmp/verify.sh" >/dev/null || fail "could not extract the verify block"
css="$tmp/theme/assets/css/store.css"
run() { { CLAUDE_PLUGIN_ROOT="$PWD" bash "$1" 2>&1 || true; } | sed -n '$p'; }
expect() { got=$(run "$tmp/verify.sh"); [ "$got" = "$1" ] || fail "$2: verify printed '$got', not '$1'"; }
state() { got=$(run "$tmp/written.sh"); [ "$got" = "$1" ] || fail "$2: --state printed '$got', not '$1'"; }
with() { /bin/cp -f "$tmp/good.css" "$css"; printf '%s\n' "$1" >> "$css"; }

mkdir -p "$tmp/theme/assets/css"
expect "NO STORE CSS" "no store.css"
/bin/cp -f "$tpl" "$css"
expect "NOTHING WRITTEN" "the base as installed"
state "STORE LAYER EMPTY" "the base as installed"
printf '/* nothing to carry: the demo draws no store element */\n' >> "$css"
expect "NOTHING WRITTEN" "a section of comments only"
state "STORE LAYER EMPTY" "a section of comments only"

/bin/cp -f "$tpl" "$css"
cat >> "$css" <<'CSS'
/* The demo's .shop-card { … } becomes WooCommerce's
   ul.products li.product { … }: a comment over several lines is not a selector. **/
body.woocommerce-page { --store-accent: #1a5d3a; --store-radius: 999px; }
body.woocommerce-page ul.products::before,
body.woocommerce-page ul.products::after { display: none; }
@media (min-width: 768px) {
	body.woocommerce-page ul.products { display: grid; grid-template-columns: repeat(3, 1fr); }
}
@supports (display: grid) { body.woocommerce-page ul.products li.product { float: none; } }
@keyframes store-pop { from { opacity: 0; } 50% { opacity: .5; } to { opacity: 1; } }
body.woocommerce-page ul.products li.product:not(.outofstock, .onbackorder) { animation: store-pop .2s; }
body.woocommerce-page .onsale::after { content: "} .x {"; }
body.woocommerce-cart .wc-block-cart__submit-button{padding:1rem 2rem}
CSS
/bin/cp -f "$css" "$tmp/good.css"
expect "STORE LAYER OK" "a scoped layer (comments, @media, @supports, @keyframes, :not() list, a brace in a string)"
state "STORE LAYER WRITTEN" "a written layer, so --resume would overwrite it"

with '.shop-card__title{color:#1a5d3a}'
expect "UNSCOPED SELECTOR: .shop-card__title" "a demo class on one line"
with $'body.woocommerce-page .price,\n.price del { color: #888; }'
expect "UNSCOPED SELECTOR: .price del" "an unscoped selector in a list"
with '@media (min-width: 1px) { .card { color: red; } }'
expect "UNSCOPED SELECTOR: .card" "an unscoped selector inside @media"
with 'body.woocommerce-page .price { color: #888 !important; }'
expect "IMPORTANT USED" "!important"
with 'body.woocommerce-page .price { color: #888 ! IMPORTANT }'
expect "IMPORTANT USED" "! important with a space and no semicolon"
with '/* never !important here */'
expect "STORE LAYER OK" "!important inside a comment"
with 'body.woocommerce-page .price { color: #888;'
expect "UNBALANCED BRACES" "an unclosed rule"

/bin/cp -f "$tmp/good.css" "$css"
sed -i 's/--store-radius: 0.375rem/--store-radius: 0/' "$css"
expect "BASE CHANGED" "an edit above the demo section"
# The repair the reference prescribes puts the base back and keeps the section.
repair=$(sed -n 's/^| `BASE CHANGED` | .* — `\(.*\)` — then run the check again |$/\1/p' "$ref")
[ -n "$repair" ] || fail "could not extract the BASE CHANGED repair"
repair=${repair//<theme>/$tmp/theme}
( CLAUDE_PLUGIN_ROOT="$PWD"; eval "$repair" )
expect "STORE LAYER OK" "after the BASE CHANGED repair"
cmp -s "$css" "$tmp/good.css" || fail "the BASE CHANGED repair did not restore the base and keep the section"

grep -v 'Section: Store demo' "$tmp/good.css" > "$css"
expect "MARKER MISSING" "the section's own line removed"

node bin/store-layer-check.mjs "$tpl" >/dev/null 2>&1 && fail "one argument is not a usage error"
[ "$(node bin/store-layer-check.mjs "$tpl" "$css" --bogus >/dev/null 2>&1; echo $?)" = 64 ] || fail "an unknown flag does not exit 64"

echo "PASS: the store layer installs the base, writes only the demo section on WooCommerce's selectors, and is verified"
