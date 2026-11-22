---
name: wp-clone-run
description: "Step detail of the /wp-clone run, split out of the command. Use when /wp-clone reaches a step that names one of these reference files, or when changing how a /wp-clone step behaves."
user-invocable: false
---

# /wp-clone step detail

`commands/wp-clone.md` owns the order of the run. Each step that needs more than a few
paragraphs keeps its heading and entry condition there and sends the run to one file here. The
command reads the file at that step, not before, so a run on Path A never pays for Path B.

These files are the step itself, not background reading. When the command says to read one,
read it whole and follow it in order.

## References, by step

| Step | File | Covers |
|---|---|---|
| Path A | [references/path-a.md](references/path-a.md) | A1-A13: prerequisites, SSH and remote WP-CLI checks, the remote dependency inventory (A3.5), database export and download, uploads rsync, the local `/wp-create`, import, URL search-replace, fix-up and permissions |
| Path B | [references/path-b.md](references/path-b.md) | B1-B7: validating the provided files, the local `/wp-create`, import, the dependency inventory from the database (B3.5), uploads extraction, original domain, URL search-replace, fix-up |
| Path C | [references/path-c.md](references/path-c.md) | C1-C8: validating the archive and dump, the local `/wp-create`, reading the docroot depth, table prefix and source URLs from the archive index and the dump, extracting the site (optionally with uploads on another disk), reconciling `wp-config.php`, the import, the URL search-replace with heavy tables skipped, local safety |
| 5.4.1 | [references/isolation-mail.md](references/isolation-mail.md) | The mail-capture must-use plugin written before the import: its code, why `pre_wp_mail` is the seam, what it does not stop |
| 6 | [references/verify.md](references/verify.md) | 6.1-6.7: WordPress loads, URLs, admin access, theme, plugins, the HTTP check and the clone summary |

## Changing a step

Edit the reference file, not the command, unless the step order or the step's entry
condition changes. A check that guards a step's wording reads the command with these files
expanded in place (`tests/checks/lib/expand-command.sh`); `tests/checks/wp-clone-run.sh`
asserts that every file here is named both in this table and at its step in
`commands/wp-clone.md`.
