#!/usr/bin/env node
/**
 * decision-sheet.mjs: one self-contained HTML page that puts every `design_impact` finding in
 * front of the user as a card (before and after pictures, measured values, choices), and a
 * parser that reads the answers back.
 *
 * A finding with `design_impact: true` (colour and contrast, touch targets, line length,
 * underline, typography) is never applied without an answer. Built by hand, that page was
 * wrong three times running: no photo of how it looks and how it would look, no choice buttons
 * inside the page, no way to copy the answers. The pasted text was then parsed by eye and
 * diffed between rounds. This tool makes the page and the parser the same code.
 *
 *   build   decision-sheet.mjs build --out <audit results dir> (--proposals <file.json> |
 *           --sidecar <informe-*.json> [--proposals <file.json>]) [--site <origin>]
 *           [--lang en|es] [--date YYYY-MM-DD] [--settle-ms <n>] [--page-timeout <s>]
 *   parse   decision-sheet.mjs --parse <file|->     (the block, pasted back, to JSON on stdout)
 *
 * Proposals file: a JSON list, or {"proposals": [...]}. Each entry:
 *   id         required, [A-Za-z0-9._-]+, the key the answer comes back under
 *   title      required
 *   check      optional; links the entry to a sidecar finding (by `check`)
 *   page       URL (relative ones resolve against --site); selector  CSS selector of ONE element
 *   viewports  ["1366x768","390x844"] (default both); css  the rules for the "after"
 *   props      computed properties to measure before/after (default: the ones `css` declares)
 *   measured   {"before": {...}, "after": {...}} values that cannot be read from the DOM
 *              (a contrast ratio, say); shown beside the computed ones
 *   why        one sentence for the reader
 *   options    [{"key":"approve","label":"...","recommended":true}, ...]; default is
 *              approve / reject / postpone / other. Exactly one may be `recommended`.
 * With --sidecar, every finding with `design_impact: true` becomes a card; a finding with no
 * matching proposal is listed with no pictures, marked "not measured", never skipped.
 *
 * The "after" is made by injecting `css` with every declaration forced `!important`: the
 * existing rule would otherwise win on specificity and the picture would show the old value.
 * A rule that changes none of the measured properties is reported as ineffective. Transitions
 * and animations are switched off and webfonts awaited before each picture, or the "after"
 * is caught mid-transition. Pictures are element crops (JPEG, at most 900 px wide, 600 tall)
 * embedded in the page as data URIs: the page is one file.
 *
 * Answer block (what "Copy answers" produces, and --parse reads):
 *   DECISIONS v1
 *   DECISION <id>: <option> | <note>
 *   END DECISIONS
 * option is one of the card's option keys, or `pending` when unanswered. --parse prints
 * {"decisions":[{"id","option","status","note","ledger"}],"warnings":[]}; status is
 * approved | rejected | postponed | other | chosen | pending, and `ledger` is "accepted" for a
 * rejected finding (the user decided to keep it as is) and null otherwise.
 *
 * Exit: 0 ok; 2 usage, or no browser (nothing is installed or downloaded); 3 the page was
 * written but a picture or an ineffective rule left a card incomplete.
 */
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { findBrowser } from './lib/browsers.mjs';

const USAGE = 'usage: decision-sheet.mjs build --out <dir> (--proposals <file> | --sidecar <file> [--proposals <file>]) ' +
  '[--site <origin>] [--lang en|es] [--date YYYY-MM-DD] [--settle-ms <n>] [--page-timeout <s>]\n' +
  '       decision-sheet.mjs --parse <file|->';

function usage(msg, code = 2) {
  if (msg) process.stderr.write(`decision-sheet: ${msg}\n`);
  process.stderr.write(USAGE + '\n');
  process.exit(code);
}

const ID_RE = /^[A-Za-z0-9._-]+$/;
const DEFAULT_OPTIONS = [
  { key: 'approve', label: { en: 'Approve', es: 'Aprobar' } },
  { key: 'reject', label: { en: 'Reject (keep as is)', es: 'Rechazar (dejarlo como está)' } },
  { key: 'postpone', label: { en: 'Postpone', es: 'Posponer' } },
  { key: 'other', label: { en: 'Other (write below)', es: 'Otra (escríbela abajo)' } },
];

/* ------------------------------------------------------------------ parse */

