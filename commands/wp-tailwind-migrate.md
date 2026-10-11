---
description: Convert an already-built plain-CSS theme to Tailwind-native — utilities in the markup, @apply only where the ladder demands it
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent
argument-hint: "<theme-path> [--page <slug>]"
---

# WP Tailwind Migrate

Convert a theme that was built on the plain-CSS path into a Tailwind-native one, in
place, without changing how it looks.

```
Usage: /wp-tailwind-migrate <theme-path> [--page <slug>]
       /wp-tailwind-migrate wp-content/themes/acme
       /wp-tailwind-migrate wp-content/themes/acme --page contacto
```

`--page <slug>` migrates a single template instead of the whole theme — useful for a
first careful pass before committing to the full conversion.

Read `skills/wp-tailwind-system/SKILL.md` before starting. It owns the decision
ladder and the file layout that every step below assumes.

## Step 0 — Baseline gate

Refuse to proceed unless the theme is in a git repo with a clean tree. An
uncommitted change would be indistinguishable from a migration artifact.

Every path below lives either in the plugin (`bin/…`, `skills/…`,
`starter-theme/…`) or in the theme (`assets/css/…`, `functions.php`). The `cd` in
this block changes which one a bare relative path would hit — so run plugin scripts
by their full path, `${CLAUDE_PLUGIN_ROOT}/bin/…`, never as a bare relative path.

```bash
cd <theme-path>
pwd   # record this absolute path — Step 6 re-anchors on it, never on <theme-path>
git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
  || { echo "Error: <theme-path> is not a git repo. Init one first."; exit 1; }
[ -z "$(git status --porcelain)" ] \
  || { echo "Error: uncommitted changes. Commit or stash before migrating."; exit 1; }
git commit -q --allow-empty -m "chore: baseline before /wp-tailwind-migrate"
```

### The theme must already build with Tailwind v4 — check, do not assume

Every step below writes the v4 layout: `@import "tailwindcss"`, a `@theme` block, the
four `assets/css/src/tailwindcss/` directories, and an `assets/css/dist/main.css` that
Step 5 makes the theme's only stylesheet. A theme on Tailwind **v3** has none of that.
It has a `tailwind.config.js`, a PostCSS build, and it compiles its partials into a
stylesheet WordPress requires to sit at the theme root — `style.css`, the file carrying
the `Theme Name:` header. Run these steps against it and the "migration" becomes a v3 →
v4 upgrade plus a restructure of every partial in the theme, on top of the conversion
that was actually asked for.

Nothing downstream detects the mismatch. The command does not fail: it rebuilds the
theme around a layout the theme never had, and Step 5 then deletes the stylesheet every
template it did not migrate is still styled by.

So check first, and **stop with what you found** rather than proceeding:

```bash
ver=$(node -e "try{console.log(require('tailwindcss/package.json').version)}catch(e){console.log('none')}" 2>/dev/null || true)
[ -n "$ver" ] || ver=none   # no node at all: same answer as no dependency
case "$ver" in
  4.*)  : ;;
  none) echo "Error: no tailwindcss dependency resolvable from the theme. This command converts a theme that already builds with Tailwind v4."; exit 1 ;;
  *)    echo "Error: this theme builds with Tailwind $ver. This command targets v4 only."
        echo "It writes @import \"tailwindcss\", a @theme block, the four src/tailwindcss directories and assets/css/dist/main.css — none of which exist in a v3 layout — and Step 5 deletes the old stylesheet the other templates still need."
        echo "Upgrade v3 to v4 first, as its own job with its own blast radius, or convert this theme by hand."
        exit 1 ;;
esac
if [ -f tailwind.config.js ]; then
  echo "Note: tailwind.config.js is a v3 artifact. Confirm the theme really builds with v4 before continuing."
fi
```

The same reasoning covers the layout even when the version is right: if
`assets/css/src/tailwindcss/` does not exist and the theme compiles from somewhere else,
say where it compiles from and stop. A command that relocates a build nobody asked it to
relocate is not a migration.

`<theme-path>` is relative to the directory the run started in, so it resolves exactly
once. That `cd` is the **only** `cd <theme-path>` in this command: every step after it
already has the theme root as its working directory, and a second one would resolve the
same relative argument against the theme and fail. Record what `pwd` prints — Step 6
re-anchors on that absolute path if the directory ever drifts.

