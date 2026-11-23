#!/usr/bin/env node
/**
 * store-audit.mjs: the measurements behind /wp-audit's store category (agents/wp-audit-store.md),
 * as one findings JSON in the report contract of skills/wp-audit-standards.
 *
 * Usage: store-audit.mjs <project-path> [--url <base-url>] [--read-only]
 *
 *   STORE-001..004  bin/woo-verify.mjs, run from outside: setup has nothing to change, the store
 *                   pages answer, the shop lists products, a Store API cart takes one
 *   STORE-005..014  skills/wp-woocommerce/scripts/store-audit.php, read through WP-CLI: policy
 *                   pages, email sender, shipping, tax, product data, failed scheduled actions,
 *                   order-table sync, launch state
 *
 * The tier is the manifest's `store.tier`; a store with no `store` block (one /wp-woo-setup never
 * set up) is a catalog when store-kit's catalog mode is on and a selling store otherwise, and its
 * STORE-001 is N/A. --read-only passes --read-only to woo-verify, so the cart check is not run and
 * nothing at all is written: STORE-004 comes back UNMEASURED, a report-only run's write.
 * --url is passed to woo-verify (the home URL otherwise).
 *
 * Prints the JSON on stdout. Exit: 0 no check failed, 1 a check failed, 2 nothing could be
 * measured (no native WP-CLI, WooCommerce inactive, WP-CLI did not answer), 64 usage.
 */
import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import './lib/stdio-blocking.mjs';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const FACTS = join(ROOT, 'skills/wp-woocommerce/scripts/store-audit.php');
const VERIFY = join(ROOT, 'bin/woo-verify.mjs');
const USAGE = 'usage: store-audit.mjs <project-path> [--url <base-url>] [--read-only]';
const IDS = Array.from({ length: 14 }, (_, i) => `STORE-${String(i + 1).padStart(3, '0')}`);

function usage(msg) {
  process.stderr.write(`${msg ? `${msg}\n` : ''}${USAGE}\n`);
  process.exit(64);
}

const argv = process.argv.slice(2);
let project = '';
let url = '';
let readOnly = false;
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (a === '--read-only') readOnly = true;
  else if (a === '--url') {
    url = argv[++i] || '';
    if (!/^https?:\/\/[^/]/.test(url)) usage('--url needs an http(s) URL');
  } else if (a.startsWith('--')) usage(`unknown flag ${a}`);
  else if (!project) project = a;
  else usage(`unexpected argument ${a}`);
}
if (!project) usage();

const manifestPath = join(project, '.wp-create.json');
if (!existsSync(manifestPath)) usage(`no .wp-create.json in ${project}`);
let manifest;
try {
  manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
} catch (e) {
  usage(`.wp-create.json does not parse: ${e.message}`);
}
const wrapper = manifest.wp_cli && typeof manifest.wp_cli.wrapper === 'string' && manifest.wp_cli.wrapper.trim();
const block = manifest.store && typeof manifest.store === 'object' && ['catalog', 'store', 'full'].includes(manifest.store.tier) ? manifest.store : null;
const engine = (manifest.environment && manifest.environment.engine) || 'native';

const report = { category: 'store', checks_executed: [], findings: [], unmeasured: [], not_applicable: [], notes: [] };

