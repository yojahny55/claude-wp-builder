- **The cinematic starter no longer ships unreplaced placeholders.** It used `__TEXTDOMAIN__`
  and `__VERSION__`, which `/wp-init` Step 4 never replaces, so every generated cinematic theme
  carried the literal tokens in its stylesheet header, constants, menu labels and nav. It now
  uses `__starter__` as the text domain and a literal `1.0.0`, like the Tailwind starter.
  `tests/checks/wp-init-templates.sh` fails on any `__token__` in either starter that Step 4
  does not replace.
