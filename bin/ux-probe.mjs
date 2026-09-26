#!/usr/bin/env node
/**
 * ux-probe.mjs: the usability audit's page harness — one browser, every probe, a budget
 * enforced in code.
 *
 * wp-audit-ux once ran 25 minutes on an 8-page audit while the other six auditors
 * finished in 8–14. It wrote a new script for every question (diag.mjs … diag15.mjs,
 * click_test2.mjs), each launching its own Chromium and waiting for `networkidle` on a
 * ~600 KB page with ~170 requests, and a failed selector always led to one more script,
 * never to UNMEASURED. The agent's prose now carries a budget; this tool makes it a
 * fact rather than a request:
 *
 *   - ONE launch per run. Every page is opened once per viewport, in contexts of that one
 *     browser, and every probe runs on the page already loaded. `load` plus a short
 *     settle, never `networkidle`: a page with a polling widget may never go idle.
 *   - A state file (--state, default <out dir>/ux-probe-state.json) counts across runs:
 *       launches   at most 3 per audit; the fourth run exits 3 and measures nothing;
 *       wall clock 15 minutes from the first run; after that, exit 3;
 *       attempts   a site probe that has errored twice is not run again: it is reported
 *                  `unmeasured` with each error and the probe source it ran, which is the
 *                  "selectors tried" evidence the report needs.
 *     A new audit starts with a new state file; --state-reset clears one on purpose.
 *
 * Built-in DOM probes, run on every page at every viewport (criterion codes are the
 * UX-NNN catalog in skills/wp-audit-ux-standards/SKILL.md):
 *
 *   lineLength   UX-006  longest rendered line, in characters, per text block
 *   actionGaps   UX-009  adjacent action elements closer than 8 px
 *   linkStyle    UX-018  in-text links not underlined AND not differing from the text
 *   imageLinks   UX-019  a > img with no alt and no other accessible name
 *   required     UX-001  required fields whose label carries no visible marker
 *   links        UX-014/015  every href on the page (desktop viewport only, since menus
 *                collapse on mobile); --links-out writes them as `href TAB page`, the
 *                input of skills/wp-cli-patterns/scripts/resolve-link-targets.php
 *
 * Site probes (--probes <module.mjs>) are where the theme-specific interactions live: the
 * login popup, AJAX pagination, a form's error state. The module's default export is an
 * array of { id, criterion, viewports?, run }, where `run({ page, url, path, viewport })`
 * returns anything JSON-serialisable, and must leave the page on `url`. A probe that times
 * out cannot be stopped, only abandoned, so the harness reloads `url` before the next one. Extending that module and rerunning is how a
 * follow-up question is asked — never a new script with its own browser.
 *
 * usage:
 *   ux-probe.mjs --site <origin> --pages </a/,/b/> [--out <file.json>] [--probes <module>]
 *                [--viewports mobile,tablet,desktop] [--links-out <file>] [--state <file>]
 *                [--state-reset] [--page-timeout <s>] [--probe-timeout <s>]
 *
 * exit 0 = ran (findings and unmeasured items are in the JSON), 2 = usage or no browser,
 * 3 = budget spent (launches or wall clock) — report what you have.
 */
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { findBrowser } from './lib/browsers.mjs';

const USAGE = 'usage: ux-probe.mjs --site <origin> --pages </a/,/b/> [--out <file.json>] ' +
  '[--probes <module>] [--viewports mobile,tablet,desktop] [--links-out <file>] [--state <file>] ' +
  '[--state-reset] [--page-timeout <s>] [--probe-timeout <s>]';
const MAX_LAUNCHES = 3;
const MAX_ATTEMPTS = 2;
const WALL_CLOCK_MS = 15 * 60 * 1000;
const VIEWPORTS = {
  mobile: { width: 390, height: 844 },
  tablet: { width: 768, height: 1024 },
  desktop: { width: 1440, height: 900 },
};

function usage(msg, code = 2) {
  if (msg) process.stderr.write(`ux-probe: ${msg}\n`);
  if (code === 2) process.stderr.write(USAGE + '\n');
  process.exit(code);
}

