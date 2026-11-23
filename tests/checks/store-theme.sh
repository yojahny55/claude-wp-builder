#!/usr/bin/env bash
# /wp-woo-setup Step 6.6 installs templates/store/store-theme.php and templates/store/store.css
# into a tailwind theme: WooCommerce theme support, the wrapper and sidebar the theme's own
# <main id="primary"> makes wrong, and a stylesheet loaded on store pages only. This pins:
#   - the step's contract (fixed files, new store or --store-theme only, tailwind only, rebuild);
#   - the PHP: parses once substituted, declares support, swaps the wrapper, gates the enqueue;
#   - the CSS: every selector is scoped to a store body class, so it cannot restyle another
#     page even if it were loaded there; the demo section is last; every theme token it reads
#     is named in the PHP (Tailwind keeps only the variables its @source mentions);
#   - the copy block itself: install, unchanged, demo section edited (still unchanged), head
#     edited (EDITED), PHP edited (EDITED).
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/lib/assert.sh

cmd=commands/wp-woo-setup.md
php_tpl=templates/store/store-theme.php
css_tpl=templates/store/store.css
[ -f "$php_tpl" ] || fail "$php_tpl is missing"
[ -f "$css_tpl" ] || fail "$css_tpl is missing"

need_token "$cmd" '## Step 6.6: Store pages in the theme (tailwind themes)'
need_token "$cmd" 'argument-hint: "[project-path] [--force] [--store-theme]"'
need_token "$cmd" 'templates/store/store-theme.php'
need_token "$cmd" 'templates/store/store.css'
need_token "$cmd" '**installs only on a new store**'
need_token "$cmd" '**or with `--store-theme`**'
need_token "$cmd" 'records `**Template:** tailwind`'
need_token "$cmd" "require_once __DIR__ . '/inc/store-theme.php';"
need_token "$cmd" 'bin/tailwind-rebuild.sh'
need_token "$cmd" 'never load it twice'
need_token BACKLOG.md 'tests/checks/store-theme.sh'
need_token BACKLOG.md 'tests/checks/store-theme-integration.sh'
need_token .github/workflows/ci.yml 'bash tests/checks/store-theme-integration.sh'

need_token "$php_tpl" "defined( 'ABSPATH' ) || exit;"
need_token "$php_tpl" "add_theme_support( 'woocommerce' );"
need_token "$php_tpl" "add_theme_support( 'wc-product-gallery-zoom' );"
need_token "$php_tpl" "add_theme_support( 'wc-product-gallery-lightbox' );"
need_token "$php_tpl" "add_theme_support( 'wc-product-gallery-slider' );"
need_token "$php_tpl" "remove_action( 'woocommerce_before_main_content', 'woocommerce_output_content_wrapper', 10 );"
need_token "$php_tpl" "remove_action( 'woocommerce_after_main_content', 'woocommerce_output_content_wrapper_end', 10 );"
need_token "$php_tpl" "remove_action( 'woocommerce_sidebar', 'woocommerce_get_sidebar', 10 );"
need_token "$php_tpl" "return is_woocommerce() || is_cart() || is_checkout() || is_account_page();"
need_token "$php_tpl" "if ( ! __prefix___is_store_page() ) {"

require_tool php python3
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
sed -e 's/__prefix__/fx/g' -e 's/__textdomain__/fx-theme/g' "$php_tpl" > "$tmp/store-theme.php"
if grep -q '__prefix__\|__textdomain__' "$tmp/store-theme.php"; then fail "$php_tpl has a token the command does not substitute"; fi
php -l "$tmp/store-theme.php" >/dev/null || fail "$php_tpl does not parse"

# The CSS: scoped selectors, demo section last, theme tokens named in the PHP.
python3 - "$css_tpl" "$php_tpl" <<'PY' || exit 1
import re, sys
css = open(sys.argv[1]).read()
php = open(sys.argv[2]).read()
def die(msg):
    print("FAIL: " + msg); sys.exit(1)
body = re.sub(r'/\*.*?\*/', '', css, flags=re.S)
for sel_list in re.findall(r'([^{}]+)\{', body):
    for sel in sel_list.split(','):
        sel = sel.strip()
        if sel and not re.match(r'body\.woocommerce-(page|cart|checkout|account)\b', sel):
            die(f"store.css selector not scoped to a store body class: {sel}")
marker = '/* ====== Section: Store demo ====== */'
if marker not in css:
    die("store.css has no 'Section: Store demo'")
if re.search(r'\{', css.split(marker, 1)[1]):
    die("store.css ships rules after 'Section: Store demo'; that section is the project's")
for var in sorted(set(re.findall(r'var\((--(?:color|font)-[a-z-]+)', css))):
    if f'var({var})' not in php:
        die(f"store.css reads {var} but store-theme.php does not name it; Tailwind would drop it")
PY

# The copy block, exactly as the command writes it.
awk '/^## Step 6.6/{f=1} f&&/^```bash$/{c++; if(c==1){g=1;next}} g&&/^```$/{exit} g' "$cmd" \
  | sed -e "s#<theme>#$tmp/theme#" -e 's#<prefix>#fx#' -e 's#<slug>#fx-theme#' > "$tmp/block.sh"
grep -F 'head_of' "$tmp/block.sh" >/dev/null || fail "could not extract the Step 6.6 copy block"
run() { CLAUDE_PLUGIN_ROOT="$PWD" bash "$tmp/block.sh" 2>&1 | grep -E '^(INSTALLED|UNCHANGED|EDITED|FAILED|UNSUBSTITUTED|PHP LINT)' | sed "s#$tmp/theme/##" | tr '\n' ' '; }
mkdir -p "$tmp/theme"
got=$(run); [ "$got" = "INSTALLED inc/store-theme.php INSTALLED assets/css/store.css " ] || fail "first run: $got"
cmp -s "$tmp/store-theme.php" "$tmp/theme/inc/store-theme.php" || fail "the installed PHP is not the substituted template"
got=$(run); [ "$got" = "UNCHANGED inc/store-theme.php UNCHANGED assets/css/store.css " ] || fail "second run: $got"
printf 'body.woocommerce-page { --store-accent: #b91c1c; }\n' >> "$tmp/theme/assets/css/store.css"
got=$(run); [ "$got" = "UNCHANGED inc/store-theme.php UNCHANGED assets/css/store.css " ] || fail "a filled demo section reads as an edit: $got"
sed -i 's/--store-radius: 0.375rem/--store-radius: 0/' "$tmp/theme/assets/css/store.css"
got=$(run); [ "$got" = "UNCHANGED inc/store-theme.php EDITED assets/css/store.css " ] || fail "an edit above the demo section went unnoticed: $got"
printf '// edited\n' >> "$tmp/theme/inc/store-theme.php"
got=$(run); case "$got" in "EDITED inc/store-theme.php "*) ;; *) fail "an edited store-theme.php went unnoticed: $got" ;; esac

echo "PASS: store-theme installs WooCommerce support and a store-only stylesheet, scoped and copy-checked"
