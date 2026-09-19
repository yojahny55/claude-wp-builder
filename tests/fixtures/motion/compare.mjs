// Compare freshly-rendered shots against the approved baselines, and report how far off
// each one is.
//
// Usage: node tests/fixtures/motion/compare.mjs <shotdir> <baselinedir> <diffdir> <tolerance>
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

const [shotdir, baselinedir, diffdir, toleranceArg] = process.argv.slice(2);
if (!shotdir || !baselinedir || !diffdir || !toleranceArg) {
  console.log('usage: node compare.mjs <shotdir> <baselinedir> <diffdir> <tolerance>');
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
    console.log(`FAIL [${name}] rendered, but no approved baseline -- run with --approve and review the PNG`);
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

await writeFile(join(diffdir, 'report.json'), JSON.stringify(report, null, 2) + '\n');
console.log(failed ? 'VISUAL FAILED' : `VISUAL OK (${report.length} shots)`);
process.exit(failed);
