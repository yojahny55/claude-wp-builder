# Security — detection details for SEC-044, SEC-045, SEC-043

Part of the `wp-audit-standards` skill. Moved verbatim out of `agents/wp-audit-security.md` so the agent does not carry it on every dispatch; the agent's index names when to read it. Read before SEC-043, SEC-044 or SEC-045. SEC-001 to SEC-014 stay in the agent.

## Contents

- SEC-044 — Content-Security-Policy header
- SEC-045 — File-manager plugin installed
- SEC-043 — Duplicate/redeclared function across site code

**SEC-044 — Content-Security-Policy header.** Response headers belong to the host that serves
the site, and a local clone's own server answers headers production's edge never sets (and the
reverse), so this check reads them from the production host only. Take the public URL
confirmed in `/wp-audit` Step 2.3; with none, record `UNMEASURED` ("needs the public URL") and
stop. Never probe the clone and report the result as the site's.

```bash
curl -sSI --max-time 15 -A "Mozilla/5.0" "https://<production-host>/" | grep -i '^content-security-policy'
```

No `content-security-policy` header is a finding. Only `content-security-policy-report-only`
is `INFO` (the policy is not enforced). A present policy fails when `script-src` (falling back
to `default-src`) allows bare `*`, `data:` or `'unsafe-eval'`. A `403`, challenge page, `5xx` or
curl error is `UNMEASURED` with the status line as evidence: a WAF answer is not the site's
header set. WordPress themes and page builders inline scripts, so the fix is a policy built
for the site (start report-only), never a one-line paste, and it is not auto-applied.

**SEC-045 — File-manager plugin installed.** A file manager in wp-admin reads, uploads and
edits any file the web server can write, PHP included. It ignores `DISALLOW_FILE_EDIT`, which
only hides the core theme and plugin editors, so one stolen admin session becomes code
execution. Most of these plugins are a wrapper around elFinder, whose connector is a PHP file
under the plugin folder that answers direct requests whether the plugin is active or not: that
is how File Manager (`wp-file-manager`) was mass-exploited without login in 2020.
So an inactive copy is a finding too, not only an active one.

Match on either signal, for every installed plugin:

```bash
$WP plugin list --fields=name,status --format=csv
# known slugs: wp-file-manager, file-manager-advanced, filester
# fingerprint: the plugin folder bundles elFinder
{ find wp-content/plugins -maxdepth 6 -type f -iname 'elfinder*.js'
  find wp-content/plugins -maxdepth 6 -type f -iname 'connector*.php' -exec grep -l 'elFinder' {} +
} | awk -F/ '{print $3}' | sort -u
```

A `connector*.php` counts only when it names elFinder. The file name alone is common:
Smush, Forminator and any plugin vendoring `illuminate/contracts` ship one, and matching
on the name would report them as file managers and tell the owner to delete them.

The fingerprint is what catches renamed forks and premium copies the slug list does not
know. Report the slug, its status and the matched signal. The message for an active copy is
`File manager <slug> is active: any admin session can edit PHP on the server`. For an inactive
copy it is `File manager <slug> is installed (inactive); its bundled elFinder connector stays
reachable`. The fix is to delete the plugin, never to deactivate it: `Fix: manual`, because the
site owner may still use it, and removal is their decision. A file manager is never one of the
`Clone-suppressed plugins` categories, so a local clone reports it like production does.

**SEC-043 — Duplicate/redeclared function across site code:**
- This is Tier 1 — a code scan, no network and no vulnerability feed needed. Two files that
  each declare `function acme_get_field()` at the top level cannot both load; nothing short
  of reading all the site's code together catches it before that happens.
- Scope — everything that can put a function into the global namespace, not only what is
  active right now:
  - every installed plugin, **active and inactive** (and `active-network` on a multisite),
    with the loaded/inactive split from **Plugin inventory** — clone-suppressed plugins are
    loaded. Two plugins already active together have mostly proven they coexist; the
    inactive one is where the collision is waiting;
  - the must-use plugins: each top-level `wp-content/mu-plugins/*.php` (the only files
    WordPress loads from there) and each subdirectory (where a loader file `require`s its
    code from). A `*.php.disabled` or `*.bak` left in that folder is not loaded and is not
    scanned; a parked drop-in comes from the `Parked drop-ins` line instead;
  - the drop-ins (`$WP plugin list --status=dropin --field=name`), plus every file on the
    `Parked drop-ins` line — a drop-in parked as `*.bak` on a clone runs on production;
  - the active theme and its parent.
  On an adopted site this is a superset of `code_scope.editable` and `code_scope.read_only`.