export function parseAnswers(text) {
  const decisions = new Map(), warnings = [];
  const re = /^[\s>*\-]*DECISION\s+([A-Za-z0-9._-]+)\s*:\s*([^\s|]+)\s*(?:\|\s*(.*?))?\s*$/;
  let inBlock = false, sawBlock = false;
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim().replace(/^[>*\-\s]+/, '');
    if (/^DECISIONS v\d+$/.test(line)) { inBlock = true; sawBlock = true; continue; }
    if (/^END DECISIONS$/.test(line)) { inBlock = false; continue; }
    const m = re.exec(raw);
    if (!m) continue;
    if (sawBlock && !inBlock) continue;
    const [, id, option, note = ''] = m;
    if (decisions.has(id)) warnings.push(`${id}: answered more than once, the last answer wins`);
    const status = { approve: 'approved', reject: 'rejected', postpone: 'postponed', other: 'other', pending: 'pending' }[option] || 'chosen';
    if (option === 'other' && !note) warnings.push(`${id}: "other" has no note, the instruction is empty`);
    decisions.set(id, { id, option, status, note, ledger: status === 'rejected' ? 'accepted' : null });
  }
  if (!decisions.size) warnings.push('no DECISION lines found');
  return { decisions: [...decisions.values()], warnings };
}

function runParse(src) {
  let text;
  try { text = src === '-' ? readFileSync(0, 'utf8') : readFileSync(src, 'utf8'); }
  catch (e) { usage(`cannot read ${src}: ${e.message}`); }
  const out = parseAnswers(text);
  process.stdout.write(JSON.stringify(out, null, 2) + '\n');
  process.exit(out.decisions.length ? 0 : 1);
}

/* ----------------------------------------------------------------- inputs */

function parseArgs(argv) {
  const o = { cmd: argv[0], lang: 'en', settleMs: 500, pageTimeout: 30 };
  const next = (i, f) => { if (i + 1 >= argv.length) usage(`${f} needs a value`); return argv[i + 1]; };
  for (let i = 1; i < argv.length; i++) {
    const a = argv[i];
    switch (a) {
      case '--out': o.out = next(i++, a); break;
      case '--proposals': o.proposals = next(i++, a); break;
      case '--sidecar': o.sidecar = next(i++, a); break;
      case '--site': o.site = next(i++, a); break;
      case '--lang': o.lang = next(i++, a); break;
      case '--date': o.date = next(i++, a); break;
      case '--settle-ms': o.settleMs = Number(next(i++, a)); break;
      case '--page-timeout': o.pageTimeout = Number(next(i++, a)); break;
      default: usage(`unknown option ${a}`);
    }
  }
  return o;
}

function readJson(f) {
  try { return JSON.parse(readFileSync(f, 'utf8')); } catch (e) { return usage(`cannot read ${f}: ${e.message}`); }
}

function loadProposals(o) {
  let list = [];
  if (o.proposals) {
    const j = readJson(o.proposals);
    list = Array.isArray(j) ? j : j.proposals;
    if (!Array.isArray(list)) usage(`${o.proposals} is not a list of proposals`);
  }
  if (o.sidecar) {
    const sc = readJson(o.sidecar);
    const findings = (sc.findings || []).filter(f => f.design_impact === true);
    const by = new Map(list.filter(p => p.check).map(p => [p.check, p]));
    const used = new Set(list.map(p => p.id));
    findings.forEach((f, i) => {
      const check = String(f.check ?? `finding-${i + 1}`);
      if (by.has(check)) return;
      // The same check on several pages is several findings: each needs its own id.
      const base = check.replace(/[^A-Za-z0-9._-]+/g, '-') || `finding-${i + 1}`;
      let id = base, n = 1;
      while (used.has(id)) id = `${base}-${++n}`;
      used.add(id);
      list.push({ id, title: f.message || check, check, page: f.page || null, why: f.evidence || null, noProposal: true });
    });
  }
  if (!list.length) usage('no proposals (give --proposals, or a --sidecar with design_impact findings)');
  const seen = new Set();
  for (const p of list) {
    if (!p.id || !ID_RE.test(p.id)) usage(`proposal id "${p.id}" must match ${ID_RE}`);
    if (seen.has(p.id)) usage(`duplicate proposal id ${p.id}`);
    seen.add(p.id);
    if (!p.title) usage(`proposal ${p.id} has no title`);
    const opts = p.options || DEFAULT_OPTIONS.map(d => ({ key: d.key, label: d.label[o.lang] || d.label.en }));
    for (const op of opts) {
      if (!op.key || !/^[^\s|]+$/.test(op.key)) usage(`proposal ${p.id}: option key "${op.key}" must have no spaces or |`);
      if (op.key === 'pending') usage(`proposal ${p.id}: "pending" is reserved`);
    }
    if (opts.filter(op => op.recommended).length > 1) usage(`proposal ${p.id}: more than one recommended option`);
    p.options = opts;
  }
  return list;
}

