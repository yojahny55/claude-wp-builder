#!/usr/bin/env node
/**
 * link-sweep.mjs: status-code sweep over a list of links, with the load limits built in.
 *
 * Audit agents are told to follow links and report broken ones. Given no method, one
 * improvised a crawler with 25 concurrent `curl -L` workers against a local WooCommerce
 * build: hundreds of uncached ~570 KB term archives, MariaDB at ~18 cores, load 18, and
 * every other site on the machine slowed down with it. A local site shares one database
 * and one web server with every project on the box, and an uncached WordPress render is
 * expensive. This tool is the sweep with those limits fixed, so agents stop writing one.
 *
 *   - at most 4 requests in flight, whatever --concurrency asks for;
 *   - HEAD first; GET with `Range: bytes=0-0` only when HEAD is refused (405/501);
 *   - links are classified before anything is requested:
 *       internal      same host as --site
 *       clone-origin  the host named by --clone-origin (production, seen from a clone):
 *                     never requested unless --follow-clone-origin says the operator
 *                     confirmed that host this run; UNMEASURED otherwise
 *       external      any other http(s) host
 *       fragment      `#…` pointing at the page it is on: reported, never requested
 *       skipped       mailto:, tel:, javascript: and other non-http schemes
 *   - a CDN bot challenge (403/503 with `cf-mitigated: challenge`, or a body carrying
 *     `challenge-platform`) is UNMEASURED, never broken, and never retried with another
 *     User-Agent;
 *   - internal links are sampled per group (--per-group, default 20): the third input
 *     column when present (`tax:<taxonomy>`, `type:<post_type>`, as written by
 *     skills/wp-cli-patterns/scripts/resolve-link-targets.php), else the first path
 *     segment. Hundreds of term archives cost 20 renders rather than hundreds; --full
 *     lifts it;
 *   - --per-page <n> caps the requests charged to each page a link was found on (a link
 *     carried by several pages is charged once, to the first page with quota left), so a
 *     mega-menu of every archive on the site does not become the whole sweep;
 *   - a wall-clock budget (--budget, default 120 s): what is not done by then is
 *     UNMEASURED with the reason, and the tool still exits with a report.
 *
 * Input is one link per line on stdin or in --urls <file>, optionally followed by a TAB
 * and the page it was found on, and optionally a TAB and a sampling group. Relative links resolve against the page, else --site.
 * Duplicates collapse into one request whose `pages` lists every page carrying it.
 *
 * usage:
 *   link-sweep.mjs --site <origin> [--urls <file>] [--clone-origin <host>]
 *                  [--follow-clone-origin] [--concurrency <1-4>] [--per-group <n>] [--full]
 *                  [--per-page <n>] [--max <n>] [--timeout <s>] [--budget <s>] [--insecure]
 *
 * Output: JSON on stdout, `{ summary, results }`. Each result carries `url`, `class`,
 * `status` (HTTP code or null), `final` (after redirects), `verdict`
 * (ok | broken | redirect | unmeasured | fragment | skipped), `reason` and `pages`.
 *
 * exit 0 = sweep ran (findings are in the JSON), 2 = usage.
 */
import { readFileSync } from 'node:fs';

const USAGE = 'usage: link-sweep.mjs --site <origin> [--urls <file>] [--clone-origin <host>] ' +
  '[--follow-clone-origin] [--concurrency <1-4>] [--per-group <n>] [--full] [--per-page <n>] [--max <n>] ' +
  '[--timeout <s>] [--budget <s>] [--insecure]';
const MAX_CONCURRENCY = 4;
const UA = 'claude-wp-builder-link-sweep';

function usage(msg) {
  if (msg) process.stderr.write(`link-sweep: ${msg}\n`);
  process.stderr.write(USAGE + '\n');
  process.exit(2);
}

