- **`tests/checks/lib/expand-command.sh` splices in only the command's own `-run` references.**
  It expanded every `skills/*/references/*.md` path a command named, so a command that points
  at another skill's reference as reading (`/wp-demo` names `wp-demo-craft`'s `fingerprint.md`)
  got that file's text spliced in, and a check could pass on wording the command never
  carried. It now expands only `skills/<command>-run/references/`.
