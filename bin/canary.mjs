#!/usr/bin/env node
/**
 * canary.mjs: post-deploy check of a live site's key pages, before and after a push.
 *
 * Why: /wp-update verifies the root it runs on, which in a rollout is the local clone. Staging
 * and production then receive the update by `git push`, and nothing measured the live sites
 * afterwards: a plugin update that 404s its own stylesheet, or throws in the browser, went
 * unnoticed until someone opened the page.
 *
 *   node bin/canary.mjs snapshot <url>... --out <file.json> [--delay <s>] [--timeout <s>]
 *   node bin/canary.mjs compare <before.json> <after.json> [--json]
 *
 * snapshot loads each URL in headless Chromium, one page at a time, and records the final
 * status, load time, title, console errors, failed same-site requests and which landmarks
 * (h1, header, nav, main, footer) are present. compare reads two snapshots of the same host
 * and reports, per page, ok / warn / regression.
 *
 * Regression: a 2xx/3xx page that no longer is; a console error that was not there before
 * (runs of 4+ digits normalized, so ids and timestamps do not read as new); a same-site
 * request (the host, its www-less apex or a subdomain of it) that now fails; a landmark that
 * disappeared; a page that now lands on another URL (redirect to login or maintenance), errors
 * or is missing. Warning only: a changed title, a page that was already failing before the push,
 * and load time over 2x the baseline and over 3 s, since live timing is noisy. Third-party failures (analytics, CDNs of others) never count.
 *
 * Nothing is installed: playwright-core comes from PLAYWRIGHT_CORE or an existing install,
 * Chromium from bin/lib/browsers.mjs. Production runs go through bin/prod-gate.sh.
 *
 * Exit codes (COMMON): 0 ok, 1 regression found, 2 could not measure (no playwright-core,
 * no Chromium, or every page failed to load), 3 crash, 64 usage.
 */
import './lib/stdio-blocking.mjs';
import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { findBrowser } from './lib/browsers.mjs';

export const LANDMARKS = ['h1', 'header', 'nav', 'main', 'footer'];
const SLOW_FACTOR = 2;
const SLOW_FLOOR_MS = 3000;
const SETTLE_MS = 3000;

class UsageError extends Error {}

function usage(msg, code = 64) {
  process.stderr.write(`canary: ${msg}\n`);
  process.exit(code);
}

/**
 * "Same site" = the snapshot host, its www-less apex, and any subdomain of that apex
 * (www.site.test, site.test, cdn.site.test). Anything else is third party.
 */
export function sameSite(url, host) {
  const apex = host.replace(/^www\./, '');
  try {
    const h = new URL(url).hostname;
    return h === host || h === apex || h.endsWith(`.${apex}`);
  } catch {
    return false;
  }
}

/** Only long digit runs are volatile (ids, timestamps); HTTP codes and short numbers keep their meaning. */
const norm = (text) => String(text).replace(/\d{4,}/g, '#').trim();
const ok = (status) => status >= 200 && status < 400;
const broken = (p) => !!p.error || !ok(p.status);
/** Origin + path of where the page ended up, ignoring query and fragment. */
const landing = (p) => {
  try { const u = new URL(p.finalUrl ?? p.url); return u.origin + u.pathname; } catch { return String(p.finalUrl ?? p.url); }
};

function byUrl(snapshot, label) {
  const map = new Map();
  for (const p of snapshot.pages) {
    if (map.has(p.url)) throw new UsageError(`duplicate page ${p.url} in the ${label} snapshot`);
    map.set(p.url, p);
  }
  return map;
}

