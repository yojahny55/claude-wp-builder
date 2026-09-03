---
description: Responsive validation — screenshots at 5 viewports, checks for layout issues
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
argument-hint: "<url-or-file-path>"
---

# WP Responsive Check — Responsive Validation

Responsive validation now lives in `/wp-demo-verify`. Dispatch to it with the same
argument:

```bash
/wp-demo-verify $ARGUMENTS
```

It walks the same five viewports this command used to cover (375, 576, 768, 1024,
1440), plus the per-section scroll walk at 1440x900 and 390x844 that a single
static screenshot per breakpoint cannot show.
