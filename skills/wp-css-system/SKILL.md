---
name: wp-css-system
description: CSS design system standards — custom properties, BEM naming, spacing/typography/color scales, no build tools
user-invocable: false
---

# CSS Design System Standards

This skill defines the CSS architecture for all themes. The system uses **CSS custom properties** (variables), **BEM naming**, and **no build tools** -- plain CSS files served directly.

---

## Principles

1. **No frameworks** -- no Bootstrap, Tailwind, Foundation, or any CSS framework
2. **No preprocessors** -- no Sass, Less, or PostCSS
3. **No build step** -- CSS files are authored and served as-is
4. **All values use custom properties** -- never hardcode colors, spacing, font sizes, or other design tokens directly in rules
5. **BEM naming convention** for all class names
6. **Consistency between demo HTML and WordPress theme CSS** -- the design system carries over from the demo to the theme unchanged

---

## Custom Property Reference

All design tokens are defined in `:root` at the top of the main stylesheet.

### Colors

```css
:root {
    /* Primary palette */
    --color-primary: #1a5632;
    --color-primary-light: #2d7a4a;
    --color-primary-dark: #0f3d22;

    /* Secondary palette */
    --color-secondary: #c9a84c;
    --color-secondary-light: #d4b96e;
    --color-secondary-dark: #a88a2e;

    /* Tertiary palette */
    --color-tertiary: #2c3e50;
    --color-tertiary-light: #3d5571;
    --color-tertiary-dark: #1a2530;

    /* Neutral scale (gray ramp) */
    --color-neutral-50: #fafafa;
    --color-neutral-100: #f5f5f5;
    --color-neutral-200: #e5e5e5;
    --color-neutral-300: #d4d4d4;
    --color-neutral-400: #a3a3a3;
    --color-neutral-500: #737373;
    --color-neutral-600: #525252;
    --color-neutral-700: #404040;
    --color-neutral-800: #262626;
    --color-neutral-900: #171717;

    /* Semantic colors */
    --color-text: var(--color-neutral-800);
    --color-text-light: var(--color-neutral-500);
    --color-text-inverse: #ffffff;
    --color-background: #ffffff;
    --color-background-alt: var(--color-neutral-50);
    --color-border: var(--color-neutral-200);
    --color-success: #16a34a;
    --color-error: #dc2626;
    --color-warning: #f59e0b;
}
```

### Spacing Scale

A consistent spacing scale based on `rem` units. Use these for all margin, padding, and gap values.

```css
:root {
    --spacing-xs: 0.25rem;   /* 4px */
    --spacing-sm: 0.5rem;    /* 8px */
    --spacing-md: 1rem;      /* 16px */
    --spacing-lg: 1.5rem;    /* 24px */
    --spacing-xl: 2rem;      /* 32px */
    --spacing-2xl: 3rem;     /* 48px */
    --spacing-3xl: 4rem;     /* 64px */
}
```

### Typography

```css
:root {
    /* Font families */
    --font-family-primary: 'DM Sans', 'Helvetica Neue', Arial, sans-serif;
    --font-family-secondary: 'Cormorant Garamond', Georgia, 'Times New Roman', serif;

    /* Font size scale */
    --font-size-xs: 0.75rem;    /* 12px */
    --font-size-sm: 0.875rem;   /* 14px */
    --font-size-base: 1rem;     /* 16px */
    --font-size-md: 1.125rem;   /* 18px */
    --font-size-lg: 1.25rem;    /* 20px */
    --font-size-xl: 1.5rem;     /* 24px */
    --font-size-2xl: 2rem;      /* 32px */
    --font-size-3xl: 2.5rem;    /* 40px */
    --font-size-4xl: 3rem;      /* 48px */
    --font-size-5xl: 3.5rem;    /* 56px */
    --font-size-6xl: 4rem;      /* 64px */

    /* Font weights */
    --font-weight-regular: 400;
    --font-weight-medium: 500;
    --font-weight-semibold: 600;
    --font-weight-bold: 700;

    /* Line heights */
    --line-height-tight: 1.2;
    --line-height-normal: 1.5;
    --line-height-relaxed: 1.75;
}
```

### Shadows

```css
:root {
    --shadow-sm: 0 1px 2px rgba(0, 0, 0, 0.05);
    --shadow-md: 0 4px 6px rgba(0, 0, 0, 0.07), 0 2px 4px rgba(0, 0, 0, 0.06);
    --shadow-lg: 0 10px 15px rgba(0, 0, 0, 0.1), 0 4px 6px rgba(0, 0, 0, 0.05);
}
```

### Border Radius

