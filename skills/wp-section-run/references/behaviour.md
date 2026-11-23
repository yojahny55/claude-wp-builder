# /wp-section — Step 6.4

`commands/wp-section.md` sends the run here at Step 6.4, once the section has not been skipped (`--transcribe`, `--hybrid`, a `cinematic` theme). Follow it in order; nothing in it is optional background.

Otherwise find the scripts that touch the section. A hit in the page's
markup is not one — the section's own HTML always names its classes — so search scripts only:
the demo's own `.js` files (not minified or vendored libraries), and the inline `<script>`
bodies of the demo page, which `bin/demo-scripts.mjs` extracts (no `src`, no JSON-LD; exit 0
printed, 1 none matching):

```bash
grep -rlE '<root-class>|<child-ids-or-data-attributes>' demo --include=*.js \
  --exclude=*.min.js --exclude-dir=vendor --exclude-dir=node_modules
bash -c 'node "$1/bin/demo-scripts.mjs" "$2" --match "$3"' _ "${CLAUDE_PLUGIN_ROOT}" \
  'demo/<page>.html' '<root-class>|<child-ids-or-data-attributes>'
```

None: skip, and say "no behaviour" in the summary. Some: dispatch **wp-js** with the slug,
the theme directory, the template part path, the section's CSS, the demo section's markup and
those scripts (a shared script whole: the agent ports only what acts on this section).
It writes `assets/js/src/sections/<slug>.js`, wires it into `index.js`, adds `data-` hooks to
the template part, and rebuilds the bundle. A `BLOCKED:` return (a library the theme does not
have, no `index.js`) goes into the summary verbatim with the files it touched; the section
is reported as built without its behaviour, never as finished. Its "CSS needed" lines go
into the summary too: the CSS agent's next pass owns them.
