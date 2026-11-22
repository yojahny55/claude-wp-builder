#!/usr/bin/env node
/**
 * demo-sections.mjs: list the sections a demo declares, without initializing anything.
 *
 * Reads the section delimiters of demo/*.html (or one page) and prints, per page, each
 * section's name, the slug /wp-section takes, its line range and whether the theme already
 * has its template part. It also reports the delimiter defects that make /wp-init, /wp-section
 * and /wp-yolo misread a demo: a section opened and never closed, an END with no open section
 * or with another section's name, a section opened inside another, a name used twice on one
 * page, and a page with no delimiters at all.
 *
 * Read-only: it writes nothing, runs no WP-CLI and touches no network.
 *
 * Both delimiter forms are read:
 *   <!-- ============ SECTION: Hero ============ -->  ...  <!-- ============ END SECTION: Hero ============ -->
 *   <!-- SECTION: scene-1 -->  ...  <!-- END SECTION -->      (cinematic demos: END may carry no name)
 *
 * Exit codes: 0 sections listed and no delimiter defect, 1 a delimiter defect was found,
 * 2 nothing to read (no demo/ directory, no such page, or no .html in it), 3 crash, 64 usage.
 */
import './lib/stdio-blocking.mjs';
import { readFileSync, existsSync, statSync, readdirSync } from 'node:fs';
import { join, resolve, basename } from 'node:path';
import { pathToFileURL } from 'node:url';

const HELP = `usage: demo-sections.mjs [<project-path>] [--page <slug>] [--json] [--help]

Lists the sections declared by the delimiters in <project-path>/demo/*.html (or only
demo/<slug>.html with --page), with the /wp-section slug, line range and whether the theme's
template-parts/section-<slug>.php exists. Read-only.
Exit 0 listed with no delimiter defect, 1 a delimiter defect, 2 nothing to read, 3 crash, 64 usage.
`;

// Exit codes are set through process.exitCode, never forced with process.exit(): a forced exit
// right after a write to a pipe drops whatever the pipe has not taken yet (64 KiB), so a large
// --json listing would reach its reader cut short. Bad usage throws, and the entry point sets 64.
class UsageError extends Error {}
function usage(msg) {
  throw new UsageError(msg);
}

const isFile = (p) => { try { return statSync(p).isFile(); } catch { return false; } };
const isDir = (p) => { try { return statSync(p).isDirectory(); } catch { return false; } };

// The section name -> the first argument /wp-section takes and the template part's suffix.
export function slugify(name) {
  return name.toLowerCase().normalize('NFKD').replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
}

// One delimiter comment. Group 1 = "END" when closing, group 2 = the name (may be empty on END).
// An opening delimiter needs its colon, so a prose comment such as <!-- Section intro --> is not one.
const DELIM = /<!--\s*=*\s*(?:(END)\s+SECTION\b\s*:?|SECTION\s*:)\s*(.*?)\s*=*\s*-->/gi;

// Header and footer are delimited like any section but built by their own commands.
const OWNERS = new Map([['header', '/wp-header'], ['footer', '/wp-footer']]);

export function parsePage(html) {
  const sections = [];
  const problems = [];
  const lineAt = (idx) => html.slice(0, idx).split('\n').length;
  let open = null;
  const seen = new Map();
  for (const m of html.matchAll(DELIM)) {
    const line = lineAt(m.index);
    const isEnd = Boolean(m[1]);
    const name = m[2].trim();
    if (!isEnd) {
      if (!name) { problems.push(`line ${line}: SECTION delimiter with no name`); continue; }
      if (open) {
        problems.push(`line ${line}: "${name}" opens inside "${open.name}" (opened at line ${open.start}, not closed yet)`);
        sections.push({ ...open, end: null });
      }
      // Two names that slug alike build the same template part, so the slug is the identity.
      const slug = slugify(name);
      if (!slug) problems.push(`line ${line}: "${name}" has no usable slug: name it with ASCII letters or digits`);
      else if (seen.has(slug)) {
        const first = seen.get(slug);
        problems.push(`line ${line}: "${name}" is declared twice on this page (same slug "${slug}" as "${first.name}" at line ${first.line})`);
      } else seen.set(slug, { name, line });
      open = { name, slug, start: line, end: null };
      continue;
    }
    if (!open) { problems.push(`line ${line}: END SECTION${name ? ` "${name}"` : ''} closes no open section`); continue; }
    if (name && name.toLowerCase() !== open.name.toLowerCase()) {
      problems.push(`line ${line}: END SECTION "${name}" closes "${open.name}" (opened at line ${open.start})`);
    }
    sections.push({ ...open, end: line });
    open = null;
  }
  if (open) {
    problems.push(`line ${open.start}: "${open.name}" is never closed`);
    sections.push({ ...open, end: null });
  }
  if (sections.length === 0 && problems.length === 0) problems.push('no section delimiters: run /wp-polish on this page');
  return { sections, problems };
}

