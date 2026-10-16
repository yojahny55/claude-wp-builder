#!/usr/bin/env node
/**
 * style-diff.mjs: before/after visual regression by computed style, not by pixels.
 *
 * A screenshot diff cannot see the regression this tool exists for. A tag swap or a reset
 * class (`.btn-reset { color: inherit; font: inherit }` added so a <span> can become a
 * <button>) beats the utility classes already on the element on source order: a white 26px
 * icon renders black at 18px, in a flex row that moves nothing else. No value was edited, the
 * diff reads as a markup fix, and the page still "looks the same" at thumbnail size. The
 * only evidence is the element's own computed values, before and after, at desktop and
 * mobile, on every element that shares the class. This tool takes that measurement on every
 * element of the page, so the question is never "did I look at the right one".
 *
 *   snapshot  load each page at each viewport, record per element a structural selector
 *             path, a computed-style subset and the box size; also JS console errors and
 *             failed requests. One browser launch per run; `load` plus a short settle,
 *             never `networkidle`.
 *   diff      compare two snapshots. Style diffs and size diffs are reported separately,
 *             with a pixel tolerance on lengths. Exit 1 when a style diff outside the
 *             noise set exists.
 *
 * Baseline noise. Take TWO snapshots before the change and pass both as --noise. Any
 * element that already differs between them (a random-order product carousel, a rotating
 * slider, an animation caught mid-frame, a 0/1 px separator) is noisy: it is listed apart
 * and never fails the run. Measured on a WooCommerce store, two untouched baselines differed
 * only inside random-order product carousels and one 0/1 px footer separator: without the
 * second baseline every run is red for reasons the change did not cause.
 *
 * Selector path. `body>*:nth-child(2)>*:nth-child(1)`: positions only, no tag or class, so
 * an element whose tag or class changed is still the same element, and the change shows as
 * a diff of its `tag` and styles rather than as one removal plus one addition. Inserting a
 * sibling shifts everything after it; that is reported as a structural change, which is
 * true. Elements added or removed are listed under `structure`, with the size diffs.
 *
 * usage:
 *   style-diff.mjs snapshot --out <dir> [--label <name>] (--urls <u1,u2> | --urls-file <file>)
 *                  [--site <origin>] [--viewports 1366x768,390x844] [--scroll] [--positions]
 *                  [--state name=selector[@width]]... [--settle-ms <n>] [--page-timeout <s>]
 *   style-diff.mjs diff <A.json> <B.json> [--noise <base1.json> <base2.json>]
 *                  [--tolerance <px, default 0.5>] [--positions] [--fail-on-size]
 *                  [--out <file.json>] [--limit <n per section, default 40>]
 *
 * --scroll walks the page once to trigger lazy content, then returns to the top.
 * --state records an interactive state: after the default snapshot, the page is reloaded,
 * `selector` is clicked and the page is recorded again as `<viewport>#<name>`. `@390`
 * limits it to viewports of that width (a mobile menu toggle). A selector that is absent
 * or hidden is recorded as `unmeasured` for that viewport, never as a pass.
 * --positions adds x,y (page coordinates) and compares them as size.
 * Relative URLs resolve against --site.
 *
 * Output: snapshot writes <out>/<label>.json (label defaults to a timestamp) and prints
 * the path; diff prints a text report and, with --out, the same as JSON.
 * exit 0 = no non-noise style diff (size diffs fail only with --fail-on-size), 1 = style
 * diffs found, 2 = usage or no browser (nothing is installed or downloaded), 3 = INCOMPLETE:
 * no diff, but a page or viewport was unmeasured, which is never a pass.
 */
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { findBrowser } from './lib/browsers.mjs';

const USAGE = 'usage: style-diff.mjs snapshot --out <dir> [--label <name>] (--urls <u1,u2> | --urls-file <file>) ' +
  '[--site <origin>] [--viewports 1366x768,390x844] [--scroll] [--positions] [--state name=selector[@width]] ' +
  '[--settle-ms <n>] [--page-timeout <s>]\n' +
  '       style-diff.mjs diff <A.json> <B.json> [--noise <base1.json> <base2.json>] [--tolerance <px>] ' +
  '[--positions] [--fail-on-size] [--out <file.json>] [--limit <n>]';

