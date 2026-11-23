#!/usr/bin/env node
/**
 * woo-launch.mjs: take a WooCommerce store set up by /wp-woo-setup live, on purpose (/wp-woo-launch).
 *
 * Usage: woo-launch.mjs <project-path> [--url <base-url>] [--confirm <host>] [--backup-out <dir>]
 *        woo-launch.mjs <project-path> --revert
 *
 * Without --confirm it only checks, and writes nothing to the store (the cart check's session is
 * deleted, as in /wp-woo-verify):
 *   pass|fail <id>   skills/wp-woocommerce/scripts/woo-launch.php check: production, the live
 *                    Stripe keys and real Turnstile keys in wp-config.php (selling tiers)
 *   pass|fail verify bin/woo-verify.mjs: setup has nothing left to change, a cart works
 *   pass|fail audit  bin/store-audit.mjs --read-only: no CRITICAL finding but STORE-014 (the launch
 *                    itself), and the terms (STORE-005) and refund (STORE-007) pages say something
 * and the last line is `launch: ready` or `launch: blocked, N failed`.
 *
 * --confirm <host> launches, and only when <host> is exactly the host of the site's home URL:
 * the checks again, then a verified backup (bin/wp-backup.sh --label pre-launch, into
 * --backup-out or its default), then woo-launch.php apply (Stripe live, cash on delivery off,
 * Turnstile on the checkout, coming soon off last), then woo-verify again on the live store. When
 * that last verify fails the store goes back to coming soon and nothing is recorded. When it
 * passes, store.launch = { at, backup } is written to .wp-create.json, and from then on
 * /wp-woo-setup never writes launch state. A store already launched (store.launch with no
 * reverted_at) is refused.
 *
 * --revert puts the store back to coming soon, nothing else, and adds store.launch.reverted_at.
 * A launch after it replaces the record.
 *
 * --url is passed to woo-verify and store-audit (the home URL otherwise); --confirm still names
 * the home URL's host.
 *
 * Exit: 0 ready, launched or reverted; 1 blocked, refused, or the launch failed; 2 could not
 * measure (no native WP-CLI, WP-CLI or the site did not answer); 64 usage.
 */
import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import './lib/stdio-blocking.mjs';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const LAUNCH = join(ROOT, 'skills/wp-woocommerce/scripts/woo-launch.php');
const VERIFY = join(ROOT, 'bin/woo-verify.mjs');
const AUDIT = join(ROOT, 'bin/store-audit.mjs');
const BACKUP = join(ROOT, 'bin/wp-backup.sh');
const CONFIG = join(ROOT, 'bin/wp-config.mjs');
const USAGE = 'usage: woo-launch.mjs <project-path> [--url <base-url>] [--confirm <host>] [--backup-out <dir>] | <project-path> --revert';
// Findings that block a launch whatever their severity: a store takes money under its terms
// and its refund policy, and setup publishes the terms page empty.
const BLOCKING = ['STORE-005', 'STORE-007'];

function usage(msg) {
  process.stderr.write(`${msg ? `${msg}\n` : ''}${USAGE}\n`);
  process.exit(64);
}

const argv = process.argv.slice(2);
let project = '';
let url = '';
let confirm = null;
let backupOut = '';
let revert = false;
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (a === '--revert') revert = true;
  else if (a === '--confirm') {
    confirm = argv[++i];
    if (!confirm) usage('--confirm needs the host of the site, typed by the operator');
  } else if (a === '--backup-out') {
    backupOut = argv[++i] || '';
    if (!backupOut) usage('--backup-out needs a directory');
  } else if (a === '--url') {
    url = argv[++i] || '';
    if (!/^https?:\/\/[^/]/.test(url)) usage('--url needs an http(s) URL');
  } else if (a.startsWith('--')) usage(`unknown flag ${a}`);
  else if (!project) project = a;
  else usage(`unexpected argument ${a}`);
}
if (!project) usage();
if (revert && (confirm !== null || backupOut || url)) usage('--revert takes no other flag');

const manifestPath = join(project, '.wp-create.json');
if (!existsSync(manifestPath)) usage(`no .wp-create.json in ${project}`);
let manifest;
try {
  manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
} catch (e) {
  usage(`.wp-create.json does not parse: ${e.message}`);
}
const block = manifest.store && typeof manifest.store === 'object' && ['catalog', 'store', 'full'].includes(manifest.store.tier) ? manifest.store : null;
const wrapper = manifest.wp_cli && typeof manifest.wp_cli.wrapper === 'string' && manifest.wp_cli.wrapper.trim();
const engine = (manifest.environment && manifest.environment.engine) || 'native';

let failed = 0;
function line(status, id, detail = '') {
  if (status === 'fail') failed++;
  process.stdout.write(`${status} ${id}${detail ? `: ${detail}` : ''}\n`);
}
function refuse(msg, code = 1) {
  process.stdout.write(`refused: ${msg}\n`);
  process.exit(code);
}

if (!block) refuse('the manifest has no store block -- /wp-woo-setup records one, and only a store it set up is launched here');
if (engine !== 'native') refuse(`the store scripts need native WP-CLI on the host, and environment.engine is ${engine}`, 2);
if (!wrapper) refuse('the manifest has no wp_cli.wrapper', 2);

function run(cmd, args) {
  const r = spawnSync(cmd, args, { encoding: 'utf8', maxBuffer: 32 * 1024 * 1024 });
  return { code: r.status === null ? -1 : r.status, out: `${r.stdout || ''}`, err: `${r.stderr || ''}` };
}
const lastLine = (s) => s.trim().split('\n').pop() || '';
/** woo-launch.php through the manifest's WP-CLI; the arguments never pass through a shell string. */
const php = (...args) => run('bash', ['-c', `${wrapper} eval-file "$@"`, '_', LAUNCH, ...args]);
const withUrl = (args) => (url ? [...args, '--url', url] : args);

