#!/usr/bin/env node
/**
 * family-lint.mjs: the measurable part of a craft family's Avoid list, reported, never enforced.
 *
 * skills/wp-demo-craft/references/families.md gives every family an Avoid list, and the
 * evaluator reads it from contact sheets. Three of its items are visible in the CSS itself,
 * so this lint finds them and hands the list to the evaluator, who decides whether each one
 * is a hit for the family recorded in demo/BRIEF.md or the page's one deliberate exception:
 *
 *   glass          a `backdrop-filter` (or -webkit-) whose value is not `none`.
 *   rounded-card   a rule that ends up with a visible border on all four sides (each side
 *                  with a width, a style and a colour that is not transparent, from the
 *                  border shorthands and longhands applied in order as in the cascade) and a
 *                  `border-radius` over 12px, the last one winning. Pills
 *                  and circles (a radius of 100px or more) are not cards and are left out; a
 *                  percentage is not read as a length. A border and a radius set in two
 *                  different rules for one element are not combined.
 *   accents        more than one saturated hue on the page, grouped by hue within 20 degrees.
 *                  Saturated means HSL saturation of at least 45% and lightness 20-80% for
 *                  hex, rgb(), hsl(), hwb() and named colours; chroma of at least 0.1 (oklch,
 *                  oklab) or 30 (lch, lab) at a mid lightness for the CSS Color 4 spaces.
 *                  Custom properties, gradients and color-mix() arguments are read; color()
 *                  is not, and the report counts what it could not read so an empty report
 *                  is never mistaken for a page without accents.
 *
 * Reads every .html (its <style> blocks and style="" attributes) and .css file under the
 * given paths, skipping dot-directories (demo/.verify), node_modules, vendor, dist, build and
 * *.min.css. CSS is walked by brace depth, so rules inside @media and nested rules count.
 * `var(--x)` is resolved against the rule's own custom properties first, then those declared
 * on `:root` or `html`, then the first declaration anywhere, so a
 * `border-radius: var(--radius-card)` is read as its value. A property redefined per
 * component or per theme is read with that order, not per element.
 *
 * Exit codes: 0 report printed (findings or none: the lint never blocks), 2 nothing to read
 * (no such path, or no .html/.css under it), 3 crash, 64 usage.
 */
import './lib/stdio-blocking.mjs';
import { readFileSync, readdirSync, statSync, realpathSync } from 'node:fs';
import { join, relative, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const HELP = `usage: family-lint.mjs <path>... [--json] [--help]

Reports glass (backdrop-filter), rounded bordered cards (radius over 12px) and more than one
saturated accent hue in the .html/.css under each path. Report only: it never blocks, and
the evaluator decides whether a finding is an Avoid hit for the recorded family.
Exit 0 report printed, 2 nothing to read, 3 crash, 64 usage.
`;

const SKIP_DIRS = new Set(['node_modules', 'vendor', 'dist', 'build']);
export const RADIUS_MAX = 12;
const PILL_PX = 100;
const SAT_MIN = 0.45;
const L_MIN = 0.2;
const L_MAX = 0.8;
const HUE_GAP = 20;

// Real paths are tracked, so a symlink back up the tree is read once and never loops.
function walk(p, out = [], seen = new Set()) {
  let st;
  let real;
  try { st = statSync(p); real = realpathSync(p); } catch { return out; }
  if (seen.has(real)) return out;
  seen.add(real);
  if (st.isFile()) {
    if (/\.(html|css)$/i.test(p) && !/\.min\.css$/i.test(p)) out.push(p);
    return out;
  }
  if (!st.isDirectory()) return out;
  let names;
  try { names = readdirSync(p).sort(); } catch { return out; } // unreadable: skipped, not a crash
  for (const n of names) {
    if (n.startsWith('.') || SKIP_DIRS.has(n)) continue;
    walk(join(p, n), out, seen);
  }
  return out;
}

// Line number of an offset: one index of newline offsets per file, searched by bisection, so a
// large stylesheet with thousands of colours is not rescanned from the top for each one.
export function lineIndex(text) {
  const nl = [];
  for (let i = text.indexOf('\n'); i !== -1; i = text.indexOf('\n', i + 1)) nl.push(i);
  return (idx) => {
    let lo = 0;
    let hi = nl.length;
    while (lo < hi) { const mid = (lo + hi) >> 1; if (nl[mid] < idx) lo = mid + 1; else hi = mid; }
    return lo + 1;
  };
}

// Comments blanked (newlines kept, so offsets and line numbers survive) and braces or
// semicolons inside strings neutralised, so the brace walk below cannot be misled.
function blankCss(text) {
  return text
    .replace(/\/\*[\s\S]*?\*\//g, (m) => m.replace(/[^\n]/g, ' '))
    .replace(/"(?:\\.|[^"\\\n])*"|'(?:\\.|[^'\\\n])*'/g, (m) => m.replace(/[{};]/g, ' '));
}

/** [{ selector, decls: [{ prop, value, idx }] }] for every rule, at-rule bodies included. */
export function parseCss(raw, offset = 0) {
  const text = blankCss(raw);
  const rules = [];
  const stack = [{ selector: '', decls: [] }];
  let pending = '';
  let pendingAt = 0;
  const flush = () => {
    const m = pending.match(/^\s*([\w-]+)\s*:\s*([\s\S]+?)\s*$/);
    if (m) {
      const lead = pending.length - pending.trimStart().length;
      stack[stack.length - 1].decls.push({
        // Custom property names are case-sensitive; every other property name is not.
        prop: m[1].startsWith('--') ? m[1] : m[1].toLowerCase(),
        value: m[2].replace(/\s*!important\s*$/i, ''),
        idx: offset + pendingAt + lead,
      });
    }
    pending = '';
  };
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (!pending) pendingAt = i;
    if (ch === '{') {
      const sel = pending.trim();
      pending = '';
      stack.push({ selector: sel, decls: [] });
    } else if (ch === '}') {
      flush();
      if (stack.length === 1) continue;
      const done = stack.pop();
      if (done.decls.length) rules.push(done);
    } else if (ch === ';') {
      flush();
    } else {
      pending += ch;
    }
  }
  flush();
  // A block left open at the end of the source still counts: close every frame still open.
  while (stack.length > 1) {
    const done = stack.pop();
    if (done.decls.length) rules.push(done);
  }
  if (stack[0].decls.length) rules.push(stack[0]); // a bare style="" body
  return rules;
}