const STYLE_PROPS = ['color', 'backgroundColor', 'fontSize', 'fontFamily', 'fontWeight', 'lineHeight',
  'borderWidth', 'borderRadius', 'display', 'visibility', 'opacity', 'margin', 'padding'];

function usage(msg, code = 2) {
  if (msg) process.stderr.write(`style-diff: ${msg}\n`);
  process.stderr.write(USAGE + '\n');
  process.exit(code);
}

function parseArgs(argv) {
  const o = { cmd: argv[0], files: [], noise: [], states: [], viewports: '1366x768,390x844', settleMs: 600,
    pageTimeout: 30, tolerance: 0.5, limit: 40, scroll: false, positions: false, failOnSize: false };
  const next = (i, f) => { if (i + 1 >= argv.length) usage(`${f} needs a value`); return argv[i + 1]; };
  for (let i = 1; i < argv.length; i++) {
    const a = argv[i];
    switch (a) {
      case '--out': o.out = next(i++, a); break;
      case '--label': o.label = next(i++, a); break;
      case '--urls': o.urls = next(i++, a).split(',').map(s => s.trim()).filter(Boolean); break;
      case '--urls-file': o.urlsFile = next(i++, a); break;
      case '--site': o.site = next(i++, a); break;
      case '--viewports': o.viewports = next(i++, a); break;
      case '--state': o.states.push(next(i++, a)); break;
      case '--scroll': o.scroll = true; break;
      case '--positions': o.positions = true; break;
      case '--fail-on-size': o.failOnSize = true; break;
      case '--settle-ms': o.settleMs = Number(next(i++, a)); break;
      case '--page-timeout': o.pageTimeout = Number(next(i++, a)); break;
      case '--tolerance': o.tolerance = Number(next(i++, a)); break;
      case '--limit': o.limit = Number(next(i++, a)); break;
      case '--noise': o.noise.push(next(i++, a), next(i++, a)); break;
      default:
        if (a.startsWith('--')) usage(`unknown option ${a}`);
        o.files.push(a);
    }
  }
  return o;
}

/* ---------------------------------------------------------------- snapshot */

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

/* Runs inside the page. */
function collect({ props, positions }) {
  const SKIP = new Set(['SCRIPT', 'STYLE', 'NOSCRIPT', 'TEMPLATE', 'LINK', 'META']);
  const out = {};
  const px = n => Math.round(n * 100) / 100;
  const walk = (el, path) => {
    const cs = getComputedStyle(el);
    const r = el.getBoundingClientRect();
    const s = {};
    for (const p of props) {
      if (p === 'margin') s.margin = ['Top', 'Right', 'Bottom', 'Left'].map(d => cs['margin' + d]).join(' ');
      else if (p === 'padding') s.padding = ['Top', 'Right', 'Bottom', 'Left'].map(d => cs['padding' + d]).join(' ');
      else if (p === 'borderWidth') s.borderWidth = ['Top', 'Right', 'Bottom', 'Left'].map(d => cs['border' + d + 'Width']).join(' ');
      else s[p] = cs[p];
    }
    const rec = { tag: el.tagName.toLowerCase(), cls: (el.getAttribute('class') || '').slice(0, 80),
      text: [...el.childNodes].filter(n => n.nodeType === 3).map(n => n.textContent.trim()).join(' ').slice(0, 40),
      w: px(r.width), h: px(r.height), s };
    if (positions) { rec.x = px(r.left + scrollX); rec.y = px(r.top + scrollY); }
    out[path] = rec;
    let i = 0;
    for (const c of el.children) {
      i++;
      if (!SKIP.has(c.tagName)) walk(c, `${path}>*:nth-child(${i})`);
    }
  };
  walk(document.body, 'body');
  return out;
}

async function scrollWalk(page) {
  await page.evaluate(async () => {
    const step = Math.max(300, innerHeight - 100);
    for (let y = 0; y < document.documentElement.scrollHeight && y < 40000; y += step) {
      scrollTo(0, y);
      await new Promise(r => setTimeout(r, 150));
    }
    scrollTo(0, 0);
  });
  await page.waitForTimeout(300);
}

