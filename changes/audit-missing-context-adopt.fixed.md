- **`/wp-audit` no longer sends an existing site to `/wp-init`.** With no
  `.claude/CLAUDE.md` it said "Project not initialized. Run /wp-init first", which contradicts
  the adoption flow and points a site that already has a theme at a command that scaffolds a
  starter. It now suggests `/wp-adopt` for an existing site and `/wp-init` for a new project.
