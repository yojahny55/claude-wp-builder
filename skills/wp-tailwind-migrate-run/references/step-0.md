# /wp-tailwind-migrate — Step 0

`commands/wp-tailwind-migrate.md` sends the run here at Step 0, once the Tailwind v4 check has passed. Follow it in order; nothing in it is optional background.

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
