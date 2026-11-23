#!/usr/bin/env node
/**
 * store-layer-check.mjs: verify the demo section of a theme's store.css.
 *
 * /wp-woo-setup installs templates/store/store.css as a fixed base whose last section,
 * `Section: Store demo`, belongs to the project; /wp-yolo's store layer has wp-css write the
 * demo's store styling there. This reads the theme's copy against the template and says
 * whether that section is sound: the base above it untouched, at least one rule written,
 * every selector scoped to a store body class, no !important.
 *
 * Usage: store-layer-check.mjs <template-store.css> <theme-store.css> [--state]
 *
 * It parses the CSS rather than matching lines: comments and strings are skipped, a selector
 * list splits only at commas outside parentheses (`:not(.a, .b)` is one selector), selectors
 * inside @media, @supports, @container, @layer and @scope are checked, and the bodies of
 * @keyframes, @font-face and other at-rules that hold no selectors are not. A rule nested in
 * a rule (CSS nesting) is scoped by its parent.
 *
 * --state prints `STORE LAYER EMPTY` (the section holds no rule: only the placeholder,
 * comments or nothing) or `STORE LAYER WRITTEN`, exit 0, and checks nothing else.
 *
 * Otherwise the last line is one of, exit 0 for the first and 1 for the rest:
 *   STORE LAYER OK
 *   NO STORE CSS                  the theme has no store.css
 *   MARKER MISSING                the theme's copy has no `Section: Store demo` line
 *   BASE CHANGED                  something above the marker differs from the template
 *   NOTHING WRITTEN               the section holds no rule
 *   IMPORTANT USED                a declaration in the section uses !important
 *   UNSCOPED SELECTOR: <sel>      a selector does not start with body.woocommerce
 *   UNBALANCED BRACES             the section does not parse
 *
 * Exit: 0 ok (or --state), 1 a finding above, 64 usage.
 */
import { existsSync, readFileSync } from 'node:fs';
import './lib/stdio-blocking.mjs';

const MARKER = '====== Section: Store demo ======';
const GROUP_AT = new Set(['media', 'supports', 'container', 'layer', 'scope', 'document']);

const args = process.argv.slice(2);
const stateOnly = args.includes('--state');
const files = args.filter((a) => a !== '--state');
if (files.length !== 2 || args.some((a) => a.startsWith('--') && a !== '--state')) {
  process.stderr.write('usage: store-layer-check.mjs <template-store.css> <theme-store.css> [--state]\n');
  process.exit(64);
}
const [tplPath, cssPath] = files;

function finish(line, code) {
  process.stdout.write(`${line}\n`);
  process.exit(code);
}

/** Split at the marker line: [head, tail], tail starting with the marker line; null when absent. */
function split(text) {
  const lines = text.split('\n');
  const at = lines.findIndex((l) => l.includes(MARKER));
  if (at < 0) return null;
  return [lines.slice(0, at).join('\n'), lines.slice(at).join('\n')];
}

/** Drop comments, keeping strings intact. */
function stripComments(css) {
  let out = '';
  for (let i = 0; i < css.length; i++) {
    const c = css[i];
    if (c === '/' && css[i + 1] === '*') {
      const end = css.indexOf('*/', i + 2);
      i = end < 0 ? css.length : end + 1;
      out += ' ';
    } else if (c === '"' || c === "'") {
      let j = i + 1;
      while (j < css.length && css[j] !== c) j += css[j] === '\\' ? 2 : 1;
      out += css.slice(i, j + 1);
      i = j;
    } else {
      out += c;
    }
  }
  return out;
}

/** Split a selector list at top-level commas only. */
function selectors(prelude) {
  const out = [];
  let depth = 0;
  let cur = '';
  for (const c of prelude) {
    if (c === '(' || c === '[') depth++;
    else if (c === ')' || c === ']') depth = Math.max(0, depth - 1);
    if (c === ',' && depth === 0) {
      out.push(cur.trim());
      cur = '';
    } else {
      cur += c;
    }
  }
  out.push(cur.trim());
  return out.filter(Boolean);
}

/** Walk the section: rule count, the first unscoped selector, whether !important is used. */
function analyse(css) {
  const stack = []; // 'group' | 'skip' | 'rule'
  let prelude = '';
  let rules = 0;
  let unscoped = null;
  let important = false;
  for (let i = 0; i < css.length; i++) {
    const c = css[i];
    if (c === '"' || c === "'") {
      let j = i + 1;
      while (j < css.length && css[j] !== c) j += css[j] === '\\' ? 2 : 1;
      prelude += css.slice(i, j + 1);
      i = j;
      continue;
    }
    const top = stack[stack.length - 1];
    if (c === '{') {
      const p = prelude.trim();
      prelude = '';
      if (top === 'skip') { stack.push('skip'); continue; }
      if (top === 'rule') { stack.push('rule'); continue; } // nested rule: scoped by its parent
      const at = /^@([\w-]+)/.exec(p);
      if (at) { stack.push(GROUP_AT.has(at[1].toLowerCase()) ? 'group' : 'skip'); continue; }
      rules++;
      for (const s of selectors(p)) {
        if (!unscoped && !/^body\.woocommerce/.test(s)) unscoped = s.replace(/\s+/g, ' ');
      }
      stack.push('rule');
    } else if (c === '}') {
      if (top === 'rule' && /!\s*important/i.test(prelude)) important = true;
      prelude = '';
      if (!stack.length) return { error: true };
      stack.pop();
    } else if (c === ';') {
      if (top === 'rule' && /!\s*important/i.test(prelude)) important = true;
      prelude = '';
    } else {
      prelude += c;
    }
  }
  if (stack.length) return { error: true };
  return { rules, unscoped, important };
}

if (!existsSync(cssPath)) finish('NO STORE CSS', 1);
const tplParts = split(readFileSync(tplPath, 'utf8'));
if (!tplParts) {
  process.stderr.write(`the template ${tplPath} has no '${MARKER}' line\n`);
  process.exit(64);
}
const parts = split(readFileSync(cssPath, 'utf8'));
if (!parts) finish('MARKER MISSING', 1);
const result = analyse(stripComments(parts[1]));

if (stateOnly) finish(!result.error && result.rules === 0 ? 'STORE LAYER EMPTY' : 'STORE LAYER WRITTEN', 0);
if (parts[0] !== tplParts[0]) finish('BASE CHANGED', 1);
if (result.error) finish('UNBALANCED BRACES', 1);
if (result.rules === 0) finish('NOTHING WRITTEN', 1);
if (result.important) finish('IMPORTANT USED', 1);
if (result.unscoped) finish(`UNSCOPED SELECTOR: ${result.unscoped}`, 1);
finish('STORE LAYER OK', 0);