// Where each failing check's fix lands, and who applies it. The audit never applies a store fix
// itself: each is a command of this plugin, or the merchant's.
const FIX = {
  'STORE-001': 'Run /wp-woo-setup: it brings the store back to its block, leaving the values the client changed alone unless force is passed.',
  'STORE-002': 'Run /wp-woo-setup, which assigns and publishes the store pages; a page that is assigned and still fails is a theme or server error to read in the response.',
  'STORE-003': 'Publish products: /wp-seed --products creates a demo\'s, otherwise the merchant adds them in WooCommerce.',
  'STORE-004': 'Read the Store API error in the evidence: a product that is not purchasable or in stock, a plugin refusing the cart, or a catalog that sells.',
  'STORE-005': 'Write and publish the terms and conditions, then pick the page in WooCommerce > Settings > Advanced.',
  'STORE-006': 'Write and publish the privacy policy, then pick the page in Settings > Privacy.',
  'STORE-007': 'Write and publish the refund and returns policy (WooCommerce creates a draft of it) and link it from the checkout terms.',
  'STORE-008': 'Set the sender name and an address on the site domain in WooCommerce > Settings > Emails, and the new-order recipient.',
  'STORE-009': 'Add an enabled shipping method to the zone that covers the store address, or record it in the store block and run /wp-woo-setup.',
  'STORE-010': 'Add the tax rates the store must charge, or switch taxes off if it charges none: record either in the store block and run /wp-woo-setup.',
  'STORE-011': 'Give each listed product a price, an image and a category of its own in WooCommerce.',
  'STORE-012': 'Read the failed actions in WooCommerce > Status > Scheduled Actions; fix what makes them fail, then run them again.',
  'STORE-013': 'Let WooCommerce finish the sync (WooCommerce > Settings > Advanced > Features), or run wp wc hpos sync.',
  'STORE-014': 'Launch the store on purpose, in the launch order of skills/wp-woocommerce; never by switching these off one by one.',
};
const SEVERITY = { 'STORE-001': 'WARNING', 'STORE-002': 'CRITICAL', 'STORE-003': 'CRITICAL', 'STORE-004': 'CRITICAL' };
const OWNER = { 'STORE-001': 'setting', 'STORE-002': 'setting', 'STORE-003': 'content', 'STORE-004': 'setting' };

function pass(check) {
  if (!report.checks_executed.includes(check)) report.checks_executed.push(check);
}
function finding(check, severity, ownership, resource, message, evidence) {
  pass(check);
  report.findings.push({
    check, status: 'FAIL', severity, ownership, resource, message, evidence, fix: FIX[check],
    auto_fixable: false, design_impact: false, root_cause: null, file: null, line: null,
  });
}
function na(check, reason) {
  report.not_applicable.push({ check, reason });
}
function unmeasured(check, reason) {
  report.unmeasured.push({ check, reason });
}
function done(code) {
  process.stdout.write(`${JSON.stringify(report, null, 2)}\n`);
  process.exit(code === undefined ? (report.findings.length ? 1 : 0) : code);
}
function nothing(reason) {
  for (const id of IDS) unmeasured(id, reason);
  done(2);
}

// The store scripts run through WP-CLI on the host: a container's WP-CLI sees neither them nor the
// project, the reason /wp-woo-setup and /wp-woo-verify stop there too.
if (engine !== 'native') nothing(`no WP-CLI on the host: the store scripts need native WP-CLI, and environment.engine is ${engine}`);
if (!wrapper) nothing('no WP-CLI: the manifest has no wp_cli.wrapper');

function evalFile(...args) {
  const r = spawnSync('bash', ['-c', `${wrapper} eval-file "$@"`, '_', FACTS, ...args], { encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 });
  const out = `${r.stdout || ''}`;
  const json = out.split('\n').reverse().find((l) => l.startsWith('{'));
  if (r.status !== 0 || !json) {
    const why = (out.split('\n').find((l) => l.startsWith('refused:')) || `${r.stderr || ''}`.trim().split('\n').pop() || `exit ${r.status}`).slice(0, 300);
    return { error: why };
  }
  return JSON.parse(json);
}

let tier = block && block.tier;
if (!tier) {
  const t = evalFile('tier');
  if (t.error) nothing(/not active/.test(t.error) ? `no WP-CLI answer from WooCommerce: ${t.error}` : `no WP-CLI answer: ${t.error}`);
  tier = t.tier;
  report.notes.push(`no store block: audited as a ${tier === 'catalog' ? 'catalog (store-kit catalog mode is on)' : 'selling store'}`);
}

// --- STORE-001..004: woo-verify, from outside ------------------------------------------------------
const vArgs = [VERIFY, project];
if (url) vArgs.push('--url', url);
if (readOnly) vArgs.push('--read-only');
if (!block) vArgs.push('--tier', tier);
const v = spawnSync(process.execPath, vArgs, { encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 });
const lines = `${v.stdout || ''}`.split('\n').filter(Boolean);
const rows = lines.map((l) => /^(pass|fail|skip|note) (\S+?)(?:: (.*))?$/.exec(l)).filter(Boolean)
  .map(([, status, check, detail = '']) => ({ status, check, detail }));
const of = (name) => rows.filter((r) => r.check === name || r.check.startsWith(`${name}:`));

