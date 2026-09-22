#!/usr/bin/env node
/**
 * theme-template-check.mjs: static checks over a theme's PHP that no build step fails on.
 *
 * Each rule below is a defect that shipped on a real build because nothing refused it:
 *
 *   abspath  Every theme PHP file carries the quoted `defined( 'ABSPATH' )` guard. The
 *            agents already required it, including in inc/seed/*.php, and sixteen seed
 *            files shipped without it anyway. A contract nobody runs is not a gate.
 *            The unquoted `defined( ABSPATH )` form is a PHP 8 fatal and fails too.
 *
 *   classes  (Tailwind themes with a compiled assets/css/dist/*.css) Every class token
 *            that looks like a Tailwind utility must exist as a selector in the compiled
 *            CSS. A template carried `group-aria-[expanded=&quot;false&quot;]:rotate-90`:
 *            an HTML entity inside an arbitrary variant, which Tailwind cannot match, so
 *            it emitted nothing and the icon never rotated. Nobody noticed, because a
 *            missing utility is silent. Two failures:
 *              - an HTML entity (`&quot;`, `&#39;`) inside a class token, always;
 *              - a utility-shaped token (a `variant:`, an `[arbitrary]` value, or a known
 *                utility prefix with a Tailwind-shaped value) absent from dist/*.css.
 *            BEM and component classes (`card__title`, `btn--primary`), `js-*` hooks and
 *            plain words are not utility-shaped and are ignored. A token built at runtime
 *            (`card--<?php echo $x; ?>`, `' . $class . '`) cannot be checked statically:
 *            it is listed as CANNOT VERIFY and never fails the run.
 *
 *   widgets  Markup that needs a script ships with it: `role="tab"` needs the tabs
 *            module, an accordion trigger (`data-accordion-trigger`) the accordion one,
 *            and a `data-directory` filter bar the directory-filter one, each imported
 *            from assets/js/src/index.js. A build's tabs once moved only the underline
 *            marker and never switched a panel.
 *
 * usage:
 *   theme-template-check.mjs <theme-dir> [--rule abspath|classes|widgets]...
 *
 * exit 0 = PASS (CANNOT VERIFY and SKIP lines are information), 1 = FAIL, 2 = usage.
 */
import { readFileSync, readdirSync, existsSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';

const args = process.argv.slice(2);
const theme = args.find((a, i) => !a.startsWith('--') && args[i - 1] !== '--rule');
if (!theme || !existsSync(theme) || !statSync(theme).isDirectory()) {
  console.error('usage: theme-template-check.mjs <theme-dir> [--rule abspath|classes|widgets]...');
  process.exit(2);
}
const ALL = ['abspath', 'classes', 'widgets'];
const picked = args.flatMap((a, i) => (args[i - 1] === '--rule' ? [a] : []));
for (const r of picked) {
  if (!ALL.includes(r)) {
    console.error(`unknown rule: ${r}`);
    process.exit(2);
  }
}
const rules = picked.length ? picked : ALL;

const SKIP_DIRS = new Set(['node_modules', 'vendor', '.git', '.codebase-memory']);
function walk(dir, ext, out = []) {
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    if (e.isDirectory()) {
      if (!SKIP_DIRS.has(e.name)) walk(join(dir, e.name), ext, out);
    } else if (e.name.endsWith(ext)) {
      out.push(join(dir, e.name));
    }
  }
  return out;
}

// `*.asset.php` is written by @wordpress/scripts on every build (a bare `return array()`),
// so it is neither a template nor a file anyone can keep a guard in.
const phpFiles = walk(theme, '.php').filter((f) => !f.endsWith('.asset.php')).sort();
const rel = (f) => relative(theme, f);
const lineAt = (text, idx) => text.slice(0, idx).split('\n').length;
let failures = 0;
const fail = (msg) => {
  failures++;
  console.log(`FAIL: ${msg}`);
};

