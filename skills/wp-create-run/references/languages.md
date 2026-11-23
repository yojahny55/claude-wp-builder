# /wp-create — Step 4.14

`commands/wp-create.md` sends the run here at Step 4.14 (Install Languages, if non-English). Follow it in order; nothing in it is optional background.

For each additional language:

```bash
bash -c "$WP language core install es_ES"
```

Use full WordPress locale codes, not bare language codes. `es` is not a locale — WP-CLI warns `Language 'es' not available` and reports `Installed 0 of 1 languages (1 skipped)` with a **zero exit code**, so this failure is silent unless the output is read. Map the user's answer to a real locale (`es` -> `es_ES`, `pt` -> `pt_BR`, `fr` -> `fr_FR`) and confirm the choice when the language has several regional variants.

If the primary language is not English:

```bash
bash -c "$WP site switch-language ${PRIMARY_LANG}"
```

**Validation:** `$WP language core list --status=installed` lists every requested locale.
