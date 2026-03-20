# Security Policy

## About This Project

Claude WP Builder is a code generation tool — it generates WordPress theme files (PHP, CSS, JavaScript) from demo HTML. It does not run as a service or handle user data directly.

## What to Report

Security-relevant issues include:

- **Generated code with vulnerabilities** — if a command or agent produces PHP with XSS, SQL injection, CSRF, or other OWASP Top 10 patterns
- **Hardcoded credentials** — if generated files contain API keys, passwords, or tokens
- **Unsafe file operations** — if commands write files to unexpected locations or with dangerous permissions
- **WP-CLI command injection** — if user input is passed unsafely to shell commands

## How to Report

Open a [GitHub Issue](https://github.com/yojahny55/claude-wp-builder/issues/new?labels=security) with the `security` label.

Since this is a code generation tool (not a running service), public disclosure via Issues is acceptable. If you believe the issue is sensitive, contact the maintainer directly via their [GitHub profile](https://github.com/yojahny55).

## Automated Security Checks

The plugin includes a built-in security auditor:

```bash
/wp-audit --security
```

This command scans generated theme code for common vulnerabilities and can auto-fix many issues. See [README.md](README.md) for details.

## Response Time

The maintainer aims to acknowledge security reports within 7 days and provide a fix or mitigation within 30 days.

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.3.x   | Yes       |
| 1.2.x   | Yes       |
| < 1.2   | No        |
