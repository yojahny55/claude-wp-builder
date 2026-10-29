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

// A host that answers its probe is a slow page, not a silent host: the streak resets, the run
// goes on, and the page is recorded unmeasured with the reason.
const slowOut = path.join(tmpDir, 'slow.json');
const slowPages = path.join(tmpDir, 'slow-pages.json');
let slowInterrupted = 0;
const sg = new Guard({ max: 2, out: slowOut, pagesOut: slowPages, baseURL: 'https://host.example/',
  probe: () => ({ status: 200, ms: 800 }), interrupt: () => { slowInterrupted += 1; } });
for (let i = 0; i < 5; i += 1) sg.onTestEnd({ id: `p${i}`, title: `page ${i}` }, { status: 'timedOut', duration: 90000 });
assert.strictEqual(slowInterrupted, 0, 'timeouts on a host that answers must not trip the guard');
assert.ok(!fs.existsSync(slowOut), 'a slow page must not write unmeasured.json');
const slow = JSON.parse(fs.readFileSync(slowPages, 'utf8'));
assert.strictEqual(slow.length, 5, 'every slow page is recorded');
assert.ok(/slow page/.test(slow[0].reason) && /HTTP 200 in 800 ms/.test(slow[0].reason), slow[0].reason);
// A retry that passes removes its page from the list.
sg.onTestEnd({ id: 'p0', title: 'page 0' }, { status: 'passed' });
assert.strictEqual(JSON.parse(fs.readFileSync(slowPages, 'utf8')).length, 4, 'a passing retry clears its entry');

// A host that refuses (no answer, or 403/429/503) still counts and trips.
for (const probe of [{ error: 'UND_ERR_CONNECT_TIMEOUT', ms: 5000 }, { status: 429, ms: 40 }]) {
  let n = 0;
  const bg = new Guard({ max: 2, out: path.join(tmpDir, `b${probe.ms}.json`), baseURL: 'https://host.example/',
    probe: () => probe, interrupt: () => { n += 1; } });
  bg.onTestEnd({ id: 'a', title: 'a' }, { status: 'timedOut' });
  bg.onTestEnd({ id: 'b', title: 'b' }, { status: 'timedOut' });
  assert.strictEqual(n, 1, `a host answering ${JSON.stringify(probe)} must trip the guard`);
}
// A TLS certificate Node cannot verify is still the host answering.
assert.strictEqual(Guard.hostAnswered({ error: 'DEPTH_ZERO_SELF_SIGNED_CERT' }), true);
assert.strictEqual(Guard.hostAnswered({ error: 'ECONNREFUSED' }), false);

// A helper that ran on a page closed under it is recorded unmeasured, never counted.
const closedPages = path.join(tmpDir, 'closed-pages.json');
const cg = new Guard({ max: 1, out: path.join(tmpDir, 'closed.json'), pagesOut: closedPages, interrupt: () => { throw new Error('must not trip'); } });
cg.onTestEnd({ id: 'm', title: 'metadata page' }, { status: 'failed', errors: [{ message: 'locator.count: Target page, context or browser has been closed' }] });
assert.ok(/page closed/.test(JSON.parse(fs.readFileSync(closedPages, 'utf8'))[0].reason));

// The real probe, against a server in another process (spawnSync blocks this one's loop).
const { spawn } = require('child_process');
const child = spawn(process.execPath, ['-e', "const s=require('http').createServer((q,r)=>r.end('ok')).listen(0,'127.0.0.1',()=>console.log(s.address().port))"]);
child.stdout.once('data', (d) => {
  const answered = Guard.probeHost(`http://127.0.0.1:${String(d).trim()}/`, 3000);
  child.kill();
  assert.strictEqual(answered.status, 200, JSON.stringify(answered));
  assert.strictEqual(Guard.hostAnswered(Guard.probeHost('http://127.0.0.1:9/', 2000)), false, 'a refused connection is not an answer');
  console.log('PASS');
});
