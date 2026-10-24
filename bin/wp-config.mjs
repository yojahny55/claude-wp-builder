#!/usr/bin/env node
/**
 * wp-config.mjs: the one gate every command that reads .wp-create.json passes through.
 *
 * Exit codes are fixed and are part of the contract: 0 ok, 1 invalid or refused,
 * 2 a migration is available, 3 there is no manifest. `drift` adds 4: the manifest
 * validates but no longer describes the site. `gitignore-check` also uses 4: tool state
 * paths are listed that git would commit.
 */
import {
  readFileSync, existsSync, writeFileSync, copyFileSync, mkdirSync, renameSync, unlinkSync, rmdirSync, statSync, readdirSync,
} from 'node:fs';
import { join, resolve, dirname, basename } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import {
  CURRENT_VERSION, MANIFEST_NAME, LOCAL_NAME, detectVersion, versionProblem, validateManifest, migrateManifest,
  renderContext, spliceContext, contextDrift, resolveSecret, getKey, SECRETS, validateProfile,
  supersedeProseDecisions, testedVerdicts,
} from './lib/manifest.mjs';
import {
  detectWrapper, runProbe, buildManifest, isWordPressRoot, manifestDrift, isTransientWrapper,
  isPluginListDrift, isScaffoldManifest, carryOver, detectStack,
} from './lib/adopt.mjs';

// Every manifest write goes through here: the bytes land in a sibling temp file and are
// renamed over the target, so a reader (or a parallel builder) sees the old file or the
// new one, never a half-written one. rename(2) is atomic within a directory.
// Only `set` also takes withLock: migrate, render-context, adopt and refresh are one-shot
// commands run by a single operator or a sequential flow, so they are single-writer by
// contract; the temp name carries the pid, so concurrent writers never share a temp file.
function sweepOrphans(dir, prefix, suffixOk, maxAgeMs) {
  // A writer killed between create and rename/rmdir leaves its temp file or aside directory
  // behind. Anything this old belongs to a dead process (a live write takes milliseconds).
  let names = [];
  try { names = readdirSync(dir); } catch { return; }
  for (const n of names) {
    if (!n.startsWith(prefix) || !suffixOk(n)) continue;
    const p = join(dir, n);
    try {
      if (Date.now() - statSync(p).mtimeMs <= maxAgeMs) continue;
      if (statSync(p).isDirectory()) rmdirSync(p); else unlinkSync(p);
    } catch { /* raced with its owner or another sweeper */ }
  }
}

function writeAtomic(file, data) {
  sweepOrphans(dirname(file), `${basename(file)}.`, (n) => n.endsWith('.tmp'), 60000);
  const tmp = `${file}.${process.pid}.${Date.now()}.tmp`;
  try {
    writeFileSync(tmp, data);
    renameSync(tmp, file);
  } catch (err) {
    try { unlinkSync(tmp); } catch { /* nothing to clean */ }
    throw err;
  }
}

// Serializes read-modify-write cycles (`set`) across processes. An atomic rename stops torn
// reads but not lost updates: two writers that both read before either writes would each
// overwrite the other's key. mkdir is the portable atomic test-and-set; a lock older than
// 30 s belongs to a dead writer and is taken over.
function withLock(file, fn) {
  const lock = `${file}.lock`;
  sweepOrphans(dirname(file), `${basename(lock)}.stale.`, () => true, 60000);
  const deadline = Date.now() + 10000;
  for (;;) {
    try { mkdirSync(lock); break; } catch (err) {
      if (err.code !== 'EEXIST') throw err;
      try {
        if (Date.now() - statSync(lock).mtimeMs > 30000) {
          // Move the stale lock aside under a unique name first (rename is atomic), then
          // re-check the age of what we actually moved. The aside copy is always removed,
          // never renamed back: rename(2) onto an empty directory replaces it on POSIX, so
          // restoring could destroy a lock another process acquired in the meantime. If we
          // moved a fresh lock, re-create the lock path with mkdir, which fails (EEXIST)
          // instead of replacing when someone else holds it. The window this leaves is a few
          // microseconds; a holder releases by path, so it cannot be closed without owner files.
          const aside = `${lock}.stale.${process.pid}.${Date.now()}`;
          renameSync(lock, aside);
          const fresh = Date.now() - statSync(aside).mtimeMs <= 30000;
          rmdirSync(aside);
          if (fresh) { try { mkdirSync(lock); } catch { /* someone else holds it now */ } }
          continue;
        }
      } catch { continue; }
      if (Date.now() > deadline) { warn(`could not lock ${file}: another writer holds ${lock}`); process.exit(1); }
      Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 50); // sleeps without spinning the CPU
    }
  }
  try { return fn(); } finally { try { rmdirSync(lock); } catch { /* already gone */ } }
}