async function runSnapshot(o) {
  if (!o.out) usage('snapshot needs --out');
  let urls = o.urls || [];
  if (o.urlsFile) urls = urls.concat(readFileSync(o.urlsFile, 'utf8').split('\n').map(s => s.trim()).filter(s => s && !s.startsWith('#')));
  if (!urls.length) usage('snapshot needs --urls or --urls-file');
  const vps = o.viewports.split(',').map(v => {
    const m = /^(\d+)x(\d+)$/.exec(v.trim());
    if (!m) usage(`bad viewport ${v}, expected WIDTHxHEIGHT`);
    return { key: v.trim(), width: +m[1], height: +m[2] };
  });
  const states = o.states.map(s => {
    const m = /^([^=]+)=(.+?)(?:@(\d+))?$/.exec(s);
    if (!m) usage(`bad --state ${s}, expected name=selector[@width]`);
    return { name: m[1], selector: m[2], width: m[3] ? +m[3] : null };
  });
  const chromium = await loadChromium();
  if (!chromium) usage('playwright-core not found (set PLAYWRIGHT_CORE); nothing is installed');
  const executablePath = findBrowser('chromium');
  if (!executablePath) usage('no existing Chromium found (set WP_BROWSER_CHROMIUM); nothing is downloaded');
  const browser = await chromium.launch({ executablePath });
  const snap = { tool: 'style-diff', version: 1, label: o.label || new Date().toISOString().replace(/[:.]/g, '-'),
    taken: new Date().toISOString(), positions: o.positions, pages: {} };
  try {
    for (const raw of urls) {
      const url = o.site && !/^[a-z][a-z0-9+.-]*:/i.test(raw) ? new URL(raw, o.site).href : raw;
      snap.pages[url] = {};
      for (const vp of vps) {
        const ctx = await browser.newContext({ viewport: { width: vp.width, height: vp.height } });
        const page = await ctx.newPage();
        const consoleErrors = [], failedRequests = [];
        page.on('console', m => { if (m.type() === 'error') consoleErrors.push(m.text().slice(0, 300)); });
        page.on('pageerror', e => consoleErrors.push(String(e.message).slice(0, 300)));
        page.on('requestfailed', r => failedRequests.push(`${r.url().slice(0, 200)} ${r.failure()?.errorText || ''}`.trim()));
        page.on('response', r => { if (r.status() >= 400) failedRequests.push(`${r.url().slice(0, 200)} ${r.status()}`); });
        const load = async () => {
          await page.goto(url, { waitUntil: 'load', timeout: o.pageTimeout * 1000 });
          await page.waitForTimeout(o.settleMs);
          if (o.scroll) await scrollWalk(page);
        };
        const entry = { viewport: vp.key };
        try {
          await load();
          entry.elements = await page.evaluate(collect, { props: STYLE_PROPS, positions: o.positions });
          entry.consoleErrors = [...new Set(consoleErrors)];
          entry.failedRequests = [...new Set(failedRequests)];
        } catch (e) { entry.unmeasured = `load failed: ${String(e.message).split('\n')[0]}`; }
        snap.pages[url][vp.key] = entry;
        for (const st of states) {
          if (st.width && st.width !== vp.width) continue;
          const k = `${vp.key}#${st.name}`;
          const se = { viewport: k };
          try {
            await load();
            const loc = page.locator(st.selector).first();
            if (!(await loc.isVisible())) se.unmeasured = `state selector not visible: ${st.selector}`;
            else {
              await loc.click({ timeout: 5000 });
              await page.waitForTimeout(o.settleMs);
              se.elements = await page.evaluate(collect, { props: STYLE_PROPS, positions: o.positions });
            }
          } catch (e) { se.unmeasured = `state failed: ${String(e.message).split('\n')[0]}`; }
          snap.pages[url][k] = se;
        }
        await ctx.close();
      }
    }
  } finally { await browser.close(); }
  mkdirSync(resolve(o.out), { recursive: true });
  const file = join(resolve(o.out), `${snap.label}.json`);
  writeFileSync(file, JSON.stringify(snap));
  let n = 0;
  for (const p of Object.values(snap.pages)) for (const v of Object.values(p)) n += Object.keys(v.elements || {}).length;
  process.stdout.write(`${file}\n`);
  process.stderr.write(`style-diff: ${urls.length} page(s), ${n} element records\n`);
}

/* -------------------------------------------------------------------- diff */