function seconds(v, flag) {
  const n = Number(v);
  if (!Number.isFinite(n) || n <= 0) usage(`${flag} needs a positive number of seconds, got ${v}`);
  return n;
}

// A rejection is not always an Error: a probe can reject with a string, or with nothing.
function errMsg(e) {
  return String((e && e.message) || e).split('\n')[0];
}

function parseArgs(argv) {
  const o = { out: 'ux-probe.json', viewports: ['mobile', 'tablet', 'desktop'], pageTimeout: 45,
    probeTimeout: 15, stateReset: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    const next = () => { if (i + 1 >= argv.length) usage(`${a} needs a value`); return argv[++i]; };
    switch (a) {
      case '--site': o.site = next(); break;
      case '--pages': o.pages = next().split(',').map((s) => s.trim()).filter(Boolean); break;
      case '--out': o.out = next(); break;
      case '--probes': o.probes = next(); break;
      case '--viewports': o.viewports = next().split(',').map((s) => s.trim()).filter(Boolean); break;
      case '--links-out': o.linksOut = next(); break;
      case '--state': o.state = next(); break;
      case '--state-reset': o.stateReset = true; break;
      case '--page-timeout': o.pageTimeout = seconds(next(), a); break;
      case '--probe-timeout': o.probeTimeout = seconds(next(), a); break;
      case '-h': case '--help': process.stdout.write(USAGE + '\n'); process.exit(0);
      default: usage(`unknown argument ${a}`);
    }
  }
  if (!o.site) usage('--site is required');
  if (!o.pages?.length) usage('--pages is required');
  try { o.siteUrl = new URL(o.site); } catch { usage(`--site is not a URL: ${o.site}`); }
  if (!o.viewports.length) usage('--viewports is empty');
  for (const v of o.viewports) if (!VIEWPORTS[v]) usage(`unknown viewport ${v}`);
  for (const p of o.pages) { try { new URL(p, o.siteUrl); } catch { usage(`--pages entry is not a URL or path: ${p}`); } }
  o.state = o.state || join(dirname(resolve(o.out)), 'ux-probe-state.json');
  return o;
}

function readState(o) {
  const fresh = { started: Date.now(), launches: 0, probes: {} };
  if (o.stateReset || !existsSync(o.state)) return fresh;
  // Absent is a new audit; unreadable is not. Failing open would hand out a fresh budget.
  try { return { ...fresh, ...JSON.parse(readFileSync(o.state, 'utf8')) }; } catch (e) {
    usage(`state ${o.state} is unreadable (${errMsg(e)}); refusing to reset the budget, use --state-reset`);
  }
}

function writeState(o, s) {
  mkdirSync(dirname(resolve(o.state)), { recursive: true });
  writeFileSync(o.state, JSON.stringify(s, null, 2) + '\n');
}

async function loadChromium() {
  const tries = [];
  if (process.env.PLAYWRIGHT_CORE) tries.push(pathToFileURL(resolve(process.env.PLAYWRIGHT_CORE, 'index.mjs')).href);
  else {
    tries.push('playwright-core');
    const cwdEntry = join(process.cwd(), 'node_modules', 'playwright-core', 'index.mjs');
    if (existsSync(cwdEntry)) tries.push(pathToFileURL(cwdEntry).href);
  }
  for (const t of tries) {
    try { return (await import(t)).chromium; } catch { /* next */ }
  }
  return null;
}