// The one list of files this plugin writes into a site root that are working state, not
// source: regenerable, machine-specific or secret. Anything new the plugin writes there
// is registered here (tests/checks/state-files-gitignore.sh), and every command that
// proposes an ignore reads this list through `gitignore-check`.
// `when` limits an entry to roots where it applies.
const TOOL_STATE_PATHS = [
  { rule: '.wp-audit/', probe: '.wp-audit/x', why: 'audit reports and suite results' },
  { rule: '.wp-audit-findings.json', probe: '.wp-audit-findings.json', why: 'the /wp-audit findings ledger' },
  { rule: '.wp-create.local.json', probe: '.wp-create.local.json', why: 'local secrets override' },
  { rule: '.wp-create.json.bak*', probe: '.wp-create.json.bak-x', why: 'manifest backups' },
  { rule: '.wp-create.json.v*.bak', probe: '.wp-create.json.v1.bak', why: 'manifest migration backups' },
  {
    rule: '/wp-content/plugins/robin-image-optimizer/libs/factory/bootstrap/assets/cache/',
    probe: 'wp-content/plugins/robin-image-optimizer/libs/factory/bootstrap/assets/cache/x',
    why: 'Robin Image Optimizer runtime cache',
    when: 'wp-content/plugins/robin-image-optimizer',
  },
  {
    rule: '/wp-content/plugins/robin-image-optimizer/.phpunit.result.cache',
    probe: 'wp-content/plugins/robin-image-optimizer/.phpunit.result.cache',
    why: 'Robin Image Optimizer test-run state',
    when: 'wp-content/plugins/robin-image-optimizer',
  },
];

const say = (s) => console.log(s);
const warn = (s) => console.error(s);

function claudeMdPath(projectPath) {
  return join(resolve(projectPath), '.claude', 'CLAUDE.md');
}

// JSON.parse's own error message can embed up to ~20 raw bytes of the file's own
// content as a quoted snippet (`Unexpected token 's', "{"a":supersecre"... is not
// valid JSON`) -- unsafe to echo verbatim for a file that might hold a secret, which
// LOCAL_NAME (.wp-create.local.json) always might. Report the file and, when the
// message states one, the numeric position -- never the parser's own message text.
function jsonParseErrorLocation(err) {
  const m = /position (\d+)(?: \(line (\d+) column (\d+)\))?/.exec(err.message ?? '');
  if (!m) return 'at an unreported position';
  return m[2] ? `at line ${m[2]}, column ${m[3]}` : `at position ${m[1]}`;
}

function loadManifest(projectPath) {
  const file = join(resolve(projectPath), MANIFEST_NAME);
  if (!existsSync(file)) {
    warn(`no ${MANIFEST_NAME} at ${resolve(projectPath)} -- run /wp-create first`);
    process.exit(3);
  }
  try {
    return { file, manifest: JSON.parse(readFileSync(file, 'utf8')) };
  } catch (err) {
    warn(`${MANIFEST_NAME} is not valid JSON ${jsonParseErrorLocation(err)}`);
    process.exit(1);
  }
}

