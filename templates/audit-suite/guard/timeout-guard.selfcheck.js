// node guard/timeout-guard.selfcheck.js -- the guard trips on N consecutive timeouts, not on N total.
const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');
const Guard = require('./timeout-guard');

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'tg-'));
process.on('exit', () => fs.rmSync(tmpDir, { recursive: true, force: true }));
const out = path.join(tmpDir, 'unmeasured.json');
let interrupted = 0;
const g = new Guard({ max: 3, out, interrupt: () => { interrupted += 1; } });
const t = { title: 'home' };
g.onTestEnd(t, { status: 'timedOut' });
g.onTestEnd(t, { status: 'timedOut' });
g.onTestEnd(t, { status: 'passed' });
g.onTestEnd(t, { status: 'timedOut' });
g.onTestEnd(t, { status: 'failed', errors: [{ message: 'page.goto: Timeout 90000ms exceeded.' }] });
assert.strictEqual(interrupted, 0, 'a passing attempt must reset the streak');
g.onTestEnd(t, { status: 'timedOut' });
assert.strictEqual(interrupted, 1, 'three in a row must stop the run');
assert.ok(JSON.parse(fs.readFileSync(out, 'utf8')).reason.includes('3 page timeouts'));
g.onTestEnd(t, { status: 'timedOut' });
assert.strictEqual(interrupted, 1, 'it trips once');

// A browser that times out launching is not a silent host: it must neither count nor trip.
const launchOut = path.join(tmpDir, 'launch.json');
let launchInterrupted = 0;
const lg = new Guard({ max: 2, out: launchOut, interrupt: () => { launchInterrupted += 1; } });
for (let i = 0; i < 4; i += 1) {
  lg.onTestEnd(t, { status: 'failed', errors: [{ message: 'browserType.launch: Timeout 180000ms exceeded.' }] });
}
assert.strictEqual(launchInterrupted, 0, 'a browser launch timeout must not trip the guard');
assert.ok(!fs.existsSync(launchOut), 'a browser launch timeout must not write unmeasured.json');
assert.strictEqual(Guard.isTimeout({ status: 'failed', errors: [{ message: 'page.goto: Timeout 90000ms exceeded.' }] }), true);
console.log('PASS');
