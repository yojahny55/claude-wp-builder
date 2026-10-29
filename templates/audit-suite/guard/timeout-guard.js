// Playwright reporter: stop hammering a host that has stopped answering.
//
// A suite pointed at a host that drops packets (a firewall ban, a wrong host, a site that is
// down) spends the per-test timeout on every page, again on every retry, in every pass. That
// is minutes of requests against a host that already said no, and none of it measures
// anything. After WP_AUDIT_MAX_TIMEOUTS (default 3) timed-out attempts in a row the guard
// writes results/unmeasured.json with the cause and interrupts the run; bin/audit-suite.sh
// reads that file, sends nothing more and reports the browser tier UNMEASURED. Any attempt
// that finishes without timing out resets the count.
//
// A timeout is not by itself proof that the host stopped answering. On a third-party-heavy
// page (video embeds, analytics, polling widgets) a page can miss its settle while the host
// answers in under a second, and counting those tripped the brake on a healthy host three
// runs out of three. So each timeout is followed by one quick GET of BASE_URL (WP_AUDIT_PROBE_MS,
// default 5000 ms). Only a host that does not answer, refuses the connection, or answers
// 403/429/503 (a firewall or rate limiter saying no) counts toward the streak. A host that
// answers resets it: the page is recorded as slow and the run goes on.
//
// Every attempt that ends in a timeout or on a closed page is also recorded, page by page, in
// results/unmeasured-pages.json with its reason; an attempt that later passes removes its
// entry. scripts/to-run.js reports what is left there as UNMEASURED, instead of the page
// silently missing from the run or a helper's "page has been closed" reading as a finding.
const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const TIMEOUT_MESSAGE = /Timeout \d+ms exceeded|net::ERR_TIMED_OUT|ETIMEDOUT|ERR_CONNECTION_TIMED_OUT/i;

// A browser that cannot start is a local resource problem (four workers on little RAM), not
// a host that stopped answering: counting it would write unmeasured.json with the wrong cause.
const LAUNCH_FAILURE = /browserType\.launch|\blaunch:/i;

// Errors raised by a helper still running when the test timed out and the page went away.
const CLOSED_MESSAGE = /Target page, context or browser has been closed|Target closed|has been closed|Browser closed/i;

function isClosed(result) {
  return (result.errors || [result.error]).some((e) => e && CLOSED_MESSAGE.test(String(e.message || '')));
}

// One GET, in a child process so the reporter can stay synchronous. "answered" means a TCP
// connection and a response, a TLS certificate the child cannot verify included: the browser
// trusts certificates Node does not, and a handshake is the host answering.
const PROBE_SCRIPT = `
const [url, ms] = process.argv.slice(1);
const t0 = Date.now();
fetch(url, { redirect: 'manual', signal: AbortSignal.timeout(Number(ms)) })
  .then((r) => { console.log(JSON.stringify({ status: r.status, ms: Date.now() - t0 })); })
  .catch((e) => {
    const code = (e && e.cause && e.cause.code) || (e && e.name) || 'error';
    console.log(JSON.stringify({ error: String(code), ms: Date.now() - t0 }));
  });
`;
function probeHost(url, ms) {
  const r = spawnSync(process.execPath, ['-e', PROBE_SCRIPT, url, String(ms)], { encoding: 'utf8', timeout: ms + 3000 });
  try { return JSON.parse(String(r.stdout || '').trim().split('\n').pop()); } catch { return { error: 'probe failed', ms }; }
}
const TLS_ANSWER = /CERT|SELF_SIGNED|UNABLE_TO_VERIFY|ERR_TLS|ERR_SSL/i;
const REFUSING = new Set([403, 429, 503]);
function hostAnswered(probe) {
  if (!probe) return false;
  if (typeof probe.status === 'number') return !REFUSING.has(probe.status);
  return TLS_ANSWER.test(String(probe.error || ''));
}

function isTimeout(result) {
  if (result.status === 'timedOut') return true;
  if (result.status !== 'failed') return false;
  return (result.errors || [result.error]).some((e) => {
    const message = e ? String(e.message || '') : '';
    return TIMEOUT_MESSAGE.test(message) && !LAUNCH_FAILURE.test(message);
  });
}

