// Drive the motion.js `pan` device in a real browser under reduced motion, and assert
// what it did to the DOM.
//
// Why this exists: CLAUDE.md records that motion.js's behaviour under reduced motion is
// reasoned about and not walked -- "nothing in the suite runs a browser". Everything the
// pan device does there is a judgment nobody can grep: it picks the scroller BY
// MEASUREMENT rather than by name, it makes that box focusable, it names it from the
// section's own heading, and when neither box overflows it deliberately attaches nothing.
// That last one is a negative behaviour, which is exactly the kind a contract grep can
// never see and a refactor silently loses.
//
// Usage: node tests/fixtures/motion/drive.mjs
// Exits 0 on success, 1 on a failed assertion, 2 when no browser is available.

import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { join, dirname, extname } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const repo = join(here, '..', '..', '..');
const MOTION = join(repo, 'starter-theme', '__tailwind__', 'assets', 'js', 'src', 'motion.js');
// The real pinned GSAP, served from node_modules rather than a CDN: a check that reaches
// the network to fetch its engine fails for reasons that have nothing to do with the code
// under test.
const VENDOR = {
  '/gsap.min.js': join(repo, 'node_modules', 'gsap', 'dist', 'gsap.min.js'),
  '/ScrollTrigger.min.js': join(repo, 'node_modules', 'gsap', 'dist', 'ScrollTrigger.min.js'),
};

let failed = 0;
const t = (label, got, want) => {
  const ok = JSON.stringify(got) === JSON.stringify(want);
  if (!ok) {
    console.log(`FAIL [${label}]\n  got:  ${JSON.stringify(got)}\n  want: ${JSON.stringify(want)}`);
    failed = 1;
  } else {
    console.log(`ok   [${label}]`);
  }
};

// Served over HTTP rather than opened as file://, because motion.js is an ES module and a
// module import from a file:// page is blocked by CORS in Chrome. CLAUDE.md already notes
// that verification serves over HTTP while the delivered demo is a file:// artifact.
const types = { '.html': 'text/html', '.js': 'text/javascript' };
const server = createServer(async (req, res) => {
  const path = (req.url || '/').split('?')[0];
  // Chrome asks for /favicon.ico on every navigation, and a 404 for it is logged as a
  // console error -- which the assertion below reads as "a section failed". Answering it
  // with 204 removes the noise at its source rather than teaching the assertion to ignore
  // a class of error that would also hide a real missing resource.
  if (path === '/favicon.ico') {
    res.writeHead(204).end();
    return;
  }
  try {
    const file =
      path === '/motion.js' ? MOTION
      : VENDOR[path] ? VENDOR[path]
      : join(here, path === '/' ? 'pan.html' : path);
    if (!file.startsWith(here) && file !== MOTION && !Object.values(VENDOR).includes(file)) {
      res.writeHead(403).end('no');
      return;
    }
    const body = await readFile(file);
    res.writeHead(200, { 'content-type': types[extname(file)] || 'text/plain' }).end(body);
  } catch {
    res.writeHead(404).end('not found');
  }
});

await new Promise((r) => server.listen(0, '127.0.0.1', r));
const base = `http://127.0.0.1:${server.address().port}`;

let chromium;
try {
  ({ chromium } = await import('playwright-core'));
} catch {
  console.log('SKIP: playwright-core is not installed');
  server.close();
  process.exit(2);
}

// The same resolution ladder the other bin/*.mjs tools use: an explicit override first,
// then a system Chrome. No download is attempted -- a check that installs a browser is a
// check that fails differently on a cold machine.
const candidates = [
  process.env.CHROME_PATH,
  '/usr/bin/google-chrome',
  '/usr/bin/chromium',
  '/usr/bin/chromium-browser',
].filter(Boolean);

let browser = null;
for (const executablePath of candidates) {
  try {
    browser = await chromium.launch({ executablePath, args: ['--no-sandbox'] });
    break;
  } catch {
    /* try the next one */
  }
}
if (!browser) {
  console.log('SKIP: no usable Chrome found (set CHROME_PATH)');
  server.close();
  process.exit(2);
}