function parseArgs(argv) {
  const o = { concurrency: MAX_CONCURRENCY, perGroup: 20, perPage: 0, max: 0, timeout: 10, budget: 120,
    full: false, followClone: false, insecure: false };
  const num = (v, flag) => {
    const n = Number(v);
    if (!Number.isFinite(n) || n < 0) usage(`${flag} needs a non-negative number`);
    return n;
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    const next = () => { if (i + 1 >= argv.length) usage(`${a} needs a value`); return argv[++i]; };
    switch (a) {
      case '--site': o.site = next(); break;
      case '--urls': o.urls = next(); break;
      case '--clone-origin': o.cloneOrigin = next(); break;
      case '--follow-clone-origin': o.followClone = true; break;
      case '--concurrency': o.concurrency = num(next(), a); break;
      case '--per-group': o.perGroup = num(next(), a); break;
      case '--full': o.full = true; break;
      case '--per-page': o.perPage = num(next(), a); break;
      case '--max': o.max = num(next(), a); break;
      case '--timeout': o.timeout = num(next(), a); break;
      case '--budget': o.budget = num(next(), a); break;
      case '--insecure': o.insecure = true; break;
      case '-h': case '--help': process.stdout.write(USAGE + '\n'); process.exit(0);
      default: usage(`unknown argument ${a}`);
    }
  }
  if (!o.site) usage('--site is required');
  try { o.siteUrl = new URL(o.site); } catch { usage(`--site is not a URL: ${o.site}`); }
  o.concurrency = Math.min(Math.max(1, Math.floor(o.concurrency)), MAX_CONCURRENCY);
  return o;
}

const bareHost = (h) => String(h || '').toLowerCase().replace(/^www\./, '');