/* ---------------------------------------------------------------- browser */

async function loadChromium() {
  const tries = [];
  if (process.env.PLAYWRIGHT_CORE) tries.push(pathToFileURL(resolve(process.env.PLAYWRIGHT_CORE, 'index.mjs')).href);
  else {
    tries.push('playwright-core');
    const cwdEntry = join(process.cwd(), 'node_modules', 'playwright-core', 'index.mjs');
    if (existsSync(cwdEntry)) tries.push(pathToFileURL(cwdEntry).href);
  }
  for (const t of tries) {
    try { return (await import(t)).chromium; } catch { /* next */ }
  }
  return null;
}

const FREEZE = '*,*::before,*::after{transition:none!important;animation:none!important;scroll-behavior:auto!important;caret-color:transparent!important}';

/* Runs in the page: inject css, every declaration forced !important. Returns declared props. */
function injectAfter(css) {
  const st = document.createElement('style');
  st.id = '__decision_sheet_after';
  st.textContent = css;
  document.head.appendChild(st);
  const props = new Set();
  const force = rules => {
    for (const r of rules) {
      if (r.style) {
        for (const p of [...r.style]) { props.add(p); r.style.setProperty(p, r.style.getPropertyValue(p), 'important'); }
      }
      if (r.cssRules) force(r.cssRules);
    }
  };
  force(st.sheet.cssRules);
  return [...props];
}

/* Runs in the page: computed values of `props` plus the box. */
function readState({ selector, props }) {
  const el = document.querySelector(selector);
  if (!el) return null;
  const cs = getComputedStyle(el), r = el.getBoundingClientRect();
  const values = {};
  for (const p of props) values[p] = cs.getPropertyValue(p);
  return { values, w: Math.round(r.width * 100) / 100, h: Math.round(r.height * 100) / 100 };
}

async function shot(page, selector) {
  const box = await page.evaluate(sel => {
    const el = document.querySelector(sel);
    el.scrollIntoView({ block: 'center', inline: 'nearest' });
    const r = el.getBoundingClientRect();
    return { x: r.left + scrollX, y: r.top + scrollY, w: r.width, h: r.height };
  }, selector);
  await page.waitForTimeout(150);
  const pad = 16;
  const x = Math.max(0, box.x - pad), y = Math.max(0, box.y - pad);
  const clip = { x, y, width: Math.min(900, Math.ceil(box.w + 2 * pad)), height: Math.min(600, Math.ceil(box.h + 2 * pad)) };
  const buf = await page.screenshot({ type: 'jpeg', quality: 72, clip, fullPage: true, animations: 'disabled' });
  return `data:image/jpeg;base64,${buf.toString('base64')}`;
}

async function capture(browser, p, o, url) {
  const res = [];
  const vps = (p.viewports && p.viewports.length ? p.viewports : ['1366x768', '390x844']);
  for (const key of vps) {
    const m = /^(\d+)x(\d+)$/.exec(key);
    const r = { viewport: key };
    res.push(r);
    if (!m) { r.unmeasured = `bad viewport ${key}`; continue; }
    const ctx = await browser.newContext({ viewport: { width: +m[1], height: +m[2] } });
    try {
      const page = await ctx.newPage();
      await page.goto(url, { waitUntil: 'load', timeout: o.pageTimeout * 1000 });
      await page.addStyleTag({ content: FREEZE });
      await page.evaluate(() => document.fonts && document.fonts.ready);
      await page.waitForTimeout(o.settleMs);
      if (!(await page.locator(p.selector).count())) { r.unmeasured = `selector not found: ${p.selector}`; continue; }
      r.beforePic = await shot(page, p.selector);
      // css is read first so the property list is known before the "before" state is measured.
      const declared = await page.evaluate(css => {
        const t = document.createElement('style'); t.textContent = css; document.head.appendChild(t);
        const s = new Set(); (function walk(rs) { for (const x of rs) { if (x.style) for (const q of x.style) s.add(q); if (x.cssRules) walk(x.cssRules); } })(t.sheet.cssRules);
        t.remove(); return [...s];
      }, p.css || '');
      const props = p.props && p.props.length ? p.props : declared;
      r.props = props;
      r.before = await page.evaluate(readState, { selector: p.selector, props });
      await page.evaluate(injectAfter, p.css || '');
      await page.evaluate(() => document.fonts && document.fonts.ready);
      await page.waitForTimeout(o.settleMs);
      r.after = await page.evaluate(readState, { selector: p.selector, props });
      r.afterPic = await shot(page, p.selector);
      const changed = props.some(q => r.before.values[q] !== r.after.values[q]) || r.before.w !== r.after.w || r.before.h !== r.after.h;
      if (p.css && !changed) r.ineffective = 'the injected CSS changed none of the measured properties on this element';
    } catch (e) { r.unmeasured = `capture failed: ${String(e.message).split('\n')[0]}`; }
    finally { await ctx.close(); }
  }
  return res;
}

