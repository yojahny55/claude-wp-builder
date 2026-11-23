#!/usr/bin/env node
/**
 * woo-verify.mjs: check that a WooCommerce store set up by /wp-woo-setup works, from the outside.
 *
 * Usage: woo-verify.mjs <project-path> [--url <base-url>] [--order]
 *
 * Reads the `store` block and `wp_cli.wrapper` from <project-path>/.wp-create.json, then:
 *   setup      woo-setup.php's dry run plans nothing: the store still matches its block
 *   page:*     the shop, cart, checkout and account pages answer 200 (a catalog's cart and
 *              checkout send the visitor to the shop instead)
 *   shop       the shop lists products, and there is at least one published product
 *   cart       the Store API adds a product to a cart and removes it again (a catalog refuses
 *              the add); the cart's session row is deleted afterwards
 *   order      --order only: a cash-on-delivery order placed through the Store API, the
 *              new-order email sent, then the order cancelled (stock and sales count back) and
 *              deleted for good. Refused, before anything runs, unless the site is local, the
 *              tier sells, cash on delivery is on and the store has no other order -- a store
 *              with orders is a merchant's, and the new-order email would reach them.
 *
 * Without --order it writes nothing to the store: a cart session the Store API opens is deleted.
 * --url replaces the site's home URL (a `wp server` port, a host the machine resolves another
 * way). A local site's certificate is not verified; any other site's is.
 *
 * Every line is `<status> <check>[: detail]`, status pass, fail, skip or note; the last line is
 * `verify: N passed, N failed, N skipped`.
 *
 * Exit: 0 nothing failed, 1 a check failed or --order was refused, 2 could not measure (WP-CLI
 * or the site did not answer), 64 usage.
 */
import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import http from 'node:http';
import https from 'node:https';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import './lib/stdio-blocking.mjs';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const SETUP = join(ROOT, 'skills/wp-woocommerce/scripts/woo-setup.php');
const HELPER = join(ROOT, 'skills/wp-woocommerce/scripts/woo-verify.php');
const USAGE = 'usage: woo-verify.mjs <project-path> [--url <base-url>] [--order]';

function usage(msg) {
  process.stderr.write(`${msg ? `${msg}\n` : ''}${USAGE}\n`);
  process.exit(64);
}

const argv = process.argv.slice(2);
let project = '';
let baseUrl = '';
let order = false;
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (a === '--order') order = true;
  else if (a === '--url') {
    baseUrl = argv[++i] || '';
    if (!/^https?:\/\/[^/]/.test(baseUrl)) usage('--url needs an http(s) URL');
  } else if (a.startsWith('--')) usage(`unknown flag ${a}`);
  else if (!project) project = a;
  else usage(`unexpected argument ${a}`);
}
if (!project) usage();

const n = { pass: 0, fail: 0, skip: 0 };
function line(status, check, detail = '') {
  if (status in n) n[status]++;
  process.stdout.write(`${status} ${check}${detail ? `: ${detail}` : ''}\n`);
}
function finish(code) {
  process.stdout.write(`verify: ${n.pass} passed, ${n.fail} failed, ${n.skip} skipped\n`);
  process.exit(code === undefined ? (n.fail ? 1 : 0) : code);
}
function unmeasured(check, detail) {
  line('fail', check, detail);
  finish(2);
}

const manifestPath = join(project, '.wp-create.json');
if (!existsSync(manifestPath)) usage(`no .wp-create.json in ${project}`);
let manifest;
try {
  manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
} catch (e) {
  usage(`.wp-create.json does not parse: ${e.message}`);
}
const store = manifest.store;
if (!store || typeof store !== 'object' || !['catalog', 'store', 'full'].includes(store.tier)) {
  usage('the manifest has no store block with a tier -- /wp-woo-setup records one');
}
const wrapper = manifest.wp_cli && typeof manifest.wp_cli.wrapper === 'string' && manifest.wp_cli.wrapper.trim();
if (!wrapper) usage('the manifest has no wp_cli.wrapper');
const sells = store.tier !== 'catalog';

