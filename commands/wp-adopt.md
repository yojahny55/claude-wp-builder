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

Re-registering a site whose manifest is wrong (a blank scaffold the real site was restored
over, found by `wp-config.mjs drift`): add `--replace`. The old manifest is kept as
`.wp-create.json.bak-<timestamp>`; without the flag `adopt` refuses.

When the manifest being replaced is a real adoption or build (not a blank scaffold), `--replace`
carries its decisions over instead of re-proposing them: the `audit` block, the `store` block,
`project.adopted`, and as defaults the prefix, the industry and the editable and read-only code
scope (paths that no longer exist are dropped; plugins or themes in neither old list get the
normal proposal). An explicit flag still wins. The dry-run JSON lists what was kept in
`carried_over`; present it with the proposal. Over a blank scaffold nothing is carried. If only
the plugin list changed, `wp-config.mjs refresh` is the lighter tool and needs no re-adoption.

The probe prints its JSON between `<<WPCB-PROBE>>` markers and only that region is parsed, so a
plugin's PHP notices or a logger flushing at shutdown no longer fail it. For a site that is
noisy in other ways, `bin/wp-quiet.sh <wrapper>` filters stdout. A `--wrapper` that points into
a temp directory is used for the probe and **not** stored in the manifest, which keeps the
detected wrapper (`--persist-wrapper` overrides this); a wrapper that is how the site is
really reached (`ddev wp`, `docker exec … wp`) is stored as before.

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
   signal proposed as editable, read its `Author` and `Plugin URI` headers — `$WP plugin
   get` has no field for `Plugin URI`, so read what WordPress parses:
   ```bash
   $WP eval 'require_once ABSPATH . "wp-admin/includes/plugin.php";
     foreach ( get_plugins() as $file => $h ) { echo $file, "\t", $h["Author"], "\t", $h["PluginURI"], "\n"; }'
   ```
   Then look its slug up on the wp.org plugin directory (`-g`: the `[slug]` brackets are
   literal; without it curl reads them as a glob and exits 3):
   ```bash
   curl -gsS --max-time 15 -w '\nHTTP %{http_code}\n' \
     "https://api.wordpress.org/plugins/info/1.2/?action=plugin_information&request[slug]=<slug>"
   ```
   This lookup goes to wp.org only — which already receives every installed plugin's header
   on WordPress's own update checks — and never to a third-party vulnerability feed. Read
   the body before the status, since wp.org answers "not found" with an `error` body:
   - **Matching listing** — a listing whose author or home agrees with the header. *Author*:
     strip HTML tags from the API's `author`, decode entities, trim and case-fold, and
     compare with the header's `Author` treated the same way. *Home*: the host of the API's
     `homepage` equals the host of the header's `Plugin URI`, both lowercased and without a
     leading `www.`. Either one is enough; an empty value on either side never agrees. A public plugin, not site code: propose it as
     vendor code, since its next update overwrites any edit.
   - **No listing** — `error` is `Plugin not found.`, **or a listing where neither author nor
     home agrees** — a premium plugin can share its slug with an unrelated wp.org plugin, so
     a slug match alone proves nothing. When the header names an author, propose it as
     vendor code (a paid multi-currency plugin or a paid slider bundled with a commercial
     theme). An agency that built the site's own plugin also fills in `Author`, so this is
     a proposal, never a decision.
   - **Closed** — `error` is `closed`, with `closed_date` and `reason`. It was a wp.org
     plugin and gets no more updates from there, so nothing will overwrite an edit: do not
     propose it as vendor code. Keep it in the editable list, marked `closed on wp.org
     <closed_date> (<reason>)`; `/wp-audit` reports the closure under SEC-042.
   - **Lookup failed** — any other `error`, a body that is not a JSON object, any other
     non-2xx status, a timeout or no route to `api.wordpress.org`: keep the transient signal — the plugin stays in the
     editable list — and mark it `not verified (wp.org unreachable)` in the proposal. An
     author header alone is not enough to move anything.

   **Never move a plugin in silence.** Present two multi-selects, both pre-selected, so the
   operator sees and can reverse every proposal:
   - *Editable code* — what is still proposed as the site's own. Anything deselected moves to
     read-only.
   - *Looks vendor-supplied — proposed read-only* — each re-verified plugin with its reason
     (`public wp.org plugin` or `Author: <name>, no matching wp.org listing`). Anything
     deselected goes back to editable.
   `/wp-audit` prints a reminder later if a vendor-looking plugin is still sitting in
   `code_scope.editable`, but that is a safety net for a site adopted before this check
   existed — it is not a substitute for getting the split right here.

   **The parent of a child theme is always read-only.** An update overwrites it, so do not
   offer to move it.
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

