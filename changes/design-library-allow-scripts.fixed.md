- **The `wp-design-library` MCP server starts under npm 12.** npm 12 no longer runs a
  dependency's install scripts unless the package is allowed, so `npx` installed
  `better-sqlite3` without building its native binding and the server died at startup with
  `Could not locate the bindings file`; the client reported `Connection closed`. `.mcp.json`
  now passes `--allow-scripts=better-sqlite3` to `npx`, which allows that one package and
  nothing else; npm 11 accepts the flag as well. A cache entry
  left broken by an earlier start is not rebuilt: delete its `~/.npm/_npx/<hash>` folder once.
