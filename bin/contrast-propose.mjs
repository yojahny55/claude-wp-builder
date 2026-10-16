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
 */
import fs from 'node:fs';

const hex = (h) => { h = h.replace('#', ''); if (h.length === 3) h = [...h].map((c) => c + c).join(''); return [0, 2, 4].map((i) => parseInt(h.slice(i, i + 2), 16)); };
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
function nearest(move, fixed, need) {
    const [h, s, l] = rgb2hsl(move);
    let best = null;
    for (const dir of [-1, 1]) {
        for (let i = 1; i <= 1000; i++) {
            const nl = l + dir * i / 1000;
            if (nl < 0 || nl > 1) break;
            const c = hsl2rgb([h, s, nl]).map(Math.round); // test the colour that ships, not the float
            if (ratio(c, fixed) >= need) { if (!best || i < best.steps) best = { rgb: c, steps: i }; break; }
        }
    }
    return best && best.rgb;
}
function propose(fg, bg, need) {
    const F = hex(fg), B = hex(bg);
    const before = ratio(F, B);
    if (before >= need) return { fg, bg, need, before, ok: true };
    const nf = nearest(F, B, need), nb = nearest(B, F, need);
    const dist = (a, b) => Math.abs(rgb2hsl(a)[2] - rgb2hsl(b)[2]);
    const useFg = nf && (!nb || dist(nf, F) <= dist(nb, B));
    const pick = useFg ? nf : nb;
    if (!pick) return { fg, bg, need, before, ok: false };
    const nfg = useFg ? toHex(pick) : fg, nbg = useFg ? bg : toHex(pick);
    return { fg, bg, need, before, ok: false, changes: useFg ? 'fg' : 'bg', newFg: nfg, newBg: nbg, after: ratio(hex(nfg), hex(nbg)) };
}

const argv = process.argv.slice(2);
const rows = [];
for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--pair') { const [fg, bg, n] = argv[++i].split(':'); rows.push({ fg, bg, need: Number(n) || 4.5 }); }
    else if (argv[i] === '--axe') {
        const raw = JSON.parse(fs.readFileSync(argv[++i], 'utf8'));
        // accepts a flat list, the per-page shape {page, viewport, violations:[...]}, a single such
        // object, or raw axe-core results (violations[id=color-contrast].nodes[].any[].data)
        for (const e of Array.isArray(raw) ? raw : [raw]) for (const v of (e.violations || [e])) {
            if (v.fg && v.bg) { rows.push({ fg: v.fg, bg: v.bg, need: Number(v.need) || 4.5, target: v.target, text: v.text, page: v.page || e.page }); continue; }
            if (v.id !== 'color-contrast') continue;
            for (const n of v.nodes || []) {
                const d = (n.any || []).map((a) => a.data).find((x) => x && x.fgColor && x.bgColor);
                if (d) rows.push({ fg: d.fgColor, bg: d.bgColor, need: Number(d.expectedContrastRatio) || 4.5, target: (n.target || []).join(' '), text: n.html, page: e.page || e.url });
            }
        }
    }
}
if (!rows.length) { console.error('usage: contrast-propose.mjs --pair fg:bg[:need] ... | --axe file.json [--json]'); process.exit(2); }
const groups = new Map();
for (const r of rows) {
    const k = [r.fg.toLowerCase(), r.bg.toLowerCase(), r.need].join('|');
    const g = groups.get(k) || { fg: r.fg.toLowerCase(), bg: r.bg.toLowerCase(), need: r.need, nodes: 0, texts: new Set(), pages: new Set() };
    g.nodes++; if (r.text) g.texts.add(r.text); if (r.page) g.pages.add(r.page);
    groups.set(k, g);
}
const out = [...groups.values()].map((g) => ({ ...g, ...propose(g.fg, g.bg, g.need), texts: [...g.texts].slice(0, 8), pages: [...g.pages] }));
if (argv.includes('--json')) console.log(JSON.stringify(out, null, 2));
else {
console.log('| Current (text on ground) | Ratio | Needs | Proposed | Ratio | Moves | Nodes | Pages |\n|---|---|---|---|---|---|---|---|');
for (const o of out) {
    console.log(`| ${o.fg} on ${o.bg} | ${o.before.toFixed(2)} | ${o.need} | ${o.ok ? 'passes' : o.newFg ? `${o.newFg} on ${o.newBg}` : 'no shade reaches it'} | ${o.after ? o.after.toFixed(2) : '-'} | ${o.changes || '-'} | ${o.nodes} | ${o.pages.join(', ') || '-'} |`);
}
}
