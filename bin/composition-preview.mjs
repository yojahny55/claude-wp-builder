#!/usr/bin/env node
/**
 * composition-preview.mjs: render one composition to preview-1440.png and
 * preview-390.png using the neutral _preview.md tokens and the plugin's own
 * motion engine, scrolled to the section's settled state.
 *
 * usage: composition-preview.mjs <composition-dir>   exit 0 ok, 2 no browser, 3 crash
 */
import { existsSync, readFileSync, writeFileSync, mkdtempSync, readdirSync } from 'node:fs';
import { resolve, join, dirname } from 'node:path';
import { tmpdir, homedir } from 'node:os';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '..');
const dir = resolve(process.argv[2] || '.');
const html = join(dir, 'section.html');
const css = join(dir, 'section.css');
if (!existsSync(html) || !existsSync(css)) {
  console.error('composition-preview: ' + dir + ' has no section.html/section.css');
  process.exit(3);
}

/** Read the front-matter scalars we need out of _preview.md without a YAML dep. */
function previewTokens() {
  const src = readFileSync(join(root, 'skills/wp-demo-craft/references/design-md/_preview.md'), 'utf8');
  const fm = src.split('---')[1] || '';
  const pick = (re) => (fm.match(re) || [])[1] || '';
  return {
    canvas: pick(/\n  canvas: "([^"]+)"/), surface: pick(/\n  surface: "([^"]+)"/),
    ink: pick(/\n  ink: "([^"]+)"/), inkSoft: pick(/\n  ink-soft: "([^"]+)"/),
    accent: pick(/\n  accent: "([^"]+)"/), accentInk: pick(/\n  accent-ink: "([^"]+)"/),
    hairline: pick(/\n  hairline: "([^"]+)"/),
    display: pick(/\n  display:\n    fontFamily: ([^\n]+)/), text: pick(/\n  text:\n    fontFamily: ([^\n]+)/),
    section: pick(/\n  section: "([^"]+)"/), gutter: pick(/\n  gutter: "([^"]+)"/),
    rsm: pick(/\n  sm: ([^\n]+)/), rmd: pick(/\n  md: ([^\n]+)/),
  };
}

function findChrome() {
  if (process.env.WP_DEMO_CHROME && existsSync(process.env.WP_DEMO_CHROME)) return process.env.WP_DEMO_CHROME;
  for (const c of ['/usr/bin/google-chrome', '/usr/bin/google-chrome-stable', '/usr/bin/chromium', '/usr/bin/chromium-browser',
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome']) if (existsSync(c)) return c;
  for (const cache of [join(homedir(), '.cache/ms-playwright'), join(homedir(), 'Library/Caches/ms-playwright')]) {
    if (!existsSync(cache)) continue;
    for (const entry of readdirSync(cache))
      for (const tail of ['chrome-linux64/chrome', 'chrome-linux/chrome', 'chrome-mac/Chromium.app/Contents/MacOS/Chromium']) {
        const p = join(cache, entry, tail);
        if (existsSync(p)) return p;
      }
  }
  return null;
}

// PLAYWRIGHT_CORE lets the check suite force the no-browser path, mirroring
// demo-verify.mjs's own gate: a bogus value must exit 2, never crash.
let chromium;
try {
  if (process.env.PLAYWRIGHT_CORE) {
    ({ chromium } = await import(pathToFileURL(resolve(process.env.PLAYWRIGHT_CORE, 'index.mjs')).href));
  } else {
    try {
      ({ chromium } = await import('playwright-core'));
    } catch (bare) {
      // A bare specifier resolves from this file's own location (bin/), never the
      // WordPress project's node_modules; fall back to the cwd before giving up.
      const cwdEntry = join(process.cwd(), 'node_modules', 'playwright-core', 'index.mjs');
      if (!existsSync(cwdEntry)) throw bare;
      ({ chromium } = await import(pathToFileURL(cwdEntry).href));
    }
  }
} catch {
  console.error('composition-preview: playwright-core is not installed (npm i -D playwright-core)');
  process.exit(2);
}
const executablePath = findChrome();
if (!executablePath) {
  console.error('composition-preview: no Chrome found. Set WP_DEMO_CHROME or run: npx playwright install chrome');
  process.exit(2);
}

const t = previewTokens();
const motion = readFileSync(join(root, 'starter-theme/__tailwind__/assets/js/src/motion.js'), 'utf8');
const page = `<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
:root{--color-canvas:${t.canvas};--color-surface:${t.surface};--color-ink:${t.ink};--color-ink-soft:${t.inkSoft};
--color-accent:${t.accent};--color-accent-ink:${t.accentInk};--color-hairline:${t.hairline};
--font-display:"${t.display}",system-ui,sans-serif;--font-text:"${t.text}",system-ui,sans-serif;
--space-section:${t.section};--space-gutter:${t.gutter};--radius-sm:${t.rsm};--radius-md:${t.rmd}}
html{background:var(--color-canvas);color:var(--color-ink);font-family:var(--font-text)}body{margin:0}
${readFileSync(css, 'utf8')}
</style></head><body>
${readFileSync(html, 'utf8')}
<script src="https://cdnjs.cloudflare.com/ajax/libs/gsap/3.13.0/gsap.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/gsap/3.13.0/ScrollTrigger.min.js"></script>
<script type="module">${motion}
initMotion(window.gsap, window.ScrollTrigger);</script>
</body></html>`;

const work = mkdtempSync(join(tmpdir(), 'wp-comp-'));
const file = join(work, 'index.html');
writeFileSync(file, page);

let browser; let code = 0;
try {
  browser = await chromium.launch({ executablePath });
  for (const [w, h] of [[1440, 900], [390, 844]]) {
    const ctx = await browser.newContext({ viewport: { width: w, height: h } });
    const p = await ctx.newPage();
    await p.goto(pathToFileURL(file).href, { waitUntil: 'load' });
    await p.waitForTimeout(500);
    // Settle every scroll device: walk to the bottom and back to the top of the section.
    await p.evaluate(() => window.scrollTo(0, document.documentElement.scrollHeight));
    await p.waitForTimeout(400);
    await p.evaluate(() => window.scrollTo(0, 0));
    await p.waitForTimeout(400);
    await p.screenshot({ path: join(dir, 'preview-' + w + '.png'), fullPage: true });
    await ctx.close();
  }
  console.log('composition-preview: wrote previews in ' + dir);
} catch (err) {
  console.error('composition-preview: crashed:', err && err.stack ? err.stack : err);
  code = 3;
} finally {
  if (browser) await browser.close().catch(() => {});
}
process.exit(code);
