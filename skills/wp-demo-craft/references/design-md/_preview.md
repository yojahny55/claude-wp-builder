---
version: alpha
name: wp-demo-craft-preview
description: "Neutral reference used only to render composition previews. Cool off-black canvas, bone ink, one desaturated blue accent, Archivo display over Source Sans 3 text. Not a brand; never copied into a client DESIGN.md."

colors:
  canvas: "#0e1116"
  surface: "#161b22"
  ink: "#e8e6df"
  ink-soft: "#a4a89f"
  accent: "#4f8fd9"
  accent-ink: "#0b1420"
  hairline: "#2a313b"

typography:
  display:
    fontFamily: Archivo
    fontSize: 64px
    fontWeight: 700
    lineHeight: 1.0
    letterSpacing: -1.6px
  text:
    fontFamily: Source Sans 3
    fontSize: 18px
    fontWeight: 400
    lineHeight: 1.6
    letterSpacing: 0px

rounded:
  sm: 4px
  md: 10px

spacing:
  base: 4px
  section: "clamp(4rem, 10vw, 9rem)"
  gutter: "clamp(1rem, 4vw, 3rem)"
  container: "1440px"
---

## Token contract

Every composition's CSS uses exactly these custom properties and no others for
colour and type: `--color-canvas`, `--color-surface`, `--color-ink`,
`--color-ink-soft`, `--color-accent`, `--color-accent-ink`, `--color-hairline`,
`--font-display`, `--font-text`, `--space-section`, `--space-gutter`,
`--container-max`, `--radius-sm`, `--radius-md`. A client `demo/DESIGN.md` maps its
own tokens onto these names in the demo's `:root`.
