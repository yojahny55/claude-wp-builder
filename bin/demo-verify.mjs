#!/usr/bin/env node
/**
 * demo-verify.mjs: walk a demo (or a live page) by scrolling it, and report what
 * only a moving page can show.
 *
 * A scroll page has no single state. Screenshotting the top and the bottom proves
 * nothing about the twelve positions in between, which is where dead scroll,
 * half-faded headlines and clipped copy live.
 *
 * Exit codes: 0 clean, 1 findings, 2 no usable browser (distinct on purpose, so
 * the caller can fall back to MCP screenshot tools rather than reporting a failure),
 * 3 the walk itself crashed (not a findings report).
 */
import { existsSync, mkdirSync, writeFileSync, readdirSync, statSync, createReadStream, realpathSync } from 'node:fs';
import { resolve, join, dirname, basename, extname, normalize, sep } from 'node:path';
import { homedir } from 'node:os';
import { pathToFileURL } from 'node:url';
import { createServer } from 'node:http';
import { findBrowser } from './lib/browsers.mjs';

// Advisory kinds report what the harness could not see, not what the page got
// wrong, so they are printed and written to findings.json but never raise the
// exit code — a gate that fails a round on the strength of what it could not
// read gets overruled in prose, and then so does every gate beside it. Every
// other kind blocks. Listed here, once, so a new kind joins a list instead of
// re-deriving the rule at the exit.
const ADVISORY = new Set(['unobserved', 'external-module', 'engine-delta']);

// Every context and page this tool opens accepts a self-signed certificate.
// `/wp-create` gives a local site HTTPS with its own CA, so without this the
// walk dies on ERR_CERT_AUTHORITY_INVALID before the first screenshot — and
// /wp-finalize, /wp-polish, /wp-responsive-check and /wp-audit all forward
// here, so one rejected certificate took out the whole finish-phase gate suite
// on a standard local install. Nothing here authenticates or posts; it
// screenshots and reads the DOM.
const TLS = { ignoreHTTPSErrors: true };

const args = process.argv.slice(2);
if (args.includes('--help')) {
  console.log(
    'usage: demo-verify.mjs [file-or-dir-or-url] [--out DIR] [--positions N] [--widths 1440x900,390x844] [--no-firefox]\n' +
    '       demo-verify.mjs --probe     exit 0 if playwright-core and a Chrome are usable, else 2'
  );
  process.exit(0);
}
const PROBE = args.includes('--probe');

// The command documents demo/index.html as the default target, and exit 2 is
// reserved for "no usable browser" so a caller can fall back to MCP screenshots.
// Exiting 2 on a bare invocation made a missing argument look like a missing
// browser and sent the caller down the wrong branch of that ladder.
//
// The target is the first argument that is neither a flag nor a flag's value.
// Testing args[0] alone silently dropped the target in
// `demo-verify.mjs --positions 6 other.html` and verified the default instead.
const VALUE_FLAGS = new Set(['--out', '--positions', '--widths']);
const positional = () => {
  for (let i = 0; i < args.length; i++) {
    if (VALUE_FLAGS.has(args[i])) {
      i++; // skip the value this flag consumes
      continue;
    }
    if (args[i].startsWith('--')) continue;
    return args[i];
  }
  return null;
};
const target = positional() || 'demo/index.html';
const opt = (name, dflt) => {
  const i = args.indexOf(name);
  return i === -1 ? dflt : args[i + 1];
};
// An invalid or missing value must not silently skip the walk: NaN or a
// value under 2 makes the sample loop's k < positions never run, producing
// zero frames, zero findings, and a false clean report.
const rawPositions = Number(opt('--positions', 6));
const positions = Number.isFinite(rawPositions) && rawPositions >= 2 ? Math.floor(rawPositions) : 6;
const widths = opt('--widths', '1440x900,390x844')
  .split(',')
  .map((s) => {
    const [w, h] = s.split('x').map(Number);
    return { width: w, height: h };
  });
const targetIsUrl = /^https?:\/\//.test(target);
const targetIsDir = !targetIsUrl && existsSync(target) && statSync(target).isDirectory();
// A directory walks every page in it. Interior pages are where a craft build
// is emptiest, and verifying only index.html let that ship.
const pages = targetIsDir
  ? readdirSync(target).filter((f) => f.endsWith('.html')).sort().map((f) => join(target, f))
  : [target];
// resolve() on a URL string treats it as a filesystem path, which is never
// what the caller means; a URL target with no --out writes into cwd/.verify
// instead of guessing a directory from the URL text.
const outDir = resolve(
  opt('--out', targetIsUrl ? '.verify' : join(targetIsDir ? resolve(target) : dirname(resolve(target)), '.verify'))
);

const MIME = { '.html': 'text/html', '.css': 'text/css', '.js': 'text/javascript',
  '.mjs': 'text/javascript', '.json': 'application/json', '.png': 'image/png',
  '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.svg': 'image/svg+xml',
  '.webp': 'image/webp', '.woff2': 'font/woff2', '.avif': 'image/avif' };

/** Serve `root` on an ephemeral port. Verification over file:// silently blocks
 *  module scripts and relative image loads; neither is a defect in the demo. */
const serve = (root) => new Promise((ready, fail) => {
  // realpath once: the containment test below compares real paths, so a root
  // that is itself reached through a symlink must be in the same terms.
  const base = realpathSync(root);
  const server = createServer((req, res) => {
    // decodeURIComponent throws URIError on a malformed escape (a bare `%` is
    // enough), and an uncaught throw here kills the process mid-walk — a
    // verification that produced no answer, which is the failure this whole
    // branch exists to stop. Decode inside the guard and answer 400.
    let file;
    try {
      // Leading separators stripped as well as leading ../: a request path is
      // always rooted at '/', and resolve() treats an absolute second argument
      // as the whole answer — '/index.html' would resolve to the filesystem
      // root, not to a file under the demo.
      const rel = normalize(decodeURIComponent(req.url.split('?')[0]))
        .replace(/^(\.\.[/\\])+/, '')
        .replace(/^[/\\]+/, '');
      // Stripping leading ../ is not containment: a Windows drive-absolute path
      // (/C:/Windows/...) makes resolve() land outside the root outright, and a
      // symlink inside the root pointing outside it is followed by the read. So
      // resolve, follow the links with realpath, and demand the result still be
      // the root or under it — a page under test could otherwise read arbitrary
      // local files through this server. realpathSync throws on a missing file,
      // which the catch already answers 404.
      file = realpathSync(resolve(base, rel));
      if (file !== base && !file.startsWith(base + sep)) return res.writeHead(404).end();
      if (statSync(file).isDirectory()) return res.writeHead(403).end();
    } catch (err) { return res.writeHead(err instanceof URIError ? 400 : 404).end(); }
    res.writeHead(200, { 'content-type': MIME[extname(file).toLowerCase()] || 'application/octet-stream' });
    createReadStream(file).pipe(res);
  });
  // Without this the promise never settles when the bind fails (port
  // exhaustion, a sandbox refusing it) and the walk hangs instead of reporting
  // a crash — the worst shape of "no answer", because it looks like progress.
  // Removed once listen succeeds, so a later runtime error cannot reject an
  // already-settled promise.
  server.once('error', fail);
  server.listen(0, '127.0.0.1', () => {
    server.removeListener('error', fail);
    ready({ server, port: server.address().port });
  });
});

