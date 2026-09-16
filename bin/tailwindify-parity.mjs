#!/usr/bin/env node
/**
 * tailwindify-parity.mjs: prove a Tailwind conversion did not lose a declaration.
 *
 * `/wp-tailwindify` rewrites a plain-CSS demo page into utility classes and moves
 * the original aside. Step 4 then checks the STRUCTURE of the result — delimiters
 * kept, no `<style>` block, no project stylesheet `<link>` — and nothing checks
 * what it RENDERS. That gap is not theoretical. A demo whose reset read
 *
 *     button{font:inherit;color:inherit;background:none;border:0;padding:0;cursor:pointer}
 *
 * converted with the whole line dropped as "preflight covers it". Preflight covers
 * five of those six declarations and NOT `cursor`: Tailwind v4 leaves buttons on
 * the UA default, which is `default`. Every button on the site lost its pointer —
 * and because every later gate compares the build against the CONVERTED demo, the
 * loss was invisible to all of them. The converted page is the source of truth
 * downstream, so a defect introduced here is inherited by everything, permanently,
 * and no check in the pipeline is looking the other way.
 *
 * The two files use different class systems, so they cannot be joined on selectors.
 * They render the same words, so this joins leaf elements on tag + text and
 * compares computed styles on the pairs.
 *
 * usage:
 *   tailwindify-parity.mjs <converted.html|dir> --against <original.html|dir>
 *                          [--widths 1440x900,390x844] [--json OUT]
 *
 * exit 0 clean · 1 deltas found · 2 no usable browser · 3 the run itself crashed
 */
import { existsSync, readdirSync, statSync, createReadStream, readFileSync, realpathSync, writeFileSync, mkdirSync } from 'node:fs';
import { resolve, join, dirname, extname, normalize, sep, basename } from 'node:path';
import { homedir } from 'node:os';
import { pathToFileURL } from 'node:url';
import { createServer } from 'node:http';

const args = process.argv.slice(2);
if (args.includes('--help') || !args.length) {
  console.log(
    'usage: tailwindify-parity.mjs <converted.html|dir> --against <original.html|dir>\n' +
    '                              [--widths 1440x900,390x844] [--json OUT]'
  );
  process.exit(0);
}
const opt = (name, dflt) => {
  const i = args.indexOf(name);
  return i === -1 || i === args.length - 1 ? dflt : args[i + 1];
};
const VALUE_FLAGS = new Set(['--against', '--widths', '--json']);
const positional = args.filter((a, i) => !a.startsWith('--') && !VALUE_FLAGS.has(args[i - 1]));

const converted = resolve(positional[0] || 'demo/index.html');
const against = opt('--against', '');
if (!against) { console.error('tailwindify-parity: --against is required'); process.exit(3); }
const original = resolve(against);
for (const p of [converted, original]) {
  if (!existsSync(p)) { console.error('tailwindify-parity: no such path: ' + p); process.exit(3); }
}
const explicitWidths = opt('--widths', '1440x900,390x844')
  .split(',')
  .map((s) => s.split('x').map(Number))
  .filter((p) => p.length === 2 && p.every(Number.isFinite));

/* An off-by-one at a converted breakpoint (Tailwind's `max-*` is EXCLUSIVE; a
 * plain-CSS demo's `max-width: Npx` is INCLUSIVE) is invisible everywhere except AT
 * N itself — 1440 and 390 never land on it. Read every `max-width`/`min-width`
 * value out of the ORIGINAL's own CSS and sample those exact pixel widths too, on
 * top of whatever `--widths` asked for. */
function collectBreakpoints(root) {
  const found = new Set();
  const walk = (dir) => {
    let entries;
    try { entries = readdirSync(dir); } catch { return; }
    for (const entry of entries) {
      const p = join(dir, entry);
      let st;
      try { st = statSync(p); } catch { continue; }
      if (st.isDirectory()) { walk(p); continue; }
      if (!entry.toLowerCase().endsWith('.css')) continue;
      let css;
      try { css = readFileSync(p, 'utf8'); } catch { continue; }
      for (const m of css.matchAll(/m(?:in|ax)-width\s*:\s*(\d+(?:\.\d+)?)px/gi)) {
        const n = Math.round(parseFloat(m[1]));
        if (n > 0 && n <= 3000) found.add(n);
      }
    }
  };
  walk(root);
  return [...found].sort((a, b) => a - b);
}

/* Properties chosen because each one is a declaration a conversion can silently
 * drop while the page still looks built. `cursor` is the one that started this. */
const PROPS = [
  'fontFamily', 'fontSize', 'fontWeight', 'lineHeight', 'letterSpacing', 'fontStyle',
  'textTransform', 'textDecorationLine', 'color', 'backgroundColor', 'cursor',
  'borderRadius', 'textAlign', 'whiteSpace',
];

