- **The commands can be exported for Cursor, Gemini CLI and `AGENTS.md` readers.**
  `bin/export-platform.mjs --target agents-md|cursor|gemini <out-dir>` writes, from the
  commands as they are, an `AGENTS.md` index, one Cursor rule per command, or Gemini CLI
  commands with their arguments. Plugin paths are made absolute, and each exported command
  opens with what another agent lacks: run a subagent's steps yourself, in order, and ask
  questions in the chat. No command changes.
