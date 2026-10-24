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
console.log('PASS');
