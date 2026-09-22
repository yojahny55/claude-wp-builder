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
 *      ~/Library/Caches/ms-playwright, %LOCALAPPDATA%\ms-playwright, newest revision first;
 *   3. Chromium only: the system Chrome/Chromium. A system Firefox or Safari cannot be
 *      driven by Playwright (it needs its own patched builds), so they are not candidates.
 *
 * CLI: `node bin/lib/browsers.mjs <chromium|firefox|webkit>` prints the path and exits 0,
 * or prints nothing and exits 2.
 */
import { existsSync, readdirSync } from 'node:fs';
import { join, resolve } from 'node:path';
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

/** Absolute path of an existing executable for `engine`, or null. Never downloads. */
export function findBrowser(engine) {
  const override = process.env['WP_BROWSER_' + engine.toUpperCase()];
  if (override) return existsSync(override) ? override : null;
  // `chromium-1243`, never `chromium_headless_shell-1243`: the shell has no headed mode
  // and a different directory layout.
  const prefix = engine + '-';
  for (const root of cacheRoots()) {
    if (!existsSync(root)) continue;
    const entries = readdirSync(root)
      .filter((e) => e.startsWith(prefix) && /-\d+$/.test(e))
      .sort((a, b) => revision(b) - revision(a));
    for (const entry of entries)
      for (const tail of TAILS[engine] || []) {
        const p = join(root, entry, tail);
        if (existsSync(p)) return p;
      }
  }
  if (engine === 'chromium') for (const p of SYSTEM_CHROMIUM) if (existsSync(p)) return p;
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