// Only exit 0 or 1 is a run that reported its checks; anything else (2, 64, a crash, no spawn)
// measured nothing, whatever rows it printed before stopping.
const verifyRan = v.status === 0 || v.status === 1;
const lastErr = `${v.stderr || ''}`.trim().split('\n').pop() || `exit ${v.status}`;
// A check passes only on a row that says so: no row is no measurement, never a pass.
function passOrUnmeasured(check, name, ok) {
  if (ok) pass(check);
  else unmeasured(check, `no WP-CLI answer or woo-verify printed no result for ${name} (exit ${v.status}: ${lastErr.slice(0, 200)})`);
}
if (!verifyRan) {
  const why = (rows.find((r) => r.status === 'fail') || {}).detail || lastErr;
  const reason = /WP-CLI/.test(why) ? `no WP-CLI answer: ${why}` : `the site did not answer over the network: ${why}`;
  for (const id of ['STORE-001', 'STORE-002', 'STORE-003', 'STORE-004']) unmeasured(id, reason);
} else {
  // STORE-001: setup's dry run plans nothing.
  const setup = of('setup');
  const sFail = setup.find((r) => r.status === 'fail');
  if (setup.some((r) => r.status === 'skip')) na('STORE-001', 'no store block: /wp-woo-setup has not set this store up, so there is no recorded state to drift from');
  else if (sFail) {
    const notes = setup.filter((r) => r.status === 'note').map((r) => r.detail);
    finding('STORE-001', SEVERITY['STORE-001'], OWNER['STORE-001'], 'site', `the store no longer matches its store block: ${sFail.detail}`, notes.join('; ') || sFail.detail);
  } else passOrUnmeasured('STORE-001', 'setup', setup.some((r) => r.status === 'pass'));

  // STORE-002 and STORE-003: a coming-soon store shows visitors a placeholder on every page.
  const comingSoon = rows.find((r) => r.check === 'pages' && r.status === 'skip');
  if (comingSoon) {
    na('STORE-002', 'the store is coming soon: every page is the placeholder, and STORE-014 reports the launch state');
    na('STORE-003', 'the store is coming soon: every page is the placeholder, and STORE-014 reports the launch state');
  } else {
    const pFail = of('page').filter((r) => r.status === 'fail');
    if (pFail.length) finding('STORE-002', SEVERITY['STORE-002'], OWNER['STORE-002'], 'site', `${pFail.length} store page(s) fail: ${pFail.map((r) => r.check.slice(5)).join(', ')}`, pFail.map((r) => `${r.check}: ${r.detail}`).join('; '));
    else passOrUnmeasured('STORE-002', 'the store pages', of('page').filter((r) => r.status === 'pass').length === 4);
    const shop = of('shop').find((r) => r.status === 'fail');
    if (shop) finding('STORE-003', SEVERITY['STORE-003'], OWNER['STORE-003'], 'site', shop.detail, `woo-verify: fail shop: ${shop.detail}`);
    else passOrUnmeasured('STORE-003', 'shop', of('shop').some((r) => r.status === 'pass'));
  }

  // STORE-004: a Store API cart.
  const cart = of('cart');
  const cFail = cart.find((r) => r.status === 'fail');
  if (cart.some((r) => r.status === 'skip')) unmeasured('STORE-004', 'report-only run: the cart check opens a Store API cart session, a write this run may not make');
  else if (cFail) finding('STORE-004', SEVERITY['STORE-004'], OWNER['STORE-004'], 'site', cFail.detail, `woo-verify: fail cart: ${cFail.detail}`);
  else passOrUnmeasured('STORE-004', 'cart', cart.some((r) => r.status === 'pass'));
}

// --- STORE-005..014: the database, through WP-CLI ---------------------------------------------------
const facts = evalFile(tier, block ? 'yes' : 'no');
if (facts.error) {
  for (const id of IDS.slice(4)) unmeasured(id, `no WP-CLI answer: ${facts.error}`);
} else {
  for (const c of facts.checks) {
    if (c.status === 'na') na(c.check, c.message);
    else if (c.status === 'fail') finding(c.check, c.severity, c.ownership, c.resource, c.message, c.evidence);
    else pass(c.check);
  }
}

done(!verifyRan && facts.error ? 2 : undefined);