function findChrome() {
  if (process.env.WP_DEMO_CHROME && existsSync(process.env.WP_DEMO_CHROME))
    return process.env.WP_DEMO_CHROME;
  const win = process.platform === 'win32';
  // Windows was unreachable before: with no candidate paths and no cache root
  // for it, findChrome returned null and the command exited 2 (no usable
  // browser) on a machine that had Chrome installed.
  const candidates = win
    ? [
        join(process.env.PROGRAMFILES || 'C:\\Program Files', 'Google\\Chrome\\Application\\chrome.exe'),
        join(process.env['PROGRAMFILES(X86)'] || 'C:\\Program Files (x86)', 'Google\\Chrome\\Application\\chrome.exe'),
        process.env.LOCALAPPDATA
          ? join(process.env.LOCALAPPDATA, 'Google\\Chrome\\Application\\chrome.exe')
          : null,
      ]
    : [
        '/usr/bin/google-chrome',
        '/usr/bin/google-chrome-stable',
        '/usr/bin/chromium',
        '/usr/bin/chromium-browser',
        '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
      ];
  for (const c of candidates) if (c && existsSync(c)) return c;
  // Playwright's own browser cache, when one already exists on the machine.
  // Walked with readdirSync rather than a glob: fs.globSync landed in Node 22 and
  // importing it outright makes this whole script a SyntaxError on Node 18 and 20.
  // macOS caches under ~/Library/Caches, not ~/.cache, so all roots are tried.
  const cacheRoots = win
    ? [join(process.env.LOCALAPPDATA || homedir(), 'ms-playwright')]
    : [
        join(homedir(), '.cache/ms-playwright'),
        join(homedir(), 'Library/Caches/ms-playwright'),
      ];
  const tails = win
    ? ['chrome-win\\chrome.exe']
    : [
        'chrome-linux64/chrome',
        'chrome-linux/chrome',
        'chrome-mac/Chromium.app/Contents/MacOS/Chromium',
      ];
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

// PLAYWRIGHT_CORE lets the check suite force the no-browser path; a bogus
// value must produce exit 2, never a crash, and skips the fallback ladder
// below entirely so the forced failure stays deterministic.
let chromium;
let firefox;
try {
  if (process.env.PLAYWRIGHT_CORE) {
    ({ chromium, firefox } = await import(pathToFileURL(resolve(process.env.PLAYWRIGHT_CORE, 'index.mjs')).href));
  } else {
    try {
      ({ chromium, firefox } = await import('playwright-core'));
    } catch (bare) {
      // A bare specifier resolves from this file's own location (bin/),
      // walking up through the plugin's own node_modules — never the
      // WordPress project the plugin is invoked from, which is not this
      // file's ancestor. `npm i -D playwright-core` run in the project root
      // (what the probe's own failure message, and Task 7's gate, tell the
      // agent to do) is invisible to that resolution, so fall back to the
      // cwd's node_modules before giving up.
      const cwdEntry = join(process.cwd(), 'node_modules', 'playwright-core', 'index.mjs');
      if (!existsSync(cwdEntry)) throw bare;
      ({ chromium, firefox } = await import(pathToFileURL(cwdEntry).href));
    }
  }
} catch {
  console.error(PROBE ? 'probe: missing playwright-core' : 'demo-verify: playwright-core is not installed (npm i -D playwright-core)');
  process.exit(2);
}
const executablePath = findChrome();
if (!executablePath) {
  console.error(PROBE ? 'probe: missing chrome' : 'demo-verify: no existing Chrome or Chromium found. Set WP_DEMO_CHROME to one; nothing is downloaded.');
  process.exit(2);
}
// Firefox is the second engine, never a requirement: a Playwright Firefox build that
// already exists is used, and a machine without one gets a notice and a Chromium-only run.
// A system Firefox cannot be driven (Playwright needs its own patched build), and nothing
// here downloads one.
const firefoxPath = args.includes('--no-firefox') || !firefox ? null : findBrowser('firefox');
if (PROBE) {
  console.log('probe: ok ' + executablePath + (firefoxPath ? ' (firefox ' + firefoxPath + ')' : ' (no firefox)'));
  process.exit(0);
}

// The five legacy /wp-responsive-check viewports plus 620, 1100, 1152 and 1280. One full-page
// shot each, at the top of the page, no scroll-walk: this is layout coverage, not motion
// coverage.
//
// The legacy five sample breakpoint EDGES only, and an edge is where the rules change, not where
// they do damage. Between 1024 and 1279 Tailwind's `lg:` utilities apply with no `xl:` override
// yet, so a row can be correct at 1024, correct again at 1280 once `xl:` takes over, and wrong
// for the 256px in between — a band no shot covered. 1152 sits inside it. 1280 is kept because
// it is the first width where `xl:` applies, which is its own thing worth seeing.
//
// 620 and 1100 sample two more bands the edges skip. 620 sits between 576 and 768, where a
// grid that is one column on the phone and two at `md:` is still one stretched column.
// 1100 sits just under the
// 1140-1200px containers most demos use, where the wrapper has stopped centring and its
// content meets the gutters.
const RESPONSIVE_WIDTHS = [375, 576, 620, 768, 1024, 1100, 1152, 1280, 1440];

// sheet.png is a full-resolution grid of the walk's PNG frames -- exactly the file
// a human wants and exactly the file that makes a bad orchestrator prompt: it is
// meant to be Read into the model's context (Step 4's "read the sheets"), and an
// image Read stays in context, re-billed on every later call until compaction. A
// real verify session read 14.6MB of these across a single directory walk, several
// sheets over 1MB each. sheet.jpg is the same grid, downscaled and re-encoded, and
// is what the command now points the model at; sheet.png stays on disk at full size
// for a human who opens it directly, which costs nothing extra to keep.
const SHEET_JPEG_WIDTH = 1000;
const SHEET_JPEG_QUALITY = 70;

/** One full-page screenshot per legacy viewport, filenames responsive-<width>.png,
 *  restoring the convention /wp-tailwind-migrate's visual-golden workflow depends on. */
async function captureResponsiveShots(browser, url, outDir) {
  mkdirSync(outDir, { recursive: true });
  for (const width of RESPONSIVE_WIDTHS) {
    const height = width <= 480 ? 812 : 900;
    const context = await browser.newContext({ viewport: { width, height }, ...TLS });
    const page = await context.newPage();
    await page.goto(url, { waitUntil: 'load' });
    await page.waitForTimeout(400);
    await page.screenshot({ path: join(outDir, 'responsive-' + width + '.png'), fullPage: true });
    await context.close();
  }
}

// Chromium vs Firefox, element by element. Verification used to be Chromium-only, and a
// difference between engines surfaced only when the client opened the site in another
// browser. Motion is neutralised as in the section walk (same reasons: a transform is not
// layout), the page is read after its fonts load, and each box is keyed by its DOM path so
// the two engines' lists line up. `y` is taken relative to the parent: one taller heading
// would otherwise shift every box below it and report the page a hundred times over.
const ENGINE_DELTA_PX = 2;
const ENGINE_DELTA_REPORT = 15;
const ENGINE_BOX_SELECTOR =
  'header, nav, main, footer, section, article, aside, h1, h2, h3, h4, p, ul, ol, li, a, button, ' +
  'input, select, textarea, label, img, svg, picture, video, iframe, form, table';

async function engineBoxes(browser, url, size) {
  const context = await browser.newContext({ viewport: size, reducedMotion: 'reduce', ...TLS });
  try {
    const page = await context.newPage();
    await page.goto(url, { waitUntil: 'load' });
    await page.evaluate(() => document.fonts && document.fonts.ready);
    await page.waitForTimeout(300);
    return await page.evaluate((sel) => {
      const style = document.createElement('style');
      style.textContent =
        '*,*::before,*::after{animation:none !important;transition:none !important;' +
        'transform:none !important;translate:none !important;scale:none !important;' +
        'rotate:none !important}';
      document.head.appendChild(style);
      const pathOf = (el) => {
        const parts = [];
        for (let n = el; n && n !== document.body; n = n.parentElement) {
          let i = 1;
          for (let s = n.previousElementSibling; s; s = s.previousElementSibling) if (s.tagName === n.tagName) i++;
          parts.unshift(n.tagName.toLowerCase() + ':nth-of-type(' + i + ')');
        }
        return parts.join(' > ');
      };
      const out = {};
      for (const el of document.querySelectorAll(sel)) {
        const r = el.getBoundingClientRect();
        if (!r.width || !r.height) continue;
        // A broken image renders its alt text, and each engine draws that differently:
        // a missing file is its own finding, not an engine difference.
        if (el.tagName === 'IMG' && el.complete && !el.naturalWidth) continue;
        const pr = el.parentElement ? el.parentElement.getBoundingClientRect() : { top: 0 };
        const cls = typeof el.className === 'string' ? el.className.trim().split(/\s+/)[0] : '';
        out[pathOf(el)] = {
          label: el.tagName.toLowerCase() + (cls ? '.' + cls : ''),
          x: Math.round(r.left * 10) / 10, y: Math.round((r.top - pr.top) * 10) / 10,
          w: Math.round(r.width * 10) / 10, h: Math.round(r.height * 10) / 10,
        };
      }
      return out;
    }, ENGINE_BOX_SELECTOR);
  } finally {
    await context.close();
  }
}

async function engineDeltas(chromeBrowser, ffBrowser, url, size) {
  const [a, b] = [await engineBoxes(chromeBrowser, url, size), await engineBoxes(ffBrowser, url, size)];
  const rows = [];
  for (const [key, c] of Object.entries(a)) {
    const f = b[key];
    if (!f) continue;
    const d = Math.max(Math.abs(c.x - f.x), Math.abs(c.y - f.y), Math.abs(c.w - f.w), Math.abs(c.h - f.h));
    if (d > ENGINE_DELTA_PX) rows.push({ d, key, c, f });
  }
  rows.sort((p, q) => q.d - p.d);
  return rows.slice(0, ENGINE_DELTA_REPORT).map((r) => ({
    kind: 'engine-delta',
    pass: 'firefox',
    width: size.width,
    element: r.c.label,
    path: r.key,
    chromium: { x: r.c.x, y: r.c.y, w: r.c.w, h: r.c.h },
    firefox: { x: r.f.x, y: r.f.y, w: r.f.w, h: r.f.h },
    delta: Math.round(r.d * 10) / 10,
    ...(rows.length > ENGINE_DELTA_REPORT ? { of: rows.length } : {}),
  }));
}

/** Read one section's frame signature plus the page's static defects. Runs inside the page.
 *  The device walk is scoped to the section, because a document-wide count meant
 *  `samplable === 0` required every device on the page to be unreadable — so
 *  `unobserved` could only fire where `no-engine` already did, and a section
 *  carrying only pointer devices (tilt, magnet, spotlight) was judged by whether
 *  some other section happened to be readable. Scoping also stops one section's
 *  motion from perturbing every other section's signature on the same page. */
const probe = (idx) => {
  const sig = [];
  let devices = 0;
  let samplable = 0;
  const root = document.querySelectorAll('section, [data-motion]')[idx] || document.body;
  const scope = [];
  if (root.matches && root.matches('[data-motion]')) scope.push(root);
  root.querySelectorAll('[data-motion]').forEach((el) => scope.push(el));
  scope.forEach((el) => {
    devices += 1;
    const before = sig.length;
    const p = el.style.getPropertyValue('--motion-p');
    if (p) sig.push(p);
    const rail = el.querySelector('[data-motion-rail]');
    if (rail) sig.push(rail.style.transform || '');
    if (el.style.clipPath) sig.push(el.style.clipPath);
    // `reveal` publishes no progress value under either engine — the CSS path
    // animates opacity and translate directly, the JS path tweens them. Sample
    // the child the ruleset actually targets (`[data-motion="reveal"] > *`) so a
    // working reveal contributes a changing signature instead of nothing.
    if (el.getAttribute('data-motion') === 'reveal') {
      const child = el.firstElementChild;
      if (child) {
        const cs = getComputedStyle(child);
        sig.push(Number(cs.opacity).toFixed(2));
        sig.push(cs.translate || cs.transform || '');
      }
    }
    if (sig.length > before) samplable += 1;
  });
  const cues = [];
  // Page-level from here down, deliberately: the cue sweep, the canvas sample,
  // `clipped` and `overflow` are facts about the document, not about this
  // section. Only the [data-motion] walk above is scoped — do not "fix" these.
  document.querySelectorAll('[data-motion-cue]').forEach((el, i) => {
    // A cue that is not rendered at this width (mobile-only copy behind a
    // display:none at desktop, most often) never gets driven, so its opacity
    // sits at its initial value forever and scores a cue-never-peaks finding
    // for copy the reader was never shown. getClientRects also catches the
    // case where the cue is fine but an ancestor is hidden.
    const style = getComputedStyle(el);
    if (style.display === 'none' || style.visibility === 'hidden' || el.getClientRects().length === 0) return;
    const o = Number(style.opacity);
    sig.push(o.toFixed(2));
    cues.push({ i, text: (el.textContent || '').trim().slice(0, 60), opacity: o });
  });
  // A cinematic stage paints to a canvas, so its signature is a pixel sample.
  document.querySelectorAll('canvas').forEach((c) => {
    try {
      const ctx = c.getContext('2d');
      if (!ctx) return;
      const d = ctx.getImageData(Math.floor(c.width / 2), Math.floor(c.height / 2), 1, 1).data;
      sig.push(d[0] + ',' + d[1] + ',' + d[2]);
    } catch { /* tainted or webgl: not signable, skip */ }
  });
  // Copy hidden from sighted users on purpose is not clipped copy. The standard
  // accessible-honeypot and sr-only patterns both work by making a box far smaller
  // than its text and hiding the overflow -- which is exactly the signature this
  // detector looks for, so one honeypot field produced 72 blocking findings
  // (element x section x width x scroll position) on a build whose accessibility
  // was correct. A gate that fails correct code teaches authors to delete the
  // correct code.
  const deliberatelyHidden = (el) => {
    for (let node = el; node; node = node.parentElement) {
      const st = getComputedStyle(node);
      if (st.display === 'none' || st.visibility === 'hidden' || st.visibility === 'collapse' || Number(st.opacity) === 0) {
        return true;
      }
      if (st.position === 'absolute' || st.position === 'fixed') {
        // Parked off-canvas: recognise the -9999px family by direction. Large
        // positive left/top values can be visible on a large page or viewport.
        const far = Math.max(4096, window.innerWidth * 2, window.innerHeight * 2);
        const left = parseFloat(st.left);
        const top = parseFloat(st.top);
        const right = parseFloat(st.right);
        const bottom = parseFloat(st.bottom);
        const off = (Number.isFinite(left) && left <= -far)
          || (Number.isFinite(top) && top <= -far)
          || (Number.isFinite(right) && right >= far)
          || (Number.isFinite(bottom) && bottom >= far);
        if (off) return true;
      }
      // The sr-only clip: a 1px box holding real text.
      const r = node.getBoundingClientRect();
      const clipped = st.overflowX === 'hidden' || st.overflowX === 'clip'
        || st.overflowY === 'hidden' || st.overflowY === 'clip'
        || (st.clip && st.clip !== 'auto') || (st.clipPath && st.clipPath !== 'none');
      if (clipped && r.width <= 2 && r.height <= 2 && (node.textContent || '').trim().length > 2) return true;
    }
    return false;
  };
  const clipped = [];
  document.querySelectorAll('p, h1, h2, h3, li').forEach((el, i) => {
    if (el.scrollHeight > el.clientHeight + 2 && getComputedStyle(el).overflow === 'hidden') {
      if (deliberatelyHidden(el)) return;
      clipped.push({ i, text: (el.textContent || '').trim().slice(0, 60) });
    }
  });
  // Which boxes stick out, not only that one does. A bare `overflow: true` sent
  // the reader hunting, and the box that stretched a real page was a 1px
  // screen-reader span inside a carousel card: invisible in every screenshot. It
  // was `position: absolute`, its containing block sat OUTSIDE the carousel's
  // `overflow-x: auto` strip, and overflow only clips descendants whose
  // containing block is the clipping box or inside it -- so every off-screen
  // card's span widened the document. The walk below follows that rule: an
  // ancestor that clips counts only once the chain has reached the containing
  // block of every absolute box on the way up. `escapes` names the clipping box
  // the culprit got past, which is where the fix goes.
  const culprits = [];
  if (document.documentElement.scrollWidth > window.innerWidth + 1) {
    const edge = document.documentElement.clientWidth + 1;
    const describe = (el) => el.tagName.toLowerCase() + (el.id ? '#' + el.id : '')
      + (typeof el.className === 'string' && el.className.trim()
        ? '.' + el.className.trim().split(/\s+/).slice(0, 3).join('.') : '');
    const containing = (s) => s.position !== 'static' || s.transform !== 'none'
      || s.filter !== 'none' || /paint|layout|strict|content/.test(s.contain);
    const found = new Set();
    for (const el of document.body.querySelectorAll('*')) {
      const r = el.getBoundingClientRect();
      if (!r.width || r.right <= edge) continue;
      const st = getComputedStyle(el);
      // A fixed box is laid out against the viewport and never widens the document.
      if (st.position === 'fixed') continue;
      let waiting = st.position === 'absolute';
      let clipped = false;
      let bypassed = null;
      for (let a = el.parentElement; a && a !== document.body; a = a.parentElement) {
        const s = getComputedStyle(a);
        if (waiting && containing(s)) waiting = false;
        if (s.overflowX !== 'visible') {
          if (!waiting) { clipped = true; break; }
          if (!bypassed) bypassed = a;
        }
        if (s.position === 'absolute') waiting = true;
      }
      if (clipped) continue;
      found.add(el);
      // An in-flow child of a culprit only follows its parent out; the parent is
      // the one to report. An absolute child is its own case.
      let p = el.parentElement;
      while (p && !found.has(p)) p = p.parentElement;
      if (p && st.position !== 'absolute') continue;
      culprits.push({
        selector: describe(el),
        right: Math.round(r.right),
        position: st.position,
        ...(bypassed ? { escapes: describe(bypassed) } : {}),
      });
    }
    culprits.sort((x, y) => y.right - x.right);
  }
  return {
    signature: sig.join('|'),
    devices,
    samplable,
    // no-engine is the one judgment that stayed page-level: "this demo carries
    // no motion at all". Scoping its counter turned every ordinary static
    // section on a moving page into a blocking no-engine, which is the false
    // positive this whole gate exists to avoid.
    pageDevices: document.querySelectorAll('[data-motion]').length,
    cues,
    clipped,
    overflow: document.documentElement.scrollWidth > window.innerWidth + 1,
    culprits: culprits.slice(0, 5),
    scrollHeight: document.documentElement.scrollHeight,
  };
};

/**
 * One section's `reveal` children, as a string. `reveal` is a one-shot entry
 * transition a few pixels long — measured on a real Chrome it moves between
 * scrollY top-viewport and about 120px later, whatever the section's height,
 * because `animation-timeline: view()` is applied to `[data-motion="reveal"] > *`
 * and driven by that child's own view progress. Asking a stall walk "did the
 * signature change across N samples" is the right question for a scrubbed
 * device and the wrong shape for this one: whether a sparse walk lands inside
 * those pixels is sampling luck, and a miss reports dead scroll on a section
 * that reveals perfectly. Compare two positions instead — below the fold and
 * fully entered. Returns '' when the section has no reveal children to read.
 *
 * What is read at each point is the scroll-driven animation itself, not the
 * computed style it happens to produce. Reading `opacity`/`translate` made the
 * check spoofable by any ambient motion: a decorative `@keyframes pulse` on the
 * same children, or a percentage transform re-resolving after a lazy image
 * loads, moved the computed style and the section passed with no reveal wired
 * at all. `getAnimations()` filtered to a `ViewTimeline` is the device's own
 * contract — `[data-motion="reveal"] > *` sets `animation-timeline: view()` —
 * and an unrelated keyframe runs on the document timeline, so it cannot
 * counterfeit it. A child with no scroll-driven animation contributes the
 * literal `none`, so a reveal that was never wired reads the same at both
 * points and is reported, instead of returning an empty string and being
 * skipped.
 *
 * Known limits: only `reveal` is read here. `parallax` is neither scrubbed nor
 * reveal, publishes no --motion-p, and writes `transform` on the device element
 * itself, so a parallax-only section is not judged at all — deliberately, since
 * sampling every device element's transform would also start judging devices the
 * harness has never been able to read (`counter`) and invent findings on them.
 * And the comparison is still an OR across the section's reveals: one live child
 * changes the joined string, so it excuses its dead siblings.
 */
const revealState = (idx) => {
  // motion.js wires reveal in GSAP whenever `view()` is missing, and a GSAP tween
  // is rAF-driven, not a Web Animation, so getAnimations() returns nothing and a
  // working reveal would read `none|none` and be reported dead. On such a browser
  // the section is unjudged — same sentinel as the above-the-fold and `parallax`
  // ceilings. Latent on the current harness (Chrome has shipped `view()` since 115).
  if (!CSS.supports('animation-timeline', 'view()')) return '';
  const root = document.querySelectorAll('section, [data-motion]')[idx];
  if (!root) return '';
  const devices = [];
  if (root.matches('[data-motion="reveal"]')) devices.push(root);
  root.querySelectorAll('[data-motion="reveal"]').forEach((el) => devices.push(el));
  const out = [];
  devices.forEach((el) => {
    Array.from(el.children).forEach((child) => {
      const driven = child.getAnimations().filter(
        (a) => typeof ViewTimeline !== 'undefined' && a.timeline instanceof ViewTimeline
      );
      if (!driven.length) {
        out.push('none');
        return;
      }
      driven.forEach((a) => {
        const t = a.effect ? a.effect.getComputedTiming() : null;
        const p = t && t.progress != null ? Number(t.progress).toFixed(3) : 'null';
        out.push((a.animationName || 'anim') + ':' + p);
      });
    });
  });
  return out.join('|');
};

/** Report @container rules whose subject can never match a container. */
/* A page whose entire motion is `reveal` plus pointer devices is a static page that
 * measures as animated. `reveal` is a one-shot entrance, and on the CSS path an element
 * already in view at load lands on its end state without animating at all; `tilt`,
 * `magnet` and `spotlight` need a pointer, so they do nothing on a touch screen. Neither
 * reacts to scrolling. A build once shipped eleven of twelve pages in exactly this state
 * — 74 reveals and 19 pointer devices between them, not one scroll-reactive device — and
 * every gate passed, because each device present was correctly wired. What no gate asked
 * was whether the mix could move. This one does.
 *
 * Returns the device kinds present, so the finding can name what the page actually has
 * rather than assert an absence. */
const SCROLL_REACTIVE_DEVICES = new Set(['drift', 'count', 'parallax', 'pan', 'cascade']);
const motionMix = () => {
  const devices = {};
  document.querySelectorAll('[data-motion]').forEach((el) => {
    const k = (el.getAttribute('data-motion') || '').trim();
    if (k) devices[k] = (devices[k] || 0) + 1;
  });
  const cssScroll = [...document.querySelectorAll('*')].some((el) => {
    const st = getComputedStyle(el);
    return st.animationName !== 'none' && st.animationTimeline && st.animationTimeline !== 'auto';
  });
  return { devices, cssScroll };
};

const containerAudit = () => {
  const out = [];
  const sheets = [...document.styleSheets];
  // @container nested inside @media, @supports or @layer was never linted — a
  // silent false negative in a lint whose whole job is finding rules that
  // silently do nothing. proof-row already nests @media inside @supports.
  const containerRules = [];
  const collect = (rules) => {
    for (const rule of rules) {
      const n = rule.constructor.name;
      if (n === 'CSSContainerRule') containerRules.push(rule);
      else if (n === 'CSSMediaRule' || n === 'CSSSupportsRule' || n === 'CSSLayerBlockRule') {
        try { collect([...rule.cssRules]); } catch { /* not a grouping rule at runtime */ }
      }
    }
  };
  for (const sheet of sheets) {
    let rules;
    try { rules = [...sheet.cssRules]; } catch { continue; } // cross-origin
    collect(rules);
  }
  for (const rule of containerRules) {
    for (const inner of [...rule.cssRules]) {
      const sel = inner.selectorText;
      if (!sel) continue;
      // Every match, not the first: a selector matching several elements
      // applies as soon as ONE of them sits inside a container, and judging
      // it by document.querySelector(sel) reported that rule as dead when the
      // first match happened to be the one outside. container-noop is
      // blocking, so that false positive failed a round on correct CSS.
      let els;
      try { els = document.querySelectorAll(sel); } catch { continue; }
      if (!els.length) continue;
      let found = false;
      for (const el of els) {
        // An element never matches a container query against the container it
        // establishes itself, so start the walk at its parent.
        let node = el.parentElement;
        while (node) {
          const ct = getComputedStyle(node).containerType;
          if (ct && ct !== 'normal') { found = true; break; }
          node = node.parentElement;
        }
        if (found) break;
      }
      if (!found) out.push(sel);
    }
  }
  return [...new Set(out)];
};

let browser;
let ffBrowser = null;
let http = null;
let exitCode = 0;
const report = { pages: [] };

try {
  browser = await chromium.launch({ executablePath, args: ['--autoplay-policy=no-user-gesture-required'] });
  if (firefoxPath) {
    try {
      ffBrowser = await firefox.launch({ executablePath: firefoxPath });
    } catch (err) {
      const why = err && typeof err.message === 'string' ? err.message.split('\n')[0] : String(err);
      console.error('demo-verify: Firefox at ' + firefoxPath + ' did not launch (' + why + ') -- Chromium only this run');
    }
  } else if (!args.includes('--no-firefox')) {
    console.error('demo-verify: no Playwright Firefox build found (set WP_BROWSER_FIREFOX) -- Chromium only this run; nothing is downloaded');
  }
  report.firefox = ffBrowser ? firefoxPath : null;

  for (const pageTarget of pages) {
  // One page's failure costs that page, never the walk. A single screenshot
  // exceeding its timeout used to reject out of the whole loop, so a 16-page
  // directory lost fifteen completed pages and wrote no findings.json at all —
  // three times on one build, each time re-run from zero. The page is recorded
  // as crashed, which is blocking, and the walk goes on.
  // Hoisted so the catch below can still name the page and keep its findings.
  // `let`, not `const`: the local-page branch inside the try reassigns this to
  // the loopback URL once its server is up, and that server call can throw, so
  // it cannot be computed before the try.
  let pageUrl = pageTarget;
  const findings = [];
  try {
  const isRemote = /^https?:\/\//.test(pageTarget);
  // Loading a local page as file:// puts it on an opaque origin, where Chrome
  // blocks an external `<script type="module">` outright — the engine never
  // boots and every section reports dead scroll, silently. Serving removes
  // the whole class. One server per page, closed before the next is opened;
  // process.exit() at the very end reclaims whichever one is still open.
  if (http) { http.server.close(); http = null; }
  if (!isRemote) {
    const abs = resolve(pageTarget);
    const root = statSync(abs).isDirectory() ? abs : dirname(abs);
    http = await serve(root);
    const leaf = statSync(abs).isDirectory() ? 'index.html' : basename(abs);
    pageUrl = `http://127.0.0.1:${http.port}/${leaf}`;
  }
  const pageOut = pages.length > 1 ? join(outDir, basename(pageTarget, '.html')) : outDir;
  const sections = [];
  let staticChecked = false;
  // One list of dead selectors per width walked, intersected after the loop.
  // See the container-noop block below for why a single width cannot decide it.
  const containerNoop = [];
  const clippedSeen = new Set();
  const overflowSeen = new Set();
  let containFreeze = null;
  let mix = null;

  // The docs promise the reduced-motion pass at desktop width. Pinning it to
  // widths[0] meant a mobile-first --widths list ran it at the phone size and
  // skipped the desktop check entirely, so pick the widest explicitly.
  const reducedPassAt = widths.reduce((a, b) => (b.width > a.width ? b : a), widths[0]);
  for (const size of widths) {
  for (const reduced of size === reducedPassAt ? [false, true] : [false]) {
    const label = size.width + (reduced ? '-reduced' : '');
    const dir = join(pageOut, String(label));
    mkdirSync(dir, { recursive: true });
    const context = await browser.newContext({
      viewport: size,
      reducedMotion: reduced ? 'reduce' : 'no-preference',
      ...TLS,
    });
    const page = await context.newPage();
    await page.goto(pageUrl, { waitUntil: 'load' });
    await page.waitForTimeout(600);

    // Independent of scroll position, NOT of width: `container-type` is routinely
    // declared inside a `@media` block, and the audit now reads `@container`
    // rules nested there too — so a rule that is dead at 1440 is live at 390 and
    // the reverse. Measured: `@media (max-width:700px){.x{container-type:inline-size}
    // @container(min-width:400px){.x__y{}}}` audits clean at 390 and reports
    // `.x__y` at 1440. container-noop is blocking, so sampling one width failed a
    // round on correct CSS. Collect per width, report only what is dead at ALL of
    // them, below the loop.
    if (!reduced) containerNoop.push(await page.evaluate(containerAudit));
    if (!reduced && !mix) mix = await page.evaluate(motionMix);
    // `container-type` on an ancestor of the scroll subject freezes
    // `animation-timeline: view()` -- the timeline reports one constant progress at
    // every scroll position, so every CSS-path reveal lands dead. The existing
    // dead-scroll finding catches the symptom; nothing named the cause, and a build
    // that had added `container-type: inline-size` to `body` (a reasonable thing to
    // do in a container-query-based library) spent a full round on 58 of them.
    // Measured on that build: ViewTimeline currentTime pinned at 11.2849% with the
    // declaration, tracking -10.34% -> 47.02% without it.
    if (!reduced && containFreeze === null) {
      containFreeze = await page.evaluate(() => {
        const seen = new Set();
        const compositionRoots = new Set(document.querySelectorAll('section'));
        const subjects = [...document.querySelectorAll('section, [data-motion]')];
        if (!subjects.length && document.body) subjects.push(document.body);
        for (const root of subjects) {
          for (let node = root.parentElement; node; node = node.parentElement) {
            if (seen.has(node)) continue;
            seen.add(node);
            // Every composition intentionally establishes its own inline-size
            // container; only wrappers around compositions freeze their timelines.
            if (compositionRoots.has(node)) continue;
            const ct = getComputedStyle(node).containerType;
            if (ct && ct !== 'normal') {
              return node.tagName.toLowerCase() + ' { container-type: ' + ct + ' }';
            }
          }
        }
        return '';
      });
    }
    // Width-independent (a <script src> is in the markup at every size), so this
    // one stays a once-per-page read.
    if (!staticChecked) {
      staticChecked = true;
      const external = await page.$$eval('script[type="module"][src]', (n) => n.map((s) => s.getAttribute('src')));
      for (const src of external) {
        findings.push({ kind: 'external-module', pass: 'normal', width: size.width, src });
      }
    }

    const bounds = await page.evaluate(() => {
      // Measure the LAYOUT box, not the painted one. `getBoundingClientRect()` returns
      // the box after transforms, and every value read here becomes a scroll position
      // the walk then drives to -- so a section that happens to be moving when it is
      // measured gets walked at the wrong offsets, and the error is largest on exactly
      // the sections this walk exists to judge. Measured on a fixture at 1280x800,
      // painted box minus layout box:
      //
      //   plain section                             top    0px   height   0px
      //   parallax bed (engine writes transform)          -90px            0px
      //   entrance start state (translate 44px)           +44px            0px
      //   scaled wrapper (scale 1.14)                     -28px          +56px
      //
      // Neutralising the box-moving properties for the duration of the read is the
      // only version that covers all three causes at once: `animation: none` alone
      // leaves the engine's inline `transform` on a parallax bed, and `offsetTop`
      // alone misreads under a transformed ancestor, which is a containing block.
      // Transforms never affect layout, so removing them cannot change what is
      // measured -- only what was being measured wrongly.
      const neutraliser = document.createElement('style');
      neutraliser.textContent =
        '*,*::before,*::after{animation:none !important;transition:none !important;' +
        'transform:none !important;translate:none !important;scale:none !important;' +
        'rotate:none !important}';
      document.head.appendChild(neutraliser);
      // pin/pan/kinetic/wipe/drift are the only devices drive() publishes
      // --motion-p for. A section whose subtree carries none of them has
      // nothing pinning progress open across [top, top+height-viewport], so
      // it gets a different sampling window below (see the walk loop).
      const SCRUB = ['pin', 'pan', 'kinetic', 'wipe', 'drift'];
      const els = document.querySelectorAll('section, [data-motion]');
      const out = [];
      els.forEach((el, i) => {
        const r = el.getBoundingClientRect();
        // A zero-height element (a display:none mobile-only section at desktop
        // width, most often) collapses the scrub range to 1px, so every sample
        // lands on the same frame and the walk reports dead scroll for a section
        // that is not on screen at all. /wp-finalize fails the build on that.
        if (r.height <= 0) return;
        const scrub = SCRUB.some(
          (d) => el.matches('[data-motion="' + d + '"]') || el.querySelector('[data-motion="' + d + '"]')
        );
        out.push({
          id: el.id || el.className.toString().split(' ')[0] || 'section',
          top: r.top + window.scrollY,
          height: r.height,
          scrub,
          // Index into the same query, so the two-point reveal check below can
          // re-find this exact element without inventing a selector for it.
          idx: i,
        });
      });
      // Nothing after this read should see the page neutralised: every check below
      // judges the page as it actually paints.
      neutraliser.remove();
      return out;
    });
    if (!sections.length) sections.push(...bounds);

    let shot = 0;
    const peak = new Map();
    // The no-sections fallback has to walk the real document, not a 1px stub:
    // at height 1 every sample landed on scroll 0, so the page was checked for
    // overflow only at the top and came back clean without ever scrolling.
    const pageHeight = await page.evaluate(() => document.documentElement.scrollHeight);
    for (const b of bounds.length ? bounds : [{ id: 'page', top: 0, height: pageHeight, scrub: true }]) {
      let previous = null;
      let stalls = 0;
      let startY, scrubRange;
      if (b.scrub) {
        // Every scrub device shares start: 'top top', end: 'bottom bottom', so the
        // real scrub range ends at top + height - viewportHeight, not top + height,
        // whenever a section is taller than the viewport (the normal case for a
        // pin section with span > 1). Sampling past that point walks into the
        // flat tail where progress is clamped at 1 and reports it as dead scroll.
        // A section SHORTER than the viewport has an inverted range (its end sits
        // above its top), so clamping with max(1, height - viewport) collapsed
        // every sample onto a single pixel and reported the section as dead
        // scroll. Derive both ends from geometry and walk between them.
        const clampedEnd = Math.max(0, b.top + b.height - size.height);
        scrubRange = Math.max(1, Math.abs(clampedEnd - b.top));
        startY = Math.min(b.top, clampedEnd);
      } else {
        // No pin/pan/kinetic/wipe/drift device in this section's subtree, so
        // there is nothing holding scrub progress open past entry — the case
        // above's window starts exactly at "fully entered" (view()'s entry
        // 100%), which is already past where a reveal-only section's
        // animation-range (entry 0%-40%, up to 68% staggered) finishes. Walk
        // the entry itself instead: from first appearance, one viewport above
        // top, to fully entered at top.
        startY = Math.max(0, b.top - size.height);
        scrubRange = Math.max(1, b.top - startY);
      }
      for (let k = 0; k < positions; k++) {
        const y = startY + (scrubRange * k) / Math.max(1, positions - 1);
        await page.evaluate((to) => window.scrollTo(0, to), y);
        await page.waitForTimeout(180);
        const frame = await page.evaluate(probe, b.idx);
        await page.screenshot({ path: join(dir, String(shot++).padStart(3, '0') + '.png') });

        // Keyed by element index, not text: two cues sharing a string are real
        // and distinct DOM elements, and collapsing them by text would mask
        // one instance never peaking behind another that does.
        frame.cues.forEach((c) => {
          const prior = peak.get(c.i);
          peak.set(c.i, { text: c.text, max: Math.max(prior ? prior.max : 0, c.opacity) });
        });
        // Every finding records which pass produced it: a defect that only
        // appears under reduced motion needs a different fix from the same
        // symptom in the normal pass, and without this they were identical
        // rows in findings.json.
        const pass = reduced ? 'reduced' : 'normal';
        // Deduplicated like clipped copy: the same boxes sticking out at every
        // sampled position are one defect per width, not one row per position.
        if (frame.overflow) {
          const key = pass + '|' + size.width + '|' + frame.culprits.map((c) => c.selector).join(',');
          if (!overflowSeen.has(key)) {
            overflowSeen.add(key);
            const row = { kind: 'overflow', pass, width: size.width, section: b.id, y: Math.round(y), culprits: frame.culprits };
            if (frame.culprits.some((c) => c.escapes))
              row.hint = 'a position:absolute box escapes the overflow of the box named in `escapes`: its containing block sits outside it -- give an ancestor inside that box position:relative';
            findings.push(row);
          }
        }
        // One element clipped at every scroll position is one defect, not one per
        // sample. Undeduplicated, a single element reported once per section x width x
        // position, which buried the rest of the report under a repeated line.
        frame.clipped.forEach((c) => {
          const key = pass + '|' + b.id + '|' + size.width + '|' + c.i;
          if (clippedSeen.has(key)) return;
          clippedSeen.add(key);
          findings.push({ kind: 'clipped-copy', pass, width: size.width, section: b.id, text: c.text });
        });
        if (previous !== null && frame.signature === previous) stalls++;
        else stalls = 0;
        if (stalls >= 2 && !reduced) {
          // A page with no devices cannot stall its way to a finding under the
          // old guard, so a motionless demo walked clean. It fails loudly now.
          // Counted document-wide on purpose: see probe's pageDevices. The push
          // sits on the line directly under this guard, and its check pins it
          // there — moving it into the branch below turns "this demo does not
          // move" into "this section has no device", which blocks a plain
          // <section> on a moving page.
          if (frame.pageDevices === 0) {
            findings.push({ kind: 'no-engine', pass, width: size.width, section: b.id, y: Math.round(y) });
          } else if (frame.devices === 0) {
            // A plain <section> on a page that does move. Nothing to read and
            // nothing broken — not even advisory. Silence is the finding.
          } else if (frame.samplable === 0 && !b.scrub) {
            // The harness cannot read these devices, which is not the same claim
            // as "this section does not move". Advisory, so it never fails a
            // round on the strength of what the harness could not see.
            //
            // Only when the section carries no SCRUB device. drive() is
            // contractually required to publish --motion-p for pin/pan/kinetic/
            // wipe/drift, so on one of those, nothing samplable does not mean
            // "unreadable device" — it means the engine never ran, which is the
            // exact failure this branch exists to catch (file:// blocking the
            // module script shipped a demo the client rejected). That falls
            // through to the blocking dead-scroll below.
            findings.push({ kind: 'unobserved', pass, width: size.width, section: b.id, y: Math.round(y), devices: frame.devices });
          } else if (b.scrub) {
            // Only a scrubbed section is judged by the walk. A section whose
            // devices are all entry-driven is judged by the two-point check
            // after this loop, which does not depend on sampling density.
            findings.push({ kind: 'dead-scroll', pass, width: size.width, section: b.id, y: Math.round(y) });
          }
        }
        previous = frame.signature;
      }

      // The two-point reveal assertion. Below the fold, then fully entered: if
      // any reveal child moved, the section is alive. Its one blind spot is a
      // reveal that animates and returns exactly to its start state, which
      // describes no reveal in the library.
      // ponytail: a section that starts above the fold cannot be parked below
      // it, so it is not judged at all — its entry already happened on load.
      const belowFold = b.top - size.height - 40;
      if (!b.scrub && !reduced && belowFold >= 0) {
        await page.evaluate((to) => window.scrollTo(0, to), belowFold);
        await page.waitForTimeout(180);
        const before = await page.evaluate(revealState, b.idx);
        if (before !== '') {
          await page.evaluate((to) => window.scrollTo(0, to), b.top);
          await page.waitForTimeout(300);
          const after = await page.evaluate(revealState, b.idx);
          if (after === before)
            findings.push({ kind: 'dead-scroll', pass: 'normal', width: size.width, section: b.id, y: Math.round(b.top) });
        }
      }
    }
    if (!reduced) {
      for (const { text, max } of peak.values()) {
        // Below 0.85 a line is never graded for contrast anywhere, and the reader
        // sees washed-out type at whatever position they stop on.
        if (max < 0.85) findings.push({ kind: 'cue-never-peaks', pass: 'normal', width: size.width, text, max: Number(max.toFixed(2)) });
      }
    }

    // The contact sheet. Reading the frames side by side is the whole point;
    // a folder of PNGs never gets looked at that way. Written to a real file and
    // loaded via file://, because Chromium blocks file:// subresources (the <img>
    // tags below) from a setContent()/about:blank document context.
    const files = Array.from({ length: shot }, (_, n) => String(n).padStart(3, '0') + '.png');
    const sheetHtml =
      '<body style="margin:0;background:#111;display:grid;grid-template-columns:repeat(6,1fr);gap:4px">' +
      files.map((f) => '<img src="' + f + '" style="width:100%;display:block">').join('') +
      '</body>';
    writeFileSync(join(dir, 'sheet.html'), sheetHtml);
    const sheet = await browser.newPage({ ...TLS });
    await sheet.setViewportSize({ width: 1200, height: 800 });
    await sheet.goto(pathToFileURL(join(dir, 'sheet.html')).href, { waitUntil: 'load' });
    await sheet.waitForTimeout(400);
    await sheet.screenshot({ path: join(dir, 'sheet.png'), fullPage: true });
    // The read copy: same grid, narrower viewport, re-encoded as JPEG. Resizing the
    // already-loaded page reflows the CSS grid in place, so this is one extra
    // screenshot, not a second render pass or a new dependency.
    await sheet.setViewportSize({ width: SHEET_JPEG_WIDTH, height: 800 });
    await sheet.waitForTimeout(150);
    await sheet.screenshot({
      path: join(dir, 'sheet.jpg'),
      fullPage: true,
      type: 'jpeg',
      quality: SHEET_JPEG_QUALITY,
    });
    await sheet.close();
    await context.close();
  }
}

  // A selector is dead only if no element matching it had a container-establishing
  // ancestor at ANY width walked: the intersection, never the union. The finding's
  // shape is unchanged; `width` names the first width the audit ran at.
  // Scroll-reactive means: reacts to the page moving. `reveal` fires once on entry and
  // the pointer devices need a cursor, so a page holding only those cannot respond to a
  // scroll at all — which is the complaint a reader makes as "nothing happens here",
  // while the device count says the page is busy.
  if (containFreeze) {
    for (const f of findings) {
      if (f.kind === 'dead-scroll' && !f.hint) {
        f.hint = 'a scroll-subject ancestor sets container-type (' + containFreeze +
          '), which freezes animation-timeline: view() -- remove it before looking anywhere else';
      }
    }
  }

  if (mix) {
    const kinds = Object.keys(mix.devices);
    const scrollReactive = kinds.filter((k) => SCROLL_REACTIVE_DEVICES.has(k));
    if (kinds.length && !scrollReactive.length && !mix.cssScroll) {
      findings.push({
        kind: 'static-page',
        pass: 'normal',
        width: widths[0].width,
        devices: mix.devices,
        detail: 'only reveal and pointer devices: nothing on this page reacts to scrolling',
      });
    }
  }

  if (containerNoop.length) {
    for (const sel of containerNoop.reduce((a, b) => a.filter((s) => b.includes(s))))
      findings.push({ kind: 'container-noop', pass: 'normal', width: widths[0].width, selector: sel });
  }

  await captureResponsiveShots(browser, pageUrl, pageOut);
  // Firefox is the second engine, never a requirement: a crash mid-pass keeps the
  // Chromium findings and says so, like a Firefox that never launched.
  if (ffBrowser) {
    try {
      await captureResponsiveShots(ffBrowser, pageUrl, join(pageOut, 'firefox'));
      for (const size of widths) findings.push(...(await engineDeltas(browser, ffBrowser, pageUrl, size)));
    } catch (err) {
      const why = err && typeof err.message === 'string' ? err.message.split('\n')[0] : String(err);
      console.error('demo-verify: Firefox pass failed on ' + pageUrl + ' (' + why + ') -- Chromium findings kept');
    }
  }
  report.pages.push({ url: pageUrl, findings });
  } catch (err) {
    // Keep whatever this page did find before it died: a section list that
    // stops half way is still evidence, and the reason is on the row.
    // Coerce before splitting: a thrown value whose .message is not a string
    // would throw again HERE, inside the handler, and that exception reaches the
    // walk-level catch and aborts the whole directory — the exact failure this
    // block exists to prevent.
    const msg = err && typeof err.message === 'string' ? err.message : String(err);
    const why = msg.split('\n')[0];
    findings.push({ kind: 'page-crashed', pass: 'normal', width: 0, error: why });
    report.pages.push({ url: pageUrl, findings });
    console.error('demo-verify: ' + basename(pageTarget) + ' crashed, continuing: ' + why);
    exitCode = Math.max(exitCode, 1);
  }
  }

  mkdirSync(outDir, { recursive: true });
  // Tag advisory rows in the artifact, not only on stdout: a consumer reading
  // findings.json otherwise has to carry its own copy of the kind list to know
  // why a run with findings exited 0, and that copy goes stale the moment a
  // kind joins ADVISORY. Blocking rows carry no flag — absence is the default.
  for (const p of report.pages)
    for (const f of p.findings) if (ADVISORY.has(f.kind)) f.advisory = true;
  writeFileSync(join(outDir, 'findings.json'), JSON.stringify(report, null, 2));
  const total = report.pages.reduce((n, p) => n + p.findings.length, 0);
  const blocking = report.pages.reduce((n, p) => n + p.findings.filter((f) => !ADVISORY.has(f.kind)).length, 0);
  const advisory = total - blocking;
  if (total === 0) {
    console.log('demo-verify: no machine findings on ' + report.pages.length + ' page(s). Read the contact sheets before calling this a pass.');
  } else {
    // Advisory lines carry the word on the line itself: a reader scanning the
    // output has to be able to see why the run exited 0 with findings on screen.
    for (const p of report.pages)
      for (const f of p.findings)
        console.log(
          'FINDING ' + f.kind + (ADVISORY.has(f.kind) ? ' [advisory]' : '') + ' ' + basename(p.url) + ' ' + JSON.stringify(f)
        );
    console.log(
      blocking === 0
        ? 'demo-verify: nothing blocking, ' + advisory + ' advisory finding(s). Sheets under ' + outDir
        : 'demo-verify: ' + blocking + ' blocking finding(s)' +
            (advisory ? ' and ' + advisory + ' advisory' : '') + '. Sheets under ' + outDir
    );
  }
  exitCode = blocking === 0 ? 0 : 1;
} catch (err) {
  console.error('demo-verify: the walk crashed:', err && err.stack ? err.stack : err);
  exitCode = 3;
} finally {
  if (http) http.server.close();
  if (ffBrowser) {
    try {
      await ffBrowser.close();
    } catch {
      /* already closed */
    }
  }
  if (browser) {
    try {
      await browser.close();
    } catch {
      /* already closed or never fully opened */
    }
  }
}
process.exit(exitCode);
