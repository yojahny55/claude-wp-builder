#!/usr/bin/env node
/**
 * assets-fresh.mjs: fail when per-template critical CSS cuts no longer match the sheet
 * they were cut from.
 *
 * A build that inlines a critical cut and loads the full sheet later needs two scripts run
 * in order: the one that rebuilds the bundle and its manifest, then the one that regenerates
 * the cuts from that bundle. Run only the first, and every cut is invalidated: the page
 * still works because the full sheet arrives anyway, so nothing errors and the first paint
 * is silently the uncut one. The same happens after a WordPress, plugin or builder update
 * rewrites a sheet the cuts were taken from. This tool recomputes CONTENT hashes (never
 * mtimes, which change on every checkout) and exits non-zero when any differ.
 *
 *   node bin/assets-fresh.mjs <theme-dir> [--manifest assets/build.json] [--root <dir>]
 *
 * Manifest (JSON), written by the project's own build:
 *   {
 *     "sheets": { "assets/css/bundle.min.css": "<sha256 hex>" },
 *     "cuts":   { "assets/critical/single-bundle.css":
 *                   { "source": "assets/css/bundle.min.css", "hash": "<sha256 hex>" } }
 *   }
 * `sheets` pins built files; each cut pins the hash of the sheet it was cut from. Paths are
 * relative to --root (default: the theme dir), so a cut taken from a core or plugin sheet
 * can name it with a path outside the theme, e.g. "../../../wp-includes/css/dist/block-library/style.min.css".
 *
 * Exit 0: fresh, or no manifest (nothing to check; prints SKIP). Exit 1: stale, with the
 * message "regenerate critical cuts". Exit 2: bad usage or an unreadable manifest.
 */
import { createHash } from 'node:crypto';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const KNOWN = new Set(['--manifest', '--root']);
const opts = {};
const positional = [];
const argv = process.argv.slice(2);
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (a.startsWith('--')) {
    if (!KNOWN.has(a)) {
      console.error(`ERROR: unknown flag ${a}`);
      process.exit(2);
    }
    const v = argv[i + 1];
    if (v === undefined || v.startsWith('--')) {
      console.error(`ERROR: ${a} needs a value`);
      process.exit(2);
    }
    opts[a] = v;
    i++;
  } else {
    positional.push(a);
  }
}
const manifestRel = opts['--manifest'] ?? 'assets/build.json';
const rootArg = opts['--root'] ?? null;
const themeDir = positional[0];
if (!themeDir) {
  console.error('usage: assets-fresh.mjs <theme-dir> [--manifest assets/build.json] [--root <dir>]');
  process.exit(2);
}
const root = resolve(rootArg ?? themeDir);
const manifestPath = resolve(themeDir, manifestRel);
if (!existsSync(manifestPath)) {
  console.log(`SKIP: no ${manifestRel} in ${themeDir}, nothing to check`);
  process.exit(0);
}

let manifest;
try {
  manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
} catch (e) {
  console.error(`ERROR: cannot read ${manifestPath}: ${e.message}`);
  process.exit(2);
}

if (!manifest || typeof manifest !== 'object' || Array.isArray(manifest)) {
  console.error(`ERROR: ${manifestPath} is not a JSON object`);
  process.exit(2);
}

const sha = (rel) => {
  const p = resolve(root, rel);
  if (!existsSync(p)) return null;
  try {
    return createHash('sha256').update(readFileSync(p)).digest('hex');
  } catch (e) {
    console.error(`ERROR: cannot read ${p}: ${e.message}`);
    process.exit(2);
  }
};
const stale = [];
for (const [rel, want] of Object.entries(manifest.sheets ?? {})) {
  const got = sha(rel);
  if (got !== want) stale.push(`sheet ${rel}: ${got ? 'content changed' : 'missing'}`);
}
for (const [cut, meta] of Object.entries(manifest.cuts ?? {})) {
  if (!meta || typeof meta.source !== 'string' || typeof meta.hash !== 'string') {
    console.error(`ERROR: cut "${cut}" in manifest is missing required "source" or "hash" property`);
    process.exit(2);
  }
  if (sha(cut) === null) {
    stale.push(`cut ${cut}: missing`);
    continue;
  }
  const got = sha(meta.source);
  if (got !== meta.hash) stale.push(`cut ${cut}: source ${meta.source} ${got ? 'changed since the cut' : 'is missing'}`);
}

if (stale.length) {
  console.error('STALE: regenerate critical cuts (rebuild the bundle first, then the cuts, and commit both with the manifest)');
  for (const s of stale) console.error(`  - ${s}`);
  process.exit(1);
}
console.log('FRESH: every sheet and critical cut matches its recorded hash');
