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

// Advisory kinds report what the harness could not see, not what the page got
// wrong, so they are printed and written to findings.json but never raise the
// exit code — a gate that fails a round on the strength of what it could not
// read gets overruled in prose, and then so does every gate beside it. Every
// other kind blocks. Listed here, once, so a new kind joins a list instead of
// re-deriving the rule at the exit.
const ADVISORY = new Set(['unobserved', 'external-module']);

const args = process.argv.slice(2);
if (args.includes('--help')) {
  console.log(
    'usage: demo-verify.mjs [file-or-dir-or-url] [--out DIR] [--positions N] [--widths 1440x900,390x844]\n' +
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
  // Playwright's own download, when the user has run `npx playwright install`.
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
try {
  if (process.env.PLAYWRIGHT_CORE) {
    ({ chromium } = await import(pathToFileURL(resolve(process.env.PLAYWRIGHT_CORE, 'index.mjs')).href));
  } else {
    try {
      ({ chromium } = await import('playwright-core'));
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
      ({ chromium } = await import(pathToFileURL(cwdEntry).href));
    }
  }
} catch {
  console.error(PROBE ? 'probe: missing playwright-core' : 'demo-verify: playwright-core is not installed (npm i -D playwright-core)');
  process.exit(2);
}
const executablePath = findChrome();
if (!executablePath) {
  console.error(PROBE ? 'probe: missing chrome' : 'demo-verify: no Chrome found. Set WP_DEMO_CHROME or run: npx playwright install chrome');
  process.exit(2);
}
if (PROBE) {
  console.log('probe: ok ' + executablePath);
  process.exit(0);
}

// The five legacy /wp-responsive-check viewports. One full-page shot each, at the
// top of the page, no scroll-walk: this is layout coverage, not motion coverage.
const RESPONSIVE_WIDTHS = [375, 576, 768, 1024, 1440];

/** One full-page screenshot per legacy viewport, filenames responsive-<width>.png,
 *  restoring the convention /wp-tailwind-migrate's visual-golden workflow depends on. */
async function captureResponsiveShots(browser, url, outDir) {
  for (const width of RESPONSIVE_WIDTHS) {
    const height = width <= 480 ? 812 : 900;
    const context = await browser.newContext({ viewport: { width, height } });
    const page = await context.newPage();
    await page.goto(url, { waitUntil: 'load' });
    await page.waitForTimeout(400);
    await page.screenshot({ path: join(outDir, 'responsive-' + width + '.png'), fullPage: true });
    await context.close();
  }
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
  const clipped = [];
  document.querySelectorAll('p, h1, h2, h3, li').forEach((el) => {
    if (el.scrollHeight > el.clientHeight + 2 && getComputedStyle(el).overflow === 'hidden') {
      clipped.push((el.textContent || '').trim().slice(0, 60));
    }
  });
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
let http = null;
let exitCode = 0;
const report = { pages: [] };

try {
  browser = await chromium.launch({ executablePath, args: ['--autoplay-policy=no-user-gesture-required'] });

  for (const pageTarget of pages) {
  const isRemote = /^https?:\/\//.test(pageTarget);
  // Loading a local page as file:// puts it on an opaque origin, where Chrome
  // blocks an external `<script type="module">` outright — the engine never
  // boots and every section reports dead scroll, silently. Serving removes
  // the whole class. One server per page, closed before the next is opened;
  // process.exit() at the very end reclaims whichever one is still open.
  if (http) { http.server.close(); http = null; }
  let pageUrl = pageTarget;
  if (!isRemote) {
    const abs = resolve(pageTarget);
    const root = statSync(abs).isDirectory() ? abs : dirname(abs);
    http = await serve(root);
    const leaf = statSync(abs).isDirectory() ? 'index.html' : basename(abs);
    pageUrl = `http://127.0.0.1:${http.port}/${leaf}`;
  }
  const pageOut = pages.length > 1 ? join(outDir, basename(pageTarget, '.html')) : outDir;
  const findings = [];
  const sections = [];
  let staticChecked = false;

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
    });
    const page = await context.newPage();
    await page.goto(pageUrl, { waitUntil: 'load' });
    await page.waitForTimeout(600);

    // Both static: independent of scroll position, so read once per page
    // rather than once per width/reduced-motion pass.
    if (!staticChecked) {
      staticChecked = true;
      for (const sel of await page.evaluate(containerAudit)) {
        findings.push({ kind: 'container-noop', pass: 'normal', width: size.width, selector: sel });
      }
      const external = await page.$$eval('script[type="module"][src]', (n) => n.map((s) => s.getAttribute('src')));
      for (const src of external) {
        findings.push({ kind: 'external-module', pass: 'normal', width: size.width, src });
      }
    }

    const bounds = await page.evaluate(() => {
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
        if (frame.overflow)
          findings.push({ kind: 'overflow', pass, width: size.width, section: b.id, y: Math.round(y) });
        frame.clipped.forEach((t) =>
          findings.push({ kind: 'clipped-copy', pass, width: size.width, section: b.id, text: t })
        );
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
    const sheet = await browser.newPage();
    await sheet.setViewportSize({ width: 1200, height: 800 });
    await sheet.goto(pathToFileURL(join(dir, 'sheet.html')).href, { waitUntil: 'load' });
    await sheet.waitForTimeout(400);
    await sheet.screenshot({ path: join(dir, 'sheet.png'), fullPage: true });
    await sheet.close();
    await context.close();
  }
}

  await captureResponsiveShots(browser, pageUrl, pageOut);
  mkdirSync(pageOut, { recursive: true });
  report.pages.push({ url: pageUrl, findings });
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
  if (browser) {
    try {
      await browser.close();
    } catch {
      /* already closed or never fully opened */
    }
  }
}
process.exit(exitCode);