function cmdValidate(projectPath) {
  const { manifest } = loadManifest(projectPath);
  const version = detectVersion(manifest);
  if (version > CURRENT_VERSION) {
    warn(`manifest_version ${version} is newer than this plugin understands (${CURRENT_VERSION}); leaving it untouched`);
    process.exit(1);
  }
  const problems = validateManifest(manifest);
  if (problems.length) {
    for (const p of problems) warn(`invalid: ${p}`);
    process.exit(1);
  }
  const claudeFile = claudeMdPath(projectPath);
  if (existsSync(claudeFile)) {
    const drift = contextDrift(readFileSync(claudeFile, 'utf8'), manifest);
    if (drift) {
      warn(`invalid: ${drift}`);
      // A malformed marker state can't be regenerated by render-context either --
      // it refuses the same way, for the same reason. Point at the real fix.
      warn(drift.startsWith('malformed wp-create markers')
        ? `fix the wp-create:begin/wp-create:end markers in ${claudeFile} by hand`
        : 'run wp-config.mjs render-context to regenerate it, or fix the manifest it came from');
      process.exit(1);
    }
  }
  if (version < CURRENT_VERSION) {
    warn(`manifest_version ${version} can migrate to ${CURRENT_VERSION}: run wp-config.mjs migrate`);
    process.exit(2);
  }
  say(`ok: ${MANIFEST_NAME} valid at version ${version}`);
}

function cmdMigrate(projectPath) {
  const { file, manifest } = loadManifest(projectPath);
  // Before detectVersion, because detectVersion reads a malformed version as "absent",
  // and absent means legacy 1 -- so `"manifest_version": "99"` would migrate a manifest
  // from a future plugin down to this one's shape. Refuse it as malformed instead.
  const badVersion = versionProblem(manifest);
  if (badVersion) {
    warn(`invalid: ${badVersion}`);
    process.exit(1);
  }
  const version = detectVersion(manifest);
  if (version > CURRENT_VERSION) {
    warn(`manifest_version ${version} is newer than this plugin understands (${CURRENT_VERSION}); leaving it untouched`);
    process.exit(1);
  }
  if (version === CURRENT_VERSION) {
    say(`ok: already at version ${CURRENT_VERSION}, nothing to migrate`);
    return;
  }
  const claudeFile = claudeMdPath(projectPath);
  const claudeMd = existsSync(claudeFile) ? readFileSync(claudeFile, 'utf8') : '';
  const { manifest: next, notes } = migrateManifest(manifest, { claudeMd });

  // Versioned on purpose: /wp-create writes .wp-create.json.bak when the user chooses
  // Overwrite, and reusing that name would destroy their pre-overwrite copy.
  copyFileSync(file, `${file}.v${version}.bak`);
  writeAtomic(file, `${JSON.stringify(next, null, 2)}\n`);
  for (const n of notes) say(n);
  say(`ok: migrated to version ${CURRENT_VERSION}`);

  // Retiring the legacy prose lines belongs to render-context, not here: writing the
  // block IS the act that takes ownership of them, and migrate is not the only caller.
  // Doing it here meant the recovery path (fix the manifest, run render-context) wrote
  // the block and left the prose live beside it.
  cmdRenderContext(projectPath);
}