/* Runs inside the page. Everything it returns is evidence: selectors, measured values. */
function domProbes(collectLinks) {
  const path = (el) => {
    const parts = [];
    for (let n = el; n && n.nodeType === 1 && parts.length < 4; n = n.parentElement) {
      let s = n.tagName.toLowerCase();
      if (n.id) { parts.unshift(`${s}#${n.id}`); break; }
      const cls = [...n.classList].slice(0, 2).join('.');
      if (cls) s += '.' + cls;
      parts.unshift(s);
    }
    return parts.join(' > ');
  };
  const visible = (el) => {
    const r = el.getBoundingClientRect();
    const cs = getComputedStyle(el);
    return r.width > 0 && r.height > 0 && cs.visibility !== 'hidden' && cs.display !== 'none';
  };

  // UX-006: per text block, the longest line in characters. A Range's client rects are
  // one per line box; characters per line = line width x (chars / total width).
  // The cap counts blocks kept, not blocks seen: a mega-menu's short <li>s come first in
  // document order and would otherwise use it up and report "no long lines".
  const lineLength = [];
  let lineLengthTruncated = false;
  for (const el of document.querySelectorAll('p, li, dd, blockquote, figcaption')) {
    if (lineLength.length >= 300) { lineLengthTruncated = true; break; }
    const text = (el.textContent || '').replace(/\s+/g, ' ').trim();
    if (text.length < 60 || !visible(el)) continue;
    // Text nodes only: a Range over the element also returns the boxes of inline elements
    // (a link, a <strong>), which would count their width twice on their line.
    const lines = new Map();
    const walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT);
    const range = document.createRange();
    for (let n = walker.nextNode(); n; n = walker.nextNode()) {
      range.selectNodeContents(n);
      for (const r of range.getClientRects()) {
        if (r.width > 1) lines.set(Math.round(r.top), (lines.get(Math.round(r.top)) || 0) + r.width);
      }
    }
    const widths = [...lines.values()];
    const total = widths.reduce((a, b) => a + b, 0);
    if (!total) continue;
    const longest = Math.round((Math.max(...widths) * text.length) / total);
    lineLength.push({ selector: path(el), longestLineChars: longest, lines: widths.length });
  }
  lineLength.sort((a, b) => b.longestLineChars - a.longestLineChars);

  // UX-009: action elements that sit side by side (same parent) closer than 8px.
  // Capped: the pairwise scan below is O(n^2), and a gallery or mega-menu can carry thousands.
  const actions = [...document.querySelectorAll('button, [role="button"], input[type="submit"], input[type="button"], a')]
    .filter((el) => {
      if (!visible(el)) return false;
      if (el.tagName !== 'A') return true;
      const cs = getComputedStyle(el);
      return cs.backgroundColor !== 'rgba(0, 0, 0, 0)' || parseFloat(cs.borderTopWidth) > 0
        || parseFloat(cs.paddingTop) >= 6;
    }).slice(0, 400);
  const actionGaps = [];
  for (let i = 0; i < actions.length; i++) {
    for (let j = i + 1; j < actions.length; j++) {
      const a = actions[i], b = actions[j];
      if (a.parentElement !== b.parentElement && a.parentElement?.parentElement !== b.parentElement?.parentElement) continue;
      const ra = a.getBoundingClientRect(), rb = b.getBoundingClientRect();
      const dx = Math.max(0, Math.max(ra.left, rb.left) - Math.min(ra.right, rb.right));
      const dy = Math.max(0, Math.max(ra.top, rb.top) - Math.min(ra.bottom, rb.bottom));
      const overlapX = dx === 0, overlapY = dy === 0;
      if (!overlapX && !overlapY) continue;
      const gap = overlapY ? dx : dy;
      if (gap < 8) actionGaps.push({ a: path(a), b: path(b), gapPx: Math.round(gap * 10) / 10 });
    }
  }

  // UX-018: an in-text link must differ from its text at rest, not only on hover. Only a
  // link that is neither underlined nor differs in colour or weight is a finding; links in
  // navigation, header and footer are not in-text and are skipped.
  const linkStyle = [];
  let linkStyleTruncated = false;
  for (const a of document.querySelectorAll('p a, li a, dd a, td a')) {
    if (a.closest('nav, header, footer, [role="navigation"]') || !a.parentElement || !visible(a)) continue;
    const cs = getComputedStyle(a), ps = getComputedStyle(a.parentElement);
    const underline = cs.textDecorationLine.includes('underline') || parseFloat(cs.borderBottomWidth) > 0;
    if (underline || cs.color !== ps.color || cs.fontWeight !== ps.fontWeight) continue;
    if (linkStyle.length >= 50) { linkStyleTruncated = true; break; }
    linkStyle.push({ selector: path(a), text: a.textContent.trim().slice(0, 40) });
  }

  // UX-019: an image link needs an accessible name from somewhere.
  const imageLinks = [];
  for (const a of document.querySelectorAll('a')) {
    const img = a.querySelector('img');
    if (!img) continue;
    const named = (img.getAttribute('alt') || '').trim() || (a.getAttribute('aria-label') || '').trim()
      || (a.getAttribute('title') || '').trim() || (a.textContent || '').trim();
    if (!named) imageLinks.push({ selector: path(a), href: a.getAttribute('href') });
  }

  // UX-001: a required field whose label shows no marker. `required`/aria-required tell a
  // screen reader; a sighted user needs a visible mark or the word.
  const required = [];
  for (const f of document.querySelectorAll('input, select, textarea')) {
    if (!(f.required || f.getAttribute('aria-required') === 'true') || !visible(f)) continue;
    const label = (f.id && document.querySelector(`label[for="${CSS.escape(f.id)}"]`)) || f.closest('label');
    const text = label ? label.textContent : (f.getAttribute('placeholder') || '');
    const marked = /\*|required|obligatori|requerid/i.test(text || '');
    required.push({ selector: path(f), name: f.name || f.id, label: (text || '').trim().slice(0, 60), marked });
  }

  const links = [];
  if (collectLinks) {
    const seen = new Set();
    for (const a of document.querySelectorAll('a[href]')) {
      const raw = a.getAttribute('href').trim();
      const href = raw.startsWith('#') || /^[a-z][a-z0-9+.-]*:/i.test(raw) && !/^https?:/i.test(raw) ? raw : a.href;
      if (!seen.has(href)) { seen.add(href); links.push(href); }
    }
  }
  return { lineLength: lineLength.slice(0, 20), lineLengthTruncated, actionGaps, linkStyle, linkStyleTruncated,
    imageLinks, required, links };
}