/** Every CSS source in a file: [{ css, offset }]. */
function sources(file, text) {
  if (/\.css$/i.test(file)) return [{ css: text, offset: 0, inline: false }];
  const out = [];
  for (const m of text.matchAll(/<style\b[^>]*>([\s\S]*?)<\/style>/gi)) {
    out.push({ css: m[1], offset: m.index + m[0].indexOf('>') + 1, inline: false });
  }
  for (const m of text.matchAll(/\sstyle\s*=\s*("([^"]*)"|'([^']*)')/gi)) {
    const body = m[2] ?? m[3];
    out.push({ css: body, offset: m.index + m[0].indexOf(m[1]) + 1, inline: true });
  }
  return out;
}

// vars is a lookup (name) => value | undefined.
function resolveVars(value, vars, depth = 0) {
  if (depth > 8 || !value.includes('var(')) return value;
  return resolveVars(value.replace(/var\(\s*(--[\w-]+)\s*(?:,\s*([^()]*(?:\([^()]*\)[^()]*)*))?\)/g,
    (all, name, fallback) => { const v = vars(name); return v !== undefined ? v : fallback !== undefined ? fallback : all; }), vars, depth + 1);
}

/** Largest length in a border-radius value, in px; null when it is a pill/circle or unreadable. */
export function radiusPx(value) {
  const v = value.split('/')[0];
  let max = 0;
  let any = false;
  for (const m of v.matchAll(/(-?[\d.]+)(px|rem|em)?\b/g)) {
    const n = parseFloat(m[1]);
    if (Number.isNaN(n)) continue;
    if (!m[2] && n !== 0) continue; // unitless non-zero is not a length
    any = true;
    max = Math.max(max, m[2] === 'rem' || m[2] === 'em' ? n * 16 : n);
  }
  if (!any || max >= PILL_PX) return null;
  return max;
}

const BORDER_STYLES = /\b(solid|dashed|dotted|double|groove|ridge|inset|outset)\b/;
const ZERO = /^(0+(\.0*)?|\.0+)(px|rem|em|pt)?$/;

