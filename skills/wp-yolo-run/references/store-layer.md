# /wp-yolo — Step 4

`commands/wp-yolo.md` sends the run here from Step 4, item 7, when the demo has store pages
(`pages[role=store]`): this is the store layer. Follow it in order; nothing in it is optional
background.

A demo's store pages build no template: WooCommerce renders shop, product, cart, checkout and
my account with its own markup. What carries the demo's look to them is the theme's
`assets/css/store.css`: a fixed base `/wp-woo-setup` installs, which puts WooCommerce in the
theme's tokens, and a last section, `Section: Store demo`, which this item writes from the
demo's store pages.

## Entry

Run this item only when all three hold:

- the demo has at least one `pages[role=store]` entry;
- `.wp-create.json` has a `store` block —
  `bash -c 'node "$1/bin/wp-config.mjs" get "$2" store.tier' _ "${CLAUDE_PLUGIN_ROOT}" '<project>'`
  exits `0`;
- `.claude/CLAUDE.md` records `**Template:** tailwind`.

Otherwise skip it and add one Review line: with no `store` block, "store pages: run
/wp-woo-setup first, then /wp-woo-setup --store-theme"; on any other template, "store pages:
WooCommerce's default look; styling them needs the theme's own work". The per-page Review lines
of item 7 stay either way.

## 1. Install the base

Run `/wp-woo-setup --store-theme`. On a store `/wp-create` already set up it goes straight to
`/wp-woo-setup` Step 6.6, which installs `inc/store-theme.php` and the base `store.css` into this theme and
rebuilds Tailwind. Keep two things from its report:

- every result line. `INSTALLED` and `UNCHANGED` go on. Anything else (`EDITED`, `FAILED`,
  `UNSUBSTITUTED TOKENS`, `PHP LINT FAILED`) stops this item: list the line under Review and
  carry on with item 8. The build does not depend on the store layer;
- the theme tokens it reports missing from the compiled CSS. The dispatch below passes them on.

## 2. Written already?

The base ships `Section: Store demo` with a placeholder comment and nothing else. When the
theme's section differs from the template's, an earlier run (or a person) wrote it: keep it,
skip step 3, and add the Review line "store layer kept from an earlier run". On `--resume` this
is what stops a second run from overwriting it.

```bash
tail_of() { sed -n '/====== Section: Store demo ======/,$p' "$1"; }
cmp -s <(tail_of "${CLAUDE_PLUGIN_ROOT}/templates/store/store.css") <(tail_of "<theme>/assets/css/store.css") \
  && echo "STORE LAYER EMPTY" || echo "STORE LAYER WRITTEN"
```

## 3. Dispatch `wp-css` in store layer mode

One dispatch, no `model` parameter (the frontmatter routes it). The prompt says **"store
layer"** and gives:

- the theme directory;
- every `pages[role=store]` entry as `<slug>` and its `store` surface (`shop`, `product`,
  `cart`, `checkout`, `account`), with its plain-CSS source, which only the store layer reads
  and never a section build: the Step 2.6 backup `demo/.original/<slug>.html` when there is
  one, else `demo/<slug>.html`. `store.css` is plain CSS outside the Tailwind build, so the
  converted page's utility classes are no use to it;
- the missing theme tokens from step 1, or "none".

The agent reads `skills/wp-woocommerce/references/store-selectors.md`, writes below the
`Section: Store demo` line only, and reports what it carried and what it skipped.

## 4. Verify

```bash
theme="<theme>"; tpl="${CLAUDE_PLUGIN_ROOT}/templates/store/store.css"; css="$theme/assets/css/store.css"
head_of() { sed '/====== Section: Store demo ======/,$d' "$1"; }
tail_of() { sed -n '/====== Section: Store demo ======/,$p' "$1"; }
if [ ! -f "$css" ]; then echo "NO STORE CSS"
elif ! cmp -s <(head_of "$tpl") <(head_of "$css"); then echo "BASE CHANGED"
elif cmp -s <(tail_of "$tpl") <(tail_of "$css"); then echo "NOTHING WRITTEN"
elif tail_of "$css" | grep -F '!important' >/dev/null; then echo "IMPORTANT USED"
elif tail_of "$css" | tr '\n' ' ' | sed 's#/\*\([^*]\|\*[^/]\)*\*/##g' | grep -o '[^{};]*{' \
     | tr ',' '\n' | sed 's/{$//; s/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$' \
     | grep -Ev '^(@|body\.woocommerce)' >/dev/null; then echo "UNSCOPED SELECTOR"
else echo "STORE LAYER OK"; fi
```

| Last line | Do |
|---|---|
| `STORE LAYER OK` | go on |
| `BASE CHANGED` | the agent wrote above its section. Put the base back and keep its section — `{ head_of "$tpl"; tail_of "$css"; } > "$css.new" && /bin/cp -f "$css.new" "$css" && rm -f "$css.new"` — then run the block again |
| `NOTHING WRITTEN` | the agent found nothing to carry: list its report's skipped elements under Review |
| `IMPORTANT USED`, `UNSCOPED SELECTOR` | send the agent back once with the line; a second failure goes under Review, and the section stays for a person to fix |
| `NO STORE CSS` | step 1 did not install; it is already under Review |

## 5. Review

Add under Review: every element the agent skipped, by demo page, and one line, "store pages:
check shop, product, cart, checkout and my account in a browser (cart and checkout render
client-side)". No check in this run compares those pages with the demo.
