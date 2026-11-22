#!/usr/bin/env node
/**
 * contrast-propose.mjs: the nearest compliant shade for each failing colour pair, with the
 * ratio before and after, as a table to put in front of the client.
 *
 * A contrast failure is a palette decision, not a code fix: nothing here edits a site. The
 * audit lists the pairs, this tool computes the proposal, and the client approves it before
 * any colour is changed.
 *
 *   node bin/contrast-propose.mjs --pair '#d85c33:#ffffff' --pair '#ffffff:#ff844d:4.5' [--json]
 *   node bin/contrast-propose.mjs --axe axe.json     # [{fg, bg, ratio?, need?, target?, text?, page?}, ...]
 *
 * Each pair is foreground:background[:required ratio] (default 4.5; use 3 for large text and
 * non-text UI). For each pair it moves ONE side, the one that keeps the colour closest to
 * the original (the foreground when it was text on a light ground, the background when it is
 * white text on a coloured fill, whichever is nearer), by changing lightness only so hue and
 * saturation stay recognisable. Failing pairs that share a colour and a requirement are
 * grouped, with how many nodes and which texts/pages use them.
 *
 * Colours: #rgb, #rgba, #rrggbb, #rrggbbaa (what axe emits for a translucent colour) and
 * rgb()/rgba(). A translucent background is flattened onto white, then a translucent
 * foreground onto that background; the proposal is always an opaque #rrggbb. Bad or missing
 * input is a one-line error and exit 2, never a stack. A `--pair` needs a ratio that is empty
 * (4.5) or above 1; an unknown argument is exit 2; an unreadable colour in a `--axe` node is
 * skipped with a WARN on stderr.
 */
import fs from 'node:fs';

