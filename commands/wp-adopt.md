---
description: Register an existing WordPress site this plugin did not build — read-only detection of WP-CLI, theme, code scope and plugin stack, so /wp-audit, /wp-debug and /wp-clone can run against it
allowed-tools: Read, Bash, AskUserQuestion
argument-hint: "[<wordpress-root>] [--wrapper=\"<wp-cli command>\"]"
---

# WP Adopt — Register an Existing Site

Registers a WordPress site that was not created by `/wp-create`: a client site built on a
commercial theme, an inherited install, a local copy of a production site. It writes the
two files every other command reads first — `.wp-create.json` with `"origin": "adopted"`,
and the generated block in `.claude/CLAUDE.md` — and nothing else.

**This command never changes the site.** It runs one read-only WP-CLI probe and reads theme
files. No vhost, no SSL, no options, no plugin installs, no database writes. That is the
difference from `/wp-create`'s Adopt Mode, which *reconfigures* an existing install into a
`/wp-create` environment. Use `/wp-create` when you want this plugin to own the environment;
use `/wp-adopt` when the site is already served and you only want to audit, debug or clone it.

`/wp-audit`, `/wp-debug` and `/wp-clone` run these steps themselves when their manifest gate
exits `3`, after asking. Run `/wp-adopt` directly to register a site ahead of time.

## Step 1: Resolve the root and check it is not registered

`${PROJECT_PATH}` here is the WordPress root — the directory holding `wp-load.php` — taken
from `$ARGUMENTS`, or the working directory when none is given.

**First: validate the project configuration.**

`${PROJECT_PATH}` is not an environment variable the way `${CLAUDE_PLUGIN_ROOT}` beside it is: it is the WordPress project root, the directory holding `.wp-create.json`, and you substitute the real path yourself — the one the user named, or the working directory when they named none — because an empty argument makes the validator print its usage line and exit `1`, which the table below then reads as "stop and report".

```bash
bash -c "node ${CLAUDE_PLUGIN_ROOT}/bin/wp-config.mjs validate '${PROJECT_PATH}'"
```

| Exit | Meaning | Do |
|---|---|---|
| `0` | valid | continue |
| `1` | invalid, or the generated context block disagrees with the manifest | stop and report the message verbatim |
| `2` | an older manifest can migrate | run `wp-config.mjs migrate '${PROJECT_PATH}'`, then continue |
| `3` | no manifest | this project was not created by `/wp-create`; stop and say so |

On exit 2, run the migration before continuing.

**Amending the exit `3` row above:** Exit `3` is the one this command continues on — it is the
unregistered site it exists for. Every other outcome stops: exit `0` or `2` means the site is
already registered (say so; adoption never overwrites a manifest, and a migration is not its
job), and exit `1` is reported verbatim as the table says.

## Step 2: Probe (dry run)

```bash
bash -c "node ${CLAUDE_PLUGIN_ROOT}/bin/wp-config.mjs adopt '${PROJECT_PATH}' --dry-run"
```

Pass `--wrapper="<command>"` when `$ARGUMENTS` gave one. Without it the wrapper is detected:
`.ddev/config.yaml` → `ddev wp`, `.lando.yml` → `lando wp`, otherwise `wp --path=<root>`.
A site in a plain Docker container needs the wrapper passed explicitly
(`--wrapper="docker exec <container> wp --allow-root"`).

On a non-zero exit, report the message verbatim. A failed probe usually means the wrong
wrapper, or a plugin that prints output while WordPress boots. Ask for the wrapper with
`AskUserQuestion` and retry once. Multisite is refused, and that refusal is final.

The dry run prints JSON: `manifest` (the proposal), `reasons` (why each path went where it
went), `prefix_source`, `conflicts` (two plugins active for one concern) and `problems`
(what `validate` would refuse).

## Step 3: Confirm the proposal with the operator

Present it compactly, then confirm the values that were guessed. The probe measures
everything else.

```
=== Adoption proposal: <project.name> ===
  URL           <wordpress.url>
  WP-CLI        <wp_cli.wrapper>
  Theme         <theme.slug> (parent: <theme.parent or none>)
  Languages     <primary> + <additional> (i18n strategy: <polylang|none>)
  Stack         seo=<…> security=<…> fields=<…> multilingual=<…> builder=<…> cache=<…>
  Prefix        <project.prefix>   (<prefix_source>)

  Editable code (the audit may propose fixes here)
    <path>   <reason>
  Read-only code (audited, reported, never edited)
    <path>   <reason>
```