/* ------------------------------------------------------------------- html */

const esc = s => String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

const T = {
  en: { title: 'Design decisions', lead: 'Each change below alters how the site looks. Nothing is applied without your answer.',
    before: 'Now', after: 'Would be', measured: 'Measured', prop: 'Property', box: 'Box (w x h)', recommended: 'Recommended',
    note: 'Note (required for "other")', copy: 'Copy answers', copied: 'Copied', failed: 'Select the text and copy it by hand',
    answered: 'answered', of: 'of', unmeasured: 'Not measured', ineffective: 'The "after" rule had no effect, do not trust this picture',
    noProposal: 'No proposal was prepared for this finding, so there are no pictures. Answer on the finding alone.',
    answers: 'Answers', page: 'Page', pending: 'pending', why: 'Why' },
  es: { title: 'Decisiones de diseño', lead: 'Cada cambio de abajo altera cómo se ve el sitio. No se aplica nada sin tu respuesta.',
    before: 'Ahora', after: 'Quedaría', measured: 'Medido', prop: 'Propiedad', box: 'Caja (an x al)', recommended: 'Recomendada',
    note: 'Nota (obligatoria en "otra")', copy: 'Copiar respuestas', copied: 'Copiado', failed: 'Selecciona el texto y cópialo a mano',
    answered: 'respondidas', of: 'de', unmeasured: 'Sin medir', ineffective: 'La regla del "después" no tuvo efecto, no te fíes de esta imagen',
    noProposal: 'No se preparó propuesta para este hallazgo, así que no hay imágenes. Responde sobre el hallazgo.',
    answers: 'Respuestas', page: 'Página', pending: 'pendiente', why: 'Por qué' },
};

function measuredTable(p, r, t) {
  const rows = [];
  for (const q of r.props || []) rows.push([q, r.before?.values?.[q], r.after?.values?.[q]]);
  if (r.before && r.after) rows.push([t.box, `${r.before.w} x ${r.before.h}`, `${r.after.w} x ${r.after.h}`]);
  for (const k of new Set([...Object.keys(p.measured?.before || {}), ...Object.keys(p.measured?.after || {})]))
    rows.push([k, p.measured?.before?.[k], p.measured?.after?.[k]]);
  if (!rows.length) return '';
  return `<table><thead><tr><th>${t.prop}</th><th>${t.before}</th><th>${t.after}</th></tr></thead><tbody>` +
    rows.map(([k, a, b]) => `<tr${a !== b ? ' class="diff"' : ''}><td>${esc(k)}</td><td>${esc(a ?? '-')}</td><td>${esc(b ?? '-')}</td></tr>`).join('') + '</tbody></table>';
}