class InputError extends Error {}
// Colours as axe, a stylesheet or a client write them: #rgb, #rgba, #rrggbb, #rrggbbaa,
// rgb()/rgba() with commas or spaces, channels as numbers or percentages, alpha after `,` or `/`.
// Returns [r, g, b, a].
function parseColor(input) {
    const v = String(input ?? '').trim().toLowerCase();
    let m = v.match(/^#([0-9a-f]{3,4}|[0-9a-f]{6}|[0-9a-f]{8})$/);
    if (m) {
        let h = m[1];
        if (h.length <= 4) h = [...h].map((c) => c + c).join('');
        const [r, g, b, a = 255] = [0, 2, 4, 6].slice(0, h.length / 2).map((i) => parseInt(h.slice(i, i + 2), 16));
        return [r, g, b, a / 255];
    }
    m = v.match(/^rgba?\(\s*([^)]*)\)$/);
    if (m) {
        const parts = m[1].split(/\s*[,/]\s*|\s+/).filter(Boolean);
        const num = (x, full) => (x.endsWith('%') ? (parseFloat(x) / 100) * full : parseFloat(x));
        if ((parts.length === 3 || parts.length === 4) && parts.every((x) => /^[+-]?(\d+\.?\d*|\.\d+)%?$/.test(x))) {
            const [r, g, b] = parts.slice(0, 3).map((x) => Math.min(255, Math.max(0, num(x, 255))));
            const a = parts[3] === undefined ? 1 : Math.min(1, Math.max(0, num(parts[3], 1)));
            return [r, g, b, a];
        }
    }
    throw new InputError(`cannot read colour "${input}" (use #rgb, #rrggbb, #rrggbbaa, rgb() or rgba())`);
}
// Alpha: a translucent background is flattened onto white (the page), then a translucent
// foreground onto that background, which is how the browser paints the pair. The proposal
// is always an opaque #rrggbb: it replaces the flattened colour, never the alpha.
const flatten = (top, under) => [0, 1, 2].map((i) => top[i] * top[3] + under[i] * (1 - top[3]));
const resolvePair = (fg, bg) => {
    const B = flatten(parseColor(bg), [255, 255, 255]);
    return { F: flatten(parseColor(fg), B), B };
};
const toHex = (rgb) => '#' + rgb.map((v) => Math.round(v).toString(16).padStart(2, '0')).join('');
const lin = (v) => { v /= 255; return v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4; };
const lum = ([r, g, b]) => 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b);
const ratio = (a, b) => { const [x, y] = [lum(a), lum(b)].sort((p, q) => q - p); return (x + 0.05) / (y + 0.05); };
function rgb2hsl([r, g, b]) {
    r /= 255; g /= 255; b /= 255;
    const mx = Math.max(r, g, b), mn = Math.min(r, g, b), l = (mx + mn) / 2, d = mx - mn;
    if (!d) return [0, 0, l];
    const s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn);
    const h = mx === r ? ((g - b) / d + (g < b ? 6 : 0)) : mx === g ? (b - r) / d + 2 : (r - g) / d + 4;
    return [h / 6, s, l];
}
function hsl2rgb([h, s, l]) {
    const f = (p, q, t) => { t = (t + 1) % 1; return t < 1 / 6 ? p + (q - p) * 6 * t : t < 1 / 2 ? q : t < 2 / 3 ? p + (q - p) * (2 / 3 - t) * 6 : p; };
    if (!s) return [l * 255, l * 255, l * 255];
    const q = l < 0.5 ? l * (1 + s) : l + s - l * s, p = 2 * l - q;
    return [f(p, q, h + 1 / 3), f(p, q, h), f(p, q, h - 1 / 3)].map((v) => v * 255);
}
// Move lightness toward black or white, in 0.1% steps, until the pair reaches `need`.
function nearest(move, score, need) {
    const [h, s, l] = rgb2hsl(move);
    let best = null;
    for (const dir of [-1, 1]) {
        for (let i = 1; i <= 1000; i++) {
            const nl = l + dir * i / 1000;
            if (nl < 0 || nl > 1) break;
            const c = hsl2rgb([h, s, nl]).map(Math.round); // test the colour that ships, not the float
            if (score(c) >= need) { if (!best || i < best.steps) best = { rgb: c, steps: i }; break; }
        }
    }
    return best && best.rgb;
}
function propose(fg, bg, need) {
    const { F, B } = resolvePair(fg, bg);
    const before = ratio(F, B);
    if (before >= need) return { fg, bg, need, before, ok: true };
    // The foreground is replaced by an opaque colour; the background is replaced by an opaque
    // colour under which a translucent foreground is composited again, so both candidates are
    // scored the way the final pair will be.
    const fgRgba = parseColor(fg);
    const nf = nearest(F, (c) => ratio(c, B), need), nb = nearest(B, (c) => ratio(flatten(fgRgba, c), c), need);
    const dist = (a, b) => Math.abs(rgb2hsl(a)[2] - rgb2hsl(b)[2]);
    const useFg = nf && (!nb || dist(nf, F) <= dist(nb, B));
    const pick = useFg ? nf : nb;
    if (!pick) return { fg, bg, need, before, ok: false };
    const nfg = useFg ? toHex(pick) : fg, nbg = useFg ? bg : toHex(pick);
    return { fg, bg, need, before, ok: false, changes: useFg ? 'fg' : 'bg', newFg: nfg, newBg: nbg, after: (() => { const r = resolvePair(nfg, nbg); return ratio(r.F, r.B); })() };
}

