#!/usr/bin/env node
/**
 * css-contour-lint.mjs: contour patterns that render differently across browsers, caught
 * statically because the browser that shows them is not the one verification runs.
 *
 * Verification is Chromium (plus Firefox on Linux when one exists). The defects below appear
 * in Firefox on Windows, whose rasteriser draws a 1px rounded border with visible notches at
 * the corners where the curve meets the straight edge. Linux Firefox does not reproduce it,
 * so no screenshot comparison here can catch it: this lint is the guard.
 *
 *   thin-border        A 1px `border` plus a `border-radius` on an element whose background
 *                      is transparent or white/near-white: an outline button, a focused or
 *                      error field, a ringed icon link. Draw the contour as
 *                      `box-shadow: inset 0 0 0 1px <color>` (Tailwind:
 *                      `border-0 shadow-[inset_0_0_0_1px_<color>]` or `ring-1 ring-inset`).
 *                      CSS rules are checked when they style a control or a control state
 *                      (button, .btn, a, input, select, textarea, :focus, :invalid, error);
 *                      templates when the element is one (a, button, input, select,
 *                      textarea, label) or its classes carry a focus or invalid variant.
 *
 *   drop-shadow-ring   `filter: drop-shadow()` (Tailwind `drop-shadow-*`) on a bordered,
 *                      rounded element. The filter follows the anti-aliased edge, so the
 *                      ring's corners pick up the same artifacts. Use `box-shadow`.
 *
 *   search-clear       A `type="search"` field that no rule hiding
 *                      `::-webkit-search-cancel-button` reaches: Chromium and Safari draw
 *                      their own clear "x", Firefox draws none, so the control exists in one
 *                      engine only. With a custom control and the native one still visible,
 *                      Chromium shows two. A design without a clear affordance hides the
 *                      native one too. Coverage is per field: a global
 *                      `input[type="search"]::-webkit-search-cancel-button` rule covers all,
 *                      a class- or id-scoped one only the fields carrying that class or id.
 *
 * Scans every .css, .php and .html file under the given directories, skipping compiled
 * output (dist/, *.min.css), dependencies and dot-directories. CSS is walked by brace depth,
 * so nested rules (`&:hover { }`) and rules inside @media, @supports or @layer are each read
 * for their own declarations. Tailwind `@apply` lines are read like class lists. Colours are
 * read as hex, rgb()/rgba(), hsl()/hsla() (comma or space syntax) and named light keywords.
 *
 * usage:
 *   css-contour-lint.mjs <dir>... [--rule thin-border|drop-shadow-ring|search-clear]...
 *
 * exit 0 = PASS, 1 = FAIL (one line per finding), 2 = usage.
 */
import { readFileSync, readdirSync, existsSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';

const args = process.argv.slice(2);
const dirs = args.filter((a, i) => !a.startsWith('--') && args[i - 1] !== '--rule');
const ALL = ['thin-border', 'drop-shadow-ring', 'search-clear'];
const picked = args.flatMap((a, i) => (args[i - 1] === '--rule' ? [a] : []));
if (!dirs.length || dirs.some((d) => !existsSync(d) || !statSync(d).isDirectory()) || picked.some((r) => !ALL.includes(r))) {
  console.error('usage: css-contour-lint.mjs <dir>... [--rule thin-border|drop-shadow-ring|search-clear]...');
  process.exit(2);
}
const rules = picked.length ? picked : ALL;

const SKIP_DIRS = new Set(['node_modules', 'vendor', 'dist', 'build']);
function walk(dir, out = []) {
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    if (e.name.startsWith('.')) continue;
    const p = join(dir, e.name);
    if (e.isDirectory()) {
      if (!SKIP_DIRS.has(e.name)) walk(p, out);
    } else if (/\.(css|php|html?)$/.test(e.name) && !e.name.endsWith('.min.css')) {
      out.push(p);
    }
  }
  return out;
}

const files = [...new Set(dirs.flatMap((d) => walk(d).map((f) => ({ f, base: d }))).map((x) => x.f))]
  .sort()
  .map((f) => ({ f, base: dirs.find((d) => f.startsWith(d)) || dirs[0], text: readFileSync(f, 'utf8') }));
const rel = ({ f, base }) => relative(base, f) || f;
const lineAt = (text, idx) => text.slice(0, idx).split('\n').length;