function cmdRenderContext(projectPath) {
  const { manifest } = loadManifest(projectPath);
  const file = claudeMdPath(projectPath);
  // A manifest that cannot produce a COMPLETE block must not produce a partial one.
  // The block is the authoritative record every agent reads first, and a field missing
  // from the manifest renders as an empty string there -- a blank an agent cannot tell
  // from a decision. validateManifest requires every field the block renders (that is
  // what CONTEXT_FIELDS is for), but only cmdValidate used to ask it; this path wrote
  // the blanks anyway, which is how a migration could leave a project at exit 1 for
  // fields whose only record it had just retired. Same problems, same wording, same
  // exit code as validate, so the operator sees one message and fixes one thing.
  const problems = validateManifest(manifest);
  if (problems.length) {
    for (const p of problems) warn(`invalid: ${p}`);
    warn(`refusing to write a partial block to ${file}: fill the fields in above and run render-context again`);
    process.exit(1);
  }
  const current = existsSync(file) ? readFileSync(file, 'utf8') : '';
  let spliced;
  try {
    spliced = spliceContext(current, renderContext(manifest));
  } catch (err) {
    // Refuse, don't guess: spliceContext throws on a malformed marker state rather
    // than picking an append-or-replace branch that could destroy operator text.
    warn(`invalid: ${err.message}`);
    warn(`fix the wp-create:begin/wp-create:end markers in ${file} by hand`);
    process.exit(1);
  }
  // Writing the block is what takes ownership of the legacy prose decision lines, so
  // retiring them happens here rather than in migrate: any caller that writes the block
  // has to retire them, or the file asserts the old value beside the new one with
  // validate exiting 0. Marker-aware, so the block's own lines -- same labels -- are
  // untouched, and idempotent, so a second render changes nothing. One write: the
  // refusals above must leave the file exactly as they found it.
  const owned = supersedeProseDecisions(spliced, manifest);
  mkdirSync(dirname(file), { recursive: true });
  writeAtomic(file, owned);
  say(`ok: wrote the generated block in ${file}`);
  if (owned !== spliced) say(`ok: superseded the legacy decision lines in ${file}`);
}

function loadLocal(projectPath) {
  const file = join(resolve(projectPath), LOCAL_NAME);
  if (!existsSync(file)) return {};
  try {
    return JSON.parse(readFileSync(file, 'utf8'));
  } catch (err) {
    warn(`${LOCAL_NAME} is not valid JSON ${jsonParseErrorLocation(err)}`);
    process.exit(1);
  }
}

function cmdGet(projectPath, key) {
  const { manifest } = loadManifest(projectPath);
  if (Object.hasOwn(SECRETS, key)) {
    const hit = resolveSecret(key, { env: process.env, local: loadLocal(projectPath), manifest });
    if (!hit) {
      warn(`no value for ${key} in the environment, ${LOCAL_NAME} or the manifest`);
      process.exit(1);
    }
    if (hit.source === 'manifest') {
      warn(`${key} resolved from the manifest, a legacy location: move it to ${LOCAL_NAME}, which is gitignored`);
    }
    say(hit.value);
    return;
  }
  const found = getKey(manifest, key);
  if (!found.ok) {
    warn(found.secret
      ? `${key} is a secret's manifest path: read it with get ${found.secret} instead`
      : `unknown key: ${key}`);
    process.exit(1);
  }
  say(found.value);
}

function cmdValidateProfile(file) {
  const target = resolve(file);
  if (!existsSync(target)) { warn(`no profile at ${target}`); process.exit(3); }
  let profile;
  try {
    profile = JSON.parse(readFileSync(target, 'utf8'));
  } catch (err) {
    warn(`${target} is not valid JSON ${jsonParseErrorLocation(err)}`);
    process.exit(1);
  }
  const problems = validateProfile(profile);
  // `bundled` means a plugin this repository ships under plugins/<slug>/. The pure validator
  // cannot see the filesystem; this can, and a bundled slug with nothing behind it would fail
  // the build at install time instead of here.
  const pluginRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
  for (const entry of Array.isArray(profile?.plugins) ? profile.plugins : []) {
    if (entry?.source !== 'bundled' || typeof entry.slug !== 'string') continue;
    const main = join(pluginRoot, 'plugins', entry.slug, `${entry.slug}.php`);
    if (!existsSync(main)) problems.push(`${entry.slug}: source "bundled", but plugins/${entry.slug}/${entry.slug}.php does not exist in this plugin`);
  }
  // An optional WordPress version turns this from "is the profile well-formed" into "does
  // it claim to work here". Step 4.10 passes the site's own version, so a plugin whose
  // tested range does not cover it is reported before it is installed rather than after
  // something breaks. Reported, not refused: a plugin outside its tested range usually
  // works, and blocking a build on a readme header would be worse than saying so.
  const wpVersion = process.argv[4];
  if (wpVersion) {
    for (const line of testedVerdicts(profile, wpVersion)) warn(`tested: ${line}`);
  }
  if (problems.length) {
    for (const p of problems) warn(`invalid: ${p}`);
    process.exit(1);
  }
  say(`ok: ${target} is a valid profile`);
}

