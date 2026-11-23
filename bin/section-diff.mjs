#!/usr/bin/env node
/**
 * section-diff.mjs: compare one built section against the demo section it came from, pixel by
 * pixel, at the viewports that matter.
 *
 * The parity gate in /wp-finalize compares computed styles; this compares what a visitor sees.
 * It finds the section in the demo by its delimiter (`<!-- SECTION: Hero -->`, the first
 * element after it) and in the built page by the same root class, the BEM block transcription
 * keeps, or by --selector on both. Each side is captured as an element screenshot at the same
 * viewport width, with motion settled (reduced motion, animations and transitions off, AOS
 * content shown), then compared with pixelmatch over the area both captures share. A height
 * difference is reported on its own: comparing past it would only measure the offset.
 *
 * Usage:
 *   section-diff.mjs --demo <demo.html|url> --site <url> --section <name>
 *                    [--selector <css>] [--viewports 390,1440] [--threshold 2]
 *                    [--size-tolerance 5] [--out <dir>] [--json]
 *
 * --threshold is the percent of differing pixels allowed per viewport (default 2: antialiasing
 * and font hinting alone differ between two renders of the same markup). --size-tolerance is
 * the percent the built section's width or height may differ from the demo's (default 5): the
 * pixels are compared over the shared area only, so a section that lost half its width or
 * gained a row is caught here, not there.
 *
 * The built side's selector is the demo root's first class unless --selector is given. When
 * that selector matches more than one element on the built page, the tool stops with exit 4
 * instead of measuring whichever came first.
 *
 * Writes <vw>-demo.png, <vw>-site.png, <vw>-diff.png and report.json to --out (default a new
 * temporary directory, printed). Nothing is downloaded: it drives an existing Chrome.
 *
 * Exit (the COMMON scheme of bin/lib/exit-codes.mjs): 0 every viewport within the tolerances,
 * 1 a viewport is over one of them, 2 nothing measured (no playwright-core, pixelmatch, pngjs
 * or Chrome, or the browser or a page failed: not a visual regression), 4 the section
 * was not found on one side or its selector is ambiguous, 64 usage.
 */
import './lib/stdio-blocking.mjs';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { execFileSync } from 'node:child_process';
import { findBrowser } from './lib/browsers.mjs';

const HELP = 'usage: section-diff.mjs --demo <demo.html|url> --site <url> --section <name> [--selector <css>] [--viewports 390,1440] [--threshold 2] [--size-tolerance 5] [--out <dir>] [--json]';

