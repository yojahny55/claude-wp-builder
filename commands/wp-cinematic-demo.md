---
name: wp-cinematic-demo
description: Generate (or regenerate) the cinematic HTML demo for client approval. Wraps the kit's `cinematic-site` skill but emits to `<theme>/demo/` with the same `<!-- SECTION: -->` delimiters the rest of the plugin uses, so the demo can be polished with `/wp-polish` and audited with `/wp-responsive-check` like any other plugin demo.
arguments:
  - name: --scenes
    description: Scene count (default 9)
    required: false
  - name: --hybrid
    description: Append a trailing sections block (default yes)
    required: false
  - name: --brand
    description: Path to a brand brief (markdown) to drive editorial copy
    required: false
---

# /wp-cinematic-demo

Produces a self-contained, scroll-driven demo HTML at `<theme>/demo/index.html` plus `demo/assets/{css,js,videos,posters}/`. The demo is what you send the client for approval BEFORE wiring WordPress.

### Step 0.5: Read the craft layer

Read `${CLAUDE_PLUGIN_ROOT}/skills/wp-demo-craft/SKILL.md` and its `taste.md`,
`feel.md` and `fingerprint.md` first. They set the design floor, the refuse
list, the feeling curve with one engineered peak, and the fingerprint gate
that apply to a cinematic demo exactly as they do to a static one. The kit's
own skills supply the video-specific rules on top: scene encoding, the scrub
engine, mobile substitution.

Where the two disagree, the craft layer wins on design and the kit wins on
video. Scene numbers in HUD labels are optional here, not required: a
`01 / 06` counter is on the refuse list unless the sequence information is
something the reader needs.

## Pipeline

1. Resolve kit path (same logic as `/wp-cinematic-init` step 0).
2. Invoke kit skill `04-build-cinematic-scroll-site`:
   ```
   skill: 04-build-cinematic-scroll-site
   args:
     scenes: <N>
     out_dir: <theme>/demo
     brand_brief: <--brand path or empty>
     hybrid: <true|false>
   ```
3. Kit emits raw demo (its native `templates/index.html`, `main.js`, `style.css` skeleton).
4. **Post-process** for plugin compatibility:
   - Wrap each scene with `<!-- SECTION: scene-N -->` ... `<!-- END SECTION -->` delimiters so `/wp-section` and `/wp-polish` recognize them.
   - Wrap trailing blocks with `<!-- SECTION: pricing -->`, `<!-- SECTION: contact -->`, etc.
   - Inject the standard `<!-- DEMO: name=cinematic, archetype=cinematic-scroll, hybrid=true -->` header comment so `/wp-init` demo-first detection picks it up.
5. If `--brand` provided, dispatch kit skill `01-narrative-from-brand` first; pipe its narrative into `02-storyboard-from-narrative`; feed the storyboard scenes into the demo generator (instead of placeholders).
6. Generate placeholder videos by symlinking the kit's sample reels into `demo/assets/videos/` (do NOT copy — saves disk).
7. Open `demo/index.html` in the user's browser via `wp-open` helper, or print the file:// path.

## Output structure

```
demo/
├── index.html                   # delimited demo
├── assets/
│   ├── css/style.css            # adapted from kit templates/style.css
│   ├── js/main.js               # adapted from kit templates/main.js
│   ├── videos/
│   │   ├── scene-1.mp4          # symlink to kit sample OR user-provided
│   │   ├── scene-1.mobile.mp4
│   │   └── …
│   └── posters/
│       ├── scene-1.jpg
│       └── …
└── README.md                    # how to preview, what to replace
```

## Demo → WP handoff

When the user runs `/wp-cinematic-init` after approval, the demo's scene blocks are read by the `wp-cinematic` agent and used to populate ACF defaults (eyebrow, headline, body, cta_label) so the seed script reflects what the client already saw.

## Related

- Verify the built demo with `/wp-demo-verify demo/index.html` before sending it for approval; it treats each scene section as a sample of the stage canvas, so a frozen clip gets reported instead of shipped.
- `/wp-cinematic-encode` to swap placeholder videos for real ones
- `/wp-polish` to normalize delimiters if a 3rd-party authored the demo