- Do not grep for it. A `function <name>(` pattern over a real `wp-content` matched about
  160,000 lines (methods, closures, namespaced functions), and a "guard within three lines"
  heuristic misreads a `function_exists` block wrapping several functions. Run the shipped
  tokenizer script instead — plain `php`, no WordPress bootstrap, read-only, run from the
  WordPress root (the paths below are relative to it):
  ```bash
  S=<skills>/wp-cli-patterns/scripts/find-redeclared-functions.php
  args=()
  for slug in $($WP plugin list --status=active --field=name) \
              $($WP plugin list --status=active-network --field=name) <clone-suppressed slugs>; do
    p=wp-content/plugins/$slug; [ -e "$p" ] || p="$p.php"          # a single-file plugin
    args+=("loaded:plugin/$slug=$p")
  done
  for slug in <inactive slugs, minus the clone-suppressed ones>; do
    p=wp-content/plugins/$slug; [ -e "$p" ] || p="$p.php"
    args+=("inactive:plugin/$slug=$p")
  done
  for f in wp-content/mu-plugins/*.php wp-content/mu-plugins/*/; do           # one source each
    [ -e "$f" ] || continue
    f=${f%/}; args+=("loaded:mu-plugin/${f##*/}=$f")
  done
  for f in <drop-ins> <parked drop-ins>; do args+=("loaded:drop-in/$f=wp-content/$f"); done
  args+=("loaded:theme/<active>=wp-content/themes/<active>")
  args+=("loaded:theme/<parent>=wp-content/themes/<parent>")                   # only for a child theme
  php "$S" "${args[@]}"
  ```
  It keeps a named `function` only when no enclosing block is a class, trait, interface,
  enum or function; qualifies it by namespace and lowercases it (PHP function names are
  case-insensitive); drops declarations inside `if ( ! function_exists( … ) )` (braced,
  `:`/`endif;` or braceless) and after a top-level `if ( function_exists( … ) ) return;`;
  and skips `vendor/`, `node_modules/`, `tests/` and `examples/` directories, and an
  `object-cache.php` or `advanced-cache.php` inside a plugin (the drop-in template a cache
  plugin copies into `wp-content/`). It drops `use function` imports, recognises guards
  on `function_exists`, `class_exists`, `interface_exists`, `trait_exists`, `enum_exists`
  and `defined` in `if` and `elseif`, and recognises `enum` bodies on runtimes older than 8.1. On a site with ~15,600 PHP files it runs in about 2 seconds.
- Without WP-CLI, the plugin status is unknown: pass every plugin as `inactive`, and report
  each resulting `INFO` line as WARNING, "status unknown".
- Exit status: `0` nothing collides; `1` collisions on stdout; anything else (`2` is a
  source path that does not exist, printed as `missing source: <label>`, or bad usage) is
  `UNMEASURED` with the script's stderr as the evidence line — never `PASS`, because a
  source that was not scanned cannot have been cleared. A `skipped: <path>` line on stderr
  (a file or directory that exists but cannot be read) is partial coverage: list those
  paths in the finding's evidence.
- Pass: exit 0 and nothing on stdout.
- Fail, by severity — WordPress activates a plugin in a sandbox, so a redeclare in the plugin
  being activated refuses the activation instead of taking the site down:
  - **CRITICAL** — two or more **loaded** sources declare the name: both load in one request.
    Before reporting it, read both declaring lines: when either sits in a file that is only
    included from inside a function or method (an admin view, a settings page), the two
    cannot be shown to load in one request — report WARNING, "declared in a conditionally
    included file", and name both files.
  - **WARNING** — exactly one loaded source declares it; the inactive plugin cannot be
    activated.
  - **INFO** — only inactive plugins declare it; they cannot be active together.
- Message: `<function_name>() is declared by <source A> (<file>:<line>) and <source B> (<file>:<line>) — <both load in one request | <inactive plugin> cannot be activated | they cannot be active together>`