const MIME = { '.html': 'text/html', '.css': 'text/css', '.js': 'text/javascript',
  '.mjs': 'text/javascript', '.json': 'application/json', '.png': 'image/png',
  '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.svg': 'image/svg+xml',
  '.webp': 'image/webp', '.woff2': 'font/woff2', '.avif': 'image/avif' };

/** Serve `root` on an ephemeral port. file:// blocks module scripts and relative
 *  asset loads, neither of which is a defect in the page under test. */
const serve = (root) => new Promise((ready, fail) => {
  const base = realpathSync(root);
  const server = createServer((req, res) => {
    let file;
    try {
      const rel = normalize(decodeURIComponent(req.url.split('?')[0]))
        .replace(/^(\.\.[/\\])+/, '')
        .replace(/^[/\\]+/, '');
      file = realpathSync(resolve(base, rel));
      if (file !== base && !file.startsWith(base + sep)) return res.writeHead(404).end();
      if (statSync(file).isDirectory()) return res.writeHead(403).end();
    } catch (err) { return res.writeHead(err instanceof URIError ? 400 : 404).end(); }
    res.writeHead(200, { 'content-type': MIME[extname(file).toLowerCase()] || 'application/octet-stream' });
    createReadStream(file).pipe(res);
  });
  server.once('error', fail);
  server.listen(0, '127.0.0.1', () => {
    server.removeListener('error', fail);
    ready({ server, port: server.address().port });
  });
});

function findChrome() {
  if (process.env.WP_DEMO_CHROME && existsSync(process.env.WP_DEMO_CHROME)) return process.env.WP_DEMO_CHROME;
  const win = process.platform === 'win32';
  const candidates = win
    ? [join(process.env.PROGRAMFILES || 'C:\\Program Files', 'Google\\Chrome\\Application\\chrome.exe'),
       join(process.env['PROGRAMFILES(X86)'] || 'C:\\Program Files (x86)', 'Google\\Chrome\\Application\\chrome.exe'),
       process.env.LOCALAPPDATA ? join(process.env.LOCALAPPDATA, 'Google\\Chrome\\Application\\chrome.exe') : null]
    : ['/usr/bin/google-chrome', '/usr/bin/google-chrome-stable', '/usr/bin/chromium',
       '/usr/bin/chromium-browser', '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'];
  for (const c of candidates) if (c && existsSync(c)) return c;
  const cacheRoots = win
    ? [join(process.env.LOCALAPPDATA || homedir(), 'ms-playwright')]
    : [join(homedir(), '.cache/ms-playwright'), join(homedir(), 'Library/Caches/ms-playwright')];
  const tails = win
    ? ['chrome-win\\chrome.exe']
    : ['chrome-linux64/chrome', 'chrome-linux/chrome', 'chrome-mac/Chromium.app/Contents/MacOS/Chromium'];
  for (const cache of cacheRoots) {
    if (!existsSync(cache)) continue;
    for (const entry of readdirSync(cache)) {
      for (const tail of tails) {
        const p = join(cache, entry, tail);
        if (existsSync(p)) return p;
      }
    }
  }
  return null;
}

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
  console.error('tailwindify-parity: playwright-core is not installed (npm i -D playwright-core)');
  process.exit(2);
}
const executablePath = findChrome();
if (!executablePath) {
  console.error('tailwindify-parity: no Chrome found. Set WP_DEMO_CHROME or run: npx playwright install chrome');
  process.exit(2);
}

/* Pair the pages by file name. A directory on both sides compares every page
 * present on both; a file on both sides compares just that pair. */
const isDir = (p) => statSync(p).isDirectory();
const htmlIn = (d) => readdirSync(d).filter((f) => f.endsWith('.html')).sort();
let names;
if (isDir(converted) && isDir(original)) {
  const have = new Set(htmlIn(original));
  names = htmlIn(converted).filter((f) => have.has(f));
  const only = htmlIn(converted).filter((f) => !have.has(f));
  if (only.length) console.log('note: no original for ' + only.join(', '));
} else if (!isDir(converted) && !isDir(original)) {
  names = null; // single explicit pair, handled below
} else {
  console.error('tailwindify-parity: compare a file with a file, or a directory with a directory');
  process.exit(3);
}
const cRoot = isDir(converted) ? converted : dirname(converted);
const oRoot = isDir(original) ? original : dirname(original);

