#!/usr/bin/env bash
# Builders on adopted sites: /wp-init, /wp-section, /wp-seed and the rest assume a starter theme
# and did not read `origin`, so on an adopted site (third-party theme) they could overwrite it.
# Every builder must call `wp-config.mjs require-origin`; the non-builders (audit, debug, update,
# clone, adopt...) must not, or they become unusable on the very sites they exist for. And the
# script itself must refuse (exit 5), let `--force-adopted` through, and pass a created site.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

builders="init section seed yolo header footer page cpt settings tailwind-migrate cinematic-init cinematic-scene cinematic-seed"
for b in $builders; do
  f="commands/wp-$b.md"
  grep -Eq 'wp-config\.mjs"? require-origin' "$f" || fail "$f does not call wp-config.mjs require-origin"
  grep -Fq -- '--force-adopted' "$f" || fail "$f does not document --force-adopted"
done

for n in audit debug update clone anonymize finalize robin s3 s3-media demo create context; do
  f="commands/wp-$n.md"
  [ -f "$f" ] || continue
  ! grep -Eq 'wp-config\.mjs"? require-origin' "$f" || fail "$f is not a builder and must not be gated by require-origin"
done

grep -Fq 'adds 5' <(sed -n 1,12p bin/wp-config.mjs) || fail "wp-config.mjs header does not document exit 5"

t="$(mktemp -d)"; trap 'rm -rf "$t"' EXIT
run() { node bin/wp-config.mjs require-origin "$@" >/dev/null 2>&1; echo $?; }
mkdir "$t/created" "$t/adopted" "$t/none"
echo '{"manifest_version":1}' > "$t/created/.wp-create.json"
echo '{"origin":"adopted"}' > "$t/adopted/.wp-create.json"
[ "$(run "$t/created")" = 0 ] || fail "created site must pass require-origin"
[ "$(run "$t/none")" = 0 ] || fail "no manifest must pass (validate owns that case)"
[ "$(run "$t/adopted")" = 5 ] || fail "adopted site must exit 5"
[ "$(run "$t/adopted" --force-adopted)" = 0 ] || fail "--force-adopted must let an adopted site through"
msg="$(node bin/wp-config.mjs require-origin "$t/adopted" 2>&1 || true)"
case "$msg" in *'use /wp-audit, /wp-debug or /wp-update'*) ;; *) fail "the refusal does not point at /wp-audit, /wp-debug or /wp-update" ;; esac

echo PASS