// Register a site this plugin did not build. Reads the site, never changes it: the only
// files written are the manifest and the generated block in .claude/CLAUDE.md, and only
// without --dry-run. /wp-adopt runs --dry-run first, has the operator confirm the proposal,
// then runs it again with the confirmed values as flags.
function parseFlags(argv) {
  const flags = {};
  for (const a of argv) {
    const m = /^--([a-z-]+)(?:=(.*))?$/.exec(a);
    if (m) flags[m[1]] = m[2] ?? true;
  }
  return flags;
}

function cmdAdopt(projectPath, flags) {
  const root = resolve(projectPath);
  const file = join(root, MANIFEST_NAME);
  const replacing = existsSync(file) && flags.replace;
  if (existsSync(file) && !replacing) {
    warn(`${MANIFEST_NAME} already exists at ${root}: this site is already registered -- run validate instead`);
    warn('if the manifest describes a different site (a blank scaffold the real site was restored over), run `wp-config.mjs drift` to see how, then adopt again with --replace: it keeps a timestamped backup');
    process.exit(1);
  }
  if (!isWordPressRoot(root)) {
    warn(`no WordPress install at ${root} (wp-load.php and wp-config.php): pass the WordPress root`);
    process.exit(1);
  }
  const detected = detectWrapper(root);
  const wrapper = typeof flags.wrapper === 'string' ? flags.wrapper : detected.wrapper;
  const probed = runProbe(wrapper);
  // The override runs the probe; it is written to the manifest only when it is how the site is
  // reached. A helper script in a temp directory is not, unless --persist-wrapper says so.
  const keepWrapper = flags['persist-wrapper'] || !isTransientWrapper(wrapper) ? wrapper : detected.wrapper;
  if (keepWrapper !== wrapper) {
    // The detected wrapper replaces the helper only if it reaches the site too; a site that is
    // reachable only through the helper (Docker, SSH) would otherwise get a manifest that fails.
    if (runProbe(detected.wrapper).ok) {
      warn(`note: ${wrapper.split(/\s+/)[0]} is a temp-dir helper, so the manifest keeps ${detected.wrapper} (pass --persist-wrapper to store the override)`);
    } else {
      warn(`error: ${wrapper.split(/\s+/)[0]} is a temp-dir helper and ${detected.wrapper} does not reach this site, so nothing could be stored: pass --persist-wrapper, or use a wrapper that is not a temp file`);
      process.exit(1);
    }
  }
  const { probe } = probed;
  if (probe.multisite) {
    warn('multisite installs are not supported: the code scope and the stack are per site, and this plugin audits one');
    process.exit(1);
  }
  // `--editable=` (empty value) is an empty list; a bare `--editable` or no flag keeps the proposal.
  const list = (v) => (typeof v === 'string' ? v.split(',').map((x) => x.trim()).filter(Boolean) : undefined);
  const overrides = {
    wrapper,
    name: typeof flags.name === 'string' ? flags.name : undefined,
    prefix: typeof flags.prefix === 'string' ? flags.prefix : undefined,
    industry: typeof flags.industry === 'string' ? flags.industry : undefined,
    editable: list(flags.editable),
    read_only: list(flags['read-only']),
  };
  const built = buildManifest(root, probe, { ...detected, wrapper: keepWrapper }, { ...overrides, wrapper: keepWrapper });
  const { manifest, reasons, conflicts } = built;
  let { prefixSource } = built;
  // --replace over a real adoption or build keeps the operator's decisions and the audit
  // history; over a blank scaffold there is nothing to keep and it behaves as a first adoption.
  let carried = [];
  if (replacing) {
    let old = null;
    try { old = JSON.parse(readFileSync(file, 'utf8')); } catch { /* unreadable: nothing to carry */ }
    if (old && typeof old === 'object' && !isScaffoldManifest(old, root, probe.stylesheet)) {
      carried = carryOver(old, manifest, root, flags);
      if (carried.includes('project.prefix')) prefixSource = 'carried over from the previous manifest';
    }
  }
  const problems = validateManifest(manifest);

  if (flags['dry-run']) {
    say(JSON.stringify({
      manifest, reasons, prefix_source: prefixSource, conflicts, carried_over: carried, problems,
    }, null, 2));
    return;
  }
  if (problems.length) {
    for (const p of problems) warn(`invalid: ${p}`);
    warn('nothing written: fix the values above with flags and run adopt again');
    process.exit(1);
  }
  if (replacing) {
    const bak = `${file}.bak-${new Date().toISOString().replace(/[:.]/g, '-')}`;
    copyFileSync(file, bak);
    say(`note: previous manifest kept at ${bak}`);
  }
  writeAtomic(file, `${JSON.stringify(manifest, null, 2)}\n`);
  say(`ok: wrote ${file} (origin: adopted)`);
  for (const c of conflicts) say(`note: ${c}`);
  if (carried.length) say(`note: kept from the previous manifest: ${carried.join(', ')}`);
  cmdRenderContext(root);
}