```css
:root {
    --radius-sm: 0.25rem;   /* 4px */
    --radius-md: 0.5rem;    /* 8px */
    --radius-lg: 1rem;      /* 16px */
    --radius-full: 9999px;  /* Pill/circle shape */
}
```

### Transitions

```css
:root {
    --transition-base: all 0.3s ease;
    --transition-slow: all 0.5s ease;
}
```

### Container

```css
:root {
    --container-max: 1280px;
}
```

---

## Using Custom Properties in Rules

**Every** color, spacing, font size, shadow, radius, and transition value in CSS rules MUST reference a custom property. Never hardcode values.

```css
/* CORRECT */
.hero__title {
    font-family: var(--font-family-secondary);
    font-size: var(--font-size-4xl);
    color: var(--color-text);
    margin-bottom: var(--spacing-lg);
}

.card {
    background: var(--color-background);
    border-radius: var(--radius-md);
    box-shadow: var(--shadow-md);
    padding: var(--spacing-xl);
    transition: var(--transition-base);
}

/* WRONG — hardcoded values */
.hero__title {
    font-family: 'Cormorant Garamond', serif;
    font-size: 3rem;
    color: #262626;
    margin-bottom: 1.5rem;
}
```

---

## BEM Naming Convention

All CSS classes follow the **Block Element Modifier** pattern: `.block__element--modifier`.

### Structure

- **Block**: A standalone entity (`.card`, `.hero`, `.nav`, `.footer`)
- **Element**: A part of a block (`.card__title`, `.card__image`, `.nav__link`)
- **Modifier**: A variation (`.card--featured`, `.btn--primary`, `.nav__link--active`)

### Real-World Examples

```css
/* Block */
.hero {
    padding: var(--spacing-3xl) 0;
    background: var(--color-background);
}

/* Elements */
.hero__container {
    max-width: var(--container-max);
    margin: 0 auto;
    padding: 0 var(--spacing-md);
}

.hero__title {
    font-family: var(--font-family-secondary);
    font-size: var(--font-size-4xl);
    font-weight: var(--font-weight-semibold);
    color: var(--color-text);
    margin-bottom: var(--spacing-md);
}

.hero__subtitle {
    font-size: var(--font-size-lg);
    color: var(--color-text-light);
    margin-bottom: var(--spacing-xl);
}

.hero__cta {
    display: inline-flex;
    align-items: center;
    gap: var(--spacing-sm);
}

/* Modifiers */
.btn {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    padding: var(--spacing-sm) var(--spacing-lg);
    border-radius: var(--radius-md);
    font-weight: var(--font-weight-medium);
    text-decoration: none;
    transition: var(--transition-base);
    cursor: pointer;
    border: none;
}

.btn--primary {
    background: var(--color-primary);
    color: var(--color-text-inverse);
}

.btn--primary:hover {
    background: var(--color-primary-dark);
}

.btn--secondary {
    background: transparent;
    color: var(--color-primary);
    border: 2px solid var(--color-primary);
}

.btn--secondary:hover {
    background: var(--color-primary);
    color: var(--color-text-inverse);
}

.btn--large {
    padding: var(--spacing-md) var(--spacing-xl);
    font-size: var(--font-size-lg);
}
```

### Naming Rules

- Use lowercase with hyphens inside block/element names: `.service-card__title` (not `.serviceCard__title`)
- Maximum two levels: `.block__element` (never `.block__element__subelement`)
- If nesting is needed, create a new block: `.card__header` contains `.card-header__title`
- Modifiers are always on the block or element, never standalone

---

## CSS Reset / Normalize Baseline

Every stylesheet begins with a minimal reset to ensure consistent rendering across browsers.

```css
/* ============ Section: Reset ============ */
*,
*::before,
*::after {
    box-sizing: border-box;
    margin: 0;
    padding: 0;
}

html {
    scroll-behavior: smooth;
    -webkit-text-size-adjust: 100%;
}

body {
    font-family: var(--font-family-primary);
    font-size: var(--font-size-base);
    line-height: var(--line-height-normal);
    color: var(--color-text);
    background-color: var(--color-background);
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
}

img,
picture,
video,
canvas,
svg {
    display: block;
    max-width: 100%;
    height: auto;
}

a {
    color: inherit;
    text-decoration: none;
}

button {
    font: inherit;
    cursor: pointer;
    border: none;
    background: none;
}

ul,
ol {
    list-style: none;
}

h1, h2, h3, h4, h5, h6 {
    font-weight: var(--font-weight-semibold);
    line-height: var(--line-height-tight);
}

input,
textarea,
select {
    font: inherit;
}
```

---