function themeDir(root) {
  try {
    const m = JSON.parse(readFileSync(join(root, '.wp-create.json'), 'utf8'));
    const slug = m && m.theme && m.theme.slug;
    if (typeof slug !== 'string' || !/^[a-z0-9][a-z0-9_-]*$/i.test(slug)) return null;
    const dir = join(root, 'wp-content', 'themes', slug);
    return isDir(dir) ? dir : null;
  } catch { return null; }
}

export function collect(root, page) {
  const demoDir = join(root, 'demo');
  if (!isDir(demoDir)) return { error: `no demo/ directory in ${root}` };
  let files;
  if (page) {
    const f = join(demoDir, `${page}.html`);
    if (!isFile(f)) return { error: `no demo/${page}.html` };
    files = [f];
  } else {
    // index first, then the rest in name order: the order /wp-init and /wp-yolo read them.
    files = readdirSync(demoDir).filter((n) => n.endsWith('.html') && isFile(join(demoDir, n))).sort((a, b) =>
      (a === 'index.html' ? -1 : b === 'index.html' ? 1 : a.localeCompare(b))).map((n) => join(demoDir, n));
    if (files.length === 0) return { error: 'demo/ holds no .html page' };
  }
  const theme = themeDir(root);
  const pages = files.map((f) => {
    const { sections, problems } = parsePage(readFileSync(f, 'utf8'));
    for (const s of sections) {
      const owner = OWNERS.get(s.slug);
      if (owner) { s.built = null; s.owner = owner; continue; }
      s.built = theme ? isFile(join(theme, 'template-parts', `section-${s.slug}.php`)) : null;
    }
    return { page: basename(f, '.html'), file: `demo/${basename(f)}`, sections, problems };
  });
  return { project: root, theme, pages, defects: pages.reduce((n, p) => n + p.problems.length, 0) };
}

export function render(r) {
  const L = [];
  L.push(`Theme: ${r.theme ? r.theme : 'none found (built column is "?")'}`);
  for (const p of r.pages) {
    L.push('', `${p.file} (${p.sections.length} section${p.sections.length === 1 ? '' : 's'})`);
    for (const s of p.sections) {
      const lines = s.end ? `${s.start}-${s.end}` : `${s.start}-?`;
      const built = s.owner ? `by ${s.owner}` : s.built === null ? '?' : s.built ? 'built' : 'not built';
      L.push(`  ${s.name.padEnd(24)} ${s.slug.padEnd(20)} lines ${lines.padEnd(10)} ${built}`);
    }
    for (const pr of p.problems) L.push(`  DEFECT ${pr}`);
  }
  L.push('', r.defects ? `${r.defects} delimiter defect${r.defects === 1 ? '' : 's'}: fix them (or run /wp-polish) before /wp-init, /wp-section or /wp-yolo.` : 'No delimiter defects.');
  return L.join('\n');
}

function main(argv) {
  let root = null; let page = null; let json = false;
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--help' || a === '-h') { process.stdout.write(HELP); process.exitCode = 0; return; }
    else if (a === '--json') json = true;
    else if (a === '--page') {
      page = argv[++i];
      if (!page || page.startsWith('--')) usage('--page needs a slug');
      if (!/^[A-Za-z0-9_.-]+$/.test(page)) usage(`--page takes a page slug, found ${JSON.stringify(page)}`);
      page = page.replace(/\.html$/, '');
    } else if (a.startsWith('--')) usage(`unknown flag ${a}`);
    else if (root === null) root = a;
    else usage(`unexpected argument ${a}`);
  }
  root = resolve(root || '.');
  if (!isDir(root)) usage(`${root} is not a directory`);
  const r = collect(root, page);
  if (r.error) {
    if (json) process.stdout.write(`${JSON.stringify({ project: root, error: r.error })}\n`);
    else process.stderr.write(`${r.error}\n`);
    process.exitCode = 2;
    return;
  }
  process.stdout.write(json ? `${JSON.stringify(r, null, 2)}\n` : `${render(r)}\n`);
  process.exitCode = r.defects ? 1 : 0;
}

if (import.meta.url === pathToFileURL(process.argv[1] || '').href) {
  try { main(process.argv.slice(2)); } catch (e) {
    if (e instanceof UsageError) {
      process.stderr.write(`${e.message}\n${HELP}`);
      process.exitCode = 64;
    } else {
      process.stderr.write(`demo-sections.mjs crashed: ${e && e.stack ? e.stack : e}\n`);
      process.exitCode = 3;
    }
  }
}
