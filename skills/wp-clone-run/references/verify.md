# /wp-clone — Step 6

`commands/wp-clone.md` sends the run here at Step 6. Follow it in order; nothing in it is optional background.

## Contents

- 6.1 — Check WordPress Loads
- 6.2 — Verify URLs Are Correct
- 6.3 — Check Admin Accessibility
- 6.4 — Check Active Theme
- 6.5 — Check Plugins
- 6.6 — HTTP Response Check
- 6.7 — Print Summary

Run a series of checks to verify the cloned site is working correctly.

### 6.1: Check WordPress Loads

```bash
bash -c "$WP eval 'echo \"WordPress loaded: \" . get_bloginfo(\"version\");'"
```

### 6.2: Verify URLs Are Correct

```bash
bash -c "$WP option get siteurl"
bash -c "$WP option get home"
```

Both should return the local domain (e.g., `https://local-clone.local.com`). If they still show the old domain, the search-replace may have missed serialized data — re-run with `--precise` flag.

`wp search-replace` changes the database only. Files generated under uploads keep the old
domain. Elementor's local Google Fonts are the case that shows: its
`uploads/elementor/google-fonts/css/*.css` files load each font from an absolute URL on the
original host. In the clone the browser blocks those cross-origin font requests, the theme's
fallback font renders, and text runs slightly wider (a button label can wrap to two lines).
A visual comparison of clone and production then reports a difference that production does
not have. Check for it:

```bash
grep -l "<remote-domain>" wp-content/uploads/elementor/google-fonts/css/*.css 2>/dev/null
```

Record each hit in the summary as a clone-only rendering difference. Do not rewrite those
files when uploads can travel back to production through a sync. Serve rewritten copies from
a clone-only mu-plugin that is never deployed instead.

### 6.3: Check Admin Accessibility

```bash
bash -c "$WP user list --role=administrator --format=table"
```

Verify at least one admin user exists. If admin passwords are unknown, offer to reset:

> "The cloned site has these admin users: `<list>`. Would you like to reset any admin password for local development?"

If yes:

```bash
bash -c "$WP user update <user_id> --user_pass=admin"
```

### 6.4: Check Active Theme

```bash
bash -c "$WP theme list --status=active --format=table"
```

If the active theme is missing files (not found in `wp-content/themes/`), warn the user.

### 6.5: Check Plugins

```bash
bash -c "$WP plugin list --format=table"
```

Plugins that are "active" with missing files are expected here, not a surprise: this clone
never transferred plugin files. **Reconcile this list against the dependency inventory** from
A3.5 or B3.5 rather than reporting it again as a fresh discovery — the inventory already
classified each one and, for the recoverable ones, already wrote the command that fixes it.
A second undifferentiated warning at this point reads as a new problem and sends the operator
looking for a cause that was explained several steps ago.

Anything missing here that the inventory did **not** list is worth reporting on its own: it
means the two disagree, and the inventory is what the operator is about to work from.

### 6.6: HTTP Response Check

```bash
bash -c "curl -sI -o /dev/null -w '%{http_code}' https://local-clone.local.com/ 2>/dev/null || echo 'Could not reach site'"
```

Expect a `200` or `301/302` response. If unreachable, check that the web server is running and DNS/hosts entry is configured.

### 6.7: Print Summary

```
=== Clone Complete ===
Source:       <remote-url or "manual import">
Destination:  <local-path>
Local URL:    <local-url>
Admin URL:    <local-url>/wp-admin/
DB replaced:  <old-domain> → <new-domain>
Uploads:      <synced | extracted | skipped>
Admin users:  <list of admin usernames>

Replaced:     a WordPress site was already here — "Client Demo", 47 posts
  Backup      ~/.wp-clone-backups/client-demo-20260919T161145Z.sql
              (omit this block entirely when the destination was empty)

Dependencies: 2 recoverable, 1 bundled, 2 need the client's own copies, 0 unclassified
  Inventory   ~/.wp-clone-backups/client-demo-20260919T161145Z-dependencies.md
  → This clone carries the database and uploads. Plugin and theme FILES were not
    transferred; the inventory lists what to install and what cannot be obtained.

Database dump:
  Path A        exported, transferred, imported and deleted from both machines
  Path B        /tmp/dump.sql is yours and was left in place — it is a full database
                export; remove or protect it once this clone is verified

Isolation:
  Mail          captured to wp-content/clone-mail.log (mu-plugins/00-clone-isolation.php)
  Cron          disabled (DISABLE_WP_CRON)
  Indexing      discouraged (blog_public = 0)

Still live — reported, not changed:
  - woocommerce_stripe_settings holds a live secret key (option: woocommerce_stripe_settings)
  - 2 webhooks still point at <old-domain> (options: *_webhook_url)
  - This database holds real customer records: 1,284 orders, 903 customer accounts.
    → /wp-anonymize replaces them with deterministic fakes and lists what it did not examine.
  → These are decisions, not defaults. Nothing above was edited.

Next steps:
  - Visit <local-url> to verify the site
  - Visit <local-url>/wp-admin/ to log in
  - Run /wp-debug if you encounter any issues
  - Delete wp-content/mu-plugins/00-clone-isolation.php if this site ever becomes real
```

The isolation block is **not** optional and **not** collapsed to one line when everything
succeeded. An operator who cannot see that mail is captured has no reason to believe it is,
and the one time it silently failed is the run where that line mattered.