function card(p, caps, t) {
  const vp = caps.map(r => {
    const head = `<h4>${esc(r.viewport)}</h4>`;
    if (r.unmeasured) return `<div class="vp">${head}<p class="warn">${t.unmeasured}: ${esc(r.unmeasured)}</p></div>`;
    return `<div class="vp">${head}${r.ineffective ? `<p class="warn">${t.ineffective}</p>` : ''}` +
      `<div class="pics"><figure><img alt="${t.before}" src="${r.beforePic}"><figcaption>${t.before}</figcaption></figure>` +
      `<figure><img alt="${t.after}" src="${r.afterPic}"><figcaption>${t.after}</figcaption></figure></div>${measuredTable(p, r, t)}</div>`;
  }).join('');
  const opts = p.options.map((op, i) => `<label class="opt${op.recommended ? ' rec' : ''}"><input type="radio" name="o-${esc(p.id)}" value="${esc(op.key)}">` +
    `<span>${esc(op.label || op.key)}</span>${op.recommended ? `<b class="badge">${t.recommended}</b>` : ''}</label>`).join('');
  return `<section class="card" data-id="${esc(p.id)}"><header><code>${esc(p.id)}</code><h3>${esc(p.title)}</h3>` +
    `${p.page ? `<p class="meta">${t.page}: ${esc(p.page)}${p.selector ? ` <code>${esc(p.selector)}</code>` : ''}</p>` : ''}` +
    `${p.why ? `<p>${esc(p.why)}</p>` : ''}</header>` +
    `${p.noProposal ? `<p class="warn">${t.noProposal}</p>` : vp}` +
    `<div class="opts">${opts}</div><label class="note">${t.note}<textarea rows="2" maxlength="600"></textarea></label></section>`;
}

const CSS = `:root{--bg:#fff;--fg:#1c1c1c;--mut:#5a5a5a;--line:#d6d6d6;--card:#f6f6f4;--acc:#0b5cad;--ok:#0a6b3a;--warn:#8a4b00}
@media (prefers-color-scheme:dark){:root{--bg:#161616;--fg:#eee;--mut:#aaa;--line:#3a3a3a;--card:#1f1f1f;--acc:#6ab0ff;--ok:#5fd596;--warn:#ffb866}}
*{box-sizing:border-box}body{margin:0;padding:0 16px 120px;background:var(--bg);color:var(--fg);font:16px/1.5 system-ui,sans-serif}
main{max-width:980px;margin:0 auto}h1{margin:24px 0 4px}h3{margin:4px 0}h4{margin:12px 0 4px;color:var(--mut)}
.card{background:var(--card);border:1px solid var(--line);border-radius:8px;padding:16px;margin:20px 0}
.meta{color:var(--mut);font-size:14px;word-break:break-all}.warn{color:var(--warn);font-weight:600}
.pics{display:grid;grid-template-columns:1fr 1fr;gap:12px}figure{margin:0}img{max-width:100%;height:auto;border:1px solid var(--line);background:#fff}
figcaption{font-size:14px;color:var(--mut)}
@media (max-width:640px){.pics{grid-template-columns:1fr}}
table{border-collapse:collapse;width:100%;margin-top:8px;font-size:14px}th,td{border-bottom:1px solid var(--line);padding:4px 8px;text-align:left;word-break:break-word}
tr.diff td{font-weight:600}
.opts{display:flex;flex-wrap:wrap;gap:8px;margin-top:16px}.opt{display:flex;align-items:center;gap:6px;border:1px solid var(--line);border-radius:6px;padding:8px 12px;cursor:pointer;min-height:44px}
.opt.rec{border-color:var(--ok)}.badge{background:var(--ok);color:var(--bg);border-radius:4px;padding:0 6px;font-size:12px}
.note{display:block;margin-top:12px;font-size:14px;color:var(--mut)}textarea{width:100%;font:inherit;background:var(--bg);color:var(--fg);border:1px solid var(--line);border-radius:6px;padding:6px}
.bar{position:fixed;left:0;right:0;bottom:0;background:var(--bg);border-top:1px solid var(--line);padding:10px 16px}
.bar .in{max-width:980px;margin:0 auto;display:flex;gap:12px;align-items:flex-start}
.bar textarea{flex:1;font-family:ui-monospace,monospace;font-size:12px;height:64px}
button{font:inherit;min-height:44px;padding:0 18px;border:0;border-radius:6px;background:var(--acc);color:var(--bg);cursor:pointer}`;

const JS = `(function(){
var cards=[].slice.call(document.querySelectorAll('.card')),out=document.getElementById('out'),btn=document.getElementById('copy'),st=document.getElementById('st');
var L=document.body.dataset;
function build(){var n=0,lines=['DECISIONS v1'];cards.forEach(function(c){
 var r=c.querySelector('input:checked'),o=r?r.value:'pending',note=c.querySelector('textarea').value.replace(/\\s+/g,' ').trim();
 if(r)n++;lines.push('DECISION '+c.dataset.id+': '+o+(note?' | '+note:''));});
 lines.push('END DECISIONS');out.value=lines.join('\\n');st.textContent=n+' '+L.of+' '+cards.length+' '+L.answered;}
document.addEventListener('input',build);document.addEventListener('change',build);build();
function fallback(){out.focus();out.select();var ok=false;try{ok=document.execCommand('copy');}catch(e){}return ok;}
btn.addEventListener('click',function(){build();var done=function(ok){st.textContent=ok?L.copied:L.failed;};
 if(navigator.clipboard&&navigator.clipboard.writeText){navigator.clipboard.writeText(out.value).then(function(){done(true);},function(){done(fallback());});}
 else done(fallback());});
out.addEventListener('click',function(){out.select();});
})();`;