That gate applies to **every** pass, not just the first. A `--page` pass leaves
converted templates, a rewritten `functions.php` and a new `package.json` in the tree,
so **commit before the next `--page` pass** or the next run aborts here on its own
output.

Then capture the **visual golden**. `/wp-responsive-check` takes one target at a time
and shoots five widths — 375, 576, 768, 1024 and 1440. Only its **Method B**
(Puppeteer CLI) writes the fixed filenames `responsive-375.png` …
`responsive-1440.png` into the current directory. **Method A** — the Playwright MCP
server, which it tries *first* — names and places its captures however that server
does, so there may be no `responsive-*.png` in the cwd at all. Do not assume the
glob: after each page, take the five files the run actually produced and land them
under the golden's own names. A Method-B re-run overwrites the previous one, so this
has to happen immediately after each page, before the next page is shot and long
before Step 6 re-runs:

```bash
for slug in <every page to migrate>; do
  mkdir -p .tailwind-migrate/before/"$slug"
  # /wp-responsive-check <url-for-$slug>
  # Method B — the five fixed names are already in the cwd:
  mv responsive-*.png .tailwind-migrate/before/"$slug"/ 2>/dev/null || true
  # Method A — copy each capture the MCP server wrote to
  #   .tailwind-migrate/before/"$slug"/responsive-<width>.png
  # Either way five files must land, or this page has no golden:
  [ "$(ls .tailwind-migrate/before/"$slug"/responsive-*.png 2>/dev/null | wc -l)" -eq 5 ] \
    || { echo "Error: golden for $slug is incomplete. Do not migrate."; exit 1; }
done
```

`.tailwind-migrate/` is dot-prefixed deliberately: a shell glob such as `*.png` or
`demo/*` does not descend into a dot-directory, so no other command mistakes a
baseline screenshot for site content. That immunity is not absolute — `find . -name
'*.png'` walks dot-directories like any other — so add `.tailwind-migrate/` to the
theme's `.gitignore` as well.

Add `node_modules/` to that same `.gitignore` in the same edit, before Step 2 runs.
`npm install` creates it untracked, and the clean-tree gate above runs again on every
`--page` pass — so an un-ignored `node_modules/` aborts the next pass on the previous
pass's own dependency tree. Committing `node_modules/` is not the escape; ignoring it
is.

