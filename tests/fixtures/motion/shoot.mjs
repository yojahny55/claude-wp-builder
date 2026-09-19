// Render the motion fixtures to PNGs: the capture half of the screenshot-pair check.
//
// I06 asks for approved screenshot pairs "matching fonts, content, viewports, animation
// states", and specifically for a "reduced motion motion-engine fallback scenario". The
// pairs here are the same page rendered with the engine running and with it stood down,
// plus the engine's own states along a scroll.
//
// Usage: node tests/fixtures/motion/shoot.mjs <outdir>
// Exits 0 after writing every shot, 2 when no browser is available.
//
// Determinism is the whole job. Every shot below is taken only after the thing it is
// photographing has STOPPED MOVING -- settle() polls a measured value until two
// consecutive reads agree. A screenshot taken at a fixed delay after a scroll photographs
// whatever frame the machine happened to reach, which is a baseline that disagrees with
// itself between runs and teaches everyone to raise the tolerance until it passes.
//
// That buys determinism and costs transient states: these shots can only ever show a
// settled one. Measured -- breaking the reveal so it never hides its children changes
// nothing any baseline here can see, because every frame of that section these PNGs hold
// is taken after it has finished animating in. That case belongs to
// tests/checks/motion-devices.sh, which asserts "reveal: children start hidden" and does
// catch it. The division is deliberate: pixels for what a settled page looks like, the DOM
// check for what happens on the way there.

import { mkdir, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { serveFixtures, launchChrome } from './harness.mjs';

const outdir = process.argv[2];
if (!outdir) {
  console.log('usage: node shoot.mjs <outdir>');
  process.exit(1);
}
await mkdir(outdir, { recursive: true });

const { server, base } = await serveFixtures();
const browser = await launchChrome();
if (!browser) {
  server.close();
  process.exit(2);
}

const shots = [];
const shoot = async (page, name) => {
  const path = join(outdir, name + '.png');
  await page.screenshot({ path, fullPage: false });
  shots.push(name);
  console.log('shot ' + name);
};

// Poll `probe` until two consecutive reads agree, then return. A timeout is not a failure
// here -- it means the value never settled, which the assertions in drive.mjs are the
// right place to catch. This function's only job is to not photograph a moving target.
const settle = async (page, probe, tries = 40) => {
  let last = null;
  for (let i = 0; i < tries; i++) {
    const now = await page.evaluate(probe);
    if (i > 0 && JSON.stringify(now) === JSON.stringify(last)) return now;
    last = now;
    await page.waitForTimeout(50);
  }
  return last;
};

const railX = () => {
  const el = document.querySelector('#pan [data-motion-rail]');
  if (!el) return null;
  const m = /translate3d\((-?[\d.]+)px/.exec(el.style.transform || '');
  return m ? Math.round(parseFloat(m[1])) : null;
};
const revealOpacity = () =>
  Array.prototype.map.call(document.querySelectorAll('#reveal p'), (n) =>
    Math.round(parseFloat(getComputedStyle(n).opacity) * 100)
  );

const open = async (opts, url) => {
  const ctx = await browser.newContext(opts);
  const page = await ctx.newPage();
  await page.goto(`${base}/${url}`);
  await page.waitForFunction('window.__motionReady === true', null, { timeout: 20000 });
  return page;
};

// --- the reduced-motion fallback, at both viewports -------------------------------------
// Under reduced motion the pan device attaches a scroll affordance instead of animating,
// so what these two show is the fallback a user with the OS setting on actually sees.
for (const [w, h, label] of [[1280, 800, '1280'], [390, 844, '390']]) {
  const page = await open({ reducedMotion: 'reduce', viewport: { width: w, height: h } }, 'pan.html');
  await settle(page, () => document.body.scrollHeight);
  await shoot(page, `pan-reduced-${label}`);
  await page.context().close();
}

// --- the same page with the engine standing down, and with it running -------------------
// The pair I06 names. Both passes visit the SAME two scroll positions, so each pair
// differs only in whether the motion engine ran.
//
// The first version of this photographed both at the top of the page and the two PNGs
// came out byte-identical: the pan and reveal sections are below the fold there, so the
// "pair" framed a region where nothing differs and would have passed with the entire
// reduced-motion path broken. A baseline that cannot fail is worse than no baseline,
// because it reports coverage. Each pair below is taken where the engine's effect is
// actually in frame.
const atPan = () => {
  const s = document.querySelector('#pan');
  window.scrollTo(0, s.offsetTop + s.offsetHeight / 2);
};
const atReveal = () => document.querySelector('#reveal').scrollIntoView({ block: 'center' });

const reduced = await open({ reducedMotion: 'reduce', viewport: { width: 1280, height: 800 } }, 'scroll.html');
await reduced.evaluate(atPan);
await settle(reduced, railX);
await shoot(reduced, 'scroll-reduced-pan-1280');
await reduced.evaluate(atReveal);
await settle(reduced, revealOpacity);
await shoot(reduced, 'scroll-reduced-reveal-1280');
await reduced.context().close();

const page = await open({ viewport: { width: 1280, height: 800 } }, 'scroll.html');

// State 1: at rest at the top, engine running. Not half of a pair -- just the page as
// first painted, which is the state a "First paint complete" regression would move.
await page.evaluate(() => window.scrollTo(0, 0));
await settle(page, revealOpacity);
await shoot(page, 'scroll-motion-top-1280');

// State 2: mid-pin, where ScrollTrigger has driven the rail partway. settle() waits for
// the scrub to stop, so the transform in the PNG is the one the scroll offset implies
// rather than whatever the easing was passing through.
await page.evaluate(atPan);
await settle(page, railX);
await shoot(page, 'scroll-motion-pan-1280');

// State 3: the reveal, after it has finished animating in.
await page.evaluate(atReveal);
await settle(page, revealOpacity);
await shoot(page, 'scroll-motion-reveal-1280');

await page.context().close();
// The manifest is what the comparer iterates, so a shot that silently stopped being taken
// is a missing baseline rather than a quietly smaller run.
await writeFile(join(outdir, 'shots.json'), JSON.stringify(shots.sort(), null, 2) + '\n');

await browser.close();
server.close();
console.log(`SHOT ${shots.length}`);
