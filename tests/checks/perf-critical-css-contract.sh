#!/usr/bin/env bash
# Inline critical CSS was filed as "rejected" after one FCP-only experiment, while a real build
# made it work and then lost time to process failures: the second build script forgotten (cuts
# invalidated in silence), cuts stale after an update, two different page loads compared
# instead of one DOM, a decision on simulated LCP. The five conditions must stay written down,
# the auditor must keep the regenerate order, and bin/assets-fresh.mjs must really fail on a
# stale manifest and /wp-update must call it.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

L=skills/wp-audit-standards/references/performance-lessons.md
A=agents/wp-audit-performance.md

grep -Fq 'Inline critical CSS: conditional' "$L" || fail "lessons lost the conditional section"
! grep -Fq 'measured on a real site, and rejected' "$L" || fail "lessons still files inline critical CSS as rejected"
grep -Fq 'A cut per template group' "$L" || fail "condition 1 (cut per template group) missing"
grep -Fq 'loads without blocking' "$L" || fail "condition 2 (non-blocking full sheet) missing"
grep -Fq 'CONTENT (never mtime)' "$L" || fail "condition 3 (content hash invalidates the cut) missing"
grep -Fq 'SAME DOM' "$L" || fail "condition 4 (same-DOM verification) missing"
grep -Fq 'two page loads' "$L" || fail "condition 4 lost the ban on comparing two loads"
grep -Fq 'observed LCP' "$L" || fail "condition 5 (observed LCP) missing"

grep -Fq 'regenerate critical cuts' "$A" || fail "auditor lost the regenerate-cuts instruction"
grep -Fq 'cuts and the manifest' "$A" || fail "auditor lost the commit-together rule"
grep -Fq 'bin/assets-fresh.mjs' "$A" || fail "auditor does not call assets-fresh.mjs"
grep -Fq 'bin/assets-fresh.mjs' commands/wp-update.md || fail "/wp-update does not call assets-fresh.mjs"

command -v node >/dev/null || { echo "SKIP: node missing, behavior half not run"; echo PASS; exit 0; }
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT
mkdir -p "$t/assets/css" "$t/assets/critical"
echo 'a{color:red}' > "$t/assets/css/bundle.min.css"
echo 'a{color:red}' > "$t/assets/critical/single.css"
h=$(node -e 'const fs=require("fs"),crypto=require("crypto");process.stdout.write(crypto.createHash("sha256").update(fs.readFileSync(process.argv[1])).digest("hex"))' "$t/assets/css/bundle.min.css")
printf '{"sheets":{"assets/css/bundle.min.css":"%s"},"cuts":{"assets/critical/single.css":{"source":"assets/css/bundle.min.css","hash":"%s"}}}' "$h" "$h" > "$t/assets/build.json"
node bin/assets-fresh.mjs "$t" >/dev/null || fail "fresh manifest was reported stale"
printf '{"cuts":{"assets/critical/single.css":{"hash":"%s"}}}' "$h" > "$t/assets/build.json"
if node bin/assets-fresh.mjs "$t" >"$t/malformed.out" 2>&1; then fail "cut without a source was accepted"; else rc=$?; [[ $rc -eq 2 ]] || fail "malformed manifest exited $rc, expected 2"; fi
grep -Fq 'missing required "source" or "hash" property' "$t/malformed.out" || fail "malformed manifest lacks a clear schema error"
printf '{"sheets":{"assets/css/bundle.min.css":"%s"},"cuts":{"assets/critical/single.css":{"source":"assets/css/bundle.min.css","hash":"%s"}}}' "$h" "$h" > "$t/assets/build.json"
echo 'a{color:blue}' > "$t/assets/css/bundle.min.css"
out=$(node bin/assets-fresh.mjs "$t" 2>&1) && fail "changed sheet passed as fresh"
printf '%s' "$out" | grep -Fq 'regenerate critical cuts' || fail "stale output lacks the message"
rm "$t/assets/build.json"
node bin/assets-fresh.mjs "$t" | grep -Fq SKIP || fail "missing manifest should SKIP"

echo PASS