// A border drawn in a transparent colour (the hover-reserve trick) is not a visible border.
// Read per colour token, never by searching the value: `transparent` inside color-mix() is a
// mixing input, and a token holding more than one colour is not a fully transparent one.
const invisible = (t) => {
  const v = t.trim().toLowerCase();
  if (v === 'transparent') return true;
  const c = colours(v);
  return c.length === 1 && c[0].a === 0;
};
// Top-level tokens of a value, a function call kept whole: `1px solid rgb(0 0 0 / .1)` is
// three tokens, so the zeros inside rgb() are never read as a width.
const tokens = (v) => v.trim().toLowerCase().match(/[\w.%#-]*\((?:[^()]|\([^()]*\))*\)|[^\s]+/g) || [];
const isWidth = (t) => /^-?[\d.]+(px|rem|em|pt)?$/.test(t) || /^(thin|medium|thick)$/.test(t);
const isStyle = (t) => /^(none|hidden|solid|dashed|dotted|double|groove|ridge|inset|outset)$/.test(t);
// 1-4 values to top, right, bottom, left.
const sides4 = (list) => [list[0], list[1] ?? list[0], list[2] ?? list[0], list[3] ?? list[1] ?? list[0]];
const SIDES = ['top', 'right', 'bottom', 'left'];

/**
 * Per-side border state, applied declaration by declaration as the cascade would: each side
 * has a width, a style and a colour, and it shows only when all three do. Defaults are CSS's
 * (medium width, style none, currentColor), so a radius with no border declaration never
 * reads as a bordered box. Returns { apply(prop, value), drawn() }.
 */
export function borderState() {
  const side = () => ({ width: true, style: false, color: true });
  const st = { top: side(), right: side(), bottom: side(), left: side() };
  const setWidth = (s, t) => { st[s].width = t !== undefined && isWidth(t) ? !ZERO.test(t) : st[s].width; };
  const setStyle = (s, t) => { if (t !== undefined) st[s].style = BORDER_STYLES.test(t); };
  const setColor = (s, t) => { if (t !== undefined) st[s].color = !invisible(t); };
  const shorthand = (names, value) => {
    const ts = tokens(value);
    const w = ts.find(isWidth);
    const y = ts.find(isStyle);
    const c = ts.find((t) => !isWidth(t) && !isStyle(t));
    for (const s of names) {
      st[s].width = w === undefined ? true : !ZERO.test(w); // omitted width resets to medium
      st[s].style = y !== undefined && BORDER_STYLES.test(y); // omitted style resets to none
      st[s].color = c === undefined ? true : !invisible(c);
    }
  };
  // Logical properties, read left to right: only whether all four sides show matters here.
  const LOGICAL = { inline: ['left', 'right'], block: ['top', 'bottom'], 'inline-start': ['left'], 'inline-end': ['right'], 'block-start': ['top'], 'block-end': ['bottom'] };
  return {
    apply(prop, value) {
      let m;
      if ((m = prop.match(/^border-(inline|block)(-start|-end)?(-(width|style|color))?$/))) {
        const names = LOGICAL[`${m[1]}${m[2] || ''}`];
        if (!m[4]) { shorthand(names, value); return true; }
        const ts = tokens(value);
        // border-inline-width: 1px 2px sets start then end; a single value sets both.
        names.forEach((s, i) => (m[4] === 'width' ? setWidth : m[4] === 'style' ? setStyle : setColor)(s, ts[i] ?? ts[0]));
        return true;
      }
      if (prop === 'border') shorthand(SIDES, value);
      else if ((m = prop.match(/^border-(top|right|bottom|left)$/))) shorthand([m[1]], value);
      else if ((m = prop.match(/^border-(width|style|color)$/))) {
        const v = sides4(tokens(value));
        SIDES.forEach((s, i) => (m[1] === 'width' ? setWidth : m[1] === 'style' ? setStyle : setColor)(s, v[i]));
      } else if ((m = prop.match(/^border-(top|right|bottom|left)-(width|style|color)$/))) {
        const t = tokens(value)[0];
        (m[2] === 'width' ? setWidth : m[2] === 'style' ? setStyle : setColor)(m[1], t);
      } else return false;
      return true;
    },
    drawn: () => SIDES.every((s) => st[s].width && st[s].style && st[s].color),
  };
}

const NAMED = { red: '#ff0000', blue: '#0000ff', green: '#008000', orange: '#ffa500', purple: '#800080', magenta: '#ff00ff', fuchsia: '#ff00ff', cyan: '#00ffff', aqua: '#00ffff', yellow: '#ffff00', lime: '#00ff00', crimson: '#dc143c', tomato: '#ff6347', gold: '#ffd700', teal: '#008080', navy: '#000080', coral: '#ff7f50', violet: '#ee82ee', indigo: '#4b0082', deeppink: '#ff1493', royalblue: '#4169e1', dodgerblue: '#1e90ff', orangered: '#ff4500' };

function rgbToHsl(r, g, b) {
  r /= 255; g /= 255; b /= 255;
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const l = (max + min) / 2;
  if (max === min) return { h: 0, s: 0, l };
  const d = max - min;
  const s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
  let h;
  if (max === r) h = ((g - b) / d + (g < b ? 6 : 0));
  else if (max === g) h = (b - r) / d + 2;
  else h = (r - g) / d + 4;
  return { h: h * 60, s, l };
}

// OKLab and CIE Lab (D50) to gamma-encoded sRGB 0-255, clipped (CSS Color 4 matrices).
const gamma = (x) => { const c = Math.min(1, Math.max(0, x)); return 255 * (c <= 0.0031308 ? 12.92 * c : 1.055 * c ** (1 / 2.4) - 0.055); };
export function oklabToRgb(L, a, b) {
  const l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3;
  const m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3;
  const s = (L - 0.0894841775 * a - 1.291485548 * b) ** 3;
  return [4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
    -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
    -0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s].map(gamma);
}
export function labToRgb(L, a, b) {
  const fy = (L + 16) / 116;
  const fx = fy + a / 500;
  const fz = fy - b / 200;
  const inv = (t) => (t > 6 / 29 ? t ** 3 : 3 * (6 / 29) ** 2 * (t - 4 / 29));
  const [X, Y, Z] = [0.96422 * inv(fx), inv(fy), 0.82521 * inv(fz)]; // D50 white
  // Bradford D50 to D65, then XYZ to linear sRGB, folded into one matrix.
  return [3.1338561 * X - 1.6168667 * Y - 0.4906146 * Z,
    -0.9787684 * X + 1.9161415 * Y + 0.033454 * Z,
    0.0719453 * X - 0.2289914 * Y + 1.4052427 * Z].map(gamma);
}

const SAT_MIN_OK = 0.1; // oklch/oklab chroma
const SAT_MIN_CIE = 30; // lch/lab chroma
const pct = (x, full) => (x.endsWith('%') ? (parseFloat(x) / 100) * full : parseFloat(x));
const hueDeg = (x) => {
  const unit = x.match(/[a-z]+$/)?.[0];
  const k = { turn: 360, rad: 180 / Math.PI, grad: 0.9 }[unit] || 1;
  return ((parseFloat(x) * k) % 360 + 360) % 360;
};

/**
 * Every colour in a value: [{ text, h, sat, a }] where sat says whether it reads as an accent.
 * color() is not placed; lint() counts those separately.
 */
export function colours(value) {
  const out = [];
  // url(#id) and the like are references, never colours.
  const v = value.toLowerCase().replace(/url\([^)]*\)/g, ' ');
  const hsl = (text, hsl, a) => out.push({ text, h: hsl.h, a, sat: a >= 0.5 && hsl.s >= SAT_MIN && hsl.l >= L_MIN && hsl.l <= L_MAX });
  for (const m of v.matchAll(/#([0-9a-f]{3,8})\b/g)) {
    let h = m[1];
    if (![3, 4, 6, 8].includes(h.length)) continue;
    if (h.length <= 4) h = h.split('').map((c) => c + c).join('');
    const [r, g, b] = [0, 2, 4].map((i) => parseInt(h.slice(i, i + 2), 16));
    const a = h.length === 8 ? parseInt(h.slice(6, 8), 16) / 255 : 1;
    hsl(m[0], rgbToHsl(r, g, b), a);
  }
  for (const m of v.matchAll(/\b(rgba?|hsla?|hwb|oklch|oklab|lch|lab)\(\s*([^)]*)\)/g)) {
    const parts = m[2].split(/\s*[,/]\s*|\s+/).filter(Boolean);
    if (parts.length < 3 || parts.slice(0, 3).some((x) => Number.isNaN(parseFloat(x)))) continue;
    const a = parts[3] === undefined ? 1 : pct(parts[3], 1);
    const fn = m[1];
    if (fn.startsWith('rgb')) {
      const [r, g, b] = parts.slice(0, 3).map((x) => pct(x, 255));
      hsl(m[0], rgbToHsl(r, g, b), a);
    } else if (fn.startsWith('hsl')) {
      hsl(m[0], { h: hueDeg(parts[0]), s: parseFloat(parts[1]) / 100, l: parseFloat(parts[2]) / 100 }, a);
    } else if (fn === 'hwb') {
      const h = hueDeg(parts[0]);
      const w = parseFloat(parts[1]) / 100;
      const bk = parseFloat(parts[2]) / 100;
      if (w + bk >= 1) { hsl(m[0], { h, s: 0, l: w / (w + bk) }, a); continue; }
      // The pure hue at full saturation, scaled by 1 - w - b and lifted by w (CSS Color 4).
      const k = (n) => (n + h / 30) % 12;
      const pure = [0, 8, 4].map((n) => 0.5 - 0.5 * Math.max(-1, Math.min(k(n) - 3, 9 - k(n), 1)));
      const [r, g, b] = pure.map((c) => (c * (1 - w - bk) + w) * 255);
      hsl(m[0], rgbToHsl(r, g, b), a);
    } else {
      // CSS Color 4 spaces: lightness, then chroma and hue (lch) or the a/b axes (lab). The
      // accent test reads their chroma; the hue is taken from the colour converted to sRGB, so
      // #ff0000 and oklch(0.63 0.26 29) land on the same HSL hue and count as one accent.
      const ok = fn.startsWith('ok');
      const L = pct(parts[0], ok ? 1 : 100);
      let C;
      let h;
      if (fn.endsWith('lch')) {
        C = pct(parts[1], ok ? 0.4 : 150);
        h = hueDeg(parts[2]);
      } else {
        const [x, y] = [parts[1], parts[2]].map((p) => pct(p, ok ? 0.4 : 125));
        C = Math.hypot(x, y);
        h = ((Math.atan2(y, x) * 180) / Math.PI + 360) % 360;
      }
      const mid = ok ? L >= 0.35 && L <= 0.85 : L >= 25 && L <= 80;
      const rad = (h * Math.PI) / 180;
      const rgb = ok ? oklabToRgb(L, C * Math.cos(rad), C * Math.sin(rad)) : labToRgb(L, C * Math.cos(rad), C * Math.sin(rad));
      const srgbHue = rgbToHsl(...rgb);
      out.push({ text: m[0], h: srgbHue.s > 0 ? srgbHue.h : h, a, sat: a >= 0.5 && mid && C >= (ok ? SAT_MIN_OK : SAT_MIN_CIE) });
    }
  }
  for (const m of v.matchAll(/(?:^|[\s,(])([a-z]+)(?=$|[\s,)])/g)) {
    const hex = NAMED[m[1]];
    if (!hex) continue;
    const [r, g, b] = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16));
    hsl(m[1], rgbToHsl(r, g, b), 1);
  }
  return out;
}

