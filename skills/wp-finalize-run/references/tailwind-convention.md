# /wp-finalize — Tailwind convention (tailwind template only)

`commands/wp-finalize.md` sends the run here at Tailwind convention, once `Template:` is `tailwind`. Follow it in order; nothing in it is optional background.

When `Template:` is `tailwind`, run:

```bash
"${CLAUDE_PLUGIN_ROOT}/bin/tailwind-native-check.sh" <theme-dir>
```

The script lives in the plugin, not in the project. `/wp-finalize` runs with the
working directory set to the user's WordPress project, so a bare relative `bin/…`
path resolves to nothing there and exits 127 — always invoke it through
`${CLAUDE_PLUGIN_ROOT}`.

It fails the delivery on: a leftover `assets/css/styles.css`, an empty or
comment-only `.css`, a `.css` with no live `@import` in `main.css` — a commented-out
one does not count, because the file then ships unbuilt — any directory under
`assets/css/src/tailwindcss/` other than `base`, `components`, `layouts` and
`utilities`, **including one nested inside those four**, an inline `<style>` block in
a template, or a compiled theme whose templates carry class attributes but no Tailwind
utilities among them.

That last rule scales to the theme instead of demanding a fixed three templates: it
wants utilities in every class-carrying template up to a ceiling of three, so a
correct two-template theme passes it. Fix every finding before delivering — each one
means part of the build fell back to the plain-CSS path, and none of them is a known
false positive on a correct theme.
