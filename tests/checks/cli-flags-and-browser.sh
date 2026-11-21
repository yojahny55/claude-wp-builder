#!/usr/bin/env bash
# Two pieces of tool hygiene that used to fail silently.
#
# 1. wp-config.mjs subcommands that take flags refuse what they do not know. The old parser
#    kept only arguments matching `--name[=value]` and dropped the rest without a word, so
#    `adopt --replce` ran as a plain adopt and `git-init --branch main` (a space, not `=`)
#    ran with no branch at all.
# 2. Chromium is resolved in one place, bin/lib/browsers.mjs. demo-verify, composition-preview
#    and tailwindify-parity each carried their own copy, read WP_DEMO_CHROME instead of
#    WP_BROWSER_CHROMIUM, preferred the system Chrome over the revision playwright-core pins,
#    and took the first cache directory readdir happened to return.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $1"; exit 1; }
command -v node >/dev/null || { echo "SKIP: node not found"; exit 0; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

run() { rc=0; out=$(node bin/wp-config.mjs "$@" 2>&1) || rc=$?; }

run adopt "$tmp" --replce
[ "$rc" = 1 ] || fail "adopt --replce exited $rc, want 1"
grep -Fq 'unknown flag --replce' <<<"$out" || fail "adopt --replce did not name the unknown flag: $out"
grep -Fq 'nothing done' <<<"$out" || fail "adopt --replce did not say nothing was done"

run git-init "$tmp" --branch main
[ "$rc" = 1 ] || fail "git-init --branch main exited $rc, want 1"
grep -Fq "unexpected argument 'main'" <<<"$out" || fail "git-init did not reject the space-separated value: $out"

run env-set "$tmp" --Role=prod
[ "$rc" = 1 ] || fail "env-set --Role=prod exited $rc, want 1"
grep -Fq 'malformed flag --Role=prod' <<<"$out" || fail "an uppercase flag name was not refused: $out"

# A known flag still parses, and keep-inactive's positional slug is not read as a stray argument.
run require-origin "$tmp" --force-adopted
[ "$rc" = 0 ] || fail "require-origin --force-adopted exited $rc on a root with no manifest: $out"
run keep-inactive "$tmp" akismet --unset
grep -Fq 'unexpected argument' <<<"$out" && fail "keep-inactive read its plugin slug as a stray argument: $out"
grep -Fq 'unknown flag' <<<"$out" && fail "keep-inactive refused --unset: $out"

# 2. One resolver.
for f in bin/*.mjs; do
  if grep -Eq 'function findChrome|WP_DEMO_CHROME' "$f"; then
    fail "$f resolves Chrome on its own; use findBrowser('chromium') from bin/lib/browsers.mjs"
  fi
done
for f in bin/demo-verify.mjs bin/composition-preview.mjs bin/tailwindify-parity.mjs; do
  grep -Fq "findBrowser('chromium')" "$f" || fail "$f does not resolve Chromium through findBrowser"
done

# The legacy variable is honoured only when it names an executable, and the current one wins.
fake="$tmp/chrome"; other="$tmp/chromium-pinned"
printf '#!/bin/sh\n' >"$fake"; printf '#!/bin/sh\n' >"$other"; chmod +x "$fake" "$other"
got=$(WP_BROWSER_CHROMIUM='' WP_DEMO_CHROME="$fake" node bin/lib/browsers.mjs chromium 2>/dev/null || true)
[ "$got" = "$fake" ] || fail "WP_DEMO_CHROME pointing at an executable was not used (got '$got')"
got=$(WP_BROWSER_CHROMIUM="$other" WP_DEMO_CHROME="$fake" node bin/lib/browsers.mjs chromium 2>/dev/null || true)
[ "$got" = "$other" ] || fail "WP_BROWSER_CHROMIUM did not win over WP_DEMO_CHROME (got '$got')"
got=$(WP_BROWSER_CHROMIUM='' WP_DEMO_CHROME="$tmp/missing" node bin/lib/browsers.mjs chromium 2>/dev/null || true)
[ "$got" != "$tmp/missing" ] || fail "a WP_DEMO_CHROME that does not exist was returned"

echo "PASS: wp-config refuses unknown flags; Chromium resolves through bin/lib/browsers.mjs only"
