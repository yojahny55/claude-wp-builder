#!/usr/bin/env bash
# The store block is new, so it is strict: every rule refuses by name, a Stripe key in the
# manifest is refused with the place it belongs, and a manifest without a store block renders
# exactly the generated rows it rendered before this block existed.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

out=$(node --input-type=module -e "$(cat <<'JS'
import { validateStore, validateManifest, renderContext } from './bin/lib/manifest.mjs';
import { readFileSync } from 'node:fs';
const bad = [];
const must = (cond, msg) => { if (!cond) bad.push(msg); };
const good = {
  tier: 'store',
  address: { street: '100 Main St', city: 'Tampa', postcode: '33602', country: 'US:FL' },
  currency: 'USD',
  units: { weight: 'lbs', dimension: 'in' },
  checkout: 'block',
  payments: { gateway: 'stripe', mode: 'test' },
  shipping: [{ zone: 'United States', locations: ['US'], methods: [{ type: 'flat_rate', cost: '10.00' }, { type: 'free_shipping', min_amount: '100' }] }],
  tax: { enabled: true, prices_include_tax: false, rates: [{ country: 'US', state: 'FL', rate: '6.0000', name: 'FL Sales Tax', shipping: true }] },
};
must(validateStore(good).length === 0, `a valid store block is refused: ${validateStore(good).join('; ')}`);
const refused = (label, mutate, needle) => {
  const s = structuredClone(good);
  mutate(s);
  const p = validateStore(s);
  must(p.some((x) => x.includes(needle)), `${label}: want a problem naming "${needle}", got ${JSON.stringify(p)}`);
};
refused('unknown tier', (s) => { s.tier = 'mall'; }, 'store.tier');
refused('missing address', (s) => { delete s.address; }, 'store.address');
refused('three-letter country', (s) => { s.address.country = 'USA'; }, 'store.address.country');
refused('lowercase currency', (s) => { s.currency = 'usd'; }, 'store.currency');
refused('unknown weight unit', (s) => { s.units.weight = 'stone'; }, 'store.units.weight');
refused('shortcode without a reason', (s) => { s.checkout = 'shortcode'; }, 'checkout_reason');
refused('live mode', (s) => { s.payments.mode = 'live'; }, 'store.payments.mode');
refused('a secret in the manifest', (s) => { s.payments.test_secret_key = 'sk_test_x'; }, '.wp-create.local.json');
refused('unknown key', (s) => { s.colour = 'red'; }, 'store.colour');
refused('duplicate zone', (s) => { s.shipping.push(structuredClone(s.shipping[0])); }, 'used twice');
refused('duplicate method', (s) => { s.shipping[0].methods.push({ type: 'flat_rate', cost: '5.00' }); }, 'appears twice');
refused('numeric cost', (s) => { s.shipping[0].methods[0].cost = 10; }, 'cost');
refused('junk location', (s) => { s.shipping[0].locations = ['Florida']; }, 'locations');
refused('five decimal places', (s) => { s.tax.rates[0].rate = '6.12345'; }, 'rate');
refused('duplicate rate', (s) => { s.tax.rates.push(structuredClone(s.tax.rates[0])); }, 'duplicates');
refused('tax flag as a string', (s) => { s.tax.enabled = 'yes'; }, 'store.tax.enabled');

const cat = { tier: 'catalog', address: good.address, currency: 'USD', units: good.units, enquiry: ['whatsapp'] };
must(validateStore(cat).length === 0, `a valid catalog is refused: ${validateStore(cat).join('; ')}`);
must(validateStore({ ...cat, enquiry: [] }).some((x) => x.includes('store.enquiry')), 'a catalog with no enquiry channel passes');
must(validateStore({ ...cat, enquiry: ['fax'] }).some((x) => x.includes('store.enquiry')), 'an unknown enquiry channel passes');
must(validateStore({ ...cat, payments: good.payments }).some((x) => x.includes('forbidden on a catalog')), 'payments on a catalog pass');
must(validateStore({ ...cat, checkout: 'block' }).some((x) => x.includes('forbidden on a catalog')), 'a checkout type on a catalog passes');

const base = JSON.parse(readFileSync('tests/fixtures/manifests/valid/.wp-create.json', 'utf8'));
must(validateManifest({ ...base, store: { ...good, tier: 'mall' } }).some((x) => x.includes('store.tier')), 'validateManifest does not reach the store block');
must(validateManifest({ ...base, store: good }).length === 0, 'a valid manifest with a store block is refused');
const labels = (m) => renderContext(m).split('\n').filter((l) => l.startsWith('- **')).map((l) => l.slice(4, l.indexOf(':**')));
must(JSON.stringify(labels(base)) === JSON.stringify(['Project', 'Theme slug', 'i18n strategy', 'demo mode', 'Primary language', 'Plugin profile']),
  `a manifest with no store block renders different rows: ${JSON.stringify(labels(base))}`);
must(renderContext({ ...base, store: good }).includes('- **Store tier:** store'), 'a store block does not render its tier');
if (bad.length) { console.log(bad.join('\n')); process.exit(1); }
JS
)" 2>&1) || { printf '%s\n' "$out"; fail "store block rules"; }

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/p"
node -e '
  const fs = require("fs"), m = JSON.parse(fs.readFileSync("tests/fixtures/manifests/valid/.wp-create.json", "utf8"));
  m.store = { tier: "catalog", address: { street: "1 A St", city: "Tampa", postcode: "33602", country: "US:FL" }, currency: "USD",
    units: { weight: "lbs", dimension: "in" }, enquiry: ["form"], payments: { test_secret_key: "sk_test_leaked" } };
  fs.writeFileSync(process.argv[1] + "/.wp-create.json", JSON.stringify(m, null, 2));
' "$tmp/p"
set +e; node bin/wp-config.mjs validate "$tmp/p" >"$tmp/v" 2>&1; code=$?; set -e
[ "$code" = "1" ] || fail "a manifest holding a Stripe key exited $code, want 1"
grep -q 'store.payments.test_secret_key is a secret' "$tmp/v" || fail "the refusal does not say the key is a secret: $(cat "$tmp/v")"
grep -q 'sk_test_leaked' "$tmp/v" && fail "the refusal printed the key"
set +e; node bin/wp-config.mjs get "$tmp/p" store.payments.test_secret_key >/dev/null 2>"$tmp/g"; code=$?; set -e
[ "$code" = "1" ] && grep -q 'stripe_test_secret_key' "$tmp/g" || fail "get reads a Stripe key's manifest path instead of naming the secret"
node -e '
  const fs = require("fs"), f = process.argv[1] + "/.wp-create.json", m = JSON.parse(fs.readFileSync(f, "utf8"));
  delete m.store.payments; fs.writeFileSync(f, JSON.stringify(m, null, 2));
  fs.writeFileSync(process.argv[1] + "/.wp-create.local.json", JSON.stringify({ store: { payments: { test_secret_key: "sk_test_local" } } }));
' "$tmp/p"
[ "$(node bin/wp-config.mjs get "$tmp/p" stripe_test_secret_key 2>/dev/null)" = "sk_test_local" ] || fail "the local file rung does not resolve the Stripe key"
[ "$(WP_CREATE_STRIPE_TEST_SECRET_KEY=sk_test_env node bin/wp-config.mjs get "$tmp/p" stripe_test_secret_key 2>/dev/null)" = "sk_test_env" ] \
  || fail "the environment does not win over the local file"
echo PASS