/** `<wrapper> eval-file <file> <args...>`: { code, out }. The arguments never pass through a shell string. */
function evalFile(file, ...args) {
  const r = spawnSync('bash', ['-c', `${wrapper} eval-file "$@"`, '_', file, ...args.map(String)], {
    encoding: 'utf8',
    maxBuffer: 16 * 1024 * 1024,
  });
  return { code: r.status === null ? -1 : r.status, out: `${r.stdout || ''}`, err: `${r.stderr || ''}` };
}
function helper(...args) {
  const r = evalFile(HELPER, ...args);
  const json = r.out.split('\n').reverse().find((l) => l.startsWith('{'));
  if (r.code !== 0 || !json) {
    const why = (r.out.split('\n').find((l) => l.startsWith('refused:')) || r.err.trim().split('\n').pop() || `exit ${r.code}`).slice(0, 300);
    return { error: why };
  }
  return JSON.parse(json);
}

// --- Facts ------------------------------------------------------------------------------------
const facts = helper('facts');
if (facts.error) unmeasured('facts', `WP-CLI could not read the store: ${facts.error}`);
const local = facts.environment === 'local';

if (order) {
  const refuse = [];
  if (!local) refuse.push(`the site reads as ${facts.environment}, not local`);
  if (!sells) refuse.push('a catalog sells nothing');
  if (!facts.cod) refuse.push('cash on delivery is off (setup turns it on only on a local site)');
  if (facts.orders > 0) refuse.push(`the store has ${facts.orders} order(s): a store with orders is a merchant's, and the new-order email would reach them`);
  if (refuse.length) {
    process.stdout.write(`refused: --order places an order only on a local store that sells and has none -- ${refuse.join('; ')}\n`);
    process.exit(1);
  }
}

// --- HTTP -------------------------------------------------------------------------------------
const base = new URL(baseUrl || facts.home);
const origin = base.origin;
const prefix = base.pathname.replace(/\/$/, '');

/** Relative path from WordPress (`/shop/`, `/?page_id=6`) on the base URL. */
function at(path) {
  return `${origin}${prefix}${path.startsWith('/') ? path : `/${path}`}`;
}

function request(url, { method = 'GET', headers = {}, body } = {}) {
  return new Promise((ok, ko) => {
    const u = new URL(url);
    const lib = u.protocol === 'https:' ? https : http;
    const req = lib.request(
      u,
      { method, headers: { 'User-Agent': 'woo-verify', ...headers }, rejectUnauthorized: !local, timeout: 30000 },
      (res) => {
        const chunks = [];
        res.on('data', (c) => chunks.push(c));
        res.on('end', () => ok({ status: res.statusCode, headers: res.headers, body: Buffer.concat(chunks).toString('utf8') }));
      },
    );
    req.on('timeout', () => req.destroy(new Error('timed out after 30 s')));
    req.on('error', ko);
    if (body !== undefined) req.write(body);
    req.end();
  });
}

/** GET following same-origin redirects: { status, url, hops }. */
async function follow(url) {
  const hops = [];
  for (let i = 0; i < 6; i++) {
    const r = await request(url);
    if (r.status >= 300 && r.status < 400 && r.headers.location) {
      const next = new URL(r.headers.location, url).href;
      hops.push(`${r.status} ${next}`);
      if (new URL(next).origin !== origin) return { ...r, url: next, hops, offsite: true };
      url = next;
      continue;
    }
    return { ...r, url, hops };
  }
  return { status: 0, url, hops, body: '' };
}

const API = `${origin}${prefix}/?rest_route=/wc/store/v1`;
async function api(path, token, payload) {
  const headers = { Accept: 'application/json' };
  if (token) headers['Cart-Token'] = token;
  if (payload !== undefined) headers['Content-Type'] = 'application/json';
  const r = await request(`${API}/${path}`, { method: payload === undefined ? 'GET' : 'POST', headers, body: payload === undefined ? undefined : JSON.stringify(payload) });
  let json = null;
  try {
    json = JSON.parse(r.body);
  } catch {
    json = null;
  }
  return { status: r.status, token: r.headers['cart-token'] || token, json, body: r.body };
}
function apiError(r) {
  if (!r.json) return `HTTP ${r.status}, not JSON: ${r.body.slice(0, 200)}`;
  return `${r.json.code || `HTTP ${r.status}`}: ${r.json.message || ''}`.trim();
}

/** The session key a Store API cart token names (the JWT's user_id). */
function sessionKey(token) {
  try {
    return JSON.parse(Buffer.from(token.split('.')[1], 'base64url').toString('utf8')).user_id || '';
  } catch {
    return '';
  }
}
function forget(token) {
  const key = token && sessionKey(token);
  if (!key) return;
  const r = helper('forget-session', key);
  if (r.error) line('note', 'cart', `could not delete the verification's cart session ${key}: ${r.error}`);
}