function withTimeout(p, ms, what) {
  let t;
  return Promise.race([p, new Promise((_, rej) => { t = setTimeout(() => rej(new Error(`${what} timed out after ${ms / 1000}s`)), ms); })])
    .finally(() => clearTimeout(t));
}

async function main() {
  const o = parseArgs(process.argv.slice(2));
  const state = readState(o);
  const elapsed = Date.now() - state.started;
  // Name the state file: one inherited from an earlier audit's --out dir is recognisable by its date.
  const from = `state ${o.state}, started ${new Date(state.started).toISOString()}`;
  if (state.launches >= MAX_LAUNCHES) {
    usage(`launch budget spent (${state.launches}/${MAX_LAUNCHES}; ${from}); report what you have, the rest is UNMEASURED (budget)`, 3);
  }
  if (elapsed > WALL_CLOCK_MS) {
    usage(`wall-clock budget spent (${Math.round(elapsed / 60000)} min of 15; ${from}); report what you have, the rest is UNMEASURED (budget)`, 3);
  }

  let probes = [];
  if (o.probes) {
    try {
      const mod = await import(pathToFileURL(resolve(o.probes)).href + `?t=${Date.now()}`);
      probes = Array.isArray(mod.default) ? mod.default : [];
    } catch (e) { usage(`cannot load --probes ${o.probes}: ${errMsg(e)}`); }
    for (const p of probes) if (!p || !p.id || typeof p.run !== 'function') usage('each site probe needs { id, run }');
  }

  const chromium = await loadChromium();
  if (!chromium) usage('playwright-core not found (set PLAYWRIGHT_CORE); nothing is installed', 2);
  const executablePath = findBrowser('chromium');
  if (!executablePath) usage('no existing Chromium found (set WP_BROWSER_CHROMIUM); nothing is downloaded', 2);

  state.launches += 1;
  writeState(o, state);
  const report = { site: o.site, launch: state.launches, maxLaunches: MAX_LAUNCHES,
    minutesUsed: Math.round(elapsed / 6000) / 10, pages: [], probes: {} };
  const linkRows = [];
  const browser = await chromium.launch({ executablePath });
  try {
    for (const vp of o.viewports) {
      const context = await browser.newContext({ viewport: VIEWPORTS[vp] });
      const page = await context.newPage();
      for (const p of o.pages) {
        const url = new URL(p, o.siteUrl).href;
        const entry = { path: p, viewport: vp };
        const t0 = Date.now();
        try {
          const res = await page.goto(url, { waitUntil: 'load', timeout: o.pageTimeout * 1000 });
          await page.waitForTimeout(500);
          entry.status = res ? res.status() : null;
          entry.loadMs = Date.now() - t0;
          try {
            entry.dom = await withTimeout(page.evaluate(domProbes, vp === 'desktop' || o.viewports.length === 1),
              o.pageTimeout * 1000, 'DOM probes');
          } catch (e) {
            entry.dom = { verdict: 'unmeasured', reason: errMsg(e) };
            report.pages.push(entry);
            continue;
          }
          if (entry.dom.links.length) for (const h of entry.dom.links) linkRows.push(`${h}\t${url}`);
          entry.dom.linkCount = entry.dom.links.length;
          delete entry.dom.links;
        } catch (e) {
          entry.error = errMsg(e);
          report.pages.push(entry);
          continue;
        }
        entry.site = {};
        for (const probe of probes) {
          if (probe.viewports && !probe.viewports.includes(vp)) continue;
          const rec = state.probes[probe.id] || { errors: [] };
          if (rec.errors.length >= MAX_ATTEMPTS) {
            entry.site[probe.id] = { verdict: 'unmeasured', criterion: probe.criterion || null,
              reason: `attempt limit reached (${MAX_ATTEMPTS})`, tried: rec.errors };
            continue;
          }
          try {
            const value = await withTimeout(probe.run({ page, url, path: p, viewport: vp }),
              o.probeTimeout * 1000, `probe ${probe.id}`);
            entry.site[probe.id] = { criterion: probe.criterion || null, value };
          } catch (e) {
            const err = { run: state.launches, page: p, viewport: vp, error: errMsg(e),
              source: String(probe.run).slice(0, 300) };
            // One attempt per run, however many page views it failed on: the budget is
            // about how many times the agent may rewrite a probe, not how many pages exist.
            if (!rec.errors.some((x) => x.run === state.launches)) rec.errors.push(err);
            state.probes[probe.id] = rec;
            entry.site[probe.id] = { criterion: probe.criterion || null, verdict: 'error', error: err.error,
              attemptsLeft: Math.max(0, MAX_ATTEMPTS - rec.errors.length) };
            // The failed probe may still be driving the page; put it back on this URL so the
            // next probe does not measure wherever the runaway one left it.
            try { await page.goto(url, { waitUntil: 'load', timeout: o.pageTimeout * 1000 }); }
            catch (e2) { entry.error = `page not restored after probe ${probe.id}: ${errMsg(e2)}`; break; }
          }
        }
        report.pages.push(entry);
      }
      await context.close();
    }
  } finally {
    await browser.close();
    writeState(o, state);
  }
  for (const [id, rec] of Object.entries(state.probes)) report.probes[id] = { errors: rec.errors.length, exhausted: rec.errors.length >= MAX_ATTEMPTS };
  if (o.probes) report.probesFile = o.probes;
  mkdirSync(dirname(resolve(o.out)), { recursive: true });
  writeFileSync(o.out, JSON.stringify(report, null, 2) + '\n');
  // An empty collection (a run scoped to mobile/tablet) must not truncate an earlier run's evidence.
  if (o.linksOut && linkRows.length) {
    mkdirSync(dirname(resolve(o.linksOut)), { recursive: true });
    writeFileSync(o.linksOut, [...new Set(linkRows)].join('\n') + '\n');
  }
  process.stderr.write(`ux-probe: launch ${state.launches}/${MAX_LAUNCHES}, ${report.pages.length} page views, report ${o.out}\n`);
}

main().catch((e) => { process.stderr.write(`ux-probe: ${e.stack || e}\n`); process.exit(1); });
