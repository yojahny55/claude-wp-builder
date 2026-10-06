# Responsive Layout Patterns

Worked CSS for the rules in `SKILL.md`. Copy the pattern, then fit it to the section.

## Contents

- CSS Grid and Flexbox Stacking (grid, flexbox, reversing order on mobile)
- Touch Target Sizing per Element (buttons, navigation links, form inputs, icon buttons)
- Pattern for Every Section
- Responsive Section Spacing
- Responsive Typography Scale
- Responsive Footer

## CSS Grid and Flexbox Stacking

### Grid: Columns on Desktop, Stacked on Mobile

```css
/* Mobile: single column */
.features__grid {
    display: grid;
    grid-template-columns: 1fr;
    gap: var(--spacing-lg);
}

/* Tablet: 2 columns */
@media (min-width: 768px) {
    .features__grid {
        grid-template-columns: repeat(2, 1fr);
        gap: var(--spacing-xl);
    }
}

/* Desktop: 3 columns */
@media (min-width: 1024px) {
    .features__grid {
        grid-template-columns: repeat(3, 1fr);
    }
}

/* Large: 4 columns */
@media (min-width: 1200px) {
    .features__grid {
        grid-template-columns: repeat(4, 1fr);
    }
}
```

### Flexbox: Row on Desktop, Column on Mobile

```css
/* Mobile: stacked vertically */
.hero__inner {
    display: flex;
    flex-direction: column;
    gap: var(--spacing-xl);
}

/* Desktop: side by side */
@media (min-width: 1024px) {
    .hero__inner {
        flex-direction: row;
        align-items: center;
    }

    .hero__content {
        flex: 1;
    }

    .hero__image {
        flex: 1;
    }
}
```

### Reversing Order on Mobile

```css
.hero__inner {
    display: flex;
    flex-direction: column-reverse; /* image first on mobile */
    gap: var(--spacing-xl);
}

@media (min-width: 1024px) {
    .hero__inner {
        flex-direction: row; /* content left, image right on desktop */
    }
}
```

---

## Touch Target Sizing per Element

### Buttons

```css
.btn {
    min-height: 44px;
    min-width: 44px;
    padding: var(--spacing-sm) var(--spacing-lg);
}
```

### Navigation Links

```css
.nav__link {
    display: inline-flex;
    align-items: center;
    min-height: 44px;
    padding: var(--spacing-sm) var(--spacing-md);
}

.mobile-menu__link {
    display: block;
    padding: var(--spacing-md) var(--spacing-lg);
    min-height: 44px;
}
```

### Form Inputs

```css
input[type="text"],
input[type="email"],
input[type="tel"],
textarea,
select {
    min-height: 44px;
    padding: var(--spacing-sm) var(--spacing-md);
    font-size: var(--font-size-base); /* Prevents zoom on iOS */
}
```

### Icon Buttons

```css
.icon-button {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 44px;
    height: 44px;
    padding: var(--spacing-sm);
}
```

---

## Pattern for Every Section

```css
/* ============ Section: Values ============ */

/* Base: mobile */
.values {
    padding: var(--spacing-2xl) 0;
}

.values__grid {
    display: grid;
    grid-template-columns: 1fr;
    gap: var(--spacing-lg);
}

.values__title {
    font-size: clamp(1.5rem, 3vw, 2.5rem);
    text-align: center;
    margin-bottom: var(--spacing-xl);
}

/* Tablet (768px+) */
@media (min-width: 768px) {
    .values__grid {
        grid-template-columns: repeat(2, 1fr);
        gap: var(--spacing-xl);
    }
}

/* Desktop (1024px+) */
@media (min-width: 1024px) {
    .values {
        padding: var(--spacing-3xl) 0;
    }

    .values__grid {
        grid-template-columns: repeat(3, 1fr);
    }
}
```

---

## Responsive Section Spacing

Section vertical padding should scale with the viewport.

```css
.section {
    padding: var(--spacing-2xl) 0;
}

@media (min-width: 768px) {
    .section {
        padding: var(--spacing-3xl) 0;
    }
}

@media (min-width: 1200px) {
    .section {
        padding: calc(var(--spacing-3xl) * 1.5) 0;
    }
}
```

---

## Responsive Typography Scale

While `clamp()` handles most heading sizes, ensure consistent scaling across the page.

```css
/* Mobile base sizes */
h1 { font-size: clamp(2rem, 5vw, 3.5rem); }
h2 { font-size: clamp(1.5rem, 3.5vw, 2.5rem); }
h3 { font-size: clamp(1.25rem, 2.5vw, 1.75rem); }
h4 { font-size: var(--font-size-lg); }

p {
    font-size: var(--font-size-base);
    line-height: var(--line-height-normal);
}

@media (min-width: 768px) {
    p {
        font-size: var(--font-size-md);
    }
}
```

---

## Responsive Footer

Footers typically use a multi-column grid on desktop and stack on mobile.

```css
.footer__grid {
    display: grid;
    grid-template-columns: 1fr;
    gap: var(--spacing-xl);
}

@media (min-width: 768px) {
    .footer__grid {
        grid-template-columns: repeat(2, 1fr);
    }
}

@media (min-width: 1024px) {
    .footer__grid {
        grid-template-columns: 2fr 1fr 1fr 1fr;
    }
}

.footer__bottom {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: var(--spacing-sm);
    text-align: center;
    padding-top: var(--spacing-xl);
    border-top: 1px solid var(--color-border);
    margin-top: var(--spacing-xl);
}

@media (min-width: 768px) {
    .footer__bottom {
        flex-direction: row;
        justify-content: space-between;
        text-align: left;
    }
}
```
