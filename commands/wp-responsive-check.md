---
description: Responsive validation — screenshots at 7 viewports, checks for layout issues
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
argument-hint: "<url-or-file-path>"
---

# WP Responsive Check — Responsive Validation

Responsive validation now lives in `/wp-demo-verify`. Dispatch to it with the same
argument:

```bash
/wp-demo-verify $ARGUMENTS
```

It walks the five viewports this command used to cover (375, 576, 768, 1024, 1440)
plus 1152 and 1280, and adds the per-section scroll walk at 1440x900 and 390x844
that a single static screenshot per breakpoint cannot show. The legacy five sample
breakpoint edges only: 1152 sits INSIDE the 1024-1279 band, where `lg:` utilities
apply with no `xl:` override yet and a layout can be wrong while both neighbouring
edges look right. 1280 is the first width where `xl:` applies.
