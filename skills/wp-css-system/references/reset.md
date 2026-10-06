# CSS Reset

From the `wp-css-system` skill: the reset every `Template: basic` stylesheet and plain demo
opens with, right after the `:root` tokens. Every selector in it is bare — a single type
selector, (0,0,1) — so any class on the element beats it. The skill's "Never scope a reset"
and "A reset class loses to nothing" rules say why that matters; keep it that way.

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