function renderHtml(cards, o, date, t) {
  return `<!doctype html><html lang="${o.lang}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${t.title}</title><style>${CSS}</style></head>
<body data-of="${t.of}" data-answered="${t.answered}" data-copied="${t.copied}" data-failed="${esc(t.failed)}"><main><h1>${t.title}</h1><p class="meta">${esc(date)}</p><p>${t.lead}</p>
${cards.join('\n')}</main>
<div class="bar"><div class="in"><textarea id="out" readonly aria-label="${t.answers}"></textarea><div><button id="copy" type="button">${t.copy}</button><div id="st" role="status" class="meta"></div></div></div></div>
<script>${JS}</script></body></html>
`;
}

/* ------------------------------------------------------------------ build */

async function runBuild(o) {
  if (!o.out) usage('build needs --out (the audit results directory)');
  if (!['en', 'es'].includes(o.lang)) usage('--lang is en or es');
  const t = T[o.lang];
  const list = loadProposals(o);
  const date = o.date || new Date().toISOString().slice(0, 10);
  const needBrowser = list.some(p => p.selector && p.page && !p.noProposal);
  let browser = null;
  if (needBrowser) {
    const chromium = await loadChromium();
    if (!chromium) usage('playwright-core not found (set PLAYWRIGHT_CORE); nothing is installed');
    const executablePath = findBrowser('chromium');
    if (!executablePath) usage('no existing Chromium found (set WP_BROWSER_CHROMIUM); nothing is downloaded');
    browser = await chromium.launch({ executablePath });
  }
  const cards = [], resolved = [];
  let incomplete = 0;
  try {
    for (let p of list) {
      let caps = [];
      if (p.selector && p.page && !p.noProposal) {
        const url = o.site && !/^[a-z][a-z0-9+.-]*:/i.test(p.page) ? new URL(p.page, o.site).href : p.page;
        caps = await capture(browser, p, o, url);
        for (const r of caps) if (r.unmeasured || r.ineffective) { incomplete++; process.stderr.write(`decision-sheet: ${p.id} ${r.viewport}: ${r.unmeasured || r.ineffective}\n`); }
      } else if (!p.noProposal) { p = { ...p, noProposal: true }; incomplete++; process.stderr.write(`decision-sheet: ${p.id}: no page and selector, card has no pictures\n`); }
      cards.push(card(p, caps, t));
      resolved.push({ id: p.id, title: p.title, check: p.check || null, page: p.page || null, selector: p.selector || null, css: p.css || null,
        options: p.options, measured: caps.map(r => ({ viewport: r.viewport, props: r.props || null, before: r.before || null, after: r.after || null,
          unmeasured: r.unmeasured || null, ineffective: r.ineffective || null })) });
    }
  } finally { if (browser) await browser.close(); }
  mkdirSync(resolve(o.out), { recursive: true });
  const file = join(resolve(o.out), `decisiones-${date}.html`.replace('decisiones', o.lang === 'es' ? 'decisiones' : 'decisions'));
  writeFileSync(file, renderHtml(cards, o, date, t));
  writeFileSync(file.replace(/\.html$/, '.json'), JSON.stringify({ tool: 'decision-sheet', version: 1, date, proposals: resolved }, null, 2) + '\n');
  process.stdout.write(`${file}\n${file.replace(/\.html$/, '.json')}\n`);
  process.stderr.write(`decision-sheet: ${list.length} card(s), ${incomplete} incomplete\n`);
  process.exit(incomplete ? 3 : 0);
}

const argv = process.argv.slice(2);
if (argv[0] === '--parse') {
  if (!argv[1]) usage('--parse needs a file or -');
  runParse(argv[1]);
} else if (argv[0] === 'build') await runBuild(parseArgs(argv));
else usage(argv[0] ? `unknown mode ${argv[0]}` : 'missing mode');
