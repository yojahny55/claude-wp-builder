# Polylang i18n variants

One file per starter template, each a drop-in replacement for that template's
`inc/i18n.php` when a project is scaffolded with `--i18n=polylang`.

They live HERE, outside the theme directories, for one reason: a starter that
contains two definitions of the same function is a trap. `functions.php`
requires `inc/i18n.php` by name today, so nothing breaks right now — but the
next person to swap that for a `glob( 'inc/*.php' )` gets a fatal error, and
`tests/checks/tailwind-starter.sh` correctly refuses a starter in that state.
Keeping the variants out of the copied tree means `cp -r starter-theme/__x__/`
never carries a file the project has to remember to delete.

`/wp-init` Step 5 copies the matching file over `inc/i18n.php` when the user
picks Polylang, and does nothing here otherwise.

Each variant must expose exactly the helper set its own `inc/i18n.php` does —
the two starters have deliberately different contracts (ten helpers vs four).
`tests/checks/wp-polylang.sh` asserts that pairing per starter.