Then offer one optional follow-up, once: "Publish this site to a git remote?" Default **no**, and
nothing below runs unless the operator says yes. It never touches the site's own `.gitignore`.

## Step 6 (opt-in): Publish to a git remote

Only when the operator answered yes at Step 5. The site folder stays what it is — **not a
repository** — unless the operator asks for that separately. Everything is built in a scratch
working copy.

**1. Ask** (AskUserQuestion, one round; confirm the summary before any push):

- **Remote URL** (SSH). The web host and the SSH host may differ (`gitlab.example.com` in the
  browser, `git.example.com` over SSH), so test the URL before anything else:
  `git ls-remote <url>`. Failure stops the step with git's message.
- **What to include.** Default: WordPress core, the theme(s) in `code_scope.editable`, and own
  plugins / mu-plugins the operator lists explicitly. **Never** `wp-content/uploads`, `wp-config.php`,
  `.htaccess` or `.env`, whatever the operator answers.
- **Branch layout.** Default `dev` + `master`.
- **Does the remote already have commits?** `git ls-remote --heads` answers it. GitLab creates
  `main` with a README: either build on top of it, or rename `main` to `master` (push `master`;
  the default branch and its protection must then be changed in the web UI before `main` can be
  deleted — a push that deletes the default branch is rejected by a pre-receive hook, so do not
  try it).

**2. Build in a scratch copy.** `git clone <url> "$(mktemp -d)/pub"`, then copy only the
whitelisted paths in with `rsync` (never `--delete` outside them).

`rsync` filter rules are **first match wins**. Put every `--exclude` before any `--include`:
an `--include='/*.php'` placed ahead of `--exclude='/wp-config.php'` once copied `wp-config.php`
(database credentials and salts) into the working copy. Also exclude tool artifacts:
`.codebase-memory`, `.claude`, `.playwright-mcp`, `*.log`.

**3. Write the whitelist `.gitignore` and `.gitattributes` in the copy.** Pattern, one
`!` pair per theme and plugin:

```gitignore
/wp-content/*
!/wp-content/themes/
/wp-content/themes/*
!/wp-content/themes/<theme>/
!/wp-content/plugins/
/wp-content/plugins/*
!/wp-content/plugins/<own-plugin>/
!/wp-content/mu-plugins/
/wp-config.php
.htaccess
.env
*.log
```

`.gitattributes` holds one line, `* -text`, so line endings stay byte-identical to the server.
Without it git warns about CRLF to LF on hundreds of theme and core files, and a later deploy
rewrites them.

**4. Guards, before every commit.** Stage with `git add -A`, then:

- `git ls-files | grep -x wp-config.php` must print nothing. Anything else stops the step.
- Secret scan of the staged files (`git diff --cached`): API keys, passwords, tokens
  (`AKIA`, `sk_live_`, `ghp_`, `password\s*=`, `secret`, `token` assignments, salts) and local
  hostnames (`*.local`, `*.test`, `localhost`). Show hits and stop; the operator decides.

**5. Push** both branches, and report each branch's SHA (`git rev-parse <branch>`).

**6. Record it** so later pushes reuse the same whitelist, in `.wp-create.json` under a
`git_publish` key (remote URL, branches, `include` paths); no credentials:

```bash
node -e 'const f=process.argv[1],m=JSON.parse(require("fs").readFileSync(f));m.git_publish={remote:process.argv[2],branches:["dev","master"],include:process.argv[3].split(",")};require("fs").writeFileSync(f,JSON.stringify(m,null,2)+"\n")' \
  '${PROJECT_PATH}/.wp-create.json' '<url>' '<path>,<path>'
```

On a later run, if `git_publish` exists, offer to reuse it instead of asking again, and run the
same guards.

## What an adopted manifest changes downstream

| Key | Read by | Effect |
|---|---|---|
| `origin: "adopted"` | `/wp-audit`, `/wp-debug`, `/wp-clone` | the site is registered, but no theme was scaffolded. The builders (`/wp-init`, `/wp-section`, `/wp-seed`, …) do **not** check `origin` and assume a starter theme. They are not supported on an adopted site, and nothing stops them yet |
| `code_scope.editable` | `/wp-audit` agents and fix phase | the only paths a fix may edit |
| `code_scope.read_only` | `/wp-audit` agents | audited and reported with `Fix: manual`, `Owner: manual`. Never edited |
| `git_publish` | `/wp-adopt` Step 6 | remote, branches and included paths of an earlier publish, reused by the next one; absent unless the operator opted in |
| `stack.*` | `/wp-audit` Steps 4, 5, 6 and 9 | no offer to install Rank Math or AIOS when another plugin owns SEO or security |
| `i18n strategy: none` | `/wp-audit` Step 2.5c | recorded as detected, not asked. `stack.multilingual` names the plugin |
