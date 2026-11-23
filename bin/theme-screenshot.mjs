#!/usr/bin/env node
/**
 * theme-screenshot.mjs: write a theme's screenshot.png from the built site's homepage.
 *
 * WordPress shows screenshot.png as the theme's preview in Appearance > Themes, at 1200x900
 * (4:3). The tailwind starter ships a 1x1 placeholder and the cinematic one none, so without
 * this a delivered theme previews as a blank tile. /wp-yolo runs it; /wp-finalize Check 4
 * fails a theme without a real preview and names this command as the fix.
 *
 * Usage: theme-screenshot.mjs <url> <theme-dir> [--force]
 *
 * It keeps an existing screenshot.png that is already a real preview (larger than 1x1)
 * unless --force is given, so a client's own preview image is never replaced by accident.
 * Otherwise it opens <url> at a 1200x900 viewport in an existing Chrome (nothing is
 * downloaded), with reduced motion so entrance animations are settled, waits for the network
 * and the fonts, captures the first screen, and writes it through a temporary file renamed
 * into place.
 *
 * Exit: 0 written or kept (the last line says which), 1 the page or the write failed (the old
 * file is untouched), 2 no playwright-core or no Chrome (nothing measured), 64 usage.
 */
import { existsSync, readFileSync, renameSync, statSync, unlinkSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { execFileSync } from 'node:child_process';
import './lib/stdio-blocking.mjs';
import { findBrowser } from './lib/browsers.mjs';

const WIDTH = 1200;
const HEIGHT = 900;

const argv = process.argv.slice(2);
const force = argv.includes('--force');
const [url, themeDir] = argv.filter((a) => a !== '--force');
if (!url || !themeDir || !/^https?:\/\//.test(url)) {
  console.error('usage: theme-screenshot.mjs <http(s)-url> <theme-dir> [--force]');
  process.exit(64);
}
if (!existsSync(join(themeDir, 'style.css'))) {
  console.error(`theme-screenshot: ${themeDir} has no style.css; pass the theme directory`);
  process.exit(64);
}
const out = join(resolve(themeDir), 'screenshot.png');

/** Width and height from a PNG's IHDR, or null when the file is not a PNG. */
export function pngSize(buf) {
  if (buf.length < 24 || buf.toString('latin1', 1, 4) !== 'PNG' || buf.toString('latin1', 12, 16) !== 'IHDR') return null;
  return { width: buf.readUInt32BE(16), height: buf.readUInt32BE(20) };
}

if (existsSync(out) && !force) {
  const size = pngSize(readFileSync(out));
  if (size && (size.width > 1 || size.height > 1)) {
    console.log(`kept ${out} (${size.width}x${size.height}; --force replaces it)`);
    process.exit(0);
  }
}

// playwright-core: PLAYWRIGHT_CORE, the bare import, the cwd's node_modules, then the global
// root -- the order demo-verify.mjs uses.
let chromium;
try {
  if (process.env.PLAYWRIGHT_CORE) {
    ({ chromium } = await import(pathToFileURL(resolve(process.env.PLAYWRIGHT_CORE, 'index.mjs')).href));
  } else {
    try {
      ({ chromium } = await import('playwright-core'));
    } catch (bare) {
      const cwdEntry = join(process.cwd(), 'node_modules', 'playwright-core', 'index.mjs');
      let entry = existsSync(cwdEntry) ? cwdEntry : '';
      if (!entry) {
        let root = '';
        try {
          root = execFileSync('npm', ['root', '-g'], { encoding: 'utf8', timeout: 5000, stdio: ['ignore', 'pipe', 'ignore'] }).trim();
        } catch { /* no npm: nothing found */ }
        entry = root && [
          join(root, 'playwright-core', 'index.mjs'),
          join(root, '@playwright', 'test', 'node_modules', 'playwright-core', 'index.mjs'),
        ].find((e) => existsSync(e));
      }
      if (!entry) throw bare;
      ({ chromium } = await import(pathToFileURL(entry).href));
    }
  }
} catch {
  console.error('theme-screenshot: playwright-core is not installed; screenshot.png not written');
  process.exit(2);
}
const executablePath = findBrowser('chromium');
if (!executablePath) {
  console.error('theme-screenshot: no existing Chrome or Chromium (set WP_BROWSER_CHROMIUM); screenshot.png not written');
  process.exit(2);
}

const tmp = `${out}.tmp-${process.pid}.png`;
let browser;
let code = 1;
try {
  browser = await chromium.launch({ executablePath });
  const context = await browser.newContext({
    viewport: { width: WIDTH, height: HEIGHT },
    deviceScaleFactor: 1,
    reducedMotion: 'reduce',
    ignoreHTTPSErrors: true, // local sites run on self-signed certificates
  });
  const page = await context.newPage();
  const response = await page.goto(url, { waitUntil: 'networkidle', timeout: 45000 });
  if (!response || response.status() >= 400) {
    throw new Error(`${url} answered ${response ? response.status() : 'nothing'}`);
  }
  await page.evaluate(() => document.fonts.ready);
  await page.screenshot({ path: tmp, clip: { x: 0, y: 0, width: WIDTH, height: HEIGHT } });
  const size = pngSize(readFileSync(tmp));
  if (!size || size.width !== WIDTH || size.height !== HEIGHT) {
    throw new Error(`capture is ${size ? `${size.width}x${size.height}` : 'not a PNG'}, not ${WIDTH}x${HEIGHT}`);
  }
  renameSync(tmp, out);
  console.log(`written ${out} (${WIDTH}x${HEIGHT}, ${statSync(out).size} bytes, from ${url})`);
  code = 0;
} catch (err) {
  console.error(`theme-screenshot: ${err.message.split('\n')[0]}; screenshot.png not changed`);
} finally {
  if (existsSync(tmp)) unlinkSync(tmp);
  if (browser) await browser.close();
}
process.exit(code);
