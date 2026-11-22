#!/usr/bin/env node
/**
 * wp-status.mjs: read-only "where is this project and what runs next".
 *
 * Reads .wp-create.json, .claude/CLAUDE.md, demo/ and the two ledgers (the /wp-yolo build
 * ledger and the /wp-audit findings ledger) and prints one block plus a next command.
 * It writes nothing and never runs WP-CLI or touches the network.
 *
 * Exit codes: 0 report printed (whatever the state), 3 crash, 64 usage (unknown flag, or a
 * path that is not a directory).
 */
import { readFileSync, existsSync, statSync, readdirSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { MANIFEST_NAME, validateManifest, isAdopted } from './lib/manifest.mjs';

const HELP = `usage: wp-status.mjs [<project-path>] [--json] [--help]

Read-only. Reports the manifest, demo, build and audit state of a project and the next
command to run. Exit 0 whenever a report is printed, 64 on bad usage, 3 on a crash.
`;

function usage(msg) {
  process.stderr.write(`${msg}\n${HELP}`);
  process.exit(64);
}

// A read that tolerates absence and unreadable JSON: { state: 'absent'|'unreadable'|'ok', data }.
function readJson(file) {
  if (!existsSync(file)) return { state: 'absent' };
  try {
    return { state: 'ok', data: JSON.parse(readFileSync(file, 'utf8')) };
  } catch {
    return { state: 'unreadable' };
  }
}

const isFile = (p) => { try { return statSync(p).isFile(); } catch { return false; } };

export function collect(root) {
  const m = readJson(join(root, MANIFEST_NAME));
  const manifest = { exists: m.state !== 'absent', state: m.state };
  let data = null;
  if (m.state === 'ok') {
    data = m.data;
    const problems = validateManifest(data);
    manifest.state = problems.length ? 'invalid' : 'valid';
    manifest.problems = problems;
    const obj = data !== null && typeof data === 'object' && !Array.isArray(data);
    manifest.origin = obj && isAdopted(data) ? 'adopted' : 'created';
    manifest.demo_mode = (obj && data['demo mode']) || 'plain';
    manifest.i18n_strategy = (obj && data['i18n strategy']) || 'suffix';
    manifest.store_tier = obj && data.store && typeof data.store === 'object' ? (data.store.tier ?? null) : null;
  }
  manifest.claude_md = isFile(join(root, '.claude', 'CLAUDE.md'));

  const demoDir = join(root, 'demo');
  const demo = { dir: existsSync(demoDir), html: false, failed: null };
  if (demo.dir) {
    try {
      demo.html = readdirSync(demoDir).some((f) => f.endsWith('.html'));
    } catch { /* unreadable dir counts as no html */ }
  }
  for (const [key, f] of [['brief', 'BRIEF.md'], ['design', 'DESIGN.md'], ['verify', 'VERIFY.md'], ['research', 'RESEARCH.md'], ['yolo_manifest', '.yolo-manifest.json']]) {
    demo[key] = isFile(join(demoDir, f));
  }
  if (isFile(join(demoDir, 'FAILED.md'))) {
    try {
      demo.failed = readFileSync(join(demoDir, 'FAILED.md'), 'utf8').split('\n').slice(0, 10);
    } catch { demo.failed = []; }
  }

  const b = readJson(join(demoDir, '.yolo-progress.json'));
  const build = { state: b.state, units: 0, completed: null };
  // Valid JSON that is not the ledger object (null, an array, a number) is not a build in
  // progress: it is a ledger this tool cannot read. Only a non-empty `completed` string
  // (the ISO stamp /wp-yolo writes) means the build finished.
  if (b.state === 'ok' && !(b.data && typeof b.data === 'object' && !Array.isArray(b.data))) build.state = 'unreadable';
  if (build.state === 'ok') {
    build.units = Array.isArray(b.data.units) ? b.data.units.length : 0;
    build.completed = typeof b.data.completed === 'string' && b.data.completed !== '' ? b.data.completed : null;
  }

  // The manifest pointer wins; the conventional file name is the fallback.
  let ledgerPath = '.wp-audit-findings.json';
  const ptr = data?.audit?.findings_ledger?.path;
  if (typeof ptr === 'string' && ptr !== '') ledgerPath = ptr;
  const l = readJson(resolve(root, ledgerPath));
  const audit = { ledger: ledgerPath, state: l.state, counts: {}, total: 0 };
  // A ledger that parses but has no findings array is as unreadable as one that does not parse:
  // reading it as an empty ledger would report "nothing pending" over a corrupt file.
  if (l.state === 'ok' && !Array.isArray(l.data?.findings)) audit.state = 'unreadable';
  if (audit.state === 'ok') {
    for (const f of l.data.findings) {
      // An entry without a status string is counted as open (`unknown`): it cannot be shown done.
      const s = typeof f?.status === 'string' ? f.status : 'unknown';
      audit.counts[s] = (audit.counts[s] || 0) + 1;
      audit.total += 1;
    }
  }

  return { project: root, manifest, demo, build, audit, next: decide({ manifest, demo, build, audit }) };
}

export function decide({ manifest, demo, build, audit }) {
  const n = (s) => audit.counts[s] || 0;
  // g/h/i etc. are skipped for an adopted site: it is audited, never built with /wp-yolo.
  const adopted = manifest.origin === 'adopted';

  if (!manifest.exists) return { command: '/wp-create (new site) or /wp-adopt (existing site)', reason: 'there is no .wp-create.json' };
  if (manifest.state === 'unreadable') return { command: 'node ${CLAUDE_PLUGIN_ROOT}/bin/wp-config.mjs validate <path>', reason: '.wp-create.json cannot be parsed; fix it and validate again' };
  if (manifest.state === 'invalid') return { command: 'node ${CLAUDE_PLUGIN_ROOT}/bin/wp-config.mjs validate <path>', reason: `.wp-create.json is invalid (${manifest.problems.length} problem${manifest.problems.length === 1 ? '' : 's'}); fix it` };

  if (!adopted) {
    if (!manifest.claude_md) return { command: '/wp-init', reason: 'there is no .claude/CLAUDE.md' };
    if (demo.failed) return { command: '/wp-demo', reason: 'STOP: demo/FAILED.md says the demo failed verification; fix it, then run /wp-demo again' };
    if (!demo.html) return { command: '/wp-demo', reason: 'there is no demo/*.html' };
    if (build.state !== 'ok') return { command: '/wp-yolo demo/', reason: build.state === 'unreadable' ? 'demo/.yolo-progress.json cannot be read' : 'the demo has not been built into the theme yet' };
    if (build.completed === null) return { command: '/wp-yolo demo/ --resume', reason: `the build is unfinished (${build.units} unit${build.units === 1 ? '' : 's'} done)` };
    if (!demo.verify) return { command: '/wp-finalize, then /wp-demo-verify demo/', reason: 'the build is complete and demo/VERIFY.md does not exist' };
  }

  if (audit.state !== 'ok') return { command: '/wp-audit', reason: (adopted ? 'an adopted site is audited, not built; ' : '') + (audit.state === 'unreadable' ? `the findings ledger ${audit.ledger} cannot be read` : 'there is no findings ledger') };
  // Open as the ledger defines it (new + still_failing + unmeasured), plus fixed_unverified,
  // which still needs a run to confirm, and entries whose status cannot be read.
  const open = n('new') + n('still_failing') + n('unmeasured') + n('fixed_unverified') + n('unknown');
  if (open > 0) return { command: '/wp-audit', reason: `re-run to fix or verify: ${n('new')} new, ${n('still_failing')} still failing, ${n('unmeasured')} unmeasured, ${n('fixed_unverified')} fixed but unverified${n('unknown') ? `, ${n('unknown')} without a status` : ''}` };
  return { command: null, reason: 'nothing pending' };
}

function render(r) {
  const m = r.manifest;
  const L = [];
  L.push(`Project:   ${r.project}`);
  L.push(`Manifest:  ${m.exists ? `${m.state}${m.origin ? `, ${m.origin}` : ''}` : 'absent'}${m.exists && m.claude_md ? '' : m.exists ? ', no .claude/CLAUDE.md' : ''}`);
  if (m.state === 'valid' || m.state === 'invalid') {
    L.push(`Demo mode: ${m.demo_mode}`);
    L.push(`i18n:      ${m.i18n_strategy}`);
    if (m.store_tier) L.push(`Store:     ${m.store_tier}`);
  }
  const d = r.demo;
  const bits = [d.html ? 'html' : 'no html', ...['brief', 'design', 'verify', 'research'].filter((k) => d[k]).map((k) => k.toUpperCase() + '.md')];
  L.push(`Demo:      ${bits.join(', ')}`);
  if (d.failed) { L.push('FAILED.md:'); for (const x of d.failed) L.push(`  ${x}`); }
  L.push(`Build:     ${r.build.state === 'ok' ? `${r.build.units} unit(s), ${r.build.completed ? `completed ${r.build.completed}` : 'not completed'}` : r.build.state}`);
  const c = Object.entries(r.audit.counts).map(([k, v]) => `${v} ${k}`).join(', ');
  L.push(`Audit:     ${r.audit.state === 'ok' ? (c || 'ledger is empty') : r.audit.state}`);
  L.push(r.next.command ? `Next: ${r.next.command} — ${r.next.reason}` : `Next: nothing — ${r.next.reason}`);
  return L.join('\n') + '\n';
}

function main(argv) {
  let json = false;
  let target = null;
  for (const a of argv) {
    if (a === '--help' || a === '-h') { process.stdout.write(HELP); return; }
    if (a === '--json') json = true;
    else if (a.startsWith('-')) usage(`unknown flag: ${a}`);
    else if (target === null) target = a;
    else usage(`unexpected argument: ${a}`);
  }
  const root = resolve(target ?? '.');
  if (!existsSync(root) || !statSync(root).isDirectory()) usage(`not a directory: ${root}`);
  const r = collect(root);
  process.stdout.write(json ? JSON.stringify(r, null, 2) + '\n' : render(r));
}

try {
  main(process.argv.slice(2));
} catch (e) {
  process.stderr.write(`wp-status crashed: ${e?.stack || e}\n`);
  process.exit(3);
}
