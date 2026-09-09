#!/usr/bin/env node
/**
 * composition-preview.mjs: render one composition to preview-1440.png and
 * preview-390.png using the neutral _preview.md tokens and the plugin's own
 * motion engine, scrolled to the section's settled/arrived state.
 *
 * usage: composition-preview.mjs <composition-dir>   exit 0 ok, 2 no browser, 3 crash
 */
import { existsSync, readFileSync, writeFileSync, mkdtempSync, readdirSync, rmSync } from 'node:fs';
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

/** One required scalar out of _preview.md's front matter. Throws, naming the key,
 *  rather than degrading to an empty string a reformatted file would hide. */
function pick(fm, key, re) {
  const m = fm.match(re);
  if (!m) throw new Error('_preview.md is missing the token: ' + key);
  return m[1];
}

/** Every scalar composition CSS is allowed to depend on, out of _preview.md's front
 *  matter — regexes over the raw text, no YAML dependency. */
function previewTokens() {
  const src = readFileSync(join(root, 'skills/wp-demo-craft/references/design-md/_preview.md'), 'utf8');
  const fm = src.split('---')[1] || '';
  const p = (key, re) => pick(fm, key, re);
  return {
    canvas: p('canvas', /\n  canvas: "([^"]+)"/), surface: p('surface', /\n  surface: "([^"]+)"/),
    ink: p('ink', /\n  ink: "([^"]+)"/), inkSoft: p('ink-soft', /\n  ink-soft: "([^"]+)"/),
    accent: p('accent', /\n  accent: "([^"]+)"/), accentInk: p('accent-ink', /\n  accent-ink: "([^"]+)"/),
    hairline: p('hairline', /\n  hairline: "([^"]+)"/),
    display: p('display.fontFamily', /\n  display:\n    fontFamily: ([^\n]+)/),
    text: p('text.fontFamily', /\n  text:\n    fontFamily: ([^\n]+)/),
    section: p('spacing.section', /\n  section: "([^"]+)"/), gutter: p('spacing.gutter', /\n  gutter: "([^"]+)"/),
    rsm: p('rounded.sm', /\n  sm: ([^\n]+)/), rmd: p('rounded.md', /\n  md: ([^\n]+)/),
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

// playwright-core resolution ladder, the same house pattern demo-verify.mjs uses for
// its own import/findChrome ladder: PLAYWRIGHT_CORE lets the check suite force the
// no-browser path deterministically; the bare specifier resolves from this file's own
// location in bin/, never the WordPress project the plugin is invoked from, so a
// project-local `npm i -D playwright-core` needs the cwd fallback to be found at all.
let chromium;
try {
  if (process.env.PLAYWRIGHT_CORE) {
    ({ chromium } = await import(pathToFileURL(resolve(process.env.PLAYWRIGHT_CORE, 'index.mjs')).href));
  } else {
    try {
      ({ chromium } = await import('playwright-core'));
    } catch (bare) {
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

/** "Source Sans 3" -> "Source+Sans+3", the Google Fonts css2 family param form. */
const fontParam = (name) => name.trim().split(/\s+/).join('+');

// Everything below is real render work: a missing/unreadable _preview.md or motion.js,
// an unwritable temp dir, a failed CDN load or a page crash must all land on exit 3, not
// Node's default 1 — so none of it runs outside this try, and exit 2 stays reserved for
// the browser checks above, which already returned before this point.
let browser;
let work;
let code = 0;
try {
  const t = previewTokens();
  const motion = readFileSync(join(root, 'starter-theme/__tailwind__/assets/js/src/motion.js'), 'utf8');
  const fontsHref =
    'https://fonts.googleapis.com/css2?family=' + fontParam(t.display) + ':wght@700' +
    '&family=' + fontParam(t.text) + ':wght@400&display=swap';
  const page = `<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<link rel="stylesheet" href="${fontsHref}">
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

  work = mkdtempSync(join(tmpdir(), 'wp-comp-'));
  const file = join(work, 'index.html');
  writeFileSync(file, page);

  browser = await chromium.launch({ executablePath });
  for (const [w, h] of [[1440, 900], [390, 844]]) {
    const ctx = await browser.newContext({ viewport: { width: w, height: h } });
    const p = await ctx.newPage();
    await p.goto(pathToFileURL(file).href, { waitUntil: 'load' });
    await p.waitForTimeout(300);

    // waitUntil: 'load' resolves once the CDN requests settle, success or not, and
    // initMotion() is a silent no-op without both globals — so a blocked CDN would
    // otherwise produce a correctly styled but entirely unanimated preview at exit 0.
    const enginesOk = await p.evaluate(() => Boolean(window.gsap && window.ScrollTrigger));
    if (!enginesOk) throw new Error('GSAP/ScrollTrigger failed to load from cdnjs.cloudflare.com');

    // A missing display face changes line-wrapping, which is exactly the layout
    // judgment a preview exists to support — worth a warning, not a failed render.
    await p.evaluate(() => document.fonts.ready);
    // initMotion() runs before the webfonts swap in, so ScrollTrigger cached every
    // start/end against fallback metrics; a swap that reflows a pinned section leaves
    // those positions stale and the step-scroll below drives the wrong range.
    await p.evaluate(() => window.ScrollTrigger.refresh());
    const fontOk = await p.evaluate((face) => document.fonts.check('700 16px "' + face + '"'), t.display);
    if (!fontOk) console.error('composition-preview: display font did not load from Google Fonts: ' + t.display);

    // Step-scroll from the top to the bottom in six increments so every `once` device
    // (reveal, kinetic, count) fires and every scrub device (pin, pan, wipe, parallax,
    // the shared --motion-p driver) is driven across its full range at least once.
    const docMax = await p.evaluate(() => Math.max(0, document.documentElement.scrollHeight - window.innerHeight));
    for (let i = 0; i < 6; i++) {
      await p.evaluate((y) => window.scrollTo(0, y), Math.round((docMax * i) / 5));
      await p.waitForTimeout(250);
    }

    // The arrived frame, not the opening one: a scrub device is tied continuously to
    // scroll position with no memory of having been visited, so a shot taken back at
    // scroll 0 shows the unanimated look — the bug this replaces. A section no taller
    // than the viewport gets its top pinned to the viewport top; a taller (pinned or
    // panned) section gets its bottom pinned to the viewport bottom, so the frame
    // shows the arrived state rather than the opening one. Measuring the outer
    // data-motion element (never the inner sticky frame) keeps top + scrollY equal to
    // its true document-space position regardless of current scroll.
    const rect = await p.evaluate(() => {
      const el = document.querySelector('[data-motion], section') || document.body.firstElementChild;
      if (!el) return null;
      const r = el.getBoundingClientRect();
      return { top: r.top + window.scrollY, height: r.height };
    });
    if (rect) {
      const target = rect.height <= h ? rect.top : rect.top + rect.height - h;
      await p.evaluate((y) => window.scrollTo(0, y), Math.min(docMax, Math.max(0, Math.round(target))));
      await p.waitForTimeout(250);
    }

    // fullPage: false, deliberately: every preview then comes out exactly the
    // requested width x height, which is what makes a set of them comparable side by
    // side. A full-page shot of a 200vh pinned section is a tall image of a sticky
    // element rendered once — worse than useless.
    await p.screenshot({ path: join(dir, 'preview-' + w + '.png'), fullPage: false });
    await ctx.close();
  }
  console.log('composition-preview: wrote previews in ' + dir);
} catch (err) {
  console.error('composition-preview: crashed:', err && err.stack ? err.stack : err);
  code = 3;
} finally {
  if (browser) await browser.close().catch(() => {});
  // Task 4 loops this over twelve compositions; an unremoved mkdtempSync dir per run
  // leaks twelve scratch directories per pass, success or failure alike.
  if (work) { try { rmSync(work, { recursive: true, force: true }); } catch { /* best effort */ } }
}
process.exit(code);