function hostOf(v) {
  if (!v) return '';
  try { return new URL(/^[a-z][a-z0-9+.-]*:\/\//i.test(v) ? v : `https://${v}`).hostname; }
  catch { return v; }
}

function readLines(o) {
  let text;
  try { text = o.urls ? readFileSync(o.urls, 'utf8') : readFileSync(0, 'utf8'); }
  catch (e) { usage(`cannot read ${o.urls || 'stdin'}: ${e.message}`); }
  return text.split(/\r?\n/).map((l) => l.trim()).filter(Boolean).map((l) => {
    const [href, page, group] = l.split('\t');
    return { href: href.trim(), page: page ? page.trim() : null, group: group ? group.trim() : null };
  });
}

function classify(o, href, page) {
  const base = page ? new URL(page, o.siteUrl) : o.siteUrl;
  if (/^#/.test(href)) return { key: `fragment:${base.href}${href}`, class: 'fragment', url: href };
  if (/^[a-z][a-z0-9+.-]*:/i.test(href) && !/^https?:/i.test(href)) {
    return { key: `skipped:${href}`, class: 'skipped', url: href };
  }
  let u;
  try { u = new URL(href, base); } catch { return { key: `bad:${href}`, class: 'skipped', url: href, bad: true }; }
  const samePage = u.href.split('#')[0] === base.href.split('#')[0] && u.hash;
  u.hash = '';
  const host = bareHost(u.hostname);
  let cls = 'external';
  if (host === bareHost(o.siteUrl.hostname)) cls = samePage ? 'fragment' : 'internal';
  else if (o.cloneOrigin && host === bareHost(hostOf(o.cloneOrigin))) cls = 'clone-origin';
  return { key: `${cls}:${u.href}`, class: cls, url: u.href };
}

function isChallenge(res, body) {
  if (![403, 429, 503].includes(res.status)) return false;
  if (/challenge/i.test(res.headers.get('cf-mitigated') || '')) return true;
  return /challenge-platform|cf-chl-|_cf_chl_opt/i.test(body || '');
}

async function request(o, url, deadline) {
  const left = deadline - Date.now();
  if (left <= 0) return { verdict: 'unmeasured', status: null, reason: 'budget exhausted before this link' };
  const signal = AbortSignal.timeout(Math.min(o.timeout * 1000, left));
  const headers = { 'user-agent': UA };
  try {
    let res = await fetch(url, { method: 'HEAD', redirect: 'follow', headers, signal });
    let body = '';
    if (res.status === 405 || res.status === 501) {
      res = await fetch(url, { method: 'GET', redirect: 'follow', signal,
        headers: { ...headers, range: 'bytes=0-0' } });
      await res.body?.cancel();
    }
    if ([403, 429, 503].includes(res.status) && !res.headers.get('cf-mitigated')) {
      // A HEAD carries no body; read at most 64 KB of one GET to tell a challenge page from a
      // real refusal. One request, same User-Agent: a challenge is not a reason to retry.
      const g = await fetch(url, { method: 'GET', redirect: 'follow', headers, signal });
      const reader = g.body?.getReader();
      let got = 0;
      const dec = new TextDecoder();
      while (reader && got < 65536) {
        const { done, value } = await reader.read();
        if (done) break;
        got += value.length;
        body += dec.decode(value, { stream: true });
      }
      await reader?.cancel();
      if (isChallenge(g, body)) res = g;
    }
    if (isChallenge(res, body)) {
      return { verdict: 'unmeasured', status: res.status, final: res.url,
        reason: 'blocked by CDN bot challenge — not a broken link; not retried' };
    }
    const moved = res.url && res.url !== url;
    const verdict = res.status >= 400 ? 'broken' : moved ? 'redirect' : 'ok';
    return { verdict, status: res.status, final: res.url };
  } catch (e) {
    const timeout = e.name === 'TimeoutError' || e.name === 'AbortError';
    if (timeout && Date.now() >= deadline) {
      return { verdict: 'unmeasured', status: null, reason: 'budget exhausted during request' };
    }
    const code = e.cause?.code || e.code || e.name;
    // DNS failure is a dead link by definition; anything else is a failure to measure.
    if (code === 'ENOTFOUND') return { verdict: 'broken', status: null, reason: 'DNS: host not found' };
    return { verdict: 'unmeasured', status: null, reason: timeout ? `timeout after ${o.timeout}s` : `request failed: ${code}` };
  }
}

async function main() {
  const o = parseArgs(process.argv.slice(2));
  if (o.insecure) process.env.NODE_TLS_REJECT_UNAUTHORIZED = '0';
  const byKey = new Map();
  for (const { href, page, group } of readLines(o)) {
    const c = classify(o, href, page);
    const r = byKey.get(c.key) || { url: c.url, class: c.class, pages: [], bad: c.bad, group: group || null };
    if (page && !r.pages.includes(page)) r.pages.push(page);
    byKey.set(c.key, r);
  }
  const all = [...byKey.values()];
  const queue = [];
  const perGroup = new Map();
  const perPage = new Map();
  for (const r of all) {
    if (r.class === 'fragment') { Object.assign(r, { verdict: 'fragment', status: null, reason: 'resolves to the page it is on' }); continue; }
    if (r.class === 'skipped') { Object.assign(r, { verdict: 'skipped', status: null, reason: r.bad ? 'unparseable href' : 'not an http(s) link' }); continue; }
    if (r.class === 'clone-origin' && !o.followClone) {
      Object.assign(r, { verdict: 'unmeasured', status: null,
        reason: 'clone-origin host not confirmed this run (--follow-clone-origin)' });
      continue;
    }
    if (r.class === 'internal' && !o.full && o.perGroup > 0) {
      const seg = new URL(r.url).pathname.split('/').filter(Boolean)[0];
      const key = r.group || (seg ? `/${seg}/` : '/');
      const n = (perGroup.get(key) || 0) + 1;
      perGroup.set(key, n);
      if (n > o.perGroup) {
        Object.assign(r, { verdict: 'unmeasured', status: null,
          reason: `sampled: over ${o.perGroup} links in ${key} (--full to sweep all)` });
        continue;
      }
    }
    if (o.perPage > 0 && r.pages.length) {
      const page = r.pages.find((p) => (perPage.get(p) || 0) < o.perPage);
      if (!page) {
        Object.assign(r, { verdict: 'unmeasured', status: null,
          reason: `over --per-page ${o.perPage} on every page carrying it` });
        continue;
      }
      perPage.set(page, (perPage.get(page) || 0) + 1);
    }
    if (o.max > 0 && queue.length >= o.max) {
      Object.assign(r, { verdict: 'unmeasured', status: null, reason: `over --max ${o.max}` });
      continue;
    }
    queue.push(r);
  }

  const deadline = Date.now() + o.budget * 1000;
  let next = 0;
  let inFlight = 0;
  let peak = 0;
  const worker = async () => {
    while (next < queue.length) {
      const r = queue[next++];
      inFlight++;
      peak = Math.max(peak, inFlight);
      try { Object.assign(r, await request(o, r.url, deadline)); } finally { inFlight--; }
    }
  };
  await Promise.all(Array.from({ length: Math.min(o.concurrency, queue.length) }, worker));

  const summary = { total: all.length, requested: queue.length, concurrency: o.concurrency,
    peak_in_flight: peak };
  for (const r of all) {
    delete r.bad;
    summary[r.verdict] = (summary[r.verdict] || 0) + 1;
  }
  process.stdout.write(JSON.stringify({ summary, results: all }, null, 2) + '\n');
}

main();
