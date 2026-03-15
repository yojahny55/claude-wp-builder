---
description: Responsive validation — screenshots at 5 viewports, checks for layout issues
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
argument-hint: "<url-or-file-path>"
---

# WP Responsive Check — Responsive Validation

Take screenshots at 5 standard viewports and analyze for responsive layout issues.

## Step 1: Get Target

Get the target from `$ARGUMENTS`. It can be:
- A URL (e.g., `http://localhost/mysite/`)
- A file path (e.g., `demo/index.html`)

If `$ARGUMENTS` is empty, ask the user for the URL or file path to check.

If it is a file path, convert to an absolute path and prepend `file://` for browser tools.

## Step 2: Choose Screenshot Method

Try these methods in order. Use the first one that works:

### Method A: Playwright MCP Server
If a Playwright MCP server is available, use it to take screenshots at each viewport size.

### Method B: Puppeteer CLI
Check if Puppeteer is available:
```bash
npx puppeteer --help 2>/dev/null
```

If available, take screenshots:
```bash
npx puppeteer screenshot --viewport=375x812 --output=responsive-375.png "<target>"
npx puppeteer screenshot --viewport=576x1024 --output=responsive-576.png "<target>"
npx puppeteer screenshot --viewport=768x1024 --output=responsive-768.png "<target>"
npx puppeteer screenshot --viewport=1024x768 --output=responsive-1024.png "<target>"
npx puppeteer screenshot --viewport=1440x900 --output=responsive-1440.png "<target>"
```

### Method C: Manual Fallback
If no automated tool is available, ask the user to provide screenshots at these viewport widths:
- 375px (mobile)
- 576px (large mobile)
- 768px (tablet)
- 1024px (small desktop)
- 1440px (desktop)

## Step 3: Analyze Screenshots

For each viewport, analyze the screenshot (read the image file) and check for:

| Issue | Severity | What to Look For |
|---|---|---|
| Horizontal overflow | Critical | Content extending beyond viewport, horizontal scrollbar |
| Text truncation | Critical | Text cut off, ellipsis where it shouldn't be |
| Overlapping elements | Critical | Elements stacking on top of each other unintentionally |
| Touch targets too small | Warning | Interactive elements smaller than 44x44px on mobile |
| Image scaling | Warning | Images not scaling properly, distorted aspect ratios |
| Nav behavior | Warning | Navigation not collapsing to hamburger on mobile, menu overflowing |
| Font readability | Warning | Text too small to read (below ~14px on mobile) |
| Spacing issues | Info | Inconsistent padding/margins at different breakpoints |
| Container overflow | Info | Content touching viewport edges without padding |

## Step 4: Analyze CSS (Supplementary)

If the target is a local file or if the theme CSS is accessible, also analyze:

- Read `assets/css/styles.css` (or embedded styles)
- Check for media queries at expected breakpoints: 576px, 768px, 1024px, 1440px
- Identify sections missing responsive rules
- Check for `overflow-x: hidden` on body (band-aid fix indicator)
- Check for fixed widths that should be responsive (e.g., `width: 500px` instead of `max-width`)

## Step 5: Generate Report

Print a detailed report:

```
=== Responsive Check Report ===
Target: <url-or-path>
Method: <Playwright|Puppeteer|Manual>

--- 375px (Mobile) ---
[CRITICAL] <issue description>
[WARNING]  <issue description>
[INFO]     <issue description>
[PASS]     No issues detected

--- 576px (Large Mobile) ---
[PASS] No issues detected

--- 768px (Tablet) ---
[WARNING] <issue description>

--- 1024px (Small Desktop) ---
[PASS] No issues detected

--- 1440px (Desktop) ---
[PASS] No issues detected

--- CSS Analysis ---
[PASS] Media queries found for all breakpoints
[WARNING] Section "hero" has no responsive rules below 768px
[INFO] Fixed width detected in .services__grid (line 234)

=== Summary ===
Critical: X issues
Warnings: X issues
Info:     X notes

Screenshots saved to: responsive-*.png
```

If critical issues are found, suggest specific CSS fixes for each one.
