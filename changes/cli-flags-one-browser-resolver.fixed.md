- `bin/wp-config.mjs` refuses a flag it does not know instead of ignoring it. `adopt`,
  `code-home`, `env-set`, `git-init`, `keep-inactive` and `require-origin` each name the
  flags they accept; a typo (`adopt --replce`), a space instead of `=` (`--branch main`) or
  an uppercase name now exits 1 with the flag named and nothing done, where it used to run
  as if the flag had never been passed.
- `demo-verify`, `composition-preview` and `tailwindify-parity` resolve Chromium through
  `bin/lib/browsers.mjs` like every other tool, so they prefer the revision playwright-core
  pins over the system Chrome and read `WP_BROWSER_CHROMIUM`. `WP_DEMO_CHROME` is still
  honoured as its older name when it points at an executable.
