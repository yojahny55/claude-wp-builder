- **A11y fixes are measured by scope and state.** The tag-swap comparison now also covers
  `:hover`, `:focus-visible`, dark mode and every element sharing the class. A global colour
  fix must use the narrowest selector and be measured on light, dark, text over an overlay,
  hover and focus; the theme-switch attribute is located on `<html>` or `<body>` before
  writing a `:not()` guard, with transitions off. `wp-css-system` gains a section on
  end-of-sheet overrides. Before, a broad override could repaint overlay cards and a
  `:not([data-theme])` guard could silently never exclude dark mode.