Ask with `AskUserQuestion`, one question each:

1. **Code scope.** The split comes from the update transients. Code that no updater knows
   is proposed as editable. That signal is wrong in two known ways:
   - A vendor add-on bundled with a commercial theme has no updater of its own, so it looks
     like the site's own code.
   - A site that has never checked for updates has empty transients, so every plugin looks
     like the site's own code.

   **Re-verify the first case before offering the list.** For each plugin the transient
   signal proposed as editable, read its header — `$WP plugin get <slug> --field=author` and
   `--field=plugin_uri` — and check whether its slug resolves on the wp.org plugin directory.
   A paid multi-currency plugin or a paid slider bundled with a commercial theme is vendor
   code with no updater, not site code, even though the transient signal cannot tell the two
   apart: a header naming a vendor with no matching wp.org listing means move it to
   read-only before presenting the list, so the operator is deselecting exceptions rather
   than un-checking the common case. `/wp-audit` prints a reminder later if such a plugin is
   still sitting in `code_scope.editable`, but that is a safety net for a site adopted before
   this check existed — it is not a substitute for getting the split right here.

   Offer the editable list as a multi-select, pre-selected. Anything the operator deselects
   moves to read-only. **The parent of a child theme is always read-only.** An update
   overwrites it, so do not offer to move it.
2. **Function prefix.** Offer the inferred one first, marked recommended. The operator can
   type another. `<parent>_child_` beats `<parent>_`, because the parent's prefix belongs
   to the vendor.
3. **Industry.** This value picks between Organization and LocalBusiness schema in
   `/wp-audit`. Offer `unknown` when the operator has no answer.

Report every `conflicts` line as-is, for example two SEO plugins active at once. It is a
finding about the site, not something to resolve here.

## Step 4: Write

Run the real adoption with the confirmed values as flags. Paths are comma-separated and
relative to the WordPress root. Pass `--read-only=` with an empty value when nothing is
read-only.

```bash
bash -c "node ${CLAUDE_PLUGIN_ROOT}/bin/wp-config.mjs adopt '${PROJECT_PATH}' \
  --wrapper='<wrapper>' --prefix='<prefix>' --industry='<industry>' \
  --editable='<path>,<path>' --read-only='<path>,<path>'"
```

It re-probes, validates and writes nothing if validation fails. On success it writes
`.wp-create.json` and renders the generated block into `.claude/CLAUDE.md`. Everything the
operator wrote in that file outside the markers is kept. Then confirm:

```bash
bash -c "node ${CLAUDE_PLUGIN_ROOT}/bin/wp-config.mjs validate '${PROJECT_PATH}'"
```

It must exit `0`.

## Step 5: Say what was written, and where it may go

```
✓ Adopted <project.name> — nothing on the site was changed.
  Wrote: .wp-create.json (origin: adopted)
         .claude/CLAUDE.md (generated block)
```

If the root is a git repository, check `git check-ignore` for both files and say whether
each one would be committed. Do not edit `.gitignore` yourself. Committing them is the
operator's decision, and a shared repository may not want another tool's config in it.

## What an adopted manifest changes downstream

| Key | Read by | Effect |
|---|---|---|
| `origin: "adopted"` | `/wp-audit`, `/wp-debug`, `/wp-clone` | the site is registered, but no theme was scaffolded. The builders (`/wp-init`, `/wp-section`, `/wp-seed`, …) do **not** check `origin` and assume a starter theme. They are not supported on an adopted site, and nothing stops them yet |
| `code_scope.editable` | `/wp-audit` agents and fix phase | the only paths a fix may edit |
| `code_scope.read_only` | `/wp-audit` agents | audited and reported with `Fix: manual`, `Owner: manual`. Never edited |
| `stack.*` | `/wp-audit` Steps 4, 5, 6 and 9 | no offer to install Rank Math or AIOS when another plugin owns SEO or security |
| `i18n strategy: none` | `/wp-audit` Step 2.5c | recorded as detected, not asked. `stack.multilingual` names the plugin |