// Does the registered manifest still describe the site WP-CLI is talking to? Exit 0 it does,
// 4 it does not (one line per disagreement), 1 the probe could not run. validate cannot answer
// this: a blank scaffold the real site was restored over satisfies the schema.
function cmdDrift(projectPath) {
  const root = resolve(projectPath);
  const file = join(root, MANIFEST_NAME);
  if (!existsSync(file)) { warn(`no ${MANIFEST_NAME} at ${root}`); process.exit(3); }
  let manifest;
  try { manifest = JSON.parse(readFileSync(file, 'utf8')); } catch { warn(`${MANIFEST_NAME} is not valid JSON`); process.exit(1); }
  const wrapper = manifest.wp_cli?.wrapper || detectWrapper(root).wrapper;
  const probed = runProbe(wrapper);
  if (!probed.ok) { warn(`probe failed: ${probed.reason}`); process.exit(1); }
  const lines = manifestDrift(manifest, probed.probe, root);
  if (!lines.length) { say('ok: the manifest matches the site'); return; }
  for (const l of lines) say(`drift: ${l}`);
  process.exit(4);
}

// Update only what the probe measures (the active plugin list, the stack, the PHP and WordPress
// versions) and keep every operator decision. The lighter answer to plugin-list drift; a
// structural disagreement (theme directory missing, another active theme) still needs adopt --replace.
function cmdRefresh(projectPath) {
  const root = resolve(projectPath);
  const { file, manifest } = loadManifest(root);
  const wrapper = manifest.wp_cli?.wrapper || detectWrapper(root).wrapper;
  const probed = runProbe(wrapper);
  if (!probed.ok) { warn(`probe failed: ${probed.reason}`); process.exit(1); }
  const { probe } = probed;
  const structural = manifestDrift(manifest, probe, root).filter((l) => !isPluginListDrift(l));
  if (structural.length) {
    for (const l of structural) warn(`drift: ${l}`);
    warn('refresh only updates the plugin list and stack: this manifest describes another site -- run adopt with --replace');
    process.exit(1);
  }
  const next = structuredClone(manifest);
  next.plugins = { ...next.plugins, installed: probe.plugins.filter((p) => p.active).map((p) => p.slug) };
  if (next.stack !== undefined || next.origin === 'adopted') next.stack = detectStack(probe).stack;
  if (next.environment && probe.php) next.environment.php_version = probe.php;
  if (next.wordpress && probe.wp) next.wordpress.version = probe.wp;
  const problems = validateManifest(next);
  if (problems.length) {
    for (const p of problems) warn(`invalid: ${p}`);
    warn('nothing written');
    process.exit(1);
  }
  const bak = `${file}.bak-${new Date().toISOString().replace(/[:.]/g, '-')}`;
  copyFileSync(file, bak);
  writeAtomic(file, `${JSON.stringify(next, null, 2)}\n`);
  say(`ok: refreshed plugins.installed and stack in ${file} (previous manifest kept at ${bak})`);
  cmdRenderContext(root);
}

