# /wp-audit — Step 4

`commands/wp-audit.md` sends the run here at Step 4. Follow it in order; nothing in it is optional background.

**With `--report-only`, this step installs nothing.** Print the dependency report below
without the Options block, then continue with option C (run with what is available). A
report-only run promises to leave the site unchanged, and installing a plugin changes it.

If Tier 2 is available, check what plugins are installed:

```bash
bash -c "$WP plugin list --status=active --format=csv"
```

Determine which plugins are relevant based on selected categories:
- `--security` needs `all-in-one-wp-security-and-firewall`
- `--seo` needs `seo-by-rank-math`
- `secure-custom-fields` is always relevant

Build dependency report:

```
=== Audit Dependencies ===

WordPress Plugins:
  ✓ secure-custom-fields — installed & active
  ✗ seo-by-rank-math — not installed (needed for --seo)
  ✗ all-in-one-wp-security-and-firewall — not installed (needed for --security)

Browser measurement:
  <✓|✗> browser automation tool — <available|not available> (enables Core Web Vitals measurement)
  <✓|✗> suite (--suite) — <available|node/npm not available> (brings its own browser)

Either one is Tier 3. Print both: with `--suite` on a machine that has no MCP browser, a
line that says only "not available" contradicts the tier this run is actually at.

Options:
  [A] Install all recommended WordPress plugins
  [B] Let me pick which ones to install
  [C] Skip — run audit with what's available
```

Only show plugins relevant to the selected categories (don't prompt for Rank Math if `--security` only, don't prompt for AIOS if `--seo` only).

**On an adopted site, the stack decides what is offered** (Step 2.2):

- `stack.seo` names a plugin other than `rankmath`: do not list `seo-by-rank-math`. Print
  `✓ SEO owned by <stack.seo> — Rank Math not offered` instead.
- `stack.security` names a plugin other than `aios`: do not list
  `all-in-one-wp-security-and-firewall`. Print the same kind of line.
- `stack.fields` is `none`: do not list `secure-custom-fields`. A site with no field plugin
  has no field groups to audit. With `acf`, ACF is the field plugin, so SCF is not offered.
- A concern at `none` may still be offered its plugin (Rank Math, AIOS). Adding a plugin to
  a client site is the operator's decision, so option `[C] Skip` is listed first and marked
  recommended.

Use AskUserQuestion for the choice. If A: install all listed via `bash -c "$WP plugin install <slug> --activate"`. If B: ask which ones via AskUserQuestion and install selected. If C: continue without installing.