const autoBreakpoints = collectBreakpoints(oRoot);
const widths = [...explicitWidths];
const haveWidth = new Set(widths.map(([w]) => w));
for (const bw of autoBreakpoints) {
  if (haveWidth.has(bw)) continue;
  haveWidth.add(bw);
  widths.push([bw, bw >= 700 ? 900 : 844]);
}
if (autoBreakpoints.length) {
  console.log(
    `tailwindify-parity: also sampling ${autoBreakpoints.length} breakpoint width(s) ` +
    `found in the original CSS: ${autoBreakpoints.join(', ')}`
  );
}

/* ONE server, rooted at the common ancestor of the two trees, and pages
 * addressed by their path relative to it.
 *
 * Two roots looked simpler and silently broke the comparison: `/wp-tailwindify`
 * archives the original as `demo/.original/`, whose `css`, `js` and `assets` are
 * SYMLINKS back up to the demo folder. A server rooted at `.original/` refuses
 * them — correctly, since following a symlink out of the document root is how a
 * page under test reads arbitrary local files — so every original page rendered
 * with no CSS at all and the run reported hundreds of deltas, all of them the
 * harness's own doing. Sharing a root puts the symlink targets inside it. */
const commonRoot = (() => {
  const a = realpathSync(cRoot).split(sep);
  const b = realpathSync(oRoot).split(sep);
  const out = [];
  for (let i = 0; i < Math.min(a.length, b.length) && a[i] === b[i]; i += 1) out.push(a[i]);
  return out.join(sep) || sep;
})();
const relTo = (root, file) => {
  const p = realpathSync(join(root, file)).slice(commonRoot.length).replace(/^[/\\]+/, '');
  return p.split(sep).map(encodeURIComponent).join('/');
};
const pairs = names
  ? names.map((f) => [relTo(cRoot, f), relTo(oRoot, f), f])
  : [[relTo(cRoot, basename(converted)), relTo(oRoot, basename(original)), basename(converted)]];
if (!pairs.length || !widths.length) {
  console.error('tailwindify-parity: no comparable pages or widths');
  process.exit(3);
}

/** Leaf elements that carry their own words, keyed by tag + text. A key that
 *  appears twice on a page is dropped: an ambiguous join reports noise, and noise
 *  in a gate is worse than a smaller gate. */
const COLLECT = (props) => {
  /* Colours are resolved to RGBA through a 1x1 canvas rather than string-matched.
   * Tailwind emits `oklab(...)` for any colour carrying an opacity modifier while
   * plain CSS emits `rgba(...)`; the two paint identical pixels, and comparing the
   * strings buried the real findings under dozens of notation differences. The
   * canvas answers what the user actually sees, in one syntax, for every syntax. */
  const ctx = document.createElement('canvas').getContext('2d', { willReadFrequently: true });
  const rgba = (v) => {
    if (!v || v === 'none') return v;
    try {
      ctx.clearRect(0, 0, 1, 1);
      ctx.fillStyle = '#000';
      ctx.fillStyle = v;
      ctx.fillRect(0, 0, 1, 1);
      const [r, g, b, a] = ctx.getImageData(0, 0, 1, 1).data;
      return r + ',' + g + ',' + b + ',' + Math.round((a / 255) * 100) / 100;
    } catch (e) { return v; }
  };
  const COLOURS = new Set(['color', 'backgroundColor']);
  const map = {};
  for (const el of document.querySelectorAll('body *')) {
    if (el.children.length) continue;
    const t = (el.textContent || '').replace(/\s+/g, ' ').trim();
    if (t.length < 4 || t.length > 90) continue;
    const r = el.getBoundingClientRect();
    if (!r.width && !r.height) continue;
    const key = el.tagName + '|' + t;
    if (map[key]) { map[key] = 'DUP'; continue; }
    const c = getComputedStyle(el);
    const v = {};
    props.forEach((p) => { v[p] = COLOURS.has(p) ? rgba(c[p]) : c[p]; });
    map[key] = v;
  }
  return map;
};

/* Tailwind emits oklab() for a colour carrying an opacity modifier, where plain
 * CSS emits rgba(). Same pixels, different notation, and reporting it would bury
 * the real findings — so colours are compared as resolved RGBA, not as strings. */
