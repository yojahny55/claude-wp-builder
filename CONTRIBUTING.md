# Contributing to Claude WP Builder

Welcome, and thank you for your interest in contributing to Claude WP Builder! This is a [Claude Code](https://docs.anthropic.com/en/docs/claude-code) plugin that automates WordPress site building through markdown-driven commands, agents, and skills. Whether you want to fix a bug, add a new command, or improve documentation, your contributions are welcome.

For a full overview of the project, see the [README](README.md).

## How to Report Issues

### Bug Reports (from real project testing)

The best bug reports come from testing the plugin on real WordPress projects. When filing a bug, please include:

- **Which command was used** (e.g., `/wp-section hero`)
- **Expected behavior** vs. what actually happened
- **Demo HTML snippet** (if relevant to the issue)
- **Generated output** — the PHP, CSS, or field definitions that were produced
- **WordPress environment details** — PHP version, WP version, active plugins
- **Screenshots or diffs** showing the problem

### Feature Requests & Improvements

- Describe the **use case**, not just the solution. Explain what you were trying to build and where the plugin fell short.
- Check [BACKLOG.md](BACKLOG.md) before submitting to avoid duplicates.

## Development Setup

```bash
# 1. Fork and clone
git clone https://github.com/<your-username>/claude-wp-builder.git
cd claude-wp-builder

# 2. Install as a Claude Code plugin (for testing)
claude plugins add ./

# 3. Set up a test WordPress site
/wp-create

# 4. Test with a demo
/wp-demo
/wp-init
# ... run commands and verify output
```

## Project Structure

| Directory | Purpose |
|---|---|
| `commands/` | Slash commands (user-facing entry points) |
| `agents/` | Specialized subagents dispatched by commands |
| `skills/` | Knowledge libraries referenced by agents (not user-invocable) |
| `starter-theme/` | PHP theme template copied per project |
| `templates/` | Environment configs and plugin profiles |
| `bin/` | Shell utilities |

## How to Contribute

### Writing a New Command

- Place the file in `commands/`.
- Include frontmatter with `description`, `allowed-tools`, and `argument-hint`.
- Follow the pattern of existing commands. Read `commands/wp-section.md` as a reference.

### Writing a New Agent

- Place the file in `agents/`.
- Include frontmatter with `name`, `description`, and `tools` (order: `Read, Write, Edit, Grep, Glob, Bash`).
- The agent **must** start with a "First Action (MANDATORY)" step that reads `.claude/CLAUDE.md`.
- Reference existing agents like `agents/wp-template.md` or `agents/wp-acf.md` for the expected structure.

### Writing a New Skill

- Place the file in `skills/<skill-name>/SKILL.md`.
- Include frontmatter with `name`, `description`, and `user-invocable: false`.
- Skills are knowledge documents. They don't execute actions; they inform agents.

### Modifying the Starter Theme

- Changes go in `starter-theme/__starter__/`.
- Use `__starter__` and `__STARTER_NAME__` as placeholders (replaced at runtime by `/wp-init`).
- Follow WordPress coding standards.

## Pull Request Guidelines

### Before Opening a PR

1. Create a feature branch from `main`: `git checkout -b feat/your-feature`
2. Test your changes with at least one real WordPress demo-to-theme workflow.
3. Ensure all existing commands still work (no regressions).
4. Update `CHANGELOG.md` under an `[Unreleased]` section.
5. Update `README.md` if you are adding a new command or feature.

### PR Format

```
## Summary
Brief description of what this PR does.

## Changes
- List of specific changes

## Testing
How you tested this (which commands, which demo, what WordPress setup).

## Screenshots (if visual)
Before/after or generated output samples.

## Checklist
- [ ] Tested with a real WordPress project
- [ ] Updated CHANGELOG.md
- [ ] Updated README.md (if new command/feature)
- [ ] Frontmatter matches existing patterns
- [ ] No hardcoded paths or credentials
```

### Review Process

- PRs are reviewed by the maintainer ([@yojahny55](https://github.com/yojahny55)).
- Expect feedback within a few days.
- Small, focused PRs are preferred over large ones.
- One feature or fix per PR.

## Commit Message Convention

This project follows [Conventional Commits](https://www.conventionalcommits.org/):

| Prefix | Use |
|---|---|
| `feat:` | New feature (command, agent, skill) |
| `fix:` | Bug fix |
| `docs:` | Documentation changes |
| `chore:` | Maintenance, config changes |
| `refactor:` | Code restructuring without behavior change |

## Code of Conduct

This project follows the [Contributor Covenant](https://www.contributor-covenant.org/). Please read our [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for details. We are committed to providing a welcoming and inclusive experience for everyone.

## Questions?

Open a [Discussion](https://github.com/yojahny55/claude-wp-builder/discussions) on GitHub or reach out in [Issues](https://github.com/yojahny55/claude-wp-builder/issues).
