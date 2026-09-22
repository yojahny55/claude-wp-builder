#!/usr/bin/env node
/**
 * browsers.mjs: find a browser executable that is already on this machine.
 *
 * Nothing in this plugin downloads a browser. `playwright install` pulls a build pinned to
 * one Playwright revision, a second copy of something the machine usually has, and on a
 * machine whose policy forbids it the audit died on the install step instead of measuring.
 * Every runner resolves an existing executable here and passes it as `executablePath`;
 * when none exists the caller prints a skip notice and reports the pass unmeasured.
 *
 * Search order per engine:
 *   1. the override variable (WP_BROWSER_CHROMIUM / _FIREFOX / _WEBKIT);
 *   2. Playwright's browser caches: $PLAYWRIGHT_BROWSERS_PATH, ~/.cache/ms-playwright,
 *      ~/Library/Caches/ms-playwright, %LOCALAPPDATA%\ms-playwright. The revision pinned by
 *      the playwright-core that will drive it (its browsers.json) comes first, then the
 *      newest: a Playwright driving a build of another revision can fail to launch or
 *      misbehave. playwright-core is looked up as the runners load it: $PLAYWRIGHT_CORE
 *      alone when set, else from this plugin's bin/, else from the working directory;
 *   3. Chromium only: the system Chrome/Chromium. A system Firefox or Safari cannot be
 *      driven by Playwright (it needs its own patched builds), so they are not candidates.
 *
 * Every resolution logs one line to stderr naming the engine, the executable, its revision
 * and the revision playwright-core pins, so a mismatch shows in the run's output.
 *
 * CLI: `node bin/lib/browsers.mjs <chromium|firefox|webkit>` prints the path on stdout and
 * exits 0, or prints nothing on stdout and exits 2.
 */
import { existsSync, readdirSync, readFileSync, accessSync, constants } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join, resolve } from 'node:path';
import { homedir } from 'node:os';
import { fileURLToPath } from 'node:url';

const win = process.platform === 'win32';

const TAILS = {
  chromium: win
    ? ['chrome-win64\\chrome.exe', 'chrome-win\\chrome.exe']
    : ['chrome-linux64/chrome', 'chrome-linux/chrome', 'chrome-mac/Chromium.app/Contents/MacOS/Chromium',
       'chrome-mac-arm64/Chromium.app/Contents/MacOS/Chromium'],
  firefox: win
    ? ['firefox\\firefox.exe']
    : ['firefox/firefox', 'firefox/Nightly.app/Contents/MacOS/firefox'],
  webkit: win ? ['Playwright.exe'] : ['pw_run.sh'],
};

const SYSTEM_CHROMIUM = win
  ? [
      join(process.env.PROGRAMFILES || 'C:\\Program Files', 'Google\\Chrome\\Application\\chrome.exe'),
      join(process.env['PROGRAMFILES(X86)'] || 'C:\\Program Files (x86)', 'Google\\Chrome\\Application\\chrome.exe'),
    ]
  : [
      '/usr/bin/chromium',
      '/usr/bin/chromium-browser',
      '/usr/bin/google-chrome',
      '/usr/bin/google-chrome-stable',
      '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    ];

export function cacheRoots() {
  const roots = [];
  if (process.env.PLAYWRIGHT_BROWSERS_PATH && process.env.PLAYWRIGHT_BROWSERS_PATH !== '0')
    roots.push(resolve(process.env.PLAYWRIGHT_BROWSERS_PATH));
  if (win) roots.push(join(process.env.LOCALAPPDATA || homedir(), 'ms-playwright'));
  else roots.push(join(homedir(), '.cache/ms-playwright'), join(homedir(), 'Library/Caches/ms-playwright'));
  return [...new Set(roots)];
}

const revision = (entry) => Number((entry.match(/-(\d+)$/) || [])[1] || 0);

/** { dir, revisions: { engine: number } } of the playwright-core that will run, or null. */
export function pinnedRevisions() {
  let dir = null;
  if (process.env.PLAYWRIGHT_CORE) dir = resolve(process.env.PLAYWRIGHT_CORE);
  else
    for (const from of [fileURLToPath(import.meta.url), join(process.cwd(), 'noop.js')]) {
      try {
        dir = dirname(createRequire(from).resolve('playwright-core/package.json'));
        break;
      } catch {}
    }
  if (!dir) return null;
  try {
    const manifest = JSON.parse(readFileSync(join(dir, 'browsers.json'), 'utf8'));
    const revisions = {};
    for (const b of manifest.browsers || []) if (b.name && b.revision) revisions[b.name] = Number(b.revision);
    return { dir, revisions };
  } catch {
    return null;
  }
}

const log = (msg) => process.stderr.write(`browsers: ${msg}\n`);

// A file that exists but lacks the execute bit (a tarball that dropped permissions) fails
// at launch with a bare EACCES; skip it here so the next candidate is tried.
const isExecutable = (p) => {
  try {
    accessSync(p, constants.X_OK);
    return true;
  } catch {
    return false;
  }
};

/** Absolute path of an existing executable for `engine`, or null. Never downloads. */
export function findBrowser(engine) {
  const pins = pinnedRevisions();
  const pinned = pins?.revisions[engine] || 0;
  const wants = pins ? (pinned ? `playwright-core at ${pins.dir} pins ${pinned}` : `playwright-core at ${pins.dir} pins none`) : 'no playwright-core manifest read';
  const override = process.env['WP_BROWSER_' + engine.toUpperCase()];
  if (override) {
    const ok = isExecutable(override);
    log(`${engine} ${ok ? override : 'none'} (WP_BROWSER_${engine.toUpperCase()}${ok ? '' : ' is not an executable file'}; ${wants})`);
    return ok ? override : null;
  }
  // `chromium-1243`, never `chromium_headless_shell-1243`: the shell has no headed mode
  // and a different directory layout.
  const prefix = engine + '-';
  const found = [];
  for (const root of cacheRoots()) {
    if (!existsSync(root)) continue;
    for (const entry of readdirSync(root).filter((e) => e.startsWith(prefix) && /-\d+$/.test(e)))
      for (const tail of TAILS[engine] || []) {
        const p = join(root, entry, tail);
        if (isExecutable(p)) {
          found.push({ p, rev: revision(entry) });
          break;
        }
      }
  }
  // Root order is kept among equal revisions: the sort is stable.
  found.sort((a, b) => (b.rev === pinned) - (a.rev === pinned) || b.rev - a.rev);
  if (found.length) {
    const { p, rev } = found[0];
    const why = rev === pinned ? 'the pinned revision' : pinned ? `MISMATCH, ${pinned} is not cached, newest used` : 'newest cached';
    log(`${engine} ${p} (revision ${rev}, ${why}; ${wants})`);
    return p;
  }
  if (engine === 'chromium')
    for (const p of SYSTEM_CHROMIUM)
      if (isExecutable(p)) {
        log(`${engine} ${p} (system build, no cached revision; ${wants})`);
        return p;
      }
  log(`${engine} none (${wants}; nothing is downloaded)`);
  return null;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const engine = process.argv[2];
  if (!TAILS[engine]) {
    console.error('usage: browsers.mjs <chromium|firefox|webkit>');
    process.exit(1);
  }
  const p = findBrowser(engine);
  if (!p) process.exit(2);
  console.log(p);
}
