---
description: Convert an HTML/CSS demo to Tailwind-native HTML — preserves section delimiters, maps colors to @theme variables
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent
argument-hint: "[path/to/demo.html]"
---

# WP Tailwindify — Convert Demo to Tailwind

Convert a standard HTML/CSS demo file into Tailwind-native HTML.

## Step 1: Locate the Demo File

- If `$ARGUMENTS` is provided and is a file path, use that file.
- Otherwise, check for `demo/index.html` in the current working directory.
- If no demo file found, ask the user for the path.

Verify the file exists and is an HTML file.

## Step 2: Read and Validate

Read the demo HTML file. Check:
- Does it contain `<style>` blocks or inline styles? (If not, it may already be Tailwind-native — confirm with user.)
- Does it have section delimiters? (Warn if missing — suggest running `/wp-polish` first.)

## Step 3: Dispatch Conversion Agent

Dispatch the `wp-tailwind` agent (@agents/wp-tailwind) with the following context:

- Input file path: `<demo-file-path>`
- Output file path: `<demo-dir>/index-tailwind.html` (alongside the original)
- Project CLAUDE.md path (if exists): for @theme color mapping

## Step 4: Verify Output

After the agent completes:
1. Read the output file
2. Verify section delimiters are preserved (count should match original)
3. Verify no `<style>` blocks remain (except `@keyframes`)
4. Report the conversion result to the user

## Step 5: Offer Next Steps

```
=== Demo Converted to Tailwind ===
Original:  <original-path>
Tailwind:  <output-path>
Sections:  <count> preserved

Next steps:
- Review the converted demo in a browser
- If satisfied, replace the original: cp <output-path> <original-path>
- Run /wp-init to scaffold the project with the Tailwind template
```