// ── abspath ──────────────────────────────────────────────────────────────────
if (rules.includes('abspath')) {
  const quoted = /defined\s*\(\s*(['"])ABSPATH\1\s*\)/;
  const unquoted = /defined\s*\(\s*ABSPATH\s*\)/;
  for (const f of phpFiles) {
    const src = readFileSync(f, 'utf8');
    const m = unquoted.exec(src);
    if (m) {
      fail(`${rel(f)}:${lineAt(src, m.index)}: unquoted defined( ABSPATH ) is a PHP 8 fatal; quote the constant`);
    } else if (!quoted.test(src.split('\n').slice(0, 60).join('\n'))) {
      fail(`${rel(f)}: no defined( 'ABSPATH' ) guard in its first 60 lines`);
    }
  }
}

// ── classes ──────────────────────────────────────────────────────────────────
const DYN = '\u0000';
const ENTITY = /&(?:[a-zA-Z][a-zA-Z0-9]*|#\d+|#x[0-9a-fA-F]+);/;

function unescapeCssIdent(s) {
  return s
    .replace(/\\([0-9a-fA-F]{1,6})[ \t\n]?/g, (_, h) => String.fromCodePoint(parseInt(h, 16)))
    .replace(/\\(.)/g, '$1');
}

function compiledClasses(distFiles) {
  const set = new Set();
  const re = /\.((?:[_a-zA-Z0-9\u00a0-\uffff-]|\\[0-9a-fA-F]{1,6}[ \t\n]?|\\[^\n0-9a-fA-F])+)/g;
  for (const f of distFiles) {
    const css = readFileSync(f, 'utf8');
    let m;
    while ((m = re.exec(css))) set.add(unescapeCssIdent(m[1]));
  }
  return set;
}

// Theme token names (`--color-brand`, `--font-display`) make `bg-brand` / `font-display`
// utility-shaped; without them a project colour could never be checked.
function themeTokens(cssFiles) {
  const names = new Set();
  for (const f of cssFiles) {
    const css = readFileSync(f, 'utf8');
    for (const m of css.matchAll(/--(?:color|font|text|spacing|radius|shadow|breakpoint)-([a-zA-Z0-9-]+)\s*:/g)) {
      names.add(m[1]);
    }
  }
  return names;
}

// Same families as bin/tailwind-native-check.sh rule 6, widened to the prefixes a
// converted template actually carries.
const BARE = new Set(('flex grid block hidden contents sticky absolute relative fixed static truncate italic ' +
  'underline uppercase lowercase capitalize container inline inline-block inline-flex inline-grid sr-only ' +
  'not-sr-only visible invisible rounded border shadow grow shrink transition prose antialiased isolate').split(' '));
const PFX = ('px py pt pb pl pr ps pe p mx my mt mb ml mr ms me m -mx -my -mt -mb -ml -mr -m gap space text bg border ' +
  'rounded shadow font leading tracking w h size min-w min-h max-w max-h inset inset-x inset-y top left right ' +
  'bottom -top -left -right -bottom z opacity items justify self col row aspect object overflow cursor ' +
  'transition duration ease delay animate scale rotate -rotate translate-x translate-y -translate-x ' +
  '-translate-y order basis grow shrink divide ring outline fill stroke list whitespace break align place ' +
  'content backdrop blur from via to line-clamp columns scroll snap decoration underline-offset indent ' +
  'drop-shadow grayscale flex grid').split(' ').sort((a, b) => b.length - a.length);
const VALUE_WORDS = ('px auto full screen svh dvh lvh min max fit none xs sm md lg xl 2xl 3xl 4xl 5xl 6xl 7xl ' +
  'center left right start end between around evenly stretch baseline wrap nowrap hidden visible scroll ' +
  'clip cols rows col row transparent current inherit white black bold semibold medium light normal ' +
  'extrabold thin tight snug relaxed loose wide wider widest square video cover contain x y t b l r s e ' +
  'solid dashed dotted double pointer default mono sans serif first last inside outside disc decimal ' +
  'balance pretty ellipsis spin ping pulse bounce').split(' ');
const PALETTE = /^(slate|gray|zinc|neutral|stone|red|orange|amber|yellow|lime|green|emerald|teal|cyan|sky|blue|indigo|violet|purple|fuchsia|pink|rose)-\d/;

function utilityShaped(token, tokens) {
  if (token.includes(':') || token.includes('[')) return true;
  const t = token.replace(/^!|!$/g, '');
  if (BARE.has(t)) return true;
  for (const p of PFX) {
    if (!t.startsWith(p + '-')) continue;
    const v = t.slice(p.length + 1);
    const head = v.split('-')[0].split('/')[0];
    return /^[\d(]/.test(v) || VALUE_WORDS.includes(head) || PALETTE.test(v) || tokens.has(v) || tokens.has(head);
  }
  return false;
}

// Class attribute values, with their line. PHP islands in the HTML become DYN (padded
// with the newlines they held, so line numbers stay true); markup inside PHP strings is
// read from the PHP itself, where a value that breaks out of its string literal
// (`class="a ' . $b . '"`) is literal up to the break and dynamic after it.
function classValues(src) {
  const out = [];
  const islands = [];
  const html = src.replace(/<\?(?:php|=)?[\s\S]*?(?:\?>|$)/g, (block) => {
    islands.push(block);
    return DYN + '\n'.repeat((block.match(/\n/g) || []).length);
  });
  for (const m of html.matchAll(/(?<![\w-])class\s*=\s*(?:"([^"]*)"|'([^']*)')/g)) {
    out.push({ value: m[1] ?? m[2], line: lineAt(html, m.index) });
  }
  let offset = 0;
  for (const block of islands) {
    const start = src.indexOf(block, offset);
    offset = start + block.length;
    const patterns = [/(?<![\w-])class\s*=\s*\\?"([^"\\]*)/g, /['"]class['"]\s*=>\s*'([^']*)'/g];
    for (const re of patterns) {
      for (const m of block.matchAll(re)) {
        let v = m[1];
        const brk = v.search(/'|\{\$|\$/);
        if (brk !== -1) v = v.slice(0, brk) + DYN;
        out.push({ value: v, line: lineAt(src, start + m.index) });
      }
    }
  }
  return out;
}

if (rules.includes('classes')) {
  const distDir = join(theme, 'assets/css/dist');
  const dist = existsSync(distDir) ? walk(distDir, '.css') : [];
  if (!dist.length) {
    console.log('SKIP classes: no compiled assets/css/dist/*.css (not a Tailwind theme, or not built yet: run npm run build)');
  } else {
    const compiled = compiledClasses(dist);
    const srcDir = join(theme, 'assets/css/src');
    const tokens = themeTokens(existsSync(srcDir) ? walk(srcDir, '.css') : dist);
    let unverifiable = 0;
    for (const f of phpFiles) {
      const src = readFileSync(f, 'utf8');
      for (const { value, line } of classValues(src)) {
        for (const token of value.split(/\s+/).filter(Boolean)) {
          const where = `${rel(f)}:${line}`;
          if (ENTITY.test(token)) {
            fail(`${where}: HTML entity inside class token "${token}" (Tailwind matches the raw text, so it emits nothing; write the literal character)`);
            continue;
          }
          if (token.includes(DYN)) {
            unverifiable++;
            // A whole-attribute `<?php echo … ?>` is counted; a token only partly built
            // at runtime (`card--<?php … ?>`) is named, since its literal half is a guess.
            if (token !== DYN) console.log(`CANNOT VERIFY: ${where}: "${token.replace(DYN, '<php>')}" is built at runtime`);
            continue;
          }
          if (token.startsWith('js-') || !utilityShaped(token, tokens)) continue;
          if (!token.includes(':') && !token.includes('[') && /__|--/.test(token)) continue;
          if (!compiled.has(token)) {
            fail(`${where}: "${token}" looks like a Tailwind utility but has no selector in assets/css/dist/*.css (a typo, an unsupported variant, or a stale build)`);
          }
        }
      }
    }
    if (unverifiable) console.log(`classes: ${unverifiable} runtime-built token(s) could not be verified statically`);
  }
}

// ── widgets ──────────────────────────────────────────────────────────────────
if (rules.includes('widgets')) {
  const entry = join(theme, 'assets/js/src/index.js');
  const index = existsSync(entry) ? readFileSync(entry, 'utf8') : '';
  const needs = [
    { name: 'tabs', marker: /role\s*=\s*["']tab["']/, module: /import\s[^;]*['"]\.\/tabs(\.js)?['"]/ },
    { name: 'accordion', marker: /data-accordion-trigger/, module: /import\s[^;]*['"]\.\/accordion(\.js)?['"]/ },
    { name: 'directory-filter', marker: /data-directory[\s>=]/, module: /import\s[^;]*['"]\.\/directory-filter(\.js)?['"]/ },
  ];
  for (const n of needs) {
    const users = phpFiles.filter((f) => n.marker.test(readFileSync(f, 'utf8')));
    if (!users.length) continue;
    if (!n.module.test(index) || !existsSync(join(theme, `assets/js/src/${n.name}.js`))) {
      fail(`${users.map(rel).join(', ')} carry ${n.name} markup but assets/js/src/index.js does not import ./${n.name}.js`);
    }
  }
}

if (failures) {
  console.log(`FAIL: ${failures} finding(s)`);
  process.exit(1);
}
console.log(`PASS: ${rules.join(', ')}`);
