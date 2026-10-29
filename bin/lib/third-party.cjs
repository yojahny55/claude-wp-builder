// third-party.cjs: which hosts a browser pass may reach, shared by every runner.
//
// A news site loads 160-250 requests per page, most of them not the site's: YouTube embeds,
// GA/GTM, ad and currency widgets. Measured from a local clone, every one of those is a real
// hit on a production analytics property or a third-party API, and the widgets answered the
// clone with 403s that perturbed the very numbers being measured. The suite and
// bin/ux-probe.mjs therefore block every host outside an allowlist, and both build it here so
// "the audited host" means the same thing in each.
//
// Allowlist entries are host names, lower case, without port. `example.com` matches that host
// only; `.example.com` or `*.example.com` matches the domain and every subdomain. The audited
// host is always allowed together with its www / non-www twin, and so is loopback.
//
// Two ways to apply it, because no single mechanism covers every launch:
//   - chromiumArgs(): a `--host-resolver-rules` switch. It works for every Chromium the suite
//     starts, Lighthouse's own included (Lighthouse drives a tab over CDP, outside any route
//     Playwright could install), and it leaves Node-side requests alone, so the broken-link
//     check's HTTP requests still reach the links they verify.
//   - launchProxy(): a proxy to a closed local port with the allowlist as the bypass list, for
//     Firefox and WebKit, which have no resolver switch.
// A route handler (ux-probe) uses isBlocked() directly and can report what it stopped.
'use strict';

const DEAD_PROXY = 'http://127.0.0.1:9';
const LOOPBACK = ['localhost', '127.0.0.1', '[::1]'];

function hostOf(value) {
  if (!value) return '';
  try {
    const s = String(value).trim();
    return new URL(/^[a-z][a-z0-9+.-]*:\/\//i.test(s) ? s : `http://${s}`).hostname.toLowerCase();
  } catch {
    return '';
  }
}

// "a.com, .b.com,*.c.com" -> ['a.com', '.b.com', '.c.com']. A URL is accepted and reduced to
// its host, so `--allow-hosts https://cdn.example.com/` does what it says.
function parseHosts(list) {
  if (!list) return [];
  const items = Array.isArray(list) ? list : String(list).split(',');
  const out = [];
  for (const raw of items) {
    const s = String(raw).trim().toLowerCase();
    if (!s) continue;
    if (s.startsWith('*.') || s.startsWith('.')) {
      const h = hostOf(s.replace(/^\*?\./, ''));
      if (h) out.push(`.${h}`);
    } else {
      const h = hostOf(s);
      if (h) out.push(h);
    }
  }
  return [...new Set(out)];
}

// The audited host, its www twin, loopback and whatever the operator added.
function allowlistFor(baseUrl, extra) {
  const host = hostOf(baseUrl);
  const list = [...LOOPBACK];
  if (host) {
    list.push(host);
    const ip = /^[\d.]+$/.test(host) || host.startsWith('[');
    if (!ip) list.push(host.startsWith('www.') ? host.slice(4) : `www.${host}`);
  }
  return [...new Set([...list, ...parseHosts(extra)])];
}

function matches(host, entry) {
  if (entry.startsWith('.')) return host === entry.slice(1) || host.endsWith(entry);
  return host === entry;
}

// mode: { allow: [...] } blocks every host not on the list; { block: [...] } blocks only the
// listed hosts. Non-network schemes (data:, blob:, about:) are never blocked.
function isBlocked(url, mode) {
  let u;
  try { u = new URL(url); } catch { return false; }
  if (!/^(https?|wss?):$/.test(u.protocol)) return false;
  const host = u.hostname.toLowerCase();
  if (mode && Array.isArray(mode.block) && mode.block.length) return mode.block.some((e) => matches(host, e));
  if (mode && Array.isArray(mode.allow) && mode.allow.length) return !mode.allow.some((e) => matches(host, e));
  return false;
}

function chromiumArgs(allow) {
  const excludes = [];
  for (const e of allow) {
    // An IP literal is never resolved, so it needs no rule, and a bracketed IPv6 one is not
    // a pattern the rule parser accepts.
    if (e.startsWith('[')) continue;
    if (e.startsWith('.')) excludes.push(`EXCLUDE ${e.slice(1)}`, `EXCLUDE *${e}`);
    else excludes.push(`EXCLUDE ${e}`);
  }
  return [`--host-resolver-rules=MAP * ~NOTFOUND, ${excludes.join(', ')}`];
}

function launchProxy(allow) {
  const bypass = [];
  for (const e of allow) {
    if (e.startsWith('.')) bypass.push(e.slice(1), `*${e}`);
    else bypass.push(e);
  }
  return { server: DEAD_PROXY, bypass: bypass.join(',') };
}

// Launch options for one engine with the block applied. An explicit proxy or a resolver
// rule the caller already passed is left alone: it is somebody's deliberate setting.
// Under @playwright/test the config's use.launchOptions reach launch() through the library's
// default launch options, and the library spreads the explicit argument over them, so a block
// built from the explicit argument alone would replace the config's args and proxy. Fold the
// defaults in first so the block adds to them.
function withDefaults(defaults, options) {
  const d = defaults || {};
  const opts = Object.assign({}, options || {});
  if (Array.isArray(d.args) && d.args.length) opts.args = d.args.concat(Array.isArray(opts.args) ? opts.args : []);
  if (!opts.proxy && d.proxy) opts.proxy = d.proxy;
  return opts;
}

// Why applyToLaunch would leave this engine unblocked, or null when it applies the block.
// A proxy cannot be chained and Chromium keeps only one resolver switch, so the caller's
// setting wins; the launcher says so instead of letting third-party requests through unseen.
function blockSkipped(engine, options) {
  const opts = options || {};
  if (engine === 'chromium') {
    const args = Array.isArray(opts.args) ? opts.args : [];
    if (args.some((a) => String(a).startsWith('--host-resolver-rules'))) return 'the launch args already carry --host-resolver-rules';
    // Through an HTTP proxy the proxy resolves the target host, so the resolver rule never runs.
    if (opts.proxy) return `the launch options set a proxy, which resolves hosts itself (${opts.proxy.server || 'no server'})`;
    return null;
  }
  return opts.proxy ? `the launch options already set a proxy (${opts.proxy.server || 'no server'})` : null;
}

function applyToLaunch(engine, options, allow) {
  const opts = Object.assign({}, options || {});
  if (engine === 'chromium') {
    const args = Array.isArray(opts.args) ? opts.args.slice() : [];
    if (!args.some((a) => String(a).startsWith('--host-resolver-rules'))) args.push(...chromiumArgs(allow));
    opts.args = args;
  } else if (!opts.proxy) {
    opts.proxy = launchProxy(allow);
  }
  return opts;
}

module.exports = { hostOf, parseHosts, allowlistFor, isBlocked, chromiumArgs, launchProxy, applyToLaunch, withDefaults, blockSkipped, DEAD_PROXY };
