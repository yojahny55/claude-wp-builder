# Security Policy

## About This Project

Claude WP Builder is a Claude Code plugin. It generates WordPress theme files (PHP, CSS, JavaScript) from demo HTML, but it is more than a text generator. It also:

- ships a WordPress plugin, `plugins/store-kit`, that is copied into stores and runs on live sites;
- reads Stripe keys from `wp-config.php` constants for store setups;
- clones production data into local sites and anonymizes it (`/wp-clone`, `/wp-anonymize`);
- handles image-generation API keys (`GEMINI_API_KEY`, `OPENAI_API_KEY`) through `bin/image-gen.mjs`;
- runs WP-CLI, shell and browser tooling against the user's machine and sites.

## What to Report

- **Generated code with vulnerabilities**: a command or agent that produces PHP with XSS, SQL injection, CSRF, or other OWASP Top 10 patterns.
- **`plugins/store-kit` flaws**: anything exploitable in the plugin that reaches a store, including catalog-mode bypasses and handling of payment settings.
- **Secret exposure**: generated files, logs, manifests, reports or committed artifacts that contain API keys, Stripe keys, database passwords or tokens, or a path where a secret read from `wp-config.php` or the environment ends up somewhere it should not.
- **Clone and anonymizer leaks**: production data (personal data, credentials, tokens) that survives `/wp-anonymize`, or that a clone copies somewhere it should not.
- **Unsafe file operations**: commands that write files to unexpected locations or with dangerous permissions.
- **Command injection**: user or site input passed unsafely to WP-CLI or shell commands.

## How to Report

**Sensitive reports go to the maintainer privately first.** Contact the maintainer through their [GitHub profile](https://github.com/yojahny55) and do not post details publicly. This covers anything that exposes secrets, production data, or an exploitable flaw in code that already runs on live sites (`plugins/store-kit`, generated theme code).

GitHub's private vulnerability reporting is not enabled on this repository, so do not look for a "Report a vulnerability" button.

**Public issues are only for what is not sensitive**: a hardening suggestion, a generated-code pattern that is weak but not exploitable by itself, or a gap in the built-in checks. Open a [GitHub Issue](https://github.com/yojahny55/claude-wp-builder/issues/new?labels=security) with the `security` label.

When in doubt, treat it as sensitive.

## Automated Security Checks

The plugin includes a built-in security auditor:

```bash
/wp-audit --security
```

This command scans generated theme code for common vulnerabilities and can auto-fix many issues. See [README.md](README.md) for details.

## Response Time

The maintainer aims to acknowledge security reports within 7 days and provide a fix or mitigation within 30 days.

## Supported Versions

Only the latest release receives security fixes. The current version is in `.claude-plugin/plugin.json`.
