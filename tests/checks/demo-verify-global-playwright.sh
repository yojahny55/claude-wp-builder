#!/usr/bin/env bash
# Defect: bin/demo-verify.mjs resolved playwright-core only from PLAYWRIGHT_CORE, a bare
# import from bin/, and the cwd's node_modules. With Playwright installed only globally
# (`npm i -g @playwright/test`) the probe printed "missing playwright-core" and exited 2,
# although a working copy sat under `npm root -g`. Behavior test: a fake `npm` reports a
# fake global root holding a stub playwright-core; the probe must import it.
set -u
root="$(cd "$(dirname "$0")/../.." && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

if [ -d "$root/node_modules/playwright-core" ] || [ -d "$root/../node_modules/playwright-core" ]; then
  echo "SKIP: a playwright-core above bin/ would satisfy the bare import and hide the fallback"
  exit 0
fi

mkdir -p "$tmp/bin" "$tmp/cwd" "$tmp/groot/@playwright/test/node_modules/playwright-core"
cat > "$tmp/bin/npm" <<NPM
#!/bin/sh
[ "\$1" = root ] && [ "\$2" = -g ] && echo "$tmp/groot"
NPM
chmod +x "$tmp/bin/npm"
cat > "$tmp/groot/@playwright/test/node_modules/playwright-core/index.mjs" <<STUB
import { writeFileSync } from 'node:fs';
writeFileSync('$tmp/imported', 'yes');
export const chromium = { launch() {} };
export const firefox = { launch() {} };
STUB

out="$(cd "$tmp/cwd" && env -u PLAYWRIGHT_CORE PATH="$tmp/bin:$PATH" \
  WP_DEMO_CHROME="$tmp/nonexistent-chrome" node "$root/bin/demo-verify.mjs" --probe 2>&1)"

fail=0
case "$out" in *"missing playwright-core"*) echo "FAIL: probe did not find the global playwright-core: $out"; fail=1;; esac
[ -f "$tmp/imported" ] || { echo "FAIL: the global playwright-core was never imported"; fail=1; }

# PLAYWRIGHT_CORE must still skip the ladder: a bogus value is exit 2, not the global copy.
rm -f "$tmp/imported"
(cd "$tmp/cwd" && PLAYWRIGHT_CORE="$tmp/bogus" PATH="$tmp/bin:$PATH" node "$root/bin/demo-verify.mjs" --probe >/dev/null 2>&1)
[ $? -eq 2 ] && [ ! -f "$tmp/imported" ] || { echo "FAIL: PLAYWRIGHT_CORE no longer forces the failure path"; fail=1; }

[ "$fail" = 0 ] && echo "PASS: demo-verify-global-playwright"
exit "$fail"
