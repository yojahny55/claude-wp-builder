#!/usr/bin/env node
/**
 * demo-verify.mjs — walk a demo (or a live page) by scrolling it, and report what
 * only a moving page can show.
 *
 * A scroll page has no single state. Screenshotting the top and the bottom proves
 * nothing about the twelve positions in between, which is where dead scroll,
 * half-faded headlines and clipped copy live.
 *
 * Exit codes: 0 clean, 1 findings, 2 no usable browser (distinct on purpose, so
 * the caller can fall back to MCP screenshot tools rather than reporting a failure).
 */
import { existsSync, mkdirSync, writeFileSync, readdirSync } from 'node:fs';
import { resolve, join, dirname } from 'node:path';
import { homedir } from 'node:os';

const args = process.argv.slice(2);
if (args.includes('--help') || args.length === 0) {
  console.log(
    'usage: demo-verify.mjs <file-or-url> [--out DIR] [--positions N] [--widths 1440x900,390x844]'
  );
  process.exit(args.length === 0 ? 2 : 0);
}

const target = args[0];
const opt = (name, dflt) => {
  const i = args.indexOf(name);
  return i === -1 ? dflt : args[i + 1];
};
const positions = Number(opt('--positions', 6));
const widths = opt('--widths', '1440x900,390x844')
  .split(',')
  .map((s) => {
    const [w, h] = s.split('x').map(Number);
    return { width: w, height: h };
  });
const url = /^https?:\/\//.test(target) ? target : 'file://' + resolve(target);
const outDir = resolve(opt('--out', join(dirname(resolve(target)), '.verify')));

function findChrome() {
  if (process.env.WP_DEMO_CHROME && existsSync(process.env.WP_DEMO_CHROME))
    return process.env.WP_DEMO_CHROME;
  const candidates = [
    '/usr/bin/google-chrome',
    '/usr/bin/google-chrome-stable',
    '/usr/bin/chromium',
    '/usr/bin/chromium-browser',
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  ];
  for (const c of candidates) if (existsSync(c)) return c;
  // Playwright's own download, when the user has run `npx playwright install`.
  // Walked with readdirSync rather than a glob: fs.globSync landed in Node 22 and
  // importing it outright makes this whole script a SyntaxError on Node 18 and 20.
  const cache = join(homedir(), '.cache/ms-playwright');
  if (existsSync(cache)) {
    for (const entry of readdirSync(cache)) {
      for (const tail of [
        'chrome-linux64/chrome',
        'chrome-linux/chrome',
        'chrome-mac/Chromium.app/Contents/MacOS/Chromium',
      ]) {
        const p = join(cache, entry, tail);
        if (existsSync(p)) return p;
      }
    }
  }
  return null;
}

let chromium;
try {
  ({ chromium } = await import('playwright-core'));
} catch {
  console.error('demo-verify: playwright-core is not installed (npm i -D playwright-core)');
  process.exit(2);
}
const executablePath = findChrome();
if (!executablePath) {
  console.error('demo-verify: no Chrome found. Set WP_DEMO_CHROME or run: npx playwright install chrome');
  process.exit(2);
}