function setLaunch(value) {
  const r = spawnSync(process.execPath, [CONFIG, 'set', project, 'store.launch', '-'], { input: JSON.stringify(value), encoding: 'utf8' });
  return r.status === 0 ? '' : lastLine(`${r.stderr || ''}${r.stdout || ''}`) || `exit ${r.status}`;
}

// --- --revert: coming soon again ------------------------------------------------------------------
if (revert) {
  if (!block.launch) refuse('this store has no store.launch: /wp-woo-launch never launched it, so there is nothing to revert');
  const r = php('revert');
  process.stdout.write(r.out);
  if (r.code !== 0) refuse(`coming soon did not take: ${lastLine(r.err) || `exit ${r.code}`}`);
  const err = setLaunch({ ...block.launch, reverted_at: new Date().toISOString() });
  if (err) refuse(`the store is coming soon, but store.launch.reverted_at was not written: ${err}`);
  process.stdout.write('launch: reverted, the store is coming soon\n');
  process.exit(0);
}

if (confirm !== null && block.launch && !block.launch.reverted_at) {
  refuse(`this store was launched at ${block.launch.at}; --revert puts it back to coming soon first`);
}

// --- The checks ------------------------------------------------------------------------------------
function checks() {
  failed = 0;
  const c = php('check', block.tier);
  const facts = /^facts: (.*)$/m.exec(c.out);
  if (!facts) refuse(`WP-CLI could not read the store: ${(c.out.split('\n').find((l) => l.startsWith('refused:')) || lastLine(c.err) || `exit ${c.code}`).slice(0, 300)}`, c.out.includes('refused:') ? 1 : 2);
  for (const l of c.out.split('\n')) {
    const m = /^(pass|fail) (\S+): (.*)$/.exec(l);
    if (m) line(m[1], m[2], m[3]);
  }

  const v = run(process.execPath, withUrl([VERIFY, project]));
  if (v.code === 0) line('pass', 'verify', lastLine(v.out));
  else if (v.code === 1) line('fail', 'verify', v.out.split('\n').filter((l) => l.startsWith('fail ')).join('; ') || lastLine(v.out));
  else refuse(`woo-verify could not measure: ${v.out.split('\n').find((l) => l.startsWith('fail ')) || lastLine(v.err) || `exit ${v.code}`}`, 2);

  const a = run(process.execPath, withUrl([AUDIT, project, '--read-only']));
  let report;
  try { report = JSON.parse(a.out); } catch { refuse(`store-audit printed no report: ${lastLine(a.err) || `exit ${a.code}`}`, 2); }
  if (a.code === 2) refuse(`store-audit could not measure: ${(report.unmeasured[0] || {}).reason || `exit ${a.code}`}`, 2);
  const blocking = report.findings.filter((f) => (f.severity === 'CRITICAL' && f.check !== 'STORE-014') || BLOCKING.includes(f.check));
  if (blocking.length) line('fail', 'audit', blocking.map((f) => `${f.check} ${f.message}`).join('; '));
  else line('pass', 'audit', `no blocking finding${report.findings.length ? `; to read: ${report.findings.map((f) => `${f.check} ${f.severity}`).join(', ')}` : ''}`);
  return JSON.parse(facts[1]);
}

const facts = checks();
if (confirm === null) {
  process.stdout.write(failed ? `launch: blocked, ${failed} failed\n` : 'launch: ready\n');
  process.exit(failed ? 1 : 0);
}
if (failed) refuse(`${failed} check(s) fail: nothing was written`);
const host = new URL(facts.home).host;
if (confirm !== host) refuse(`--confirm "${confirm}" is not this site's host "${host}": nothing was written`);

// --- The launch ------------------------------------------------------------------------------------
const b = run('bash', [BACKUP, project, '--label', 'pre-launch', ...(backupOut ? ['--out', backupOut] : [])]);
const backup = lastLine(b.out);
if (b.code !== 0 || !backup.startsWith('/')) refuse(`no verified backup (wp-backup.sh exit ${b.code}: ${lastLine(b.err) || backup}): nothing was written`);
line('pass', 'backup', backup);

const ap = php('apply', block.tier);
process.stdout.write(ap.out.split('\n').filter((l) => /^(set|ok|fail) /.test(l)).map((l) => `${l}\n`).join(''));
if (ap.code !== 0) {
  refuse(`the launch stopped before coming soon went off: ${ap.out.split('\n').find((l) => /^(fail|refused)/.test(l)) || lastLine(ap.err) || `exit ${ap.code}`}; run it again once fixed, the steps done are skipped`);
}

const v = run(process.execPath, withUrl([VERIFY, project]));
if (v.code !== 0) {
  const why = v.out.split('\n').filter((l) => l.startsWith('fail ')).join('; ') || lastLine(v.err) || `exit ${v.code}`;
  const r = php('revert');
  refuse(r.code === 0
    ? `the live store failed verify (${why}); it is coming soon again, nothing recorded`
    : `the live store failed verify (${why}) AND going back to coming soon failed: switch it on in WooCommerce > Settings > Site visibility now`);
}
line('pass', 'verify', lastLine(v.out));

const err = setLaunch({ at: new Date().toISOString(), backup });
if (err) refuse(`the store is live, but store.launch was not written (${err}): /wp-woo-setup with force would take it back to coming soon; record it before running setup again`);
process.stdout.write(`launch: live, backup ${backup}\n`);