const firstHop = await request(at('/')).catch((e) => e);
if (firstHop instanceof Error) {
  unmeasured('site', `${origin} did not answer (${firstHop.code || firstHop.message})${baseUrl ? '' : ' -- pass --url when the home URL is not reachable from here'}`);
}

// --- Setup has nothing to change ---------------------------------------------------------------
const plan = evalFile(SETUP, project, 'dry-run');
const planLines = plan.out.split('\n').filter(Boolean);
if (plan.code !== 0) {
  line('fail', 'setup', (planLines.find((l) => l.startsWith('refused:')) || plan.err.trim().split('\n').pop() || `exit ${plan.code}`).slice(0, 300));
} else {
  const drift = planLines.filter((l) => l.startsWith('would-set '));
  for (const l of planLines.filter((x) => /^(client|degraded) /.test(x))) line('note', 'setup', l);
  if (drift.length) {
    for (const l of drift) line('note', 'setup', l);
    line('fail', 'setup', `${drift.length} value(s) no longer match the store block -- /wp-woo-setup brings them back`);
  } else {
    line('pass', 'setup', planLines.find((l) => l.startsWith('plan:')) || 'nothing to set');
  }
}

// --- Store pages ------------------------------------------------------------------------------
const pages = {};
if (facts.coming_soon === 'yes') {
  line('skip', 'pages', 'the store is coming soon: visitors see that page instead (launch makes it live)');
  line('skip', 'shop', 'the store is coming soon');
} else {
  for (const name of ['shop', 'cart', 'checkout', 'myaccount']) {
    const page = facts.pages[name];
    if (!page || !page.path) {
      line('fail', `page:${name}`, 'no published page is assigned -- /wp-woo-setup assigns it');
      continue;
    }
    pages[name] = await follow(at(page.path));
  }
  const shopEnd = pages.shop && pages.shop.status === 200 ? pages.shop.url : null;
  for (const [name, r] of Object.entries(pages)) {
    const via = r.hops.length ? ` (via ${r.hops.join(', ')})` : '';
    if (r.offsite) line('fail', `page:${name}`, `redirects off the site${via}`);
    else if (!sells && (name === 'cart' || name === 'checkout')) {
      if (r.status === 200 && shopEnd && r.url === shopEnd) line('pass', `page:${name}`, `a catalog sends the visitor to the shop${via}`);
      else line('fail', `page:${name}`, `a catalog's ${name} should send the visitor to the shop; ended at ${r.status} ${r.url}${via}`);
    } else if (r.status === 200) line('pass', `page:${name}`, `200 ${r.url}${via}`);
    else line('fail', `page:${name}`, `${r.status} ${r.url}${via}`);
  }

  // The shop lists products: classic and block templates both print post_class() on each one.
  if (facts.products < 1) {
    line('fail', 'shop', 'no published product -- /wp-seed --products creates a demo\'s products');
  } else if (!shopEnd) {
    line('fail', 'shop', 'the shop page did not answer 200');
  } else {
    const ids = new Set();
    for (const m of pages.shop.body.matchAll(/class="([^"]*)"/g)) {
      const cls = ` ${m[1]} `;
      const id = cls.match(/ post-(\d+) /);
      if (id && cls.includes(' type-product ')) ids.add(id[1]);
    }
    if (ids.size) line('pass', 'shop', `${ids.size} product(s) on the shop page, ${facts.products} published`);
    else line('fail', 'shop', `${facts.products} product(s) published, none on the shop page`);
  }
}

// --- Cart through the Store API ------------------------------------------------------------------
const sample = facts.sample;
let cartOk = false;
if (!sample) {
  line('fail', 'cart', 'no published simple product to put in a cart -- /wp-seed --products creates a demo\'s products');
} else {
  const opened = await api('cart');
  let token = opened.token;
  if (!token) {
    line('fail', 'cart', `the Store API returned no cart token: ${apiError(opened)}`);
  } else if (!sells) {
    const add = await api('cart/add-item', token, { id: sample.id, quantity: 1 });
    token = add.token;
    if (add.json && add.json.code === 'woocommerce_rest_product_not_purchasable') line('pass', 'cart', `a catalog refuses "${sample.name}" in a cart`);
    else line('fail', 'cart', `a catalog accepted "${sample.name}" in a cart (${add.status})`);
  } else if (!sample.purchasable) {
    line('fail', 'cart', `"${sample.name}" is not purchasable or not in stock, and no published simple product is`);
  } else {
    const add = await api('cart/add-item', token, { id: sample.id, quantity: 1 });
    token = add.token;
    const item = add.json && Array.isArray(add.json.items) ? add.json.items.find((i) => i.id === sample.id) : null;
    if (add.status !== 201 && add.status !== 200) line('fail', 'cart', `adding "${sample.name}": ${apiError(add)}`);
    else if (!item) line('fail', 'cart', `"${sample.name}" is not in the cart after adding it`);
    else {
      const removed = await api('cart/remove-item', token, { key: item.key });
      if (removed.json && removed.json.items_count === 0) {
        line('pass', 'cart', `"${sample.name}" added and removed through the Store API`);
        cartOk = true;
      } else line('fail', 'cart', `removing "${sample.name}": ${apiError(removed)}`);
    }
  }
  forget(token);
}