export function compareSnapshots(before, after) {
  for (const s of [before, after]) {
    if (!s || s.tool !== 'canary' || !Array.isArray(s.pages)) throw new UsageError('not a canary snapshot');
  }
  if (before.host !== after.host) {
    throw new UsageError(`snapshots are of different hosts (${before.host} vs ${after.host})`);
  }
  byUrl(before, 'before');
  const afterByUrl = byUrl(after, 'after');
  const pages = [];
  for (const b of before.pages) {
    const a = afterByUrl.get(b.url);
    const reasons = [];
    let verdict = 'ok';
    const regress = (r) => { reasons.push(r); verdict = 'regression'; };
    const warn = (r) => { reasons.push(r); if (verdict === 'ok') verdict = 'warn'; };
    if (!a) {
      regress('page missing from the after snapshot');
    } else if (broken(b)) {
      // Not caused by this push, but never reported as ok while the page is down.
      if (broken(a)) warn(`already failing before the push, still failing: ${a.error ?? `status ${a.status}`}`);
      else warn('was failing before the push, loads now');
    } else if (a.error) {
      regress(`page failed to load: ${a.error}`);
    } else {
      if (!ok(a.status)) regress(`status ${b.status} -> ${a.status}`);
      if (landing(a) !== landing(b)) regress(`now lands on ${landing(a)} (was ${landing(b)})`);
      const seen = new Set((b.consoleErrors ?? []).map(norm));
      for (const e of a.consoleErrors ?? []) if (!seen.has(norm(e))) regress(`new console error: ${e}`);
      const failedBefore = new Set((b.failedRequests ?? []).map((r) => r.url));
      for (const r of a.failedRequests ?? []) {
        if (!failedBefore.has(r.url) && sameSite(r.url, after.host)) {
          regress(`request failed (${r.status || 'network'}): ${r.url}`);
        }
      }
      for (const l of LANDMARKS) if (b.landmarks?.[l] && !a.landmarks?.[l]) regress(`landmark gone: ${l}`);
      if (a.title !== b.title) warn(`title changed: "${b.title}" -> "${a.title}"`);
      if (a.ms > b.ms * SLOW_FACTOR && a.ms > SLOW_FLOOR_MS) warn(`slower: ${b.ms} ms -> ${a.ms} ms`);
    }
    pages.push({ url: b.url, verdict, reasons });
  }
  return {
    host: after.host,
    pages,
    regressions: pages.filter((p) => p.verdict === 'regression').length,
    warnings: pages.filter((p) => p.verdict === 'warn').length,
  };
}

function table(result) {
  const cell = (s) => String(s).replace(/\|/g, '\\|');
  const rows = result.pages.map((p) => `| ${cell(p.url)} | ${p.verdict} | ${cell(p.reasons.join('; ') || '-')} |`);
  return [
    `Canary ${result.host}: ${result.regressions} regression(s), ${result.warnings} warning(s)`,
    '',
    '| Page | Verdict | Reasons |',
    '|---|---|---|',
    ...rows,
  ].join('\n');
}

function readSnapshot(file) {
  try {
    return JSON.parse(readFileSync(file, 'utf8'));
  } catch (e) {
    usage(`cannot read snapshot ${file}: ${e.message}`);
  }
}

function runCompare(args) {
  const json = args.includes('--json');
  const files = args.filter((a) => a !== '--json');
  if (files.length !== 2) usage('compare needs <before.json> <after.json>');
  let result;
  try {
    result = compareSnapshots(readSnapshot(files[0]), readSnapshot(files[1]));
  } catch (e) {
    if (e instanceof UsageError) usage(e.message);
    throw e;
  }
  process.stdout.write((json ? JSON.stringify(result, null, 2) : table(result)) + '\n');
  process.exit(result.regressions > 0 ? 1 : 0);
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

/* Runs inside the page: which landmarks exist. */
function landmarkProbe() {
  return {
    h1: !!document.querySelector('h1'),
    header: !!document.querySelector('header, [role=banner]'),
    nav: !!document.querySelector('nav, [role=navigation]'),
    main: !!document.querySelector('main, [role=main]'),
    footer: !!document.querySelector('footer, [role=contentinfo]'),
  };
}

function parseSnapshotArgs(args) {
  const o = { urls: [], out: null, delay: 2, timeout: 30 };
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    const value = () => {
      const v = args[++i];
      if (v === undefined) usage(`${a} needs a value`);
      return v;
    };
    if (a === '--out') o.out = value();
    else if (a === '--delay') o.delay = Number(value());
    else if (a === '--timeout') o.timeout = Number(value());
    else if (a.startsWith('--')) usage(`unknown option ${a}`);
    else o.urls.push(a);
  }
  if (!o.urls.length) usage('snapshot needs at least one URL');
  if (!o.out) usage('snapshot needs --out <file.json>');
  if (!(o.delay >= 0) || !(o.timeout > 0)) usage('--delay must be >= 0 and --timeout > 0 (seconds)');
  const hosts = new Set();
  for (const u of o.urls) {
    let url;
    try { url = new URL(u); } catch { usage(`not a URL: ${u}`); }
    if (!/^https?:$/.test(url.protocol)) usage(`not an http(s) URL: ${u}`);
    hosts.add(url.hostname);
  }
  const keys = o.urls.map((u) => { const x = new URL(u); x.hash = ''; return x.href; });
  const dup = keys.find((k, i) => keys.indexOf(k) !== i);
  if (dup) usage(`duplicate URL: ${dup}`);
  o.urls = keys;
  if (hosts.size !== 1) usage(`all URLs must be on one host, got: ${[...hosts].join(', ')}`);
  o.host = [...hosts][0];
  return o;
}