function readSnap(f) {
  let j;
  try { j = JSON.parse(readFileSync(f, 'utf8')); } catch (e) { usage(`cannot read ${f}: ${e.message}`); }
  if (j.tool !== 'style-diff') usage(`${f} is not a style-diff snapshot`);
  return j;
}

const lenTokens = v => String(v).split(/\s+/);
function sameStyle(a, b, tol) {
  if (a === b) return true;
  const ta = lenTokens(a), tb = lenTokens(b);
  if (ta.length !== tb.length) return false;
  return ta.every((x, i) => {
    if (x === tb[i]) return true;
    const mx = /^(-?[\d.]+)px$/.exec(x), my = /^(-?[\d.]+)px$/.exec(tb[i]);
    return mx && my && Math.abs(+mx[1] - +my[1]) <= tol;
  });
}

/* All differences between two element maps. Returns { style, size, structure } keyed by path. */
function compareElements(ea, eb, tol, positions) {
  const style = [], size = [], structure = [];
  for (const k of Object.keys(ea)) {
    const a = ea[k], b = eb[k];
    if (!b) { structure.push({ path: k, change: 'removed', tag: a.tag, cls: a.cls }); continue; }
    const props = {};
    if (a.tag !== b.tag) props.tag = [a.tag, b.tag];
    for (const p of Object.keys(a.s)) if (!sameStyle(a.s[p], b.s[p], tol)) props[p] = [a.s[p], b.s[p]];
    if (Object.keys(props).length) style.push({ path: k, tag: b.tag, cls: b.cls, text: b.text, props });
    const dims = {};
    for (const d of positions ? ['w', 'h', 'x', 'y'] : ['w', 'h']) {
      if (a[d] != null && b[d] != null && Math.abs(a[d] - b[d]) > tol) dims[d] = [a[d], b[d]];
    }
    if (Object.keys(dims).length) size.push({ path: k, tag: b.tag, cls: b.cls, text: b.text, dims });
  }
  for (const k of Object.keys(eb)) if (!ea[k]) structure.push({ path: k, change: 'added', tag: eb[k].tag, cls: eb[k].cls });
  return { style, size, structure };
}

const setOf = list => new Set(list.map(x => x.path));

function runDiff(o) {
  if (o.files.length !== 2) usage('diff needs two snapshot files');
  if (o.noise.length && o.noise.length !== 2) usage('--noise needs two baseline snapshots');
  const [A, B] = o.files.map(readSnap);
  const noiseSnaps = o.noise.map(readSnap);
  const rep = { a: A.label, b: B.label, tolerance: o.tolerance, noise: noiseSnaps.length === 2,
    pages: [], totals: { style: 0, size: 0, structure: 0, noisy: 0, unmeasured: 0, newConsoleErrors: 0, newFailedRequests: 0 } };
  for (const url of Object.keys(A.pages)) {
    const pageRep = { url, viewports: [] };
    if (!B.pages[url]) { pageRep.missing = 'page absent from B'; rep.totals.unmeasured++; rep.pages.push(pageRep); continue; }
    for (const vk of Object.keys(A.pages[url])) {
      const va = A.pages[url][vk], vb = B.pages[url][vk];
      const vr = { viewport: vk };
      if (!vb) vr.unmeasured = 'viewport absent from B';
      else if (va.unmeasured || vb.unmeasured) vr.unmeasured = va.unmeasured || vb.unmeasured;
      if (vr.unmeasured) rep.totals.unmeasured++;
      else {
        const noisy = new Set();
        if (noiseSnaps.length === 2) {
          const n0 = noiseSnaps[0].pages[url]?.[vk]?.elements, n1 = noiseSnaps[1].pages[url]?.[vk]?.elements;
          if (n0 && n1) {
            const c = compareElements(n0, n1, o.tolerance, o.positions);
            for (const l of [c.style, c.size, c.structure]) for (const p of setOf(l)) noisy.add(p);
          } else vr.noiseUnmeasured = 'baseline pair has no data for this page/viewport';
        }
        const c = compareElements(va.elements, vb.elements, o.tolerance, o.positions);
        const split = list => [list.filter(x => !noisy.has(x.path)), list.filter(x => noisy.has(x.path))];
        const [style, nStyle] = split(c.style), [size, nSize] = split(c.size), [structure, nStr] = split(c.structure);
        vr.style = style; vr.size = size; vr.structure = structure;
        vr.noisy = { style: nStyle.length, size: nSize.length, structure: nStr.length, paths: [...new Set([...nStyle, ...nSize, ...nStr].map(x => x.path))] };
        const newOnes = (x, y) => (y || []).filter(e => !(x || []).includes(e));
        vr.newConsoleErrors = newOnes(va.consoleErrors, vb.consoleErrors);
        vr.newFailedRequests = newOnes(va.failedRequests, vb.failedRequests);
        rep.totals.style += style.length; rep.totals.size += size.length; rep.totals.structure += structure.length;
        rep.totals.noisy += vr.noisy.paths.length;
        rep.totals.newConsoleErrors += vr.newConsoleErrors.length;
        rep.totals.newFailedRequests += vr.newFailedRequests.length;
      }
      pageRep.viewports.push(vr);
    }
    rep.pages.push(pageRep);
  }
  const fail = rep.totals.style > 0 || (o.failOnSize && (rep.totals.size > 0 || rep.totals.structure > 0));
  const incomplete = !fail && rep.totals.unmeasured > 0;
  rep.verdict = fail ? 'DIFF' : incomplete ? 'INCOMPLETE' : 'CLEAN';
  printReport(rep, o);
  if (o.out) { mkdirSync(dirname(resolve(o.out)), { recursive: true }); writeFileSync(o.out, JSON.stringify(rep, null, 2) + '\n'); }
  process.exit(fail ? 1 : incomplete ? 3 : 0);
}

