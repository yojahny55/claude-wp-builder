- **`bin/section-diff.mjs` compares a built section with its demo, pixel by pixel.** The
  parity gate compared computed styles only. The tool finds the section in the demo by its
  delimiter and in the built page by the same root class, captures both per viewport with
  motion settled, compares them with pixelmatch over the shared area, checks the width and
  height difference on their own, and writes demo, site and diff images. Exit `1` over a
  tolerance, `2` with no browser, `3` when the section is missing or its selector ambiguous,
  `4` when a page fails to load.
