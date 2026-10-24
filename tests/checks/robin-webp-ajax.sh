#!/usr/bin/env bash
# Robin's webp_delivery_mode=picture only processes template_redirect (the full page). HTML
# returned by admin-ajax kept serving PNG/JPEG beside an existing .webp (354 KB vs 39 KB), and
# neither the Robin reference nor the performance audit mentioned it. A heavier .webp was also
# preloaded for a background. The docs, the audit check and the hero verification must stay.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

D=skills/wp-robin/references/webp-delivery.md
A=agents/wp-audit-performance.md

grep -Fq 'template_redirect' "$D" || fail "webp-delivery.md does not say Robin only covers template_redirect"
grep -Fq 'admin-ajax' "$D" || fail "webp-delivery.md does not cover admin-ajax HTML"
grep -Fq 'ob_start' "$D" || fail "AJAX recipe lost the ob_start helper"
grep -Fq 'starting any buffer' "$D" || fail "AJAX recipe lost the availability-before-buffer rule"
grep -Fq 'early priority' "$D" || fail "AJAX recipe lost the early-priority hook"
grep -Fq 'internal class' "$D" || fail "AJAX recipe lost the coupling warning"
grep -Fq 'after every Robin update' "$D" || fail "AJAX recipe lost the re-check after updates"
grep -Fq 'curl' "$D" || fail "AJAX section lost the curl measurement"
grep -Fq 'weighs the same or more' "$D" || fail "lost the rule against a .webp that is not smaller"

grep -Fq 'webp-delivery.md' skills/wp-robin/SKILL.md || fail "SKILL.md does not point to webp-delivery.md"
grep -Fq 'infinite scroll' skills/wp-robin/SKILL.md || fail "SKILL.md troubleshooting lost the AJAX row"

grep -Fq '| PERF-078 |' "$A" || fail "PERF-078 row missing"
grep -Fq 'Procedure — AJAX-returned images and WebP (PERF-078)' "$A" || fail "PERF-078 procedure missing"
row=$(grep -F '| PERF-078 |' "$A")
grep -Fq 'wp_ajax_nopriv_' <<<"$row" || fail "PERF-078 does not locate wp_ajax_nopriv_ handlers"
grep -Fq 'UNMEASURED' <<<"$row" || fail "PERF-078 lost the UNMEASURED outcome"
[ "$(grep -c '^| PERF-078 |' "$A")" = 1 ] || fail "PERF-078 id is not unique"

grep -Fq 'LCP/hero image' commands/wp-robin.md || fail "wp-robin verification lost the hero webp check"

echo PASS
