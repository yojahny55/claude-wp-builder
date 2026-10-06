# CSS Patterns

Worked examples for `template=basic` themes, from the `wp-css-system` skill. They use
the tokens in `tokens.md` and the BEM rules in the skill itself.

## Contents

- BEM Real-World Examples
- Container
- Section Spacing
- Grid Layout
- Flexbox Row
- Card Component
- Section Title Pattern

## BEM Real-World Examples

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

/* The outline variant: the contour is an inset shadow, never a border on a transparent
   background (SKILL.md, "Contours That Render the Same in Every Engine"). */
.btn--outline {
    background: transparent;
    color: var(--color-primary);
    box-shadow: inset 0 0 0 1px var(--color-primary);
}

.btn--outline:hover {
    background: var(--color-primary);
    color: var(--color-text-inverse);
}

.btn--large {
    padding: var(--spacing-md) var(--spacing-xl);
    font-size: var(--font-size-lg);
}
```

## Container

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

## Section Spacing

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

## Grid Layout

Mobile first: one column at the base, more at a `min-width` step.

```css
.services__grid {
    display: grid;
    grid-template-columns: 1fr;
    gap: var(--spacing-xl);
}

@media (min-width: 768px) {
    .services__grid {
        grid-template-columns: repeat(3, 1fr);
    }
}
```

## Flexbox Row

```css
.header__inner {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--spacing-lg);
}
```

## Card Component

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

## Section Title Pattern

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