const toRgba = (v) => {
  if (typeof v !== 'string') return v;
  const m = v.match(/^rgba?\(([^)]+)\)$/);
  if (!m) return v;
  const n = m[1].split(/[\s,/]+/).filter(Boolean).map(Number);
  if (n.length < 3 || n.some(Number.isNaN)) return v;
  const a = n.length > 3 ? Math.round(n[3] * 100) / 100 : 1;
  return `${Math.round(n[0])},${Math.round(n[1])},${Math.round(n[2])},${a}`;
};
const normalise = (prop, value) => {
  if (prop === 'fontFamily') return String(value).split(',')[0].replace(/["']/g, '').trim();
  // Colours already come back as resolved RGBA from the page; this only catches a
  // value the canvas could not paint (an invalid declaration, which is a finding
  // in its own right and should still compare as text).
  if (prop === 'color' || prop === 'backgroundColor') return toRgba(value);
  return value;
};

let srv, browser;
const findings = [];
const unrenderable = [];
try {
  srv = await serve(commonRoot);
  browser = await chromium.launch({ executablePath, args: ['--no-sandbox'] });
  const page = await browser.newPage();

  for (const [w, h] of widths) {
    await page.setViewportSize({ width: w, height: h });
    for (const [cPath, oPath, label] of pairs) {
      const read = async (path) => {
        await page.goto(`http://127.0.0.1:${srv.port}/${path}`, { waitUntil: 'networkidle', timeout: 45000 });
        await page.waitForTimeout(600);
        return page.evaluate(COLLECT, PROPS);
      };
      let o, c;
      try {
        o = await read(oPath);
        c = await read(cPath);
      } catch (err) {
        findings.push({ width: w, page: label, prop: '-', key: '-', original: '-', converted: '-',
          note: 'could not load: ' + String(err).slice(0, 120) });
        continue;
      }
      const pageRows = [];
      let joined = 0;
      for (const key of Object.keys(o)) {
        if (o[key] === 'DUP' || !c[key] || c[key] === 'DUP') continue;
        joined += 1;
        for (const prop of PROPS) {
          const a = normalise(prop, o[key][prop]);
          const b = normalise(prop, c[key][prop]);
          if (a !== b) pageRows.push({ width: w, page: label, prop, key, original: a, converted: b });
        }
      }

      /* A converted page can be UNSTYLED rather than wrong. `/wp-tailwindify`
       * strips every `<style>` block and every project stylesheet `<link>` and
       * adds no replacement, so unless the demo carries its own Tailwind runtime
       * the converted page renders as bare HTML — and then every joined element
       * differs on every property. Reporting that as hundreds of lost
       * declarations is worse than useless: it buries the real findings and
       * trains the reader to ignore the gate. Detect the shape instead and say
       * plainly that there was nothing to compare. */
      const distinct = new Set(pageRows.map((r) => r.key)).size;
      if (joined >= 8 && distinct / joined > 0.6) {
        unrenderable.push({ width: w, page: label, joined, differing: distinct });
        continue;
      }
      findings.push(...pageRows);
    }
  }
} catch (err) {
  console.error('tailwindify-parity: run failed: ' + String(err).slice(0, 200));
  process.exit(3);
} finally {
  if (browser) await browser.close().catch(() => {});
  if (srv) srv.server.close();
}

const jsonOut = opt('--json', '');
if (jsonOut) {
  mkdirSync(dirname(resolve(jsonOut)), { recursive: true });
  writeFileSync(resolve(jsonOut), JSON.stringify(findings, null, 2));
}

if (unrenderable.length) {
  console.log('tailwindify-parity: NOT COMPARED — the converted page renders unstyled\n');
  unrenderable.forEach((u) => console.log(
    `   ${u.width}px ${u.page}: ${u.differing} of ${u.joined} joined elements differ on something`
  ));
  console.log('\nConversion strips the demo\'s stylesheet and adds no replacement, so a converted');
  console.log('page only renders if the demo carries its own Tailwind runtime (the browser build,');
  console.log('or a compiled stylesheet). Run this gate where the page renders: after the demo');
  console.log('gets its runtime, or against the built site. An unstyled page cannot be compared,');
  console.log('and pretending otherwise is how a real lost declaration hides in the noise.\n');
}

if (!findings.length) {
  const compared = pairs.length * widths.length - unrenderable.length;
  console.log(`tailwindify-parity: clean — ${compared} page/width comparison(s), no declaration lost`);
  process.exit(unrenderable.length ? 1 : 0);
}

/* Grouped by property, because a dropped reset rule shows up as the SAME property
 * on many elements — that shape is the diagnosis, and a flat list hides it. */
const byProp = {};
findings.forEach((f) => { (byProp[f.prop] ||= []).push(f); });
console.log(`tailwindify-parity: ${findings.length} delta(s) across ${Object.keys(byProp).length} propert(ies)\n`);
for (const [prop, rows] of Object.entries(byProp).sort((a, b) => b[1].length - a[1].length)) {
  console.log(`${prop} — ${rows.length}`);
  rows.slice(0, 8).forEach((r) => console.log(
    `   ${r.width}px ${r.page}: original=${r.original} converted=${r.converted}  [${r.key.slice(0, 58)}]`
  ));
  if (rows.length > 8) console.log(`   ... +${rows.length - 8} more`);
  console.log('');
}
console.log('A property that appears on many unrelated elements is a dropped RESET rule,');
console.log('not a per-element slip: check it declaration by declaration against preflight.');
process.exit(1);