## Section Comment Delimiters

Use the following format to separate major sections of the stylesheet. This makes the file scannable and maps to the section-based architecture of the theme.

```css
/* ============ Section: Variables ============ */
:root { ... }

/* ============ Section: Reset ============ */
*, *::before, *::after { ... }

/* ============ Section: Typography ============ */
h1, h2, h3, ... { ... }

/* ============ Section: Layout ============ */
.container { ... }

/* ============ Section: Header ============ */
.header { ... }

/* ============ Section: Hero ============ */
.hero { ... }

/* ============ Section: Services ============ */
.services { ... }

/* ============ Section: Footer ============ */
.footer { ... }

/* ============ Section: Utilities ============ */
.sr-only { ... }
```

---

## Layout Utilities

### Container

```css
.container {
    width: 100%;
    max-width: var(--container-max);
    margin-left: auto;
    margin-right: auto;
    padding-left: var(--spacing-md);
    padding-right: var(--spacing-md);
}
```

### Section Spacing

```css
.section {
    padding: var(--spacing-3xl) 0;
}

.section--compact {
    padding: var(--spacing-2xl) 0;
}

.section--alt {
    background-color: var(--color-background-alt);
}
```

### Screen Reader Only

```css
.sr-only {
    position: absolute;
    width: 1px;
    height: 1px;
    padding: 0;
    margin: -1px;
    overflow: hidden;
    clip: rect(0, 0, 0, 0);
    white-space: nowrap;
    border: 0;
}
```

---

## Page-Specific CSS Files

When a page has substantial unique styles (e.g., a pricing calculator, a software portfolio page), create a dedicated CSS file and enqueue it conditionally.

```
assets/css/
├── styles.css      # Main design system (always loaded)
├── software.css    # Software page only
└── pricing.css     # Pricing page only
```

These files:
- Must still use the same custom properties from the design system
- Are enqueued via `is_page_template()` in `functions.php`
- Should NOT duplicate base styles already in `styles.css`

---

## Consistency Between Demo and Theme

When building the demo HTML first and then converting to WordPress:

1. The `:root` custom properties in the demo `<style>` block MUST match the theme `styles.css` exactly
2. All BEM class names in the demo MUST be preserved in the WordPress templates
3. The CSS from the demo is extracted into `assets/css/styles.css` with minimal changes (primarily removing the `<style>` tags)
4. Section ordering and naming must match

---

## Common Patterns

### Grid Layout

```css
.services__grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: var(--spacing-xl);
}
```

### Flexbox Row

```css
.header__inner {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--spacing-lg);
}
```

### Card Component

```css
.card {
    background: var(--color-background);
    border-radius: var(--radius-md);
    box-shadow: var(--shadow-sm);
    padding: var(--spacing-xl);
    transition: var(--transition-base);
}

.card:hover {
    box-shadow: var(--shadow-md);
    transform: translateY(-2px);
}

.card__title {
    font-size: var(--font-size-xl);
    font-weight: var(--font-weight-semibold);
    margin-bottom: var(--spacing-sm);
}

.card__text {
    font-size: var(--font-size-base);
    color: var(--color-text-light);
    line-height: var(--line-height-relaxed);
}
```

### Section Title Pattern

```css
.section__label {
    font-size: var(--font-size-sm);
    font-weight: var(--font-weight-semibold);
    text-transform: uppercase;
    letter-spacing: 0.1em;
    color: var(--color-primary);
    margin-bottom: var(--spacing-sm);
}

.section__title {
    font-family: var(--font-family-secondary);
    font-size: var(--font-size-3xl);
    font-weight: var(--font-weight-semibold);
    color: var(--color-text);
    margin-bottom: var(--spacing-md);
}

.section__description {
    font-size: var(--font-size-lg);
    color: var(--color-text-light);
    max-width: 600px;
}
```

---

## Summary Checklist

- [ ] All design tokens defined as `:root` custom properties
- [ ] Color palette includes primary, secondary, tertiary, and neutral scale (50-900)
- [ ] Spacing scale from `--spacing-xs` to `--spacing-3xl`
- [ ] Typography scale from `--font-size-xs` to `--font-size-6xl`
- [ ] Shadow, radius, transition, and container variables defined
- [ ] All CSS rules reference custom properties (no hardcoded values)
- [ ] BEM naming used for all classes
- [ ] CSS reset/normalize included at the top
- [ ] Section comment delimiters used throughout
- [ ] No CSS frameworks, preprocessors, or build tools
- [ ] Page-specific CSS in separate files, conditionally enqueued
- [ ] Demo and theme CSS use identical design tokens and class names
