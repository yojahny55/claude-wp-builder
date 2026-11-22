# /wp-audit — Step 2

`commands/wp-audit.md` sends the run here at Step 2, after the `drift` exit `4` lines are printed. Follow it in order; nothing in it is optional background.

## Contents

- Plugin-list drift
- Deliberately inactive plugin
- Structural drift

When **every** line is a plugin-list line (`active plugin(s) not in plugins.installed`,
`plugin(s) in plugins.installed that are not active`, or `plugin path(s) in code_scope no longer
on disk`), the owner changed plugins and the manifest still describes this site. That is
measured fact, not a decision, so **do not ask**: run `refresh` straight away and print one
line for the report, `Manifest refreshed: <the drift lines>`. Run `bash -c 'node "$1/bin/wp-config.mjs" refresh "$2"' _ "${CLAUDE_PLUGIN_ROOT}" '${PROJECT_PATH}'`: it
re-probes, rewrites `plugins.installed` and `stack` (and the PHP and WordPress versions), drops
plugins that are gone from disk out of `plugins.installed` and `code_scope`, keeps a
`.bak-<timestamp>` outside the docroot, regenerates the CLAUDE.md block and validates. Anything
else in the manifest is untouched, and a run with nothing to change writes nothing. If `refresh`
exits `1` (for example the pruned scope would leave no editable code), report its message and
ask then.

A plugin the operator keeps deactivated on purpose (a security plugin turned off on the local
copy only) is not drift: record it once with
`bash -c 'node "$1/bin/wp-config.mjs" keep-inactive "$2" "$3"' _ "${CLAUDE_PLUGIN_ROOT}" '${PROJECT_PATH}' <slug>`
after asking (`AskUserQuestion`, default no), since a plugin that fell inactive by accident is
exactly what this check should surface.

When any line is structural (theme directory missing, active theme differs, `source` is
`"blank"`, a non-plugin `code_scope` path missing), the theme or code scope changed and the
manifest may describe another site; `refresh` refuses it. Only this case is put to the
operator:

```
.wp-create.json no longer describes this site.
  [A] Re-adopt it — read-only detection, keeps a timestamped backup of the old manifest (recommended)
  [B] Continue with the manifest as it is
```

Re-adoption (`wp-adopt.md` Steps 2 to 5 with `--replace`) over a real adoption carries over
`audit`, `store`, the prefix, the industry and the code scope, so the next audit still has its
baseline; over a blank scaffold it starts from the probe. On a continue answer, say in the
report that every manifest-driven choice (plugin stack, theme slug, code scope) rests on a
manifest the drift check disputed. Exit `1` (the probe could not run) is not drift: report it and
continue. Skip the check when there is no Tier 2.