async function snapPage(context, url, timeoutMs) {
  const page = await context.newPage();
  const consoleErrors = [];
  const failed = new Map();
  // "Failed to load resource" console lines repeat what failedRequests records, third-party
  // failures included, which must not count as new console errors.
  page.on('console', (m) => {
    if (m.type() === 'error' && !/^Failed to load resource:/.test(m.text())) consoleErrors.push(m.text());
  });
  page.on('pageerror', (e) => consoleErrors.push(String(e?.message ?? e)));
  // A 4xx/5xx response can also fire requestfailed; keep the status the response gave.
  page.on('requestfailed', (r) => { if (!failed.has(r.url())) failed.set(r.url(), 0); });
  page.on('response', (r) => { if (r.status() >= 400) failed.set(r.url(), r.status()); });
  const started = Date.now();
  const result = { url, finalUrl: url, status: 0, ms: 0, title: '', consoleErrors, failedRequests: [], landmarks: {} };
  // goto honours its own timeout; title, evaluate and close do not, so each is raced.
  const bounded = (p, what) => Promise.race([p, new Promise((_, rej) =>
    setTimeout(() => rej(new Error(`${what} did not finish in ${timeoutMs} ms`)), timeoutMs).unref())]);
  try {
    const res = await page.goto(url, { waitUntil: 'load', timeout: timeoutMs });
    result.ms = Date.now() - started;
    result.status = res ? res.status() : 0;
    // Late errors (deferred init, lazy assets) land after "load": settle briefly, bounded.
    await page.waitForLoadState('networkidle', { timeout: SETTLE_MS }).catch(() => {});
    result.title = await bounded(page.title(), 'page.title()');
    result.landmarks = await bounded(page.evaluate(landmarkProbe), 'landmark probe');
    result.finalUrl = page.url();
    failed.delete(url);
    failed.delete(result.finalUrl);
  } catch (e) {
    result.ms = Date.now() - started;
    result.error = String(e?.message ?? e).split('\n')[0];
  } finally {
    await bounded(page.close(), 'page.close()').catch(() => {});
  }
  result.failedRequests = [...failed].map(([u, status]) => ({ url: u, status }));
  return result;
}

async function runSnapshot(args) {
  const o = parseSnapshotArgs(args);
  const chromium = await loadChromium();
  if (!chromium) usage('playwright-core not found (set PLAYWRIGHT_CORE); nothing is installed', 2);
  const executablePath = findBrowser('chromium');
  if (!executablePath) usage('no existing Chromium found (set WP_BROWSER_CHROMIUM); nothing is downloaded', 2);
  let browser;
  try { browser = await chromium.launch({ executablePath }); }
  catch (e) { usage(`Chromium failed to launch: ${String(e?.message ?? e).split('\n')[0]}`, 2); }
  const pages = [];
  try {
    const context = await browser.newContext();
    for (const [i, url] of o.urls.entries()) {
      if (i > 0 && o.delay > 0) await new Promise((r) => setTimeout(r, o.delay * 1000));
      pages.push(await snapPage(context, url, o.timeout * 1000));
    }
  } finally {
    await browser.close().catch(() => {});
  }
  const snapshot = { tool: 'canary', version: 1, takenAt: new Date().toISOString(), host: o.host, pages };
  mkdirSync(dirname(resolve(o.out)), { recursive: true });
  writeFileSync(o.out, JSON.stringify(snapshot, null, 2) + '\n');
  const loaded = pages.filter((p) => !p.error).length;
  process.stdout.write(`canary: ${loaded}/${pages.length} page(s) loaded on ${o.host}; snapshot written to ${o.out}\n`);
  for (const p of pages.filter((p) => p.error)) process.stdout.write(`  failed: ${p.url}: ${p.error}\n`);
  process.exit(loaded === 0 ? 2 : 0);
}

async function main(argv) {
  const [cmd, ...args] = argv;
  if (cmd === 'compare') return runCompare(args);
  if (cmd === 'snapshot') return runSnapshot(args);
  usage(`unknown subcommand '${cmd ?? ''}'. Use: snapshot <url>... --out <file> | compare <before> <after> [--json]`);
}

main(process.argv.slice(2)).catch((e) => {
  process.stderr.write(`canary: crash: ${e?.stack ?? e}\n`);
  process.exit(3);
});