// reducedMotion is the whole point: this is the branch the suite has never walked.
const context = await browser.newContext({ reducedMotion: 'reduce', viewport: { width: 1280, height: 800 } });
const page = await context.newPage();
const errors = [];
page.on('pageerror', (e) => errors.push(String(e)));
// console.error too, not just pageerror. motion.js wraps each section in its own
// try/catch so that one bad section cannot abort the rest of the page -- which means a
// section that throws is reported to the console and never reaches 'pageerror'. Without
// this listener a throw inside a device is invisible here: the DOM simply lacks whatever
// that section was going to add, and an assertion about what is absent passes for the
// wrong reason. Measured -- removing the heading guard in the pan device makes it throw,
// and every DOM assertion still passed.
page.on('console', (m) => {
  if (m.type() === 'error') errors.push(m.text());
  // A section that throws is caught by motion.js's own per-section try/catch and reported
  // with console.WARN, not error -- "Fail that section loudly, keep the rest running".
  // Loudly means to the console, and until this listener existed nothing here was
  // listening: a device that threw left a DOM that simply lacked whatever it would have
  // added, and every assertion about what is absent passed for the wrong reason.
  //
  // Matched narrowly on the initialise-failure wording rather than on warnings in
  // general, because motion.js warns legitimately about authoring choices it does not
  // intend to override -- a pin span below 1.2, a pin above 2.0 with no peak. Failing on
  // those would make this check fire on a fixture that is working as designed.
  if (m.type() === 'warning' && /\[motion\] failed to initialise/.test(m.text())) {
    errors.push(m.text());
  }
});
await page.goto(`${base}/pan.html`);
await page.waitForFunction('window.__motionReady === true', null, { timeout: 20000 });

t('no section threw or logged an error', errors, []);

const read = (sel) =>
  page.evaluate((s) => {
    const section = document.querySelector(s);
    const rail = section.querySelector('[data-motion-rail]');
    const frame = rail.parentElement;
    const pick = (el) => ({
      tabindex: el.getAttribute('tabindex'),
      role: el.getAttribute('role'),
      labelled: el.hasAttribute('aria-labelledby'),
      overflows: el.scrollWidth > el.clientWidth,
    });
    return { rail: pick(rail), frame: pick(frame), overflowX: rail.style.overflowX };
  }, sel);

// --- Case A: the rail overflows and the section has a heading ---------------------------
const a = await read('#a');
t('A: reduced motion hands the rail back as a scroll region', a.overflowX, 'auto');
t('A: the overflowing box is the one measured as the scroller', a.rail.overflows, true);
t('A: the scroller is reachable by keyboard', a.rail.tabindex, '0');
t('A: the scroller is a named region', [a.rail.role, a.rail.labelled], ['region', true]);
t('A: the frame is not also made focusable', a.frame.tabindex, null);

// --- Case B: nothing overflows ----------------------------------------------------------
// The one that matters most. Attaching the affordance anyway ships a focusable, named
// region that scrolls nothing -- a dead tab stop by another route.
const b = await read('#b');
t('B: nothing overflows', [b.rail.overflows, b.frame.overflows], [false, false]);
t('B: no dead tab stop on the rail', b.rail.tabindex, null);
t('B: no dead tab stop on the frame', b.frame.tabindex, null);
t('B: no region role when nothing scrolls', [b.rail.role, b.frame.role], [null, null]);

// --- Case C: overflows, but there is no heading to name it ------------------------------
const c = await read('#c');
t('C: an unnameable scroller is still reachable', c.rail.tabindex, '0');
t('C: an unnamed region is not made a landmark', [c.rail.role, c.rail.labelled], [null, false]);

// --- the keyboard affordance actually moves the right box -------------------------------
// tabindex alone proves reachability, not that arrow keys scroll the thing the user sees
// moving. Focus the scroller and press End.
await page.focus('#a [data-motion-rail]');
const beforeLeft = await page.evaluate(() => document.querySelector('#a [data-motion-rail]').scrollLeft);
// ArrowRight, not End: End is scroll-to-bottom and moves a box vertically, so a
// horizontal rail does not move and the assertion fails on the test rather than on the
// code. Measured -- End left scrollLeft at 0 here.
await page.keyboard.press('ArrowRight');
await page.keyboard.press('ArrowRight');

