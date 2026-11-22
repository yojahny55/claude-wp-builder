# /wp-section — List mode

`commands/wp-section.md` sends the run here when `$ARGUMENTS` contains `--list`. Follow it, then
stop: no later step of the command runs.

## Contents

- The call
- What it prints
- Exit codes

## The call

`--page <slug>` limits the listing to `demo/<slug>.html`; append `--page '<slug>'` after the
path when it was given. Any other argument is ignored.

```bash
bash -c 'node "$1/bin/demo-sections.mjs" "$2" "${@:3}"' _ "${CLAUDE_PLUGIN_ROOT}" '${PROJECT_PATH}'
```

## What it prints

Per page (`index.html` first), each section's name, the slug to pass as `/wp-section <slug>`, its
line range and `built` / `not built`: whether the theme has `template-parts/section-<slug>.php`.
The column is `?` when no theme exists yet. Header and Footer show `by /wp-header` and
`by /wp-footer`. `--json` gives the same data as JSON.

## Exit codes

| Exit | Meaning | Do |
|---|---|---|
| `0` | listed, no delimiter defect | print the output verbatim and stop |
| `1` | a delimiter defect (unclosed section, stray or mismatched END, nested or duplicate name, page with no delimiters) | print the output verbatim, name `/wp-polish` as the fix, and stop |
| `2` | nothing to read (no `demo/`, no such page, no `.html`) | print the message verbatim and stop |
| `3`, `64` | crash or bad usage | report the message verbatim and stop |