const hueDist = (a, b) => { const d = Math.abs(a - b) % 360; return d > 180 ? 360 - d : d; };

export function lint(paths) {
  const files = [...new Set(paths.flatMap((p) => walk(resolve(p))))];
  if (files.length === 0) return null;
  const base = paths.length === 1 && statSync(resolve(paths[0])).isDirectory() ? resolve(paths[0]) : process.cwd();
  const parsed = [];
  const rootVars = new Map();
  const anyVars = new Map();
  for (const f of files) {
    const text = readFileSync(f, 'utf8');
    const lineOf = lineIndex(text);
    for (const src of sources(f, text)) {
      for (const rule of parseCss(src.css, src.offset)) {
        parsed.push({ file: relative(base, f) || f, lineOf, rule, inline: src.inline });
        const isRoot = /^(:root|html)$/i.test(rule.selector.trim());
        for (const d of rule.decls) {
          if (!d.prop.startsWith('--')) continue;
          if (isRoot) rootVars.set(d.prop, d.value);
          if (!anyVars.has(d.prop)) anyVars.set(d.prop, d.value);
        }
      }
    }
  }
  const findings = [];
  const hues = []; // clusters: { h, members: [{ text, where }] }
  const unread = new Set(); // distinct color() values, counted where written, not where used
  for (const { file, lineOf, rule, inline } of parsed) {
    const where = (d) => `${file}:${lineOf(d.idx)}`;
    const selector = inline ? '[style]' : rule.selector || '(top level)';
    const own = new Map();
    for (const d of rule.decls) if (d.prop.startsWith('--')) own.set(d.prop, d.value);
    const vars = (name) => (own.has(name) ? own.get(name) : rootVars.has(name) ? rootVars.get(name) : anyVars.get(name));
    // The last declaration of each wins, as in the cascade: a later `border: none`,
    // `border-bottom: 0` or `border-radius: 0` cancels an earlier one, and a later visible
    // `border-color` brings a transparent border back.
    const border = borderState();
    const borderDecls = [];
    let radius = null;
    for (const d of rule.decls) {
      const value = resolveVars(d.value, vars);
      if ((d.prop === 'backdrop-filter' || d.prop === '-webkit-backdrop-filter') && !/^none\b/i.test(value.trim())) {
        findings.push({ rule: 'glass', where: where(d), selector, detail: `${d.prop}: ${value}` });
      }
      if (border.apply(d.prop, value)) {
        borderDecls.push(`${d.prop}: ${value}`);
      } else if (d.prop === 'border-radius') {
        const px = radiusPx(value);
        radius = px !== null && px > RADIUS_MAX ? { d, value, px } : null;
      }
      for (const u of d.value.toLowerCase().match(/\bcolor\([^)]*\)/g) || []) unread.add(u.replace(/\s+/g, ' '));
      for (const c of colours(value)) {
        if (!c.sat) continue;
        const cl = hues.find((x) => hueDist(x.h, c.h) <= HUE_GAP);
        if (cl) { if (!cl.members.some((m) => m.text === c.text)) cl.members.push({ text: c.text, where: where(d) }); }
        else hues.push({ h: c.h, members: [{ text: c.text, where: where(d) }] });
      }
    }
    if (border.drawn() && radius) {
      findings.push({ rule: 'rounded-card', where: where(radius.d), selector,
        detail: `border-radius: ${radius.value} (${Math.round(radius.px)}px) with ${borderDecls.join('; ')}` });
    }
  }
  if (hues.length > 1) {
    findings.push({ rule: 'accents', where: hues[0].members[0].where, selector: null,
      detail: `${hues.length} saturated hues: ${hues.map((x) => `${Math.round(x.h)}° (${x.members.map((m) => `${m.text} at ${m.where}`).join(', ')})`).join('; ')}` });
  }
  return { files: files.length, findings, unread: unread.size };
}