function parseArgs(argv) {
  const o = { viewports: [390, 1440], threshold: 2, sizeTolerance: 5, json: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    const next = () => {
      if (i + 1 >= argv.length) throw new Error(`${a} needs a value`);
      return argv[++i];
    };
    if (a === '--demo') o.demo = next();
    else if (a === '--site') o.site = next();
    else if (a === '--section') o.section = next();
    else if (a === '--selector') o.selector = next();
    else if (a === '--out') o.out = next();
    else if (a === '--json') o.json = true;
    else if (a === '--threshold') o.threshold = Number(next());
    else if (a === '--size-tolerance') o.sizeTolerance = Number(next());
    else if (a === '--viewports') o.viewports = next().split(',').map((v) => Number(v.trim()));
    else if (a === '--help' || a === '-h') { console.log(HELP); process.exit(0); }
    else throw new Error(`unknown argument ${a}`);
  }
  if (!o.demo || !o.site || (!o.section && !o.selector)) throw new Error('--demo, --site and --section (or --selector) are required');
  if (!/^https?:\/\//.test(o.site)) throw new Error('--site must be an http(s) URL');
  if (!o.viewports.length || o.viewports.some((v) => !Number.isInteger(v) || v < 200 || v > 3840)) throw new Error('--viewports must be widths between 200 and 3840');
  if (!(o.threshold >= 0 && o.threshold <= 100) || !(o.sizeTolerance >= 0)) throw new Error('--threshold is 0-100 and --size-tolerance is >= 0');
  return o;
}

let opts;
try {
  opts = parseArgs(process.argv.slice(2));
} catch (err) {
  console.error(`section-diff: ${err.message}\n${HELP}`);
  process.exit(64);
}
const demoUrl = /^https?:\/\//.test(opts.demo) ? opts.demo : pathToFileURL(resolve(opts.demo)).href;
if (!/^https?:/.test(demoUrl) && !existsSync(resolve(opts.demo))) {
  console.error(`section-diff: ${opts.demo} does not exist`);
  process.exit(64);
}

/** Import a package from bin/'s own tree, the working directory, or the global root. */
async function load(name, entry) {
  if (name === 'playwright-core' && process.env.PLAYWRIGHT_CORE) {
    return import(pathToFileURL(resolve(process.env.PLAYWRIGHT_CORE, 'index.mjs')).href);
  }
  try {
    return await import(name);
  } catch (bare) {
    const roots = [join(process.cwd(), 'node_modules')];
    try {
      roots.push(execFileSync('npm', ['root', '-g'], { encoding: 'utf8', timeout: 5000, stdio: ['ignore', 'pipe', 'ignore'] }).trim());
    } catch { /* no npm */ }
    for (const root of roots) {
      const file = join(root, name, entry);
      if (existsSync(file)) return import(pathToFileURL(file).href);
    }
    throw bare;
  }
}

let chromium, pixelmatch, PNG;
try {
  ({ chromium } = await load('playwright-core', 'index.mjs'));
  pixelmatch = (await load('pixelmatch', 'index.js')).default;
  ({ PNG } = await load('pngjs', 'lib/png.js'));
} catch {
  console.error('section-diff: playwright-core, pixelmatch or pngjs is not installed (npm install in the plugin); nothing measured');
  process.exit(2);
}
const executablePath = findBrowser('chromium');
if (!executablePath) {
  console.error('section-diff: no existing Chrome or Chromium (set WP_BROWSER_CHROMIUM); nothing measured');
  process.exit(2);
}

const out = opts.out ? resolve(opts.out) : mkdtempSync(join(tmpdir(), 'section-diff-'));
mkdirSync(out, { recursive: true });

// Motion off on both sides, equally: what is compared is the settled layout.
const SETTLE_CSS = `*,*::before,*::after{animation:none!important;transition:none!important;caret-color:transparent!important}
[data-aos],[data-motion]{opacity:1!important;transform:none!important}`;

/**
 * In the page: find the section root and tag it. By --selector when given; otherwise the first
 * element after the demo's SECTION delimiter whose name slugifies to the wanted slug. Returns
 * the root's first class (the selector for the built side) or null.
 */
function tagRoot({ section, selector, mark }) {
  const slug = (s) => String(s).toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
  let el = null;
  if (selector) {
    el = document.querySelector(selector);
  } else {
    const walker = document.createTreeWalker(document.documentElement, NodeFilter.SHOW_COMMENT);
    for (let c = walker.nextNode(); c; c = walker.nextNode()) {
      const m = /^\s*=*\s*SECTION\s*:\s*(.*?)\s*=*\s*$/i.exec(c.nodeValue);
      if (!m || slug(m[1]) !== slug(section)) continue;
      let n = c.nextSibling;
      while (n && n.nodeType !== Node.ELEMENT_NODE) n = n.nextSibling;
      el = n;
      break;
    }
  }
  if (!el) return null;
  el.setAttribute(mark, '');
  const derived = el.classList.length ? '.' + CSS.escape(el.classList[0]) : el.tagName.toLowerCase();
  return { derived, matches: selector ? document.querySelectorAll(selector).length : 1 };
}

async function capture(page, url, find, file) {
  const response = await page.goto(url, { waitUntil: 'networkidle', timeout: 45000 });
  if (response && response.status() >= 400) throw new Error(`${url} answered ${response.status()}`);
  await page.addStyleTag({ content: SETTLE_CSS });
  await page.evaluate(() => document.fonts.ready);
  const found = await page.evaluate(tagRoot, find);
  if (found === null) return null;
  if (found.matches > 1) return { ambiguous: found.matches };
  const root = page.locator('[data-section-diff-root]').first();
  await root.scrollIntoViewIfNeeded();
  await page.waitForLoadState('networkidle').catch(() => {});
  await root.screenshot({ path: file, animations: 'disabled' });
  return found.derived;
}

/** Compare two PNG files over their shared area; write the diff image. */
function compare(aFile, bFile, diffFile) {
  const a = PNG.sync.read(readFileSync(aFile));
  const b = PNG.sync.read(readFileSync(bFile));
  const w = Math.min(a.width, b.width);
  const h = Math.min(a.height, b.height);
  const crop = (img) => {
    const o = new PNG({ width: w, height: h });
    for (let y = 0; y < h; y++) img.data.copy(o.data, y * w * 4, y * img.width * 4, y * img.width * 4 + w * 4);
    return o;
  };
  const ca = crop(a);
  const cb = crop(b);
  const diff = new PNG({ width: w, height: h });
  const differing = w && h ? pixelmatch(ca.data, cb.data, diff.data, w, h, { threshold: 0.1 }) : 0;
  writeFileSync(diffFile, PNG.sync.write(diff));
  return {
    demo: { width: a.width, height: a.height },
    site: { width: b.width, height: b.height },
    diffPercent: w && h ? Math.round((differing / (w * h)) * 10000) / 100 : 100,
    heightDeltaPercent: a.height ? Math.round(((b.height - a.height) / a.height) * 10000) / 100 : 100,
    widthDeltaPercent: a.width ? Math.round(((b.width - a.width) / a.width) * 10000) / 100 : 100,
  };
}

const report = { demo: demoUrl, site: opts.site, section: opts.section || null, threshold: opts.threshold, sizeTolerance: opts.sizeTolerance, out, viewports: [] };
let code = 0;
let browser;
try {
  browser = await chromium.launch({ executablePath });
  for (const vw of opts.viewports) {
    const context = await browser.newContext({ viewport: { width: vw, height: 900 }, deviceScaleFactor: 1, reducedMotion: 'reduce', ignoreHTTPSErrors: true });
    const page = await context.newPage();
    const demoPng = join(out, `${vw}-demo.png`);
    const sitePng = join(out, `${vw}-site.png`);
    const mark = 'data-section-diff-root';
    const demoSel = await capture(page, demoUrl, { section: opts.section, selector: opts.selector, mark }, demoPng);
    if (demoSel === null || demoSel.ambiguous) {
      console.error(demoSel === null
        ? `section-diff: section ${opts.selector || opts.section} not found in the demo`
        : `section-diff: ${opts.selector} matches ${demoSel.ambiguous} elements in the demo; pass a selector that matches one`);
      code = 4;
      await context.close();
      break;
    }
    const siteSel = opts.selector || demoSel;
    const found = await capture(page, opts.site, { selector: siteSel, mark }, sitePng);
    await context.close();
    if (found === null || found.ambiguous) {
      console.error(found === null
        ? `section-diff: ${siteSel} not found on ${opts.site} (pass --selector when the built section's root class differs)`
        : `section-diff: ${siteSel} matches ${found.ambiguous} elements on ${opts.site}; pass --selector with one that matches the section only`);
      code = 4;
      break;
    }
    const r = compare(demoPng, sitePng, join(out, `${vw}-diff.png`));
    r.viewport = vw;
    r.selector = siteSel;
    r.pass = r.diffPercent <= opts.threshold
      && Math.abs(r.heightDeltaPercent) <= opts.sizeTolerance
      && Math.abs(r.widthDeltaPercent) <= opts.sizeTolerance;
    if (!r.pass) code = 1;
    report.viewports.push(r);
  }
} catch (err) {
  // A browser that will not start or a page that fails to load measured nothing: that is not
  // a visual regression, and a gate reading exit 1 must not take it for one.
  console.error(`section-diff: ${err.message.split('\n')[0]} (nothing measured)`);
  code = code === 1 ? 1 : 2; // a regression already measured stays the result
} finally {
  if (browser) await browser.close().catch(() => {});
}
report.pass = code === 0;
writeFileSync(join(out, 'report.json'), JSON.stringify(report, null, 2) + '\n');
if (opts.json) {
  console.log(JSON.stringify(report));
} else {
  for (const r of report.viewports) {
    const sign = (v) => (v >= 0 ? '+' : '') + v;
    console.log(`${r.pass ? 'PASS' : 'FAIL'} ${r.viewport}px ${r.selector}: ${r.diffPercent}% of pixels differ (max ${opts.threshold}%), width ${sign(r.widthDeltaPercent)}%, height ${sign(r.heightDeltaPercent)}% (max ±${opts.sizeTolerance}%)`);
  }
  console.log(`images and report.json: ${out}`);
}
process.exitCode = code;