// --- The order (--order) ------------------------------------------------------------------------
if (order) {
  for (const id of facts.own_orders) {
    const r = helper('finish-order', id);
    line('note', 'order', r.error ? `a previous verification's order ${id} could not be removed: ${r.error}` : `a previous verification's order ${id} removed`);
  }
  if (!cartOk) {
    line('skip', 'order', 'the cart check failed');
  } else {
    await placeOrder();
  }
}

async function placeOrder() {
  const [country, state = ''] = String(store.address.country).split(':');
  const address = { first_name: 'Store', last_name: 'Verification', address_1: store.address.street, city: store.address.city, state, postcode: store.address.postcode, country };
  const billing = { ...address, email: facts.email };
  let token = (await api('cart')).token;
  try {
    const add = await api('cart/add-item', token, { id: sample.id, quantity: 1 });
    token = add.token;
    if (add.status !== 201 && add.status !== 200) return line('fail', 'order', `adding "${sample.name}": ${apiError(add)}`);
    const cust = await api('cart/update-customer', token, { shipping_address: address, billing_address: billing });
    if (!cust.json || cust.status !== 200) return line('fail', 'order', `the customer address: ${apiError(cust)}`);
    if (cust.json.needs_shipping) {
      for (const pkg of cust.json.shipping_rates || []) {
        const rates = pkg.shipping_rates || [];
        if (!rates.length) return line('fail', 'order', `no shipping rate for the store's own address (${store.address.country} ${store.address.postcode})`);
        if (!rates.some((r) => r.selected)) {
          const sel = await api('cart/select-shipping-rate', token, { package_id: pkg.package_id, rate_id: rates[0].rate_id });
          if (sel.status !== 200) return line('fail', 'order', `selecting ${rates[0].rate_id}: ${apiError(sel)}`);
        }
      }
    }
    const payload = { billing_address: billing, shipping_address: address, payment_method: 'cod' };
    // Setup gives a local checkout Cloudflare's test keys, which pass any token.
    if (facts.turnstile) payload.extensions = { 'simple-cloudflare-turnstile': { token: 'XXXX.DUMMY.TOKEN.XXXX' } };
    const done = await api('checkout', token, payload);
    const id = done.json && done.json.order_id;
    if (!id) return line('fail', 'order', `the checkout placed no order: ${apiError(done)}`);
    const fin = helper('finish-order', id);
    if (fin.error) return line('fail', 'order', `order ${id} was placed but not removed: ${fin.error} -- delete it in WooCommerce`);
    if (done.json.status !== 'processing' || fin.status !== 'processing') line('fail', 'order', `order ${id} is ${fin.status}, not processing`);
    else line('pass', 'order', `order ${id}, ${fin.total}, paid by cash on delivery`);
    const sent = fin.notes.find((t) => t.startsWith('Email "New order" sent'));
    const failed = fin.notes.find((t) => t.startsWith('Email "New order" failed'));
    if (sent) line('pass', 'email', `the new-order email was sent to ${facts.recipient}`);
    else line('fail', 'email', failed || 'the order has no note that the new-order email was sent');
    const back = fin.products && fin.products[sample.id];
    if (!fin.deleted) line('fail', 'cleanup', `order ${id} is still there -- delete it in WooCommerce, or setup reads the store as having orders`);
    else if (!back || back.stock !== sample.stock || back.total_sales !== sample.total_sales) {
      line('fail', 'cleanup', `order ${id} deleted, but "${sample.name}" did not get its stock and sales count back: ${JSON.stringify(back)} (was stock ${sample.stock}, sales ${sample.total_sales})`);
    } else line('pass', 'cleanup', `order ${id} deleted for good; stock and sales count back`);
  } finally {
    forget(token);
  }
}

finish();
