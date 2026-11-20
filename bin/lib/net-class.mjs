/**
 * Address classification for the link sweep's redirect checks. Pure functions plus one async
 * resolver wrapper whose DNS lookup is injectable, so the checks can exercise every branch
 * without a network.
 *
 * classifyHost(h) -> 'metadata' | 'linklocal' | 'private' | 'public'
 *   metadata   cloud instance-metadata endpoints (169.254.169.254, fd00:ec2::254, ...)
 *   linklocal  169.254/16, fe80::/10
 *   private    loopback, RFC 1918, unspecified, ::1, fc00::/7, localhost names
 * An IPv4-mapped IPv6 literal (::ffff:a.b.c.d, which WHATWG URL rewrites to ::ffff:XXXX:XXXX)
 * is classified as the IPv4 address it wraps.
 */
import { isIP } from 'node:net';

export class Refused extends Error {}

// "[::ffff:a9fe:a9fe]" / "::FFFF:169.254.169.254" -> "169.254.169.254"; other hosts lowercased.
export function normalizeHost(h) {
  const x = String(h).toLowerCase().replace(/^\[|\]$/g, '').replace(/\.$/, '');
  if (isIP(x) !== 6) return x;
  const m = /^(?:0{0,4}:){2,5}(?:0{0,4}:)?ffff:(.+)$/.exec(x) || /^::ffff:(.+)$/.exec(x);
  if (!m) return x;
  const tail = m[1];
  if (isIP(tail) === 4) return tail;
  const g = /^([0-9a-f]{1,4}):([0-9a-f]{1,4})$/.exec(tail);
  if (!g) return x;
  const hi = parseInt(g[1], 16), lo = parseInt(g[2], 16);
  return `${hi >> 8}.${hi & 255}.${lo >> 8}.${lo & 255}`;
}

// Expand an IPv6 literal to its 8 numeric groups, or null.
function groups6(x) {
  if (isIP(x) !== 6) return null;
  let s = x;
  const v4 = /(\d+\.\d+\.\d+\.\d+)$/.exec(s);
  if (v4) {
    const p = v4[1].split('.').map(Number);
    s = s.slice(0, -v4[1].length) + ((p[0] << 8) | p[1]).toString(16) + ':' + ((p[2] << 8) | p[3]).toString(16);
  }
  const [head, tail] = s.split('::');
  const h = head ? head.split(':') : [];
  const t = tail === undefined ? [] : tail ? tail.split(':') : [];
  const fill = tail === undefined ? [] : new Array(8 - h.length - t.length).fill('0');
  return [...h, ...fill, ...t].map((v) => parseInt(v, 16));
}

export function classifyHost(h) {
  const x = normalizeHost(h);
  if (x === 'metadata.google.internal' || x === 'metadata') return 'metadata';
  if (x === 'localhost' || x.endsWith('.localhost')) return 'private';
  const kind = isIP(x);
  if (kind === 4) {
    const [a, b] = x.split('.').map(Number);
    if (x === '169.254.169.254' || x === '100.100.100.200') return 'metadata';
    if (a === 169 && b === 254) return 'linklocal';
    if (a === 127 || a === 10 || a === 0 || (a === 192 && b === 168) || (a === 172 && b >= 16 && b <= 31)) return 'private';
    return 'public';
  }
  if (kind === 6) {
    const g = groups6(x);
    if (g[0] === 0xfd00 && g[1] === 0x0ec2 && g.slice(2, 7).every((v) => v === 0) && g[7] === 0x254) return 'metadata';
    if ((g[0] & 0xffc0) === 0xfe80) return 'linklocal';
    if (g.every((v) => v === 0) || (g.slice(0, 7).every((v) => v === 0) && g[7] === 1)) return 'private';
    if ((g[0] & 0xfe00) === 0xfc00) return 'private';
  }
  return 'public';
}

export const isLinkLocal = (h) => ['metadata', 'linklocal'].includes(classifyHost(h));
export const isPrivateHost = (h) => classifyHost(h) === 'private';

// Reject when `signal` aborts (the request's own timeout/budget), so a slow resolver cannot
// outlive the deadline the fetch is held to.
function withSignal(promise, signal) {
  if (!signal) return promise;
  if (signal.aborted) return Promise.reject(signal.reason);
  return new Promise((resolve, reject) => {
    const onAbort = () => reject(signal.reason);
    signal.addEventListener('abort', onAbort, { once: true });
    promise.then(resolve, reject).finally(() => signal.removeEventListener('abort', onAbort));
  });
}

/**
 * Refuse a host by what it resolves to, not only by how it is spelled. An IP literal or a
 * name already classified by its text is judged without DNS. Any other name is resolved with
 * `lookup(host, {all: true})`, and ANY returned address that is metadata/link-local (always)
 * or private/loopback (when the swept site is not itself local) refuses it. A failed lookup
 * refuses too, with the reason, so the link is reported unmeasured instead of crashing.
 *
 * Limit: this is a check at one moment. A name can resolve differently when fetch() looks it
 * up again (DNS rebinding), so it narrows the redirect surface and does not close it.
 */
export async function checkResolved(host, { siteLocal, lookup, signal, what = 'redirect host', allowUnresolved = false }) {
  const bare = String(host).replace(/^\[|\]$/g, '');
  if (isIP(normalizeHost(bare)) || classifyHost(bare) !== 'public') return;
  let addrs;
  try { addrs = await withSignal(lookup(bare, { all: true }), signal); }
  catch (e) {
    // The original link is not a redirect: a name that does not resolve is a dead link, and the
    // request itself reports it. Only a redirect hop is refused for failing to resolve.
    if (allowUnresolved) return;
    throw new Refused(`could not resolve ${what} ${host} (${e.code || e.name}); not followed`);
  }
  for (const { address } of addrs) {
    const c = classifyHost(address);
    if (c === 'metadata' || c === 'linklocal') {
      throw new Refused(`${what} ${host} resolves to link-local/metadata address ${address} not followed`);
    }
    if (c === 'private' && !siteLocal) {
      throw new Refused(`${what} ${host} resolves to private/loopback address ${address} not followed from a non-local site`);
    }
  }
}