// Set one dotted key in the manifest: `set <project> <key> <value>`. The value is parsed as
// JSON when it parses (numbers, booleans, objects, arrays) and kept as a string otherwise.
// The read-modify-write runs under a lock and the manifest is validated before it is
// written, so a parallel builder or wp-research can neither lose a key nor leave a manifest
// the gate would refuse. Secret paths and prototype keys are refused.
function cmdSet(projectPath, key, raw) {
  const parts = key.split('.');
  if (parts.some((k) => !k || k === '__proto__' || k === 'constructor' || k === 'prototype')) {
    warn(`invalid key: ${key}`);
    process.exit(1);
  }
  if (Object.keys(SECRETS).some((n) => key === SECRETS[n].manifestPath || key.startsWith(`${SECRETS[n].manifestPath}.`))) {
    warn(`refusing to set ${key}: secrets live in the environment or ${LOCAL_NAME}, not the manifest`);
    process.exit(1);
  }
  let value = raw;
  try { value = JSON.parse(raw); } catch { /* a plain string */ }
  const file = join(resolve(projectPath), MANIFEST_NAME);
  if (!existsSync(file)) { warn(`no ${MANIFEST_NAME} at ${resolve(projectPath)} -- run /wp-create first`); process.exit(3); }
  // process.exit() inside the lock would skip withLock's finally and orphan the lock, so the
  // callback only returns what went wrong (including an unreadable manifest); the exit happens after the lock is released.
  const outcome = withLock(file, () => {
    let manifest;
    try { manifest = JSON.parse(readFileSync(file, 'utf8')); } catch (err) {
      return { fatal: `${MANIFEST_NAME} is not valid JSON ${jsonParseErrorLocation(err)}`, found: [] };
    }
    let o = manifest;
    for (const k of parts.slice(0, -1)) {
      if (!Object.hasOwn(o, k) || o[k] === null || typeof o[k] !== 'object' || Array.isArray(o[k])) {
        if (Object.hasOwn(o, k)) warn(`note: replacing existing non-object value at ${k}`);
        o[k] = {};
      }
      o = o[k];
    }
    o[parts[parts.length - 1]] = value;
    const found = validateManifest(manifest);
    if (!found.length) writeAtomic(file, `${JSON.stringify(manifest, null, 2)}\n`);
    return { found };
  });
  if (outcome.fatal) { warn(outcome.fatal); process.exit(1); }
  const problems = outcome.found;
  if (problems.length) {
    for (const p of problems) warn(`invalid: ${p}`);
    warn('nothing written');
    process.exit(1);
  }
  say(`ok: set ${key} in ${file}`);
}