const USAGE = 'usage: contrast-propose.mjs --pair fg:bg[:need] ... | --axe file.json [--json]';
const die = (why) => { console.error(`ERROR: ${why}\n${USAGE}`); process.exit(2); };
const argv = process.argv.slice(2);
const rows = [];
const value = (i) => { const v = argv[i + 1]; if (v === undefined || v.startsWith('--')) die(`${argv[i]} needs a value`); return v; };
for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--json') continue;
    if (argv[i] === '--pair') {
        const spec = value(i); i++;
        const parts = spec.split(':');
        if (parts.length < 2 || parts.length > 3 || !parts[0] || !parts[1]) die(`bad --pair "${spec}": expected foreground:background[:need]`);
        const need = parts[2] === undefined || parts[2] === '' ? 4.5 : Number(parts[2]);
        if (!(need > 1)) die(`bad --pair "${spec}": the required ratio must be empty (4.5) or a number above 1`);
        try { parseColor(parts[0]); parseColor(parts[1]); } catch (e) { if (e instanceof InputError) die(e.message); throw e; }
        rows.push({ fg: parts[0], bg: parts[1], need });
    } else if (argv[i] === '--axe') {
        const file = value(i); i++;
        let raw;
        try { raw = JSON.parse(fs.readFileSync(file, 'utf8')); } catch (e) { die(`cannot read ${file}: ${e.message}`); }
        // accepts a flat list, the per-page shape {page, viewport, violations:[...]}, a single such
        // object, or raw axe-core results (violations[id=color-contrast].nodes[].any[].data)
        for (const e of Array.isArray(raw) ? raw : [raw]) for (const v of (e?.violations || [e])) {
            if (v?.fg && v?.bg) { rows.push({ fg: v.fg, bg: v.bg, need: Number(v.need) || 4.5, target: v.target, text: v.text, page: v.page || e.page }); continue; }
            if (v?.id !== 'color-contrast') continue;
            for (const n of v.nodes || []) {
                const d = (n.any || []).map((a) => a.data).find((x) => x && x.fgColor && x.bgColor);
                // axe writes the requirement as a string such as '3:1'
                if (d) rows.push({ fg: d.fgColor, bg: d.bgColor, need: parseFloat(d.expectedContrastRatio) || 4.5, target: (n.target || []).join(' '), text: n.html, page: e.page || e.url });
            }
        }
    } else die(`unknown argument: ${argv[i]}`);
}
// A node with a missing or unreadable colour is skipped with a warning: one odd node in an
// axe report must not discard the rest.
const usable = rows.filter((r) => {
    try { if (typeof r.fg !== 'string' || typeof r.bg !== 'string') throw new InputError(`non-text colour in ${JSON.stringify([r.fg, r.bg])}`); parseColor(r.fg); parseColor(r.bg); return true; }
    catch (e) { if (!(e instanceof InputError)) throw e; console.error(`WARN: skipped ${r.target || r.text || 'a node'}: ${e.message}`); return false; }
});
rows.length = 0; rows.push(...usable);
if (!rows.length) die('no usable colour pairs given');
const groups = new Map();
for (const r of rows) {
    const k = [r.fg.toLowerCase(), r.bg.toLowerCase(), r.need].join('|');
    const g = groups.get(k) || { fg: r.fg.toLowerCase(), bg: r.bg.toLowerCase(), need: r.need, nodes: 0, texts: new Set(), pages: new Set() };
    g.nodes++; if (r.text) g.texts.add(r.text); if (r.page) g.pages.add(r.page);
    groups.set(k, g);
}
let out;
try {
    out = [...groups.values()].map((g) => ({ ...g, ...propose(g.fg, g.bg, g.need), texts: [...g.texts].slice(0, 8), pages: [...g.pages] }));
} catch (e) { if (e instanceof InputError) die(e.message); throw e; }
if (argv.includes('--json')) console.log(JSON.stringify(out, null, 2));
else {
console.log('| Current (text on ground) | Ratio | Needs | Proposed | Ratio | Moves | Nodes | Pages |\n|---|---|---|---|---|---|---|---|');
for (const o of out) {
    console.log(`| ${o.fg} on ${o.bg} | ${o.before.toFixed(2)} | ${o.need} | ${o.ok ? 'passes' : o.newFg ? `${o.newFg} on ${o.newBg}` : 'no shade reaches it'} | ${o.after ? o.after.toFixed(2) : '-'} | ${o.changes || '-'} | ${o.nodes} | ${o.pages.join(', ') || '-'} |`);
}
}
