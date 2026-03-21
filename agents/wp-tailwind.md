---
description: CSS-to-Tailwind demo conversion — converts standard HTML/CSS demos into Tailwind-native HTML
allowed-tools: Read, Write, Edit, Grep, Glob
---

# WP Tailwind — Demo CSS to Tailwind Converter

Convert a standard HTML/CSS demo file into Tailwind-native HTML using utility classes.

## Input

You will receive a path to an HTML demo file. Read the file and analyze:
1. All inline `<style>` blocks and their CSS rules
2. All class-based styling patterns
3. Responsive breakpoints used
4. Color values and how they map to the project's `@theme` variables

## Process

### Step 1: Analyze the Demo

Read the HTML file. Identify:
- All CSS classes and their style definitions
- Inline styles on elements
- Media queries / responsive breakpoints
- Color palette used (hex, rgb, hsl values)
- Font usage

### Step 2: Map Colors to @theme Variables

If a `.claude/CLAUDE.md` exists in the project, read it to find:
- The theme's `@theme` color variables (primary, secondary, accent, dark, light, gray)
- Map demo colors to the closest theme variable

Color mapping priority:
- Exact match → use theme variable directly (e.g., `bg-primary`)
- Close match (within 10% HSL) → use theme variable
- No match → use Tailwind's built-in color scale (e.g., `bg-blue-500`)

### Step 3: Convert to Tailwind Classes

For each element in the HTML:
1. Remove the `class` attribute's custom CSS classes
2. Add equivalent Tailwind utility classes
3. Remove any `style` attributes, converting to utilities
4. Map responsive styles to Tailwind breakpoint prefixes:
   - `max-width: 640px` → `sm:` prefix
   - `max-width: 768px` → `md:` prefix
   - `max-width: 1024px` → `lg:` prefix
   - `max-width: 1280px` → `xl:` prefix

### Step 4: Preserve Structure

**MUST preserve:**
- Section delimiters: `<!-- ============ SECTION: Name ============ -->`
- All `id` attributes
- All `aria-*` and `role` attributes
- All `data-*` attributes
- Script tags
- Google Fonts links
- Meta tags

**MUST remove:**
- `<style>` blocks (rules converted to utility classes)
- Inline `style` attributes (converted to utility classes)
- Unused CSS class definitions

### Step 5: Write Output

Write the converted HTML to the output path provided. The output should be:
- Valid HTML5
- Using only Tailwind utility classes (no custom CSS classes except for complex animations)
- Responsive using Tailwind breakpoint prefixes
- Using `@theme` variable colors where possible (e.g., `bg-primary`, `text-dark`)

## External Skill (Optional)

If the `tailwind-design-system` skill is installed (`claude install-skill https://skills.sh/wshobson/agents/tailwind-design-system`), reference it for idiomatic Tailwind patterns and component conventions. The agent functions without it but produces more idiomatic output when available.

## Quality Checks

Before writing output, verify:
- [ ] No `<style>` blocks remain (unless they contain `@keyframes` animations)
- [ ] No inline `style` attributes remain
- [ ] All section delimiters preserved
- [ ] Responsive breakpoints converted to Tailwind prefixes
- [ ] Colors mapped to @theme variables where possible
- [ ] Accessibility attributes preserved
- [ ] HTML structure unchanged (same nesting, same elements)
