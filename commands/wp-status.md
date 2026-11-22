---
description: Where is this project and what runs next — read-only report of the manifest, demo, build ledger and audit ledger, with the next command
allowed-tools: Bash, Read
argument-hint: "[project-path] [--json]"
---

# WP Status — Where Am I?

Read-only. It changes nothing: no file is written, no WP-CLI runs, no network is touched.
Every command reports on its own step; this one reads the four places that state lives
(the project manifest, the generated project file plus `demo/`, `demo/.yolo-progress.json`, the audit
findings ledger) and names the command that comes next.

## Step 1: Run the tool

```bash
node ${CLAUDE_PLUGIN_ROOT}/bin/wp-status.mjs "${PROJECT_PATH:-.}" [--json]
```

`PROJECT_PATH` is the first argument, default the current directory. Exit 0 means a report was
printed, whatever the state; 64 is bad usage (unknown flag, path is not a directory) and 3 a crash.

## Step 2: Show the output

Show the report as printed. The last line is `Next: <command> — <reason>`. If the next step is
`demo/FAILED.md`, show its lines: the demo failed verification and needs fixing first.

## Step 3: Only if the user asks

Run the suggested command only when the user asks for it. Never run it on your own: this
command reports, it does not continue the build.
