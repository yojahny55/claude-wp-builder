- **`CLAUDE.md` is half its size.** It is loaded into every session, so its 260 lines
  were paid on every task. The `bin/` tool catalog moved to `docs/plugin-code.md`, the
  release steps to `docs/releasing.md` and the craft and store detail to
  `docs/architecture.md`; `CLAUDE.md` keeps the rules and a pointer to each, and its line
  budget drops from 260 to 150. The `/wp-contribute` skill review now runs its subagent on
  sonnet instead of inheriting the session model.