/** Read one frame's signature plus its static defects. Runs inside the page. */
const probe = () => {
  const sig = [];
  document.querySelectorAll('[data-motion]').forEach((el) => {
    sig.push(el.style.getPropertyValue('--motion-p') || '');
    const rail = el.querySelector('[data-motion-rail]');
    if (rail) sig.push(rail.style.transform || '');
    if (el.style.clipPath) sig.push(el.style.clipPath);
  });
  const cues = [];
  document.querySelectorAll('[data-motion-cue]').forEach((el, i) => {
    const o = Number(getComputedStyle(el).opacity);
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
    cues,
    clipped,
    overflow: document.documentElement.scrollWidth > window.innerWidth + 1,
    scrollHeight: document.documentElement.scrollHeight,
  };
};

const browser = await chromium.launch({ executablePath, args: ['--autoplay-policy=no-user-gesture-required'] });
const findings = [];
const sections = [];

for (const size of widths) {
  for (const reduced of size === widths[0] ? [false, true] : [false]) {
    const label = size.width + (reduced ? '-reduced' : '');
    const dir = join(outDir, String(label));
    mkdirSync(dir, { recursive: true });
    const context = await browser.newContext({
      viewport: size,
      reducedMotion: reduced ? 'reduce' : 'no-preference',
    });
    const page = await context.newPage();
    await page.goto(url, { waitUntil: 'load' });
    await page.waitForTimeout(600);

    const bounds = await page.evaluate(() => {
      const els = document.querySelectorAll('section, [data-motion]');
      const out = [];
      els.forEach((el) => {
        const r = el.getBoundingClientRect();
        out.push({
          id: el.id || el.className.toString().split(' ')[0] || 'section',
          top: r.top + window.scrollY,
          height: r.height,
        });
      });
      return out;
    });
    if (!sections.length) sections.push(...bounds);

    let shot = 0;
    const peak = new Map();
    for (const b of bounds.length ? bounds : [{ id: 'page', top: 0, height: 1 }]) {
      let previous = null;
      let stalls = 0;
      for (let k = 0; k < positions; k++) {
        const y = b.top + (b.height * k) / Math.max(1, positions - 1);
        await page.evaluate((to) => window.scrollTo(0, to), y);
        await page.waitForTimeout(180);
        const frame = await page.evaluate(probe);
        await page.screenshot({ path: join(dir, String(shot++).padStart(3, '0') + '.png') });

        frame.cues.forEach((c) => {
          peak.set(c.text, Math.max(peak.get(c.text) || 0, c.opacity));
        });
        if (frame.overflow)
          findings.push({ kind: 'overflow', width: size.width, section: b.id, y: Math.round(y) });
        frame.clipped.forEach((t) =>
          findings.push({ kind: 'clipped-copy', width: size.width, section: b.id, text: t })
        );
        if (previous !== null && frame.signature === previous && frame.signature !== '') stalls++;
        else stalls = 0;
        if (stalls >= 2 && !reduced)
          findings.push({ kind: 'dead-scroll', width: size.width, section: b.id, y: Math.round(y) });
        previous = frame.signature;
      }
    }
    if (!reduced) {
      for (const [text, max] of peak) {
        // Below 0.85 a line is never graded for contrast anywhere, and the reader
        // sees washed-out type at whatever position they stop on.
        if (max < 0.85) findings.push({ kind: 'cue-never-peaks', width: size.width, text, max: Number(max.toFixed(2)) });
      }
    }

    // The contact sheet. Reading the frames side by side is the whole point;
    // a folder of PNGs never gets looked at that way.
    const files = Array.from({ length: shot }, (_, n) => String(n).padStart(3, '0') + '.png');
    const sheet = await browser.newPage();
    await sheet.setViewportSize({ width: 1200, height: 800 });
    await sheet.setContent(
      '<body style="margin:0;background:#111;display:grid;grid-template-columns:repeat(6,1fr);gap:4px">' +
        files
          .map(
            (f) =>
              '<img src="file://' + join(dir, f) + '" style="width:100%;display:block">'
          )
          .join('') +
        '</body>'
    );
    await sheet.waitForTimeout(400);
    await sheet.screenshot({ path: join(dir, 'sheet.png'), fullPage: true });
    await sheet.close();
    await context.close();
  }
}

await browser.close();
mkdirSync(outDir, { recursive: true });
writeFileSync(join(outDir, 'findings.json'), JSON.stringify({ url, findings }, null, 2));

if (findings.length === 0) {
  console.log('demo-verify: no machine findings. Read the contact sheets before calling this a pass.');
  process.exit(0);
}
for (const f of findings) console.log('FINDING ' + f.kind + ' ' + JSON.stringify(f));
console.log('demo-verify: ' + findings.length + ' finding(s). Sheets under ' + outDir);
process.exit(1);