function printReport(rep, o) {
  const L = [];
  const lim = (list, f, name) => {
    if (!list.length) return;
    L.push(`  ${name} (${list.length})`);
    list.slice(0, o.limit).forEach(x => L.push('    ' + f(x)));
    if (list.length > o.limit) L.push(`    ... ${list.length - o.limit} more (raise --limit or read --out)`);
  };
  L.push(`style-diff: ${rep.a} -> ${rep.b}  tolerance ${rep.tolerance}px  noise baseline ${rep.noise ? 'yes' : 'no'}`);
  for (const p of rep.pages) {
    L.push(`\n${p.url}`);
    if (p.missing) { L.push(`  UNMEASURED: ${p.missing}`); continue; }
    for (const v of p.viewports) {
      L.push(` [${v.viewport}]`);
      if (v.unmeasured) { L.push(`  UNMEASURED: ${v.unmeasured}`); continue; }
      if (v.noiseUnmeasured) L.push(`  note: ${v.noiseUnmeasured}`);
      const who = x => `${x.path}  <${x.tag}${x.cls ? ' class="' + x.cls + '"' : ''}>${x.text ? ' "' + x.text + '"' : ''}`;
      lim(v.style, x => `${who(x)}\n      ` + Object.entries(x.props).map(([k, [a, b]]) => `${k}: ${a} -> ${b}`).join('; '), 'STYLE diffs');
      lim(v.size, x => `${who(x)}\n      ` + Object.entries(x.dims).map(([k, [a, b]]) => `${k}: ${a} -> ${b}`).join('; '), 'SIZE diffs');
      lim(v.structure, x => `${x.change} ${x.path} <${x.tag}${x.cls ? ' class="' + x.cls + '"' : ''}>`, 'STRUCTURE');
      if (v.noisy.paths.length) L.push(`  noisy, excluded (${v.noisy.paths.length} elements: ${v.noisy.style} style, ${v.noisy.size} size, ${v.noisy.structure} structure)`);
      lim(v.newConsoleErrors, x => x, 'NEW console errors');
      lim(v.newFailedRequests, x => x, 'NEW failed requests');
    }
  }
  const t = rep.totals;
  L.push(`\n${rep.verdict}: ${t.style} style, ${t.size} size, ${t.structure} structure, ${t.noisy} noisy excluded, ${t.unmeasured} unmeasured, ` +
    `${t.newConsoleErrors} new console errors, ${t.newFailedRequests} new failed requests`);
  process.stdout.write(L.join('\n') + '\n');
}

const o = parseArgs(process.argv.slice(2));
if (o.cmd === 'snapshot') await runSnapshot(o);
else if (o.cmd === 'diff') runDiff(o);
else usage(o.cmd ? `unknown mode ${o.cmd}` : 'missing mode');
