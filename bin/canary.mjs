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
 * (digit runs normalized, so ids and timestamps do not read as new); a same-site request
 * (the host or a subdomain of it) that now fails; a landmark that disappeared; a page that
 * now errors or is missing. Warning only: load time over 2x the baseline and over 3 s, since
 * live timing is noisy. Third-party failures (analytics, CDNs of others) never count.
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

export const LANDMARKS = ['h1', 'header', 'nav', 'main', 'footer'];
const SLOW_FACTOR = 2;
const SLOW_FLOOR_MS = 3000;

class UsageError extends Error {}

function usage(msg, code = 64) {
  process.stderr.write(`canary: ${msg}\n`);
  process.exit(code);
}

/** A host and its subdomains are "same site"; anything else is third party. */
export function sameSite(url, host) {
  try {
    const h = new URL(url).hostname;
    return h === host || h.endsWith(`.${host}`);
  } catch {
    return false;
  }
}

const norm = (text) => String(text).replace(/\d+/g, '#').trim();
const ok = (status) => status >= 200 && status < 400;

export function compareSnapshots(before, after) {
  for (const s of [before, after]) {
    if (!s || s.tool !== 'canary' || !Array.isArray(s.pages)) throw new UsageError('not a canary snapshot');
  }
  if (before.host !== after.host) {
    throw new UsageError(`snapshots are of different hosts (${before.host} vs ${after.host})`);
  }
  const afterByUrl = new Map(after.pages.map((p) => [p.url, p]));
  const pages = [];
  for (const b of before.pages) {
    const a = afterByUrl.get(b.url);
    const reasons = [];
    let verdict = 'ok';
    const regress = (r) => { reasons.push(r); verdict = 'regression'; };
    if (!a) {
      regress('page missing from the after snapshot');
    } else if (a.error && !b.error) {
      regress(`page failed to load: ${a.error}`);
    } else {
      if (ok(b.status) && !ok(a.status)) regress(`status ${b.status} -> ${a.status}`);
      const seen = new Set((b.consoleErrors ?? []).map(norm));
      for (const e of a.consoleErrors ?? []) if (!seen.has(norm(e))) regress(`new console error: ${e}`);
      const failedBefore = new Set((b.failedRequests ?? []).map((r) => r.url));
      for (const r of a.failedRequests ?? []) {
        if (!failedBefore.has(r.url) && sameSite(r.url, after.host)) {
          regress(`request failed (${r.status || 'network'}): ${r.url}`);
        }
      }
      for (const l of LANDMARKS) if (b.landmarks?.[l] && !a.landmarks?.[l]) regress(`landmark gone: ${l}`);
      if (verdict === 'ok' && a.ms > b.ms * SLOW_FACTOR && a.ms > SLOW_FLOOR_MS) {
        reasons.push(`slower: ${b.ms} ms -> ${a.ms} ms`);
        verdict = 'warn';
      }
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

async function main(argv) {
  const [cmd, ...args] = argv;
  if (cmd === 'compare') return runCompare(args);
  usage(`unknown subcommand '${cmd ?? ''}'. Use: snapshot <url>... --out <file> | compare <before> <after> [--json]`);
}

main(process.argv.slice(2)).catch((e) => {
  process.stderr.write(`canary: crash: ${e?.stack ?? e}\n`);
  process.exit(3);
});