// Waited for, not slept on. Scrolling is not synchronous with the keypress, so reading
// scrollLeft after a fixed delay is a race: it passed on an idle machine and lost once
// inside a full suite run, which is the worst way for a check to behave -- an unexplained
// red that everyone learns to re-run. Polling for the condition removes the timing
// dependency instead of widening the window and hoping.
let afterLeft = beforeLeft;
try {
  await page.waitForFunction(
    (before) => document.querySelector('#a [data-motion-rail]').scrollLeft > before,
    beforeLeft,
    { timeout: 5000 }
  );
  afterLeft = await page.evaluate(() => document.querySelector('#a [data-motion-rail]').scrollLeft);
} catch {
  afterLeft = await page.evaluate(() => document.querySelector('#a [data-motion-rail]').scrollLeft);
}
t('A: the keyboard scrolls the scroller, not the document', afterLeft > beforeLeft, true);

// ---------------------------------------------------------------------------------------
// Default motion: the branch where ScrollTrigger actually runs.
//
// Everything above drives the reduced-motion path with stubbed gsap objects, which is
// honest there because that path never calls them. This pass uses the real pinned GSAP and
// no reducedMotion override, so the scrub and the reveal below are the engine doing its
// job rather than a description of it. CLAUDE.md recorded both as walked by nobody.
// ---------------------------------------------------------------------------------------
const motionCtx = await browser.newContext({ viewport: { width: 1280, height: 800 } });
const page2 = await motionCtx.newPage();
const errors2 = [];
page2.on('pageerror', (e) => errors2.push(String(e)));
page2.on('console', (m) => {
  if (m.type() === 'error') errors2.push(m.text());
  if (m.type() === 'warning' && /\[motion\] failed to initialise/.test(m.text())) errors2.push(m.text());
});
await page2.goto(`${base}/scroll.html`);
await page2.waitForFunction('window.__motionReady === true', null, { timeout: 20000 });

t('default motion: no section threw or logged an error', errors2, []);
t('default motion: the reveal branch is reachable', await page2.evaluate(() => window.__forcedNoTimeline), true);

// --- pan: the rail's transform tracks scroll progress ----------------------------------
const railX = () =>
  page2.evaluate(() => {
    const el = document.querySelector('#pan [data-motion-rail]');
    const m = /translate3d\((-?[\d.]+)px/.exec(el.style.transform || '');
    return m ? parseFloat(m[1]) : null;
  });

await page2.evaluate(() => window.scrollTo(0, 0));
await page2.waitForTimeout(200);
const xTop = await railX();

// Scroll into the middle of the pinned section, where progress is neither 0 nor 1.
await page2.evaluate(() => {
  const s = document.querySelector('#pan');
  window.scrollTo(0, s.offsetTop + s.offsetHeight / 2);
});
await page2.waitForFunction(
  () => {
    const el = document.querySelector('#pan [data-motion-rail]');
    const m = /translate3d\((-?[\d.]+)px/.exec(el.style.transform || '');
    return m && parseFloat(m[1]) < -1;
  },
  null,
  { timeout: 5000 }
).catch(() => {});
const xMid = await railX();

t('pan: ScrollTrigger wrote a transform at all', xMid !== null, true);
// Negative and moving: the device translates the rail leftwards as progress grows, so a
// value that stayed at 0 means the trigger was created and never driven -- wired, not
// working, which is the distinction this whole check exists to make.
t('pan: the rail moved leftwards as the page scrolled', xMid !== null && xMid < (xTop === null ? 0 : xTop), true);

// --- reveal: the GSAP branch hides its children, then shows them ------------------------
const opacities = () =>
  page2.evaluate(() =>
    Array.prototype.map.call(document.querySelectorAll('#reveal p'), (n) =>
      parseFloat(getComputedStyle(n).opacity)
    )
  );

await page2.evaluate(() => window.scrollTo(0, 0));
await page2.waitForTimeout(200);
const hidden = await opacities();
t('reveal: children start hidden', hidden.every((o) => o < 0.5), true);

await page2.evaluate(() => document.querySelector('#reveal').scrollIntoView({ block: 'center' }));
await page2.waitForFunction(
  () => Array.prototype.every.call(document.querySelectorAll('#reveal p'), (n) => parseFloat(getComputedStyle(n).opacity) > 0.9),
  null,
  { timeout: 5000 }
).catch(() => {});
const shown = await opacities();
t('reveal: children are visible after scrolling them into view', shown.every((o) => o > 0.9), true);

await browser.close();
server.close();
console.log(failed ? 'MOTION FAILED' : 'MOTION OK');
process.exit(failed);
