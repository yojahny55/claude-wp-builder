// Compare freshly-rendered shots against the approved baselines, and report how far off
// each one is.
//
// Usage: node tests/fixtures/motion/compare.mjs <shotdir> <baselinedir> <diffdir> <tolerance> [<mutant,...>]
// Exits 0 when every shot is within tolerance, 1 otherwise.
//
// "Reviewable tolerances" (I06) means the number is printed whether or not it passes. A
// check that says only PASS/FAIL gives a reviewer nothing to judge a borderline change
// with, and the first response to a mystery failure is to raise the limit until it stops.
// Printing the percentage for every shot, every run, makes a drift visible while it is
// still small.

import { readFile, writeFile, mkdir, readdir } from 'node:fs/promises';
import { join, basename } from 'node:path';
import { PNG } from 'pngjs';
import pixelmatch from 'pixelmatch';

const [shotdir, baselinedir, diffdir, toleranceArg, requiredArg = ''] = process.argv.slice(2);
// Mutants that must have been rendered (comma-separated), so dropping one is a failure.
const required = requiredArg.split(',').filter(Boolean);
if (!shotdir || !baselinedir || !diffdir || !toleranceArg) {
  console.log('usage: node compare.mjs <shotdir> <baselinedir> <diffdir> <tolerance> [<mutant,...>]');
  process.exit(1);
}
const tolerance = parseFloat(toleranceArg);
if (!(tolerance >= 0)) {
  console.log(`FAIL: tolerance ${JSON.stringify(toleranceArg)} is not a number`);
  process.exit(1);
}
await mkdir(diffdir, { recursive: true });

const read = async (p) => PNG.sync.read(await readFile(p));

const shots = JSON.parse(await readFile(join(shotdir, 'shots.json'), 'utf8'));

// The baseline directory is the authority on what SHOULD exist. Iterating the fresh shots
// alone would let a shot that stopped being taken pass silently -- nothing to compare is
// not the same as nothing changed, and it is the failure a screenshot suite is most likely
// to develop as fixtures move around.
const approved = (await readdir(baselinedir))
  .filter((f) => f.endsWith('.png'))
  .map((f) => basename(f, '.png'))
  .sort();

let failed = 0;
const report = [];

for (const name of approved) {
  if (!shots.includes(name)) {
    console.log(`FAIL [${name}] approved baseline exists but nothing rendered it`);
    failed = 1;
  }
}
for (const name of shots) {
  if (!approved.includes(name)) {
    console.log(`FAIL [${name}] rendered, but no approved baseline -- review the rendered PNG (tests/baselines/.failed-diffs/rendered/) and commit it as one`);
    failed = 1;
  }
}

for (const name of shots.filter((n) => approved.includes(n))) {
  const got = await read(join(shotdir, name + '.png'));
  const want = await read(join(baselinedir, name + '.png'));

  if (got.width !== want.width || got.height !== want.height) {
    console.log(
      `FAIL [${name}] size changed: ${want.width}x${want.height} -> ${got.width}x${got.height}`
    );
    failed = 1;
    continue;
  }

  const diff = new PNG({ width: got.width, height: got.height });
  // threshold is per-pixel colour distance, and is deliberately NOT the knob a failing
  // check gets to turn. It stays at pixelmatch's default so that "how different" is
  // measured the same way every run; the reviewable number is the percentage below.
  const differing = pixelmatch(got.data, want.data, diff.data, got.width, got.height, {
    threshold: 0.1,
  });
  const total = got.width * got.height;
  const pct = (differing / total) * 100;
  const ok = pct <= tolerance;

  report.push({ name, differing, total, pct: Number(pct.toFixed(4)), ok });
  console.log(
    `${ok ? 'ok  ' : 'FAIL'} [${name}] ${pct.toFixed(4)}% of ${total} px differ (tolerance ${tolerance}%)`
  );

  if (!ok) {
    failed = 1;
    // Written only on failure, and only for the shot that failed: a reviewer looking at a
    // red run wants the picture of what moved, not a directory of identical diffs.
    await writeFile(join(diffdir, name + '.diff.png'), PNG.sync.write(diff));
    console.log(`     diff written to ${join(diffdir, name + '.diff.png')}`);
  }
}

// Mutants (shoot.mjs): one token changed on a baselined page. Each must differ from its
// baseline by more than the tolerance; one that does not names a change these baselines
// cannot see. A missing mutants.json is a shooter that stopped producing them, not a pass.
let mutants = [];
try {
  mutants = JSON.parse(await readFile(join(shotdir, 'mutants.json'), 'utf8'));
} catch {
  console.log('FAIL the shooter wrote no mutants.json');
  failed = 1;
}
if (!Array.isArray(mutants) || mutants.length === 0) {
  console.log('FAIL no mutants were rendered');
  failed = 1;
  mutants = [];
}
for (const name of required.filter((n) => !mutants.includes(n))) {
  console.log(`FAIL [${name}] required mutant was not rendered`);
  failed = 1;
}
for (const name of mutants) {
  const of = name.split('~')[0];
  if (!approved.includes(of)) {
    console.log(`FAIL [${name}] mutates ${of}, which has no approved baseline`);
    failed = 1;
    continue;
  }
  const got = await read(join(shotdir, 'mutants', name + '.png'));
  const want = await read(join(baselinedir, of + '.png'));
  // A size mismatch is not "seen": nothing was compared pixel for pixel.
  if (got.width !== want.width || got.height !== want.height) {
    console.log(`FAIL [${name}] mutant is ${got.width}x${got.height}, its baseline ${want.width}x${want.height}`);
    failed = 1;
    continue;
  }
  const differing = pixelmatch(got.data, want.data, null, got.width, got.height, { threshold: 0.1 });
  const pct = (differing / (got.width * got.height)) * 100;
  const seen = pct > tolerance;
  report.push({ name, mutant: true, pct: Number(pct.toFixed(4)), seen });
  console.log(
    `${seen ? 'ok  ' : 'FAIL'} [${name}] mutant differs by ${pct.toFixed(4)}% (must exceed ${tolerance}%)`
  );
  if (!seen) failed = 1;
}

await writeFile(join(diffdir, 'report.json'), JSON.stringify(report, null, 2) + '\n');
const nm = report.filter((r) => r.mutant).length;
console.log(failed ? 'VISUAL FAILED' : `VISUAL OK (${report.length - nm} shots, ${nm} mutants seen)`);
process.exit(failed);