// Which TOOL_STATE_PATHS would git commit? Prints one `missing:` line per unignored entry.
// Exit 0 nothing missing (or the root is not in a git work tree), 4 entries missing,
// 1 the root does not exist. Never edits .gitignore: the caller asks first.
function cmdGitignoreCheck(projectPath) {
  const root = resolve(projectPath);
  if (!existsSync(root)) { warn(`no such directory: ${root}`); process.exit(1); }
  const git = (args) => spawnSync('git', ['-C', root, ...args], { encoding: 'utf8' });
  const inside = git(['rev-parse', '--is-inside-work-tree']);
  if (inside.error || inside.status === null) {
    warn(`git unavailable; cannot check tool state ignores: ${inside.error?.message ?? 'git did not exit'}`);
    process.exit(1);
  }
  if (inside.status !== 0) {
    say('ok: not a git work tree, nothing to ignore');
    return;
  }
  const missing = [];
  for (const e of TOOL_STATE_PATHS) {
    if (e.when && !existsSync(join(root, e.when))) continue;
    const ignored = git(['check-ignore', '-q', '--', e.probe]);
    if (ignored.error || ignored.status === null) {
      warn(`git unavailable; cannot check tool state ignores: ${ignored.error?.message ?? 'git did not exit'}`);
      process.exit(1);
    }
    if (ignored.status !== 0) missing.push(e);
  }
  if (!missing.length) { say('ok: every tool state path is ignored'); return; }
  for (const e of missing) say(`missing: ${e.rule}  # ${e.why}`);
  process.exit(4);
}

// Register one named remote environment. Read-only toward the site: it only edits the manifest.
// No token flag exists on purpose; the token goes in the gitignored local file by hand.
function cmdEnvSet(projectPath, flags) {
  const { file, manifest } = loadManifest(projectPath);
  const name = flags.name;
  if (typeof name !== 'string' || !/^[a-z0-9][a-z0-9_-]*$/i.test(name)) {
    warn('usage: wp-config.mjs env-set <project-path> --name=<env> --role=local|staging|prod --url=<url> [--sync=envsync --transport=http|https [--allow-http]]');
    process.exit(1);
  }
  if (flags.sync !== undefined && flags.transport !== 'http' && flags.transport !== 'https') {
    warn('--sync requires --transport=http|https');
    process.exit(1);
  }
  if (flags.sync !== undefined && flags.transport === 'http' && !flags['allow-http']) {
    warn('--transport=http requires --allow-http');
    process.exit(1);
  }
  const env = { role: flags.role, url: flags.url };
  if (flags.sync !== undefined) {
    env.sync = { tool: flags.sync, transport: flags.transport };
    if (flags['allow-http']) env.sync.allow_http = true;
  }
  const next = structuredClone(manifest);
  next.environments = { ...(next.environments ?? {}), [name]: env };
  const problems = validateManifest(next);
  if (problems.length) {
    for (const p of problems) warn(`invalid: ${p}`);
    warn('nothing written');
    process.exit(1);
  }
  writeAtomic(file, `${JSON.stringify(next, null, 2)}\n`);
  say(`ok: environments.${name} (${env.role}) written to ${file}`);
}

const [cmd, target] = process.argv.slice(2);
if (cmd === 'validate' && target) cmdValidate(target);
else if (cmd === 'migrate' && target) cmdMigrate(target);
else if (cmd === 'render-context' && target) cmdRenderContext(target);
else if (cmd === 'get' && target && process.argv[4]) cmdGet(target, process.argv[4]);
else if (cmd === 'validate-profile' && target) cmdValidateProfile(target);
else if (cmd === 'drift' && target) cmdDrift(target);
else if (cmd === 'refresh' && target) cmdRefresh(target);
else if (cmd === 'set' && target && process.argv[4] && process.argv[5] !== undefined) cmdSet(target, process.argv[4], process.argv[5]);
else if (cmd === 'gitignore-check' && target) cmdGitignoreCheck(target);
else if (cmd === 'env-set' && target) cmdEnvSet(target, parseFlags(process.argv.slice(4)));
else if (cmd === 'adopt' && target) cmdAdopt(target, parseFlags(process.argv.slice(4)));
else {
  warn('usage: wp-config.mjs <validate|migrate|render-context|get|set|validate-profile|adopt|drift|refresh|gitignore-check|env-set> <project-path> [key [value]|wp-version|adopt flags]');
  process.exit(1);
}
