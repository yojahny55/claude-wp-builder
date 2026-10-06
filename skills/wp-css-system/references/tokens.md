# CSS Design Tokens

The `:root` token set for `Template: basic` themes and plain demos, from the
`wp-css-system` skill. Every rule references these; none hardcodes a value.

**The names and the scale are the contract. The values are placeholders.** The green and
gold palette, the `DM Sans` / `Cormorant Garamond` pair and every other value below only
show the shape of a filled-in block. Replace each one from the client's brand, or copy it
from the demo's own `:root`, which is the source of truth once a demo exists. A theme that
ships these sample values unchanged ships someone else's brand.

## Contents

- Colors
- Spacing Scale
- Typography
- Shadows
- Border Radius
- Transitions
- Container

All design tokens are defined in `:root` at the top of the main stylesheet.

## Colors

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

## Spacing Scale

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

## Typography

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

## Shadows

```css
:root {
    --shadow-sm: 0 1px 2px rgba(0, 0, 0, 0.05);
    --shadow-md: 0 4px 6px rgba(0, 0, 0, 0.07), 0 2px 4px rgba(0, 0, 0, 0.06);
    --shadow-lg: 0 10px 15px rgba(0, 0, 0, 0.1), 0 4px 6px rgba(0, 0, 0, 0.05);
}
```

## Border Radius

```css
:root {
    --radius-sm: 0.25rem;   /* 4px */
    --radius-md: 0.5rem;    /* 8px */
    --radius-lg: 1rem;      /* 16px */
    --radius-full: 9999px;  /* Pill/circle shape */
}
```

## Transitions

```css
:root {
    --transition-base: all 0.3s ease;
    --transition-slow: all 0.5s ease;
}
```

## Container

```css
:root {
    --container-max: 1280px;
}
```