class TimeoutGuard {
  constructor(options = {}) {
    const fromEnv = Number.parseInt(process.env.WP_AUDIT_MAX_TIMEOUTS || '', 10);
    this.max = options.max || (fromEnv > 0 ? fromEnv : 3);
    this.out = options.out || path.join('results', 'unmeasured.json');
    this.streak = 0;
    this.tripped = false;
    this.interrupt = options.interrupt || (() => process.kill(process.pid, 'SIGINT'));
    this.pagesOut = options.pagesOut || path.join(path.dirname(this.out), 'unmeasured-pages.json');
    // No URL to probe (a self-check, a run without BASE_URL): every timeout counts, as before.
    this.baseURL = options.baseURL !== undefined ? options.baseURL : (process.env.BASE_URL || '');
    const probeMs = Number.parseInt(process.env.WP_AUDIT_PROBE_MS || '', 10);
    this.probeMs = probeMs > 0 ? probeMs : 5000;
    this.probe = options.probe || ((url) => probeHost(url, this.probeMs));
    // Each pass is its own `playwright test` process with its own guard, all writing one file,
    // so a guard starts from what the earlier passes recorded instead of overwriting it.
    // bin/audit-suite.sh deletes the file once, before the first pass.
    this.pages = {};
    try {
      for (const e of JSON.parse(fs.readFileSync(this.pagesOut, 'utf8'))) if (e && e.key) this.pages[e.key] = e;
    } catch { /* absent or unreadable: start empty */ }
  }

  printsToStdio() { return false; }

  record(test, result, reason) {
    const titlePath = typeof test.titlePath === 'function' ? test.titlePath() : [];
    // The title path carries the project, so the key is unique across passes; a test id is
    // unique only inside one run.
    const key = titlePath.length ? titlePath.join(' > ') : (test.id || test.title);
    if (reason) this.pages[key] = { key, page: test.title, project: titlePath[1] || '', reason };
    else if (!(key in this.pages)) return;
    else delete this.pages[key];
    fs.mkdirSync(path.dirname(this.pagesOut), { recursive: true });
    fs.writeFileSync(this.pagesOut, `${JSON.stringify(Object.values(this.pages), null, 2)}\n`);
  }

  onTestEnd(test, result) {
    if (this.tripped) return;
    const timedOut = isTimeout(result);
    const closed = !timedOut && result.status !== 'passed' && isClosed(result);
    if (!timedOut && !closed) { this.streak = 0; this.record(test, result, null); return; }
    const seconds = Math.round((result.duration || 0) / 1000);
    if (closed) {
      this.record(test, result, `the page closed under a running check after ${seconds}s (a timeout elsewhere in the test) -- not measured`);
      return;
    }
    if (this.baseURL) {
      const probe = this.probe(this.baseURL);
      if (hostAnswered(probe)) {
        this.streak = 0;
        this.record(test, result, `slow page: timed out after ${seconds}s while the host answered `
          + `(${probe.status !== undefined ? `HTTP ${probe.status}` : probe.error} in ${probe.ms} ms) -- not measured, the run went on`);
        return;
      }
      this.record(test, result, `timed out after ${seconds}s and the host did not answer a direct request (${probe ? (probe.error || `HTTP ${probe.status}`) : 'no probe'})`);
    } else {
      this.record(test, result, `timed out after ${seconds}s`);
    }
    this.streak += 1;
    if (this.streak < this.max) return;
    this.tripped = true;
    const reason = this.baseURL
      ? `${this.streak} page timeouts in a row (last: ${test.title}), and the host did not answer a direct request after them -- it is not answering or is refusing this client; the run was stopped so it stops sending requests`
      : `${this.streak} page timeouts in a row (last: ${test.title}) -- the host is not answering; the run was stopped so it stops sending requests`;
    fs.mkdirSync(path.dirname(this.out), { recursive: true });
    fs.writeFileSync(this.out, `${JSON.stringify({ unmeasured: true, reason, timeouts: this.streak, max: this.max }, null, 2)}\n`);
    console.error(`[timeout-guard] ${reason}`);
    this.interrupt();
  }
}

module.exports = TimeoutGuard;
module.exports.isTimeout = isTimeout;
module.exports.isClosed = isClosed;
module.exports.hostAnswered = hostAnswered;
module.exports.probeHost = probeHost;
