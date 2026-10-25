// Playwright reporter: stop hammering a host that has stopped answering.
//
// A suite pointed at a host that drops packets (a firewall ban, a wrong host, a site that is
// down) spends the per-test timeout on every page, again on every retry, in every pass. That
// is minutes of requests against a host that already said no, and none of it measures
// anything. After WP_AUDIT_MAX_TIMEOUTS (default 3) timed-out attempts in a row the guard
// writes results/unmeasured.json with the cause and interrupts the run; bin/audit-suite.sh
// reads that file, sends nothing more and reports the browser tier UNMEASURED. Any attempt
// that finishes without timing out resets the count.
const fs = require('fs');
const path = require('path');

const TIMEOUT_MESSAGE = /Timeout \d+ms exceeded|net::ERR_TIMED_OUT|ETIMEDOUT|ERR_CONNECTION_TIMED_OUT/i;

function isTimeout(result) {
  if (result.status === 'timedOut') return true;
  if (result.status !== 'failed') return false;
  return (result.errors || [result.error]).some((e) => e && TIMEOUT_MESSAGE.test(String(e.message || '')));
}

class TimeoutGuard {
  constructor(options = {}) {
    const fromEnv = Number.parseInt(process.env.WP_AUDIT_MAX_TIMEOUTS || '', 10);
    this.max = options.max || (fromEnv > 0 ? fromEnv : 3);
    this.out = options.out || path.join('results', 'unmeasured.json');
    this.streak = 0;
    this.tripped = false;
    this.interrupt = options.interrupt || (() => process.kill(process.pid, 'SIGINT'));
  }

  printsToStdio() { return false; }

  onTestEnd(test, result) {
    if (this.tripped) return;
    if (!isTimeout(result)) { this.streak = 0; return; }
    this.streak += 1;
    if (this.streak < this.max) return;
    this.tripped = true;
    const reason = `${this.streak} page timeouts in a row (last: ${test.title}) -- the host is not answering; the run was stopped so it stops sending requests`;
    fs.mkdirSync(path.dirname(this.out), { recursive: true });
    fs.writeFileSync(this.out, `${JSON.stringify({ unmeasured: true, reason, timeouts: this.streak, max: this.max }, null, 2)}\n`);
    console.error(`[timeout-guard] ${reason}`);
    this.interrupt();
  }
}

module.exports = TimeoutGuard;
module.exports.isTimeout = isTimeout;