Do not proceed without the golden — it is the only evidence the migration preserved
the design. **Stop and report** whenever the five files do not land: no screenshot
tool at all (Method C's manual fallback), or a tool that produced fewer than five
usable captures. Migrating without a golden is a conversion nobody can verify, and
Step 6 has nothing to compare against.

## Step 1 — Audit

Inventory, and report before changing anything:

- Every `.php` template and the CSS classes its markup actually uses.
- Every file under `assets/css/**`, with size and whether anything enqueues it.
- Every `wp_enqueue_style` call in `functions.php`.
- Which CSS rules are dead — declared but matched by no markup.

Report the inventory to the user before Step 2.

## Step 2 — Install the pipeline

If the theme has no Tailwind build, add one modeled on
`starter-theme/__tailwind__`: `package.json` scripts (`tailwindwatch`,
`tailwindbuild`), `assets/css/src/tailwindcss/main.css` carrying both
`@import "tailwindcss"` and an empty `@theme` block, and the four directories `base
components layouts utilities`. That set is closed: `bin/tailwind-native-check.sh`
rule 2 errors on any other name found under `assets/css/src/tailwindcss/`, so do not
add a fifth. Then `npm install`.

Create the `@theme` block here even when it is empty. Step 3 writes the extracted
tokens into it and Step 4b registers every `@import` in the same file; neither can
write into a block that does not exist, and a token written outside `@theme` is not a
Tailwind token at all — it compiles to nothing and every utility that referenced it
silently falls back.

If a build already exists, leave it alone — with the one exception above: if its
`main.css` has no `@theme` block, add an empty one now.

## Step 3 — Extract tokens

Mine the old CSS for its colors, font families and spacing scale. Write them into the
`@theme` block of `assets/css/src/tailwindcss/main.css` — the block Step 2 created:

```css
@theme {
  --color-primary: #<from the old CSS>;
  --font-primary: "<from the old CSS>", sans-serif;
}
```

Report any value that appears 3+ times but has no obvious semantic name — ask the user
what to call it rather than inventing one.

## Step 4 — Convert, one template at a time

Dispatch `wp-tailwind` in **author mode** per template, in parallel.

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-tailwind-migrate-run/references/step-4.md` now and follow
it — it is this step, not background. It holds the dispatch prompt (the verbatim `Mode: **author**` line, the plain-CSS input state, the breakpoint rule, the five inputs, the write boundary and the no-convention-check rule) and what each agent does.

Under `--page`, dispatch only that template's agent.

## Step 4b — Promote and register, serially

Do this yourself, after every Step 4 agent has returned. Not in an agent, and not in
parallel: `utilities/site.css` and `main.css` are the two files the whole walk shares,
and one writer is the only way they survive it.

- Collect the promotion candidates the agents reported. A group two or more distinct
  pages actually use goes into `utilities/site.css`; anything else stays in the
  `components/<slug>.css` its agent already wrote. The whole converted corpus exists
  now, which is the first moment the cross-page question has a real answer.
- Write `utilities/site.css` **once**, in one edit, with every promoted rule in it —
  then delete each promoted group's now-duplicate rule from the
  `components/<slug>.css` it came from.
- Register every `@import` in `main.css` in one edit: each `components/*.css` the
  agents created, plus `utilities/site.css` if this step wrote one. Import order is
  `base` → `components` → `layouts` → `utilities`.

Under `--page` there is no cross-page corpus and nothing to promote — still register
that one template's `@import` here, because no agent did.

## Step 5 — Remove the old CSS

Delete the old CSS files and their `wp_enqueue_style` calls from `functions.php`.
Leave exactly one enqueue for the compiled `assets/css/dist/main.css`, modeled on
`starter-theme/__tailwind__/functions.php`.

Do not delete a file until its rules are accounted for in Step 4's output. A rule that
was dead in Step 1's audit is accounted for by being reported as dead.

**Under `--page`, do neither of those wholesale.** Every template you did not migrate
is still styled by the old CSS, so deleting the file or dropping its enqueue breaks
them. Strip only the rules that belonged to the migrated template, leave the file and
its enqueue in place, and finish the removal on the pass that migrates the last
template.

## Step 6 — Verify

Step 0's `cd <theme-path>` was the only one, and the working directory has been the
theme root ever since. **Do not `cd <theme-path>` again.** That argument is relative to
the directory the run started in, so a second `cd` resolves it against the theme itself
and fails — and joined by `&&` the failure swallows the build, leaving this step to
"verify" a `dist/main.css` nothing recompiled and to skip the convention check's rule 6,
which is gated on that file existing. If the directory did drift, `cd` to the absolute
path Step 0's `pwd` printed; never to `<theme-path>`.

```bash
[ -f package.json ] && [ -d assets/css/src/tailwindcss ] \
  || { echo "Error: cwd is not the theme root — cd to the absolute path Step 0 printed."; exit 1; }
npm run tailwindbuild
```

`tailwindbuild` is the script Step 2 installs, and it is the one that compiles
`assets/css/dist/main.css`. Do not reach for the starter's `build` script instead: it
runs `wp-scripts build` over `assets/js/src/index.js` first, which a theme migrated
off the plain-CSS path need not have — the CSS would never compile and the failure
would read as a Tailwind one.

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-tailwind-migrate-run/references/step-6.md` now and follow
it — it is this step, not background. It covers running the convention check by its full path and reading it under `--page`, the after-shots, the before/after comparison with its noise floor and numeric contract, and the rule that the migration is not reported successful without that comparison.

## Report

```
=== Tailwind Migration ===
Theme:        <theme-path>
Templates:    <n> converted
Tokens:       <n> extracted into @theme
site.css:     <n> cross-page classes
components/:  <n> per-page files
Removed:      <n> old CSS files, <n> enqueue calls
Check:        <PASS | FAIL: rules 1 and 6, expected part-way through a `--page` run
              | FAIL: real — name the rule>
Visual:       <n>/<n> viewports match the pre-migration golden
Golden:       .tailwind-migrate/before/  (kept — do not delete, it is the only
              record of how the theme looked before the conversion)
Diverged:     <page @ viewport — what differs, or "none">
```
