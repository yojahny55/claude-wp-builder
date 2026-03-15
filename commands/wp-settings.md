---
description: Extend the theme settings page with additional ACF fields beyond the defaults
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent
argument-hint: "[description of settings to add]"
---

# WP Settings — Extend Theme Settings Page

Add new fields, tabs, or sections to the theme's ACF/SCF settings page.

## Step 1: Read Project Context

Read `.claude/CLAUDE.md` to extract:
- **Function prefix** (e.g., `kairo_`)
- **Languages** (primary + secondary)
- **Theme directory path**

If `.claude/CLAUDE.md` does not exist, tell the user to run `/wp-init` first.

## Step 2: Read Existing Settings

Read `fields/settings.php` in the theme directory to understand:
- Existing tabs and their fields
- Field naming patterns used
- Location rules
- Current structure and organization

If the file does not exist, inform the user that the starter theme's default settings file is missing and offer to create one from scratch.

## Step 3: Get Requirements

If `$ARGUMENTS` is provided, use it as the description of what settings to add.

If `$ARGUMENTS` is empty, ask the user:
- What settings do they need to add?
- Should these go in a new tab or extend an existing tab?
- Examples: analytics codes, additional contact fields, social platforms, custom scripts, maintenance mode toggle, color overrides

## Step 4: Dispatch wp-acf Agent

Dispatch the **wp-acf** agent with these instructions:

> Update `fields/settings.php` in the theme directory to add the following settings:
>
> **Requirements from user:** <paste user requirements or $ARGUMENTS>
>
> **Rules:**
> 1. DO NOT remove or modify existing fields — only ADD new ones
> 2. If adding a new logical group, create a new Tab field to organize it
> 3. For ALL text, textarea, and wysiwyg fields, create bilingual variants:
>    - `<field_name>_en` (English variant)
>    - `<field_name>_es` (Spanish variant)
>    - (adjust languages to match project config)
> 4. Follow the existing field naming convention in the file
> 5. Use appropriate field types: text, textarea, wysiwyg, image, url, true_false, select, repeater, etc.
> 6. Add helpful instructions/descriptions to fields so the client understands what each one does
> 7. All fields should have `field_` prefixed keys
> 8. Ensure the field group location rule keeps pointing to the options page
>
> **Existing settings.php content:**
> ```php
> <paste current file content>
> ```

## Step 5: Print Summary

```
=== Settings Updated ===
File updated: fields/settings.php

New fields added:
  - <list of new field names>

Tab: <new or existing tab name>

The settings page will show the new fields under Appearance > Theme Settings.
```