// One line per distinct finding per file: a demo repeats the same outline button on every
// card, and forty identical lines hide the second, different one.
const grouped = new Map();
const report = (file, idx, rule, msg) => {
  const key = file.f + '\0' + rule + '\0' + msg;
  const g = grouped.get(key);
  if (g) g.more++;
  else grouped.set(key, { at: `${rel(file)}:${lineAt(file.text, idx)}`, rule, msg, more: 0 });
};

// ── colour and token helpers ────────────────────────────────────────────────
const NAMED_LIGHT = new Set(['white', 'snow', 'ghostwhite', 'whitesmoke', 'ivory', 'floralwhite', 'seashell', 'mintcream', 'azure', 'aliceblue']);
function isLightOrClear(value) {
  const v = value.trim().toLowerCase();
  if (/^(transparent|none|inherit|initial|unset)\b/.test(v)) return true;
  const word = v.split(/\s+/)[0];
  if (NAMED_LIGHT.has(word)) return true;
  let m = v.match(/#([0-9a-f]{3,8})\b/);
  if (m) {
    let h = m[1];
    if (h.length <= 4) h = h.split('').map((c) => c + c).join('');
    const [r, g, b] = [0, 2, 4].map((i) => parseInt(h.slice(i, i + 2), 16));
    const a = h.length === 8 ? parseInt(h.slice(6, 8), 16) / 255 : 1;
    return a < 0.1 || (r >= 240 && g >= 240 && b >= 240);
  }
  // rgb()/rgba() and hsl()/hsla(), comma or space syntax, channels as numbers or
  // percentages, alpha as a number or a percentage after `,` or `/`.
  const num = (x, full) => (x.endsWith('%') ? (parseFloat(x) / 100) * full : parseFloat(x));
  m = v.match(/\b(rgba?|hsla?)\(\s*([^)]*)\)/);
  if (m) {
    const parts = m[2].split(/\s*[,/]\s*|\s+/).filter(Boolean);
    if (parts.length < 3 || parts.slice(0, 3).some((x) => Number.isNaN(parseFloat(x)))) return false;
    const a = parts[3] === undefined ? 1 : num(parts[3], 1);
    if (a < 0.1) return true;
    let rgb;
    if (m[1].startsWith('rgb')) rgb = parts.slice(0, 3).map((x) => num(x, 255));
    else {
      const unit = parts[0].match(/[a-z]+$/)?.[0];
      const turns = { turn: 1, rad: 1 / (2 * Math.PI), grad: 1 / 400 }[unit];
      const h = ((turns ? parseFloat(parts[0]) * turns * 360 : parseFloat(parts[0])) % 360 + 360) % 360;
      const [sat, l] = [parseFloat(parts[1]) / 100, parseFloat(parts[2]) / 100];
      const k = (n) => (n + h / 30) % 12;
      const c = sat * Math.min(l, 1 - l);
      rgb = [0, 8, 4].map((n) => 255 * (l - c * Math.max(-1, Math.min(k(n) - 3, 9 - k(n), 1))));
    }
    return rgb.every((x) => x >= 240 - 0.5);
  }
  return false;
}

