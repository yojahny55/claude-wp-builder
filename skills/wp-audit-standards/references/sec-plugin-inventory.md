# Security — plugin inventory shared by SEC-041, SEC-042, SEC-043

Part of the `wp-audit-standards` skill. Moved verbatim out of `agents/wp-audit-security.md` so the agent does not carry it on every dispatch; the agent's index names when to read it. Read before SEC-041, SEC-042, SEC-043 and the vendor re-check in the adopted-site section.

## Contents

- Clone context from the dispatch
- The sets
- Headers
- Is the slug public? (the wp.org lookup)
- Which slugs go where

## Plugin inventory — shared by SEC-041, SEC-042, SEC-043 and the vendor re-check

Read this once: SEC-041, SEC-042, SEC-043 and the vendor re-check above all use it.

### Clone context from the dispatch

`/wp-audit` Step 2.3 decides whether the project is a local clone and which plugins and
drop-ins it suppressed. This agent does not re-derive that; it reads three lines from the
project context of its dispatch, by these exact names:

```
Local clone: <yes|no>
Clone-suppressed plugins: <slug>,<slug>,… | none
Parked drop-ins: <file>,<file>,… | none
```

When the three lines are absent, treat the project as **not a clone**: no plugin counts as
clone-suppressed and no parked drop-in is scanned. Print `Clone context: not passed by the
dispatch — treated as not a clone` so the report shows it, and do not guess a list from
`.wp-create.json` or from which plugins happen to be inactive — a guess would promote a
plugin that is off on production too.

**Step 2.3 suppresses a finding, not a plugin.** It hides the finding "this plugin is
deactivated" when the deactivation is a clone artifact. It does not take the plugin out of
the inventory. The clone-suppressed plugins (payment gateways, cache, mail, security
plugins) are exactly the ones active on production, so they stay in SEC-041, SEC-042 and
SEC-043 and count as **loaded**.

### The sets

- **Loaded** = `$WP plugin list --status=active --field=name` (plus `--status=active-network`
  on a multisite) **plus every slug on the `Clone-suppressed plugins` line**.
- **Inactive** = every other plugin from `$WP plugin list --status=inactive --field=name`.
- Themes: the active theme and its parent are loaded; every other installed theme is inactive.

### Headers

`$WP plugin get` has no field for the `Plugin URI` header, so read the headers WordPress
parses, for every plugin and theme in one call each:

```bash
$WP eval 'require_once ABSPATH . "wp-admin/includes/plugin.php";
  foreach ( get_plugins() as $file => $h ) { echo $file, "\t", $h["Author"], "\t", $h["PluginURI"], "\n"; }'
$WP eval 'foreach ( wp_get_themes() as $slug => $t ) { echo $slug, "\t", $t->get( "Author" ), "\t", $t->get( "ThemeURI" ), "\n"; }'
```

A plugin's slug is the directory part of `$file` (`<slug>/<main>.php`), or the file name
without `.php` for a single-file plugin.

### Is the slug public? (the wp.org lookup)

A slug is **public** when either:
- the refreshed update transient lists it **as a wp.org entry** —
  `$WP transient get update_plugins --format=json` has the plugin's file under `response` or
  `no_update` with `id` `w.org/plugins/<slug>`; for a theme, `update_themes` (rebuilt by
  `$WP theme list --update=available`) has the slug under `response` or `no_update`. In both,
  the entry's `package` host must be `downloads.wordpress.org` or its `url` host
  `wordpress.org`: a premium updater injects its own entries into the same transient, with
  its own hosts; or
- the wp.org info API returns **this plugin's listing** (below), or answers **closed**.

```bash
# -g: the [slug] brackets are literal; without it curl reads them as a glob and exits 3.
curl -gsS --max-time 15 -w '\nHTTP %{http_code}\n' \
  "https://api.wordpress.org/plugins/info/1.2/?action=plugin_information&request[slug]=<slug>"
curl -gsS --max-time 15 -w '\nHTTP %{http_code}\n' \
  "https://api.wordpress.org/themes/info/1.2/?action=theme_information&request[slug]=<slug>"
```

Read the body before the status — wp.org answers "not found" with an `error` body:
- **no listing** — `error` is `Plugin not found.` (a theme: an `error` saying the theme was
  not found);
- **closed** — `error` is `closed`, with `closed_date` and `reason`: the plugin was on wp.org
  and was closed. The slug is public;
- **lookup failed** — any other `error`, a body that is not a JSON object, any other
  non-2xx status, or a timeout: `wp.org error: <status>`;
- otherwise a **listing**. It is **this plugin's listing** when the transient entry above
  proves it, or when either field agrees with the installed header (an empty value on either
  side never agrees):
  - *author* — strip HTML tags from the API's `author` (for a theme, `author.display_name`
    when it is an object), decode entities, trim and case-fold; equal to the header's
    `Author` treated the same way;
  - *home* — the host of the API's `homepage`, lowercased and without a leading `www.`,
    equals the host of the header's `Plugin URI` / `Theme URI` treated the same way.
  A listing that neither the transient nor a field ties to the installed plugin belongs to
  another plugin that shares the slug — a premium plugin can — and counts as **no listing**.

### Which slugs go where

- **`code_scope.editable` slugs go to wp.org only, and only from the vendor re-check** (and
  from `/wp-adopt`, at adoption). SEC-041 and SEC-042 never look an editable slug up again;
  they reuse the re-check's answer:
  - proved public there (this plugin's listing, or closed): a public slug like any other —
    SEC-041 queries it and SEC-042 judges it (a closed one fails SEC-042);
  - anything else: `N/A (site's own code)` in both, never sent to a third-party
    vulnerability feed; the Tier 1 code checks cover it.
- **Only public slugs are sent to the vulnerability feed.** A site's own plugin or a paid
  vendor plugin can carry the client's or the agency's name in its slug; one with no public
  listing is decided locally, with no feed request.
- The wp.org lookup itself discloses nothing new: WordPress core already sends every
  installed plugin's header to `api.wordpress.org` on its routine update checks.
