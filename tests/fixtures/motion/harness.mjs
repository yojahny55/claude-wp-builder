// What drive.mjs and shoot.mjs both need: a static server for the motion fixtures, and a
// browser to point at it.
//
// Extracted rather than copied. Both halves carry decisions that are not obvious from
// their shape -- the 403 on paths outside the fixture directory, the 204 for /favicon.ico
// (a 404 there is logged as a console error, which the assertions read as "a section
// failed"), and the exit-2 contract for "no browser" that the check scripts turn into a
// SKIP. A second copy of that would drift from this one silently, and the drift would
// show up as a check that still passes while testing something else.

import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { join, dirname, extname } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const repo = join(here, '..', '..', '..');

export const MOTION = join(repo, 'starter-theme', '__tailwind__', 'assets', 'js', 'src', 'motion.js');

// The real pinned GSAP, served from node_modules rather than a CDN: a check that reaches
// the network to fetch its engine fails for reasons that have nothing to do with the code
// under test.
export const VENDOR = {
  '/gsap.min.js': join(repo, 'node_modules', 'gsap', 'dist', 'gsap.min.js'),
  '/ScrollTrigger.min.js': join(repo, 'node_modules', 'gsap', 'dist', 'ScrollTrigger.min.js'),
};

const types = { '.html': 'text/html', '.js': 'text/javascript' };

// Served over HTTP rather than opened as file://, because motion.js is an ES module and a
// module import from a file:// page is blocked by CORS in Chrome. CLAUDE.md already notes
// that verification serves over HTTP while the delivered demo is a file:// artifact.
export async function serveFixtures() {
  const server = createServer(async (req, res) => {
    const path = (req.url || '/').split('?')[0];
    if (path === '/favicon.ico') {
      res.writeHead(204).end();
      return;
    }
    try {
      const file =
        path === '/motion.js' ? MOTION
        : VENDOR[path] ? VENDOR[path]
        : join(here, path === '/' ? 'pan.html' : path);
      if (!file.startsWith(here) && file !== MOTION && !Object.values(VENDOR).includes(file)) {
        res.writeHead(403).end('no');
        return;
      }
      const body = await readFile(file);
      res.writeHead(200, { 'content-type': types[extname(file)] || 'text/plain' }).end(body);
    } catch {
      res.writeHead(404).end('not found');
    }
  });
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  return { server, base: `http://127.0.0.1:${server.address().port}` };
}

// Returns a browser, or null when none is usable. Callers exit 2 on null -- the check
// scripts read that as SKIP, and turn it back into a failure where a browser is supposed
// to exist (MOTION_REQUIRE_BROWSER / VISUAL_REQUIRE_BROWSER).
export async function launchChrome() {
  let chromium;
  try {
    ({ chromium } = await import('playwright-core'));
  } catch {
    console.log('SKIP: playwright-core is not installed');
    return null;
  }

  // The same resolution ladder the other bin/*.mjs tools use: an explicit override first,
  // then a system Chrome. No download is attempted -- a check that installs a browser is a
  // check that fails differently on a cold machine.
  const candidates = [
    process.env.CHROME_PATH,
    '/usr/bin/google-chrome',
    '/usr/bin/chromium',
    '/usr/bin/chromium-browser',
  ].filter(Boolean);

  for (const executablePath of candidates) {
    try {
      return await chromium.launch({ executablePath, args: ['--no-sandbox'] });
    } catch {
      /* try the next one */
    }
  }
  console.log('SKIP: no usable Chrome found (set CHROME_PATH)');
  return null;
}
