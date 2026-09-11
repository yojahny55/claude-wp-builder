#!/usr/bin/env node
/**
 * image-gen.mjs: fill a craft demo's image slots, from a client file or from a
 * generation API, without ever billing twice for the same plate.
 *
 * This is code rather than prose in wp-demo.md for one reason: prose telling
 * Claude to curl an API passes the key through a shell invocation on every
 * build, where it lands in the transcript, in shell history, and in any hook
 * that logs commands. Here the key is read from process.env in-process, so no
 * invocation exists for anything to log.
 *
 * Exit codes: 0 clean, 2 the plan is ambiguous and was refused before any
 * request, 3 no key (nothing written, nothing billed), 4 one or more slots
 * failed after work began.
 */
import { readFileSync, writeFileSync, existsSync, mkdirSync, copyFileSync, realpathSync } from 'node:fs';
import { resolve, join, dirname, basename } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { createHash } from 'node:crypto';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const COMPOSITIONS = join(ROOT, 'skills/wp-demo-craft/compositions');

// The key must never reach stdout or stderr - not through an error message and
// not through a stack frame that captured a header object. Every write funnels
// through scrub(), so a future adapter cannot reintroduce the leak by being
// careless in its own error path.
function scrub(s) {
  let out = String(s);
  for (const v of [process.env.GEMINI_API_KEY, process.env.OPENAI_API_KEY]) {
    if (v) out = out.split(v).join('[redacted]');
  }
  return out;
}
const say = (s) => console.log(scrub(s));
const warn = (s) => console.error(scrub(s));

// Every <img src="{{slot}}"> in a composition declares its own crop. Reading
// width/height off the tag is what keeps the requested aspect from drifting
// away from what the CSS will actually display.
export function slotsOf(composition) {
  const file = join(COMPOSITIONS, composition, 'section.html');
  const html = readFileSync(file, 'utf8');
  const out = [];
  for (const tag of html.match(/<img\b[^>]*>/gi) || []) {
    const slot = /\bsrc="\{\{([A-Za-z0-9_]+)\}\}"/.exec(tag);
    const w = /\bwidth="(\d+)"/.exec(tag);
    const h = /\bheight="(\d+)"/.exec(tag);
    if (slot && w && h) out.push({ slot: slot[1], width: +w[1], height: +h[1] });
  }
  return out;
}

const GOOGLE_RATIOS = ['1:1', '3:2', '2:3', '3:4', '4:3', '4:5', '5:4', '9:16', '16:9', '21:9'];
const OPENAI_SIZES = [[1024, 1024], [1536, 1024], [1024, 1536]];

export function snapAspect(width, height, vendor) {
  const want = width / height;
  if (vendor === 'openai') {
    const best = OPENAI_SIZES.reduce((a, b) =>
      Math.abs(b[0] / b[1] - want) < Math.abs(a[0] / a[1] - want) ? b : a);
    return `${best[0]}x${best[1]}`;
  }
  const ratio = (r) => { const [w, h] = r.split(':').map(Number); return w / h; };
  return GOOGLE_RATIOS.reduce((a, b) =>
    Math.abs(ratio(b) - want) < Math.abs(ratio(a) - want) ? b : a);
}

// Smallest offered size at least as wide as the slot declares, capped at 2K: a
// 4K plate costs half again as much, ships megabytes into the media library,
// and is invisible behind object-fit: cover.
const GOOGLE_SIZES = [['512px', 512], ['1K', 1024], ['2K', 2048]];
export function snapSize(width) {
  const hit = GOOGLE_SIZES.find(([, px]) => px >= width);
  return (hit || GOOGLE_SIZES[GOOGLE_SIZES.length - 1])[0];
}

// Estimates, never a bill. Google publishes no per-image figure in its own
// documentation and OpenAI bills tokens rather than images, so both columns are
// approximations that will drift.
const EST_GOOGLE = { '512px': 0.045, '1K': 0.067, '2K': 0.101 };
export function estCost(vendor, size) {
  return vendor === 'openai' ? 0.03 : (EST_GOOGLE[size] ?? 0.101);
}

export function plateHash(prompt, aspect, model) {
  return createHash('sha256').update(`${prompt}|${aspect}|${model}`).digest('hex').slice(0, 12);
}

function planPath(demo) { return join(demo, '.image-plan.json'); }
function readPlan(demo) { return JSON.parse(readFileSync(planPath(demo), 'utf8')); }
function writePlan(demo, plan) {
  writeFileSync(planPath(demo), JSON.stringify(plan, null, 2) + '\n');
}

function cmdPlan(demo) {
  const plan = readPlan(demo);
  const [vendor, model] = String(plan.provider).split('/');
  const imgDir = join(demo, 'assets', 'img');

  // Carry forward anything already authored, keyed by the slot's identity in
  // the build, so re-running plan never discards prompts a human wrote.
  const prior = new Map((plan.gaps || []).map((g) => [`${g.page}|${g.section}|${g.slot}`, g]));

  const gaps = [];
  for (const row of plan.sections || []) {
    for (const s of slotsOf(row.composition)) {
      const aspect = snapAspect(s.width, s.height, vendor);
      const size = vendor === 'openai' ? aspect : snapSize(s.width);
      const was = prior.get(`${row.page}|${row.section}|${s.slot}`) || {};
      const prompt = was.prompt || '';
      gaps.push({
        page: row.page,
        section: row.section,
        composition: row.composition,
        slot: s.slot,
        aspect,
        size,
        est_cost: estCost(vendor, size),
        prompt,
        use: was.use || '',
        cached: !!prompt && existsSync(join(imgDir, `gen-${plateHash(prompt, aspect, model)}.jpg`)),
      });
    }
  }

  const claimed = new Set(gaps.map((g) => g.use).filter(Boolean));
  plan.gaps = gaps;
  plan.unused_assets = (plan.assets_on_disk || []).filter((a) => !claimed.has(a.path));
  writePlan(demo, plan);

  const billable = gaps.filter((g) => !g.use && !g.cached);
  const total = billable.reduce((n, g) => n + g.est_cost, 0);
  say(`Image plan - ${billable.length} plate(s) to generate, ~$${total.toFixed(2)} (${plan.provider})`);
  for (const g of gaps) {
    const state = g.use ? `use ${g.use}` : g.cached ? 'cached' : g.prompt ? 'generate' : 'NEEDS PROMPT';
    say(`  ${g.page}  ${g.section}  ${g.slot}  ${g.aspect}  ${g.size}  ${state}`);
  }
  if (plan.unused_assets.length) {
    say(`  unused docs/ assets: ${plan.unused_assets.map((a) => a.path).join(', ')}`);
  }
  say('Costs are estimates, not a bill.');
}

// Only dispatch when run as a command, not when imported. Compare REAL paths:
// Node resolves symlinks when loading the module, so import.meta.url is the
// real path while argv[1] keeps the link -- comparing them directly makes a
// symlinked invocation a silent no-op.
const invokedAs = process.argv[1] ? pathToFileURL(realpathSync(process.argv[1])).href : null;
if (invokedAs === import.meta.url) {
  const [, , sub, ...rest] = process.argv;
  const demoIdx = rest.indexOf('--demo');
  const demo = demoIdx >= 0 ? rest[demoIdx + 1] : null;

  try {
    if (sub === 'plan' && demo) cmdPlan(demo);
    else {
      warn('usage: image-gen.mjs plan --demo <dir>');
      process.exit(2);
    }
  } catch (e) {
    warn(e.stack || e.message);
    process.exit(4);
  }
}