// Tailwind tokens, variants stripped for the base reading. `border` alone and
// `border-[1px]` are 1px on all four sides; `border-x`, `border-2`, `border-t` are not.
const strip = (t) => t.replace(/^!/, '').split(':').pop();
const hasVariant = (t) => t.includes(':');
const isThinBorderTok = (t) => /^(border|border-\[1px\]|border-1)$/.test(strip(t));
const isClearBorderTok = (t) => /^border-(transparent|none|0)$/.test(strip(t));
const isRoundedTok = (t) => /^rounded(-(?!none\b)[\w[\].%-]+)?$/.test(strip(t)) && strip(t) !== 'rounded-none';
const isBgTok = (t) => /^bg-(?!(clip|origin|blend|fixed|local|scroll|repeat|no-repeat|cover|contain|center|top|bottom|left|right|none|gradient|linear|radial|conic|size|position|\[url))/.test(strip(t));
const isLightBgTok = (t) => {
  const s = strip(t);
  if (/^bg-(transparent|white(\/\d+)?)$/i.test(s)) return true;
  const arb = s.match(/^bg-\[(?:color:)?(.+)\]$/);
  return !!arb && isLightOrClear(arb[1].replace(/_/g, ' '));
};
const isDropShadowTok = (t) => /^drop-shadow(-|$)/.test(strip(t));
const isStateTok = (t) => /^(focus|focus-visible|focus-within|invalid|user-invalid|aria-invalid|aria-\[invalid[^\]]*\]|group-invalid|peer-invalid)$/.test(t.split(':').slice(0, -1).pop() || '');
const isShadowContourTok = (t) => /^(shadow-\[inset|ring-1$|ring$|ring-inset$)/.test(strip(t));

// ── CSS: a brace-depth walk over every rule ─────────────────────────────────
// Each rule is read for its OWN declarations: a nested block (`&:hover { }`, a nested
// selector, an @media inside a rule) is its own rule, and the text around it still belongs
// to the parent. A regex over innermost `{ }` pairs swallowed any rule that had a nested
// block, so its border, radius and background were never read. At-rule blocks (@media,
// @supports, @layer, @container) are transparent: their children keep the enclosing
// selector. Comments are blanked and braces or semicolons inside strings neutralised first,
// both length-preserving, so every offset still points at the source line.
function blankCss(text) {
  return text
    .replace(/\/\*[\s\S]*?\*\//g, (m) => m.replace(/[^\n]/g, ' '))
    .replace(/"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*'/g, (m) => m.replace(/[{};]/g, ' '));
}
const splitList = (sel) => sel.split(',').map((x) => x.trim()).filter(Boolean);
function resolveSelector(parent, own) {
  if (!parent) return own;
  const out = [];
  for (const p of splitList(parent))
    for (const c of splitList(own)) out.push(c.includes('&') ? c.replace(/&/g, p) : `${p} ${c}`);
  return out.join(', ');
}
/** [{ selector, body, idx }] for every style rule, `selector` resolved through nesting. */
function parseCss(raw, offset = 0) {
  const text = blankCss(raw);
  const rules = [];
  const root = { selector: '', at: true, own: '', pending: '' };
  const stack = [root];
  const effective = () => {
    for (let i = stack.length - 1; i >= 0; i--) if (!stack[i].at) return stack[i].selector;
    return '';
  };
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    const top = stack[stack.length - 1];
    if (ch === '{') {
      const prelude = top.pending.trim();
      top.pending = '';
      const at = prelude.startsWith('@');
      stack.push({ selector: at ? '' : resolveSelector(effective(), prelude), at, own: '', pending: '', idx: offset + i });
    } else if (ch === '}') {
      if (stack.length === 1) continue; // stray brace
      const done = stack.pop();
      done.own += done.pending;
      if (!done.at && done.selector) rules.push({ selector: done.selector, body: done.own, idx: done.idx });
      stack[stack.length - 1].pending = '';
    } else if (ch === ';') {
      top.own += top.pending + ';';
      top.pending = '';
    } else {
      top.pending += ch;
    }
  }
  return rules;
}
function readDecls(body) {
  const decl = {};
  const apply = [];
  for (const part of body.split(';')) {
    const a = part.trim().match(/^@apply\s+(.+)$/);
    if (a) {
      apply.push(...a[1].split(/\s+/).filter(Boolean));
      continue;
    }
    const d = part.match(/^\s*([\w-]+)\s*:\s*([\s\S]+?)\s*$/);
    if (d) decl[d[1].toLowerCase()] = d[2].replace(/\s*!important\s*$/, '');
  }
  return { decl, apply };
}

// Rules that hide the native search clear button, kept per selector so each search field is
// judged by the rules that reach it (see the search-clear section below).
const CANCEL_PSEUDO = /::-webkit-search-cancel-button/i;
const hidesCancel = (decl, apply) =>
  /^none\b/.test((decl['-webkit-appearance'] || decl.appearance || '').trim()) ||
  /^none\b/.test((decl.display || '').trim()) ||
  apply.some((t) => /^(appearance-none|hidden)$/.test(strip(t)));
const cancelHiders = [];
const collectCancelHiders = (rulesList) => {
  for (const r of rulesList) {
    if (!CANCEL_PSEUDO.test(r.selector)) continue;
    const { decl, apply } = readDecls(r.body);
    if (hidesCancel(decl, apply)) for (const s of splitList(r.selector)) if (CANCEL_PSEUDO.test(s)) cancelHiders.push(s);
  }
};

const CONTROL_SEL = /(^|[\s,>+~(])(a|button|input|select|textarea)(?=$|[\s,.:[#>+~)])|\.(btn|button)\b|\[type=|:focus|:invalid|:user-invalid|error|invalid|not-valid|outline|ghost/i;
const cssFiles = files.filter((x) => x.f.endsWith('.css'));
for (const file of cssFiles) {
  const parsed = parseCss(file.text);
  collectCancelHiders(parsed);
  for (const { selector, body, idx } of parsed) {
    const { decl, apply } = readDecls(body);
    const base = apply.filter((t) => !hasVariant(t));
    const thin =
      ((decl.border && /(^|\s)1px(\s|$)/.test(decl.border) && !/\btransparent\b/.test(decl.border)) ||
        (decl['border-width'] && /^1px$/.test(decl['border-width'].trim())) ||
        apply.some(isThinBorderTok)) &&
      !/^transparent\b/.test((decl['border-color'] || '').trim()) &&
      !base.some(isClearBorderTok);
    const radius =
      (decl['border-radius'] && !/^0(px|rem|em|%)?$/.test(decl['border-radius'].trim())) || apply.some(isRoundedTok);
    const bgDecl = decl['background-color'] ?? decl.background;
    const bgClear = bgDecl !== undefined ? isLightOrClear(bgDecl) : apply.some(isLightBgTok) || !base.some(isBgTok);
    const contourByShadow = /inset\s+0\s+0\s+0\s+1px/.test(decl['box-shadow'] || '') || apply.some(isShadowContourTok);

    if (rules.includes('thin-border') && thin && radius && bgClear && !contourByShadow && CONTROL_SEL.test(selector)) {
      report(file, idx, 'thin-border', `\`${selector.replace(/\s+/g, ' ')}\`: 1px border + border-radius on a transparent/white background; draw it as box-shadow: inset 0 0 0 1px <color>`);
    }
    const dropShadow = /drop-shadow\(/.test(decl.filter || '') || apply.some(isDropShadowTok);
    const bordered = (decl.border && !/^(none|0)\b/.test(decl.border.trim())) || decl['border-width'] || apply.some((t) => /^border(-\d|-\[|$)/.test(strip(t)));
    if (rules.includes('drop-shadow-ring') && dropShadow && bordered && radius) {
      report(file, idx, 'drop-shadow-ring', `\`${selector.replace(/\s+/g, ' ')}\`: filter: drop-shadow on a bordered rounded ring; use box-shadow`);
    }
  }
}

// ── Templates: class attributes ─────────────────────────────────────────────
const tplFiles = files.filter((x) => !x.f.endsWith('.css'));
const INTERACTIVE = new Set(['a', 'button', 'input', 'select', 'textarea', 'label', 'summary']);
// A <style> block in a template reaches the page like a stylesheet does.
for (const file of tplFiles) {
  const re = /<style\b[^>]*>([\s\S]*?)<\/style>/gi;
  let m;
  while ((m = re.exec(file.text))) collectCancelHiders(parseCss(m[1]));
}
for (const file of tplFiles) {
  const text = file.text;
  const re = /\bclass\s*=\s*("([^"]*)"|'([^']*)')/g;
  let m;
  while ((m = re.exec(text))) {
    const value = (m[2] ?? m[3]).replace(/<\?(php|=)[\s\S]*?\?>/g, ' ');
    const toks = value.split(/\s+/).filter(Boolean);
    const open = text.lastIndexOf('<', m.index);
    const tag = (text.slice(open + 1, open + 20).match(/^([a-zA-Z][\w-]*)/) || [])[1]?.toLowerCase() || '';
    const base = toks.filter((t) => !hasVariant(t));
    const thin = toks.some(isThinBorderTok) && !base.some(isClearBorderTok);
    const radius = toks.some(isRoundedTok);
    const bgClear = base.some(isLightBgTok) || !base.some(isBgTok);
    const contourByShadow = toks.some(isShadowContourTok);
    const control = INTERACTIVE.has(tag) || /\b(btn|button)\b/.test(value) || toks.some(isStateTok);
    if (rules.includes('thin-border') && thin && radius && bgClear && !contourByShadow && control) {
      report(file, m.index, 'thin-border', `<${tag || '?'} class="${toks.filter((t) => isThinBorderTok(t) || isRoundedTok(t) || isBgTok(t)).join(' ')} …">: 1px border + rounded on a transparent/white background; use shadow-[inset_0_0_0_1px_<color>] (or ring-1 ring-inset) and border-0`);
    }
    if (rules.includes('drop-shadow-ring') && toks.some(isDropShadowTok) && toks.some((t) => /^border(-\d|-\[|$)/.test(strip(t))) && radius) {
      report(file, m.index, 'drop-shadow-ring', `<${tag || '?'}>: drop-shadow on a bordered rounded ring; use a box-shadow utility`);
    }
  }
}

// ── search inputs ───────────────────────────────────────────────────────────
// A field counts as covered only when a hiding rule can reach it. Each hiding selector is
// read at the compound the pseudo-element hangs on (`form .search__input::-webkit-...` is
// read as `.search__input`), and that compound must match the field's own tag: the tag is
// `input` or absent, every class is on the field, the id is the field's, and every attribute
// is present (`[type=search]` always is). Ancestors and pseudo-classes are not checked, so
// the rule errs toward coverage. A global `input[type="search"]::-webkit-search-cancel-button`
// covers every field; `.search-a::-webkit-...` covers only fields carrying `search-a`. A
// Tailwind arbitrary variant on the field itself (`[&::-webkit-search-cancel-button]:hidden`
// or `:appearance-none`) covers that field. Classes and ids printed by PHP are unknown and
// never match.
function compoundOf(sel) {
  const before = sel.split(/::-webkit-search-cancel-button/i)[0];
  const parts = before.trim().split(/\s*[\s>+~]\s*(?![^[]*\])/).filter(Boolean);
  const c = (parts.pop() || '').replace(/:{1,2}[\w-]+(\([^)]*\))?/g, '');
  return {
    tag: (c.match(/^([a-zA-Z][\w-]*|\*)/) || [])[1]?.toLowerCase() || '',
    classes: [...c.matchAll(/\.([\w-]+)/g)].map((x) => x[1]),
    ids: [...c.matchAll(/#([\w-]+)/g)].map((x) => x[1]),
    attrs: [...c.matchAll(/\[\s*([\w-]+)/g)].map((x) => x[1].toLowerCase()),
  };
}
const attrOf = (tag, name) => {
  const m = tag.match(new RegExp(`\\s${name}\\s*=\\s*("([^"]*)"|'([^']*)')`, 'i'));
  return m ? (m[2] ?? m[3]).replace(/<\?(php|=)[\s\S]*?\?>/g, ' ') : null;
};
function fieldCovered(tag) {
  const classes = (attrOf(tag, 'class') || '').split(/\s+/).filter(Boolean);
  if (classes.some((t) => /-webkit-search-cancel-button\]:(hidden|appearance-none)$/.test(t.replace(/^!/, '')))) return true;
  const id = attrOf(tag, 'id');
  return cancelHiders.some((sel) => {
    const c = compoundOf(sel);
    if (c.tag && c.tag !== '*' && c.tag !== 'input') return false;
    return (
      c.classes.every((x) => classes.includes(x)) &&
      c.ids.every((x) => x === id) &&
      c.attrs.every((a) => new RegExp(`\\s${a}(\\s*=|[\\s>/])`, 'i').test(tag + ' '))
    );
  });
}
if (rules.includes('search-clear')) {
  const CLEAR = /type\s*=\s*["']reset["']|data-[\w-]*clear|\bclass\s*=\s*["'][^"']*\bclear|['"][\w-]*_clear['"]|aria-label\s*=\s*["'][^"']*\b(clear|limpiar|borrar|effacer)/i;
  for (const file of tplFiles) {
    const re = /type\s*=\s*["']search["']/gi;
    let m;
    while ((m = re.exec(file.text))) {
      const open = file.text.lastIndexOf('<', m.index);
      const tagRe = /<[a-zA-Z](?:<\?[\s\S]*?\?>|[^>])*>/y;
      tagRe.lastIndex = open;
      const tag = (open >= 0 && tagRe.exec(file.text)?.[0]) || file.text.slice(m.index, m.index + 200);
      if (fieldCovered(tag)) continue;
      const custom = CLEAR.test(file.text);
      report(
        file,
        m.index,
        'search-clear',
        custom
          ? 'type="search" with a custom clear control while ::-webkit-search-cancel-button is still shown: Chromium draws two'
          : 'type="search" with no custom clear control: Chromium/Safari draw a native "x", Firefox none. Add a <button type="button"> clear control, or hide ::-webkit-search-cancel-button if the design has none'
      );
    }
  }
}

const findings = [...grouped.values()].map(
  (g) => `FAIL: ${g.at} [${g.rule}] ${g.msg}${g.more ? ` (+${g.more} more in this file)` : ''}`
);
for (const f of findings) console.log(f);
if (findings.length) {
  console.log(`FAIL: ${findings.length} finding(s)`);
  process.exit(1);
}
console.log(`PASS: ${rules.join(', ')} (${files.length} file(s))`);
