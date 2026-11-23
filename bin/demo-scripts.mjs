#!/usr/bin/env node
/**
 * demo-scripts.mjs: print the inline JavaScript of a demo page, and only that.
 *
 * /wp-section Step 6.4 asks whether any script of the demo touches the section it builds.
 * A grep over the page itself cannot answer: the section's own markup always names its
 * classes, and a line-range extraction (`sed '/<script/,/<\/script>/'`) that meets a one-line
 * `<script src="..."></script>` keeps printing markup until the next closing tag.
 *
 * This reads the page, drops HTML comments, and keeps each `<script>` element that has no
 * `src` attribute and whose `type` is JavaScript (absent, `module`, or a JavaScript MIME
 * type): JSON-LD, templates and import maps are not behaviour. It prints each kept body
 * after a `// inline script <n>, line <l>` header. With `--match <regex>` (a JavaScript
 * regular expression) it prints only the bodies that match.
 *
 * Read-only: it writes nothing and touches no network.
 *
 * Exit codes (COMMON scheme): 0 at least one script printed, 1 no inline script (or none
 * matching --match), 2 the page could not be read, 3 crash, 64 usage.
 */
import './lib/stdio-blocking.mjs';
import { readFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

const HELP = `usage: demo-scripts.mjs <page.html> [--match <regex>] [--help]

Prints the body of every inline JavaScript <script> of <page.html> (no src, not JSON-LD or a
template), each after a "// inline script <n>, line <l>" header. --match keeps only the bodies
that match the JavaScript regular expression. Read-only.
Exit 0 printed, 1 none (or none matching), 2 unreadable page, 3 crash, 64 usage.
`;

const JS_TYPES = new Set([
  '',
  'module',
  'text/javascript',
  'application/javascript',
  'text/ecmascript',
  'application/ecmascript',
  'text/jscript',
]);

/** Inline JavaScript scripts of an HTML string: [{ line, body }]. */
export function inlineScripts(html) {
  // Blank comments out instead of deleting them, so line numbers stay true.
  const text = html.replace(/<!--[\s\S]*?-->/g, (c) => c.replace(/[^\n]/g, ' '));
  const out = [];
  const re = /<script\b([^>]*)>([\s\S]*?)<\/script\s*>/gi;
  let m;
  while ((m = re.exec(text)) !== null) {
    const attrs = m[1];
    if (/(?:^|\s)src\s*=/i.test(attrs)) continue;
    const type = (attrs.match(/(?:^|\s)type\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))/i) || [])
      .slice(1)
      .find((v) => v !== undefined);
    if (!JS_TYPES.has((type || '').trim().toLowerCase())) continue;
    const body = m[2];
    if (body.trim() === '') continue;
    const line = text.slice(0, m.index).split('\n').length;
    out.push({ line, body });
  }
  return out;
}

class UsageError extends Error {}

function parseArgs(argv) {
  const opts = { page: null, match: null, help: false };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--help' || a === '-h') opts.help = true;
    else if (a === '--match') {
      if (i + 1 >= argv.length) throw new UsageError('--match needs a regex');
      opts.match = argv[++i];
    } else if (a.startsWith('--')) throw new UsageError(`unknown option ${a}`);
    else if (opts.page === null) opts.page = a;
    else throw new UsageError(`unexpected argument ${a}`);
  }
  if (!opts.help && opts.page === null) throw new UsageError('missing <page.html>');
  return opts;
}

function main(argv) {
  let opts;
  try {
    opts = parseArgs(argv);
  } catch (e) {
    if (!(e instanceof UsageError)) throw e;
    process.stderr.write(`demo-scripts: ${e.message}\n${HELP}`);
    process.exitCode = 64;
    return;
  }
  if (opts.help) {
    process.stdout.write(HELP);
    process.exitCode = 0;
    return;
  }
  let re = null;
  if (opts.match !== null) {
    try {
      re = new RegExp(opts.match);
    } catch (e) {
      process.stderr.write(`demo-scripts: invalid --match regex: ${e.message}\n`);
      process.exitCode = 64;
      return;
    }
  }
  let html;
  try {
    html = readFileSync(opts.page, 'utf8');
  } catch (e) {
    process.stderr.write(`demo-scripts: cannot read ${opts.page}: ${e.code || e.message}\n`);
    process.exitCode = 2;
    return;
  }
  const kept = inlineScripts(html).filter((s) => re === null || re.test(s.body));
  kept.forEach((s, i) => {
    process.stdout.write(`// inline script ${i + 1}, line ${s.line}\n${s.body.replace(/\n?$/, '\n')}`);
  });
  process.exitCode = kept.length > 0 ? 0 : 1;
}

if (import.meta.url === pathToFileURL(process.argv[1] || '').href) {
  try {
    main(process.argv.slice(2));
  } catch (e) {
    process.stderr.write(`demo-scripts: ${e.stack || e}\n`);
    process.exitCode = 3;
  }
}
