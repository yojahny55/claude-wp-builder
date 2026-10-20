#!/usr/bin/env bash
# Performance and update work had no way to prove it broke nothing: the browser suite audits
# quality, it does not walk a shopper through search, cart and checkout. The WooCommerce
# regression suite in templates/audit-suite/ is that proof, and it is only worth anything if
# three promises hold: it never orders or mails for real, a flow the site lacks SKIPs instead
# of failing, and nothing of the site it was generalized from survives in the template.
#
# Asserted here: the entry point exists and is documented, the safety rules are still in the
# code, the pure logic passes its selfcheck, and the suite is wired into the scaffold.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

suite=templates/audit-suite
flows="$suite/regression/flows.js"
spec="$suite/tests/regression.spec.js"
cfg="$suite/playwright.regression.config.js"

for f in "$flows" "$spec" "$cfg" "$suite/regression/defaults.js" "$suite/regression/helpers.js" \
  "$suite/regression/helpers.selfcheck.js" "$suite/regression/reporter.js" "$suite/scripts/regression-compare.js"; do
  [ -f "$f" ] || fail "$f is missing"
done

# 1. Entry point: npm scripts, project names, tag, scaffold copy, docs.
for s in test:regression test:regression:desktop test:regression:mobile regression:compare; do
  grep -Fq "\"$s\"" "$suite/package.json" || fail "package.json has no \"$s\" script"
done
grep -Fq 'regression-desktop' "$cfg" && grep -Fq 'regression-mobile' "$cfg" \
  || fail "the config lost its desktop or mobile project -- /wp-update selects them by name"
grep -Fq '@regression' "$spec" || fail "the spec no longer tags its tests @regression"
grep -Eq 'for item in .*\bregression\b.*playwright\.regression\.config\.js' bin/audit-suite.sh \
  || fail "bin/audit-suite.sh does not copy regression/ and its config into the scaffold -- the suite would not exist where it is run"
grep -Fq 'npm run test:regression' "$suite/README.md" || fail "the suite README does not document the entry point"
grep -Fq 'test:regression' docs/commands.md || fail "docs/commands.md does not document the regression suite"
grep -Fq 'regression' skills/wp-audit-run/references/browser-suite.md || fail "browser-suite.md does not mention the regression suite"
grep -Fq 'regression suite' CHANGELOG.md || fail "no changelog entry for the regression suite"

# 2. Safety: no real orders, no real mail off a clone, SKIP rather than FAIL for absent features.
grep -Fq 'wc-ajax=checkout' "$flows" || fail "the checkout flow no longer aborts order POSTs"
! grep -Eq 'place_order|wc-block-components-checkout-place-order-button' "$flows" \
  || fail "a flow references the place-order button -- the suite must never press it"
grep -Fq 'canWrite' "$flows" || fail "the writing flows lost their canWrite guard"
grep -Fq 'allowWrites' "$suite/regression/defaults.js" || fail "defaults lost allowWrites"
grep -Fq 'judgeMailStatus' "$flows" || fail "the contact flow no longer judges mail_failed through the clone rule"
grep -Fq 'retry' "$flows" 2>/dev/null || grep -Fq 'UNA vez' "$flows" || fail "the admin flow lost its single retry"
[ "$(grep -c 'c.skip(' "$flows")" -ge 15 ] || fail "too few c.skip() reasons -- absent features must SKIP, not FAIL"
grep -Fq 'REGRESSION_ADMIN_PASS' "$suite/.env.example" || fail "admin credentials are not environment-only"
! grep -Eq "REGRESSION_ADMIN_PASS\s*[:=]\s*['\"][^'\"]" "$suite/audit.config.js" || fail "audit.config.js holds a credential"

# 3. Nothing of the source site survives. The denylist cannot be the names (that would
# publish them here), so look for the shape of the leak: hostnames other than reserved
# examples, and table-prefixed or numeric-ID wp-cli/db calls.
leaked=$(grep -rhoE 'https?://[A-Za-z0-9.-]+' "$suite/regression" "$spec" "$cfg" \
  | sed -E 's#^https?://##' | grep -vE '^(localhost|127\.0\.0\.1)$' \
  | grep -vE '(^|\.)(example\.(com|net|org)|example|test|invalid|localhost)$' | sort -u || true)
[ -z "$leaked" ] || fail "the regression suite names a non-reserved host: $leaked"
! grep -rEq 'wp --path|db query|execSync|/srv/http|/home/' "$suite/regression" "$spec" "$cfg" \
  || fail "the regression suite shells out to wp-cli or names a local path -- it must work from the browser alone"

# 4. Every file parses and the pure logic passes.
while IFS= read -r f; do node --check "$f" >/dev/null 2>&1 || fail "$f does not parse"; done \
  < <(find "$suite/regression" "$suite/tests" "$suite/scripts" "$cfg" -name '*.js')
(cd "$suite" && node regression/helpers.selfcheck.js >/dev/null) || fail "regression/helpers.selfcheck.js fails"

# 5. The comparison fails on a regression and passes on identical runs (behavior, not wording).
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/scripts" "$tmp/regression" "$tmp/results/regression"
cp "$suite/scripts/regression-compare.js" "$tmp/scripts/"; cp "$suite/regression/helpers.js" "$tmp/regression/"
row() { printf '{"rows":[{"id":"cart","title":"c","project":"regression-desktop","status":"%s","evidence":"x","ms":1}],"sweep":[]}' "$1"; }
row PASS > "$tmp/results/regression/before.json"; row PASS > "$tmp/results/regression/same.json"; row FAIL > "$tmp/results/regression/after.json"
(cd "$tmp" && node scripts/regression-compare.js before same >/dev/null) || fail "compare flags identical runs as a regression"
if (cd "$tmp" && node scripts/regression-compare.js before after >/dev/null); then
  fail "compare does not exit non-zero when a flow goes PASS to FAIL"
fi

echo PASS