export function render(r) {
  const L = [];
  for (const f of r.findings) {
    L.push(`${f.rule.padEnd(13)} ${f.where}${f.selector ? `  ${f.selector}` : ''}`);
    L.push(`              ${f.detail}`);
  }
  if (r.unread) L.push(`${r.unread} colour${r.unread === 1 ? '' : 's'} in color() not read: the accent count leaves ${r.unread === 1 ? 'it' : 'them'} out.`);
  L.push(`${r.findings.length} finding${r.findings.length === 1 ? '' : 's'} in ${r.files} file${r.files === 1 ? '' : 's'}. Report only: the evaluator decides whether each is an Avoid hit for the family in demo/BRIEF.md.`);
  return L.join('\n');
}

// Exit codes are set, never forced with process.exit(): a forced exit after a write to a pipe
// drops whatever the pipe has not taken yet (64 KiB), and the evaluator would read half a report.
function main(argv) {
  const paths = [];
  let json = false;
  const stop = (code, err, out = '') => { if (err) process.stderr.write(err); if (out) process.stdout.write(out); process.exitCode = code; };
  for (const a of argv) {
    if (a === '--help' || a === '-h') return stop(0, '', HELP);
    if (a === '--json') json = true;
    else if (a.startsWith('--')) return stop(64, `unknown flag ${a}\n${HELP}`);
    else paths.push(a);
  }
  if (paths.length === 0) return stop(64, HELP);
  const missing = paths.filter((p) => { try { statSync(p); return false; } catch { return true; } });
  if (missing.length) return stop(2, `no such path: ${missing.join(', ')}\n`);
  const r = lint(paths);
  if (!r) return stop(2, `no .html or .css under ${paths.join(', ')}\n`);
  return stop(0, '', json ? `${JSON.stringify(r, null, 2)}\n` : `${render(r)}\n`);
}

if (import.meta.url === pathToFileURL(process.argv[1] || '').href) {
  try { main(process.argv.slice(2)); } catch (e) {
    process.stderr.write(`family-lint.mjs crashed: ${e && e.stack ? e.stack : e}\n`);
    process.exitCode = 3;
  }
}
