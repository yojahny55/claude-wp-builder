# /wp-create — Step 4.10

`commands/wp-create.md` sends the run here at Step 4.10 (Install Plugin Profile). Follow it in order; nothing in it is optional background.

## Contents

- Profile validation
- Required and optional plugins
- Licensed and supplied packages
- Validation

First validate the profile, because a profile that cannot be satisfied should say so
before anything is installed:

```bash
bash -c "node ${CLAUDE_PLUGIN_ROOT}/bin/wp-config.mjs validate-profile '<profile-path>'"
```

**Validation:** exit code `0`, printing `ok: <path> is a valid profile`.

**On failure:** exit `1` — each problem is printed to stderr, naming the plugin slug and
the rule it broke (an unmet `requires`, a `conflicts` collision, a bad `source`, a
non-boolean `required`, a non-canonical `slug`). **Stop: do not install anything from
this profile.** Report the reasons and let the user fix the profile file or choose a
different one. (Exit `3` means the profile path does not exist — same stop, different
reason.)

Then install **one plugin at a time**, using the actual slugs from the selected profile
JSON, and branch on that plugin's `required` flag:

```bash
bash -c "$WP plugin install <slug> --activate"
```

| Outcome | `required: true` | `required: false` |
|---|---|---|
| Installed and activated | record in `plugins.resolved` | record in `plugins.resolved` |
| Not found, install failed, or activation failed | **stop**: this failure blocks the dependent workflow — report the slug and the reason, and do not continue to steps that need it | warn, continue, record in `plugins.degraded` with the reason |

A plugin whose profile entry says `"source": "supplied"` is never fetched from WP.org. Ask
for the zip or path.

A plugin whose entry says `"source": "bundled"` ships inside claude-wp-builder. Copy it in and
activate it; never fetch it from WordPress.org, where the same slug could belong to someone
else. Its entry lists `woocommerce` first, because WordPress refuses to activate a plugin whose
`Requires Plugins` is inactive.

A store profile needs native WP-CLI, running on the host. The copy lands in the host's
`wp-content/plugins`, and `/wp-woo-setup` later runs host paths: Docker (our templates) mounts
only the theme, wp-env loads no plugin from the project, and DDEV and Lando run WP-CLI in a
container that mounts neither this plugin's scripts nor the host project path. On anything but
`native` (the environment chosen in Step 1; the manifest records it as `environment.engine`),
stop here, before syncing, rather than failing at `plugin activate`, and
say so in one line:

> store profiles need native WP-CLI: on `<engine>` WP-CLI cannot see the plugin's scripts or the project directory

Otherwise:

```bash
bash -c "bash '${CLAUDE_PLUGIN_ROOT}/bin/store-kit-sync.sh' '${PROJECT_PATH}/wp-content/plugins' && $WP plugin activate store-kit"
```

A failure here counts against the entry's `required` flag like any other install.

**Three different things used to be recorded as `license_missing`, and they need different
actions from the operator.** A premium plugin whose licence nobody bought, a zip that
exists but was not handed over, and a zip that was handed over and would not install are
one word in the report and three different next steps — buy it, go and find it, or debug
it. Record the reason that actually applies:

| What happened | `reason` | What the operator does next |
|---|---|---|
| No zip, and the plugin is licensed | `license_missing` | obtain a licence |
| The zip exists somewhere but was not supplied to this build | `package_not_supplied` | fetch the file and re-run |
| A zip was supplied and `wp plugin install` failed | `install_failed` | the message from WP-CLI says why |
| Installed, but `wp plugin activate` failed | `activation_failed` | usually a PHP or dependency error, which is in the log |

All four count as a failure against the entry's own `required` flag, exactly as before — a
required plugin that is absent for any of these reasons blocks the build rather than
half-installing around it. What changes is that the report says which one, so a missing
file is not reported as a purchase the client has to make.

Record what was actually resolved, not what was requested:

```json
"plugins": {
  "profile": "<PROFILE_NAME>",
  "installed": ["<plugin-slug-1>"],
  "resolved": [
    { "slug": "<plugin-slug-1>", "version": "<X.Y.Z>", "source": "wordpress.org", "active": true }
  ],
  "degraded": [
    { "slug": "<plugin-slug-2>", "reason": "not found in the WP.org repository" }
  ]
}
```

**Validation:** `$WP plugin list --status=active --format=json` includes every required
plugin from the profile.
