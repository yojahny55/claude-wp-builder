#!/usr/bin/env bash
# Compositions are the craft skill's positive examples: what a good section looks
# like, rendered. Each one must be convertible (delimiters, data-motion contract,
# tokens only) and honest about where its effect came from.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

r=bin/composition-preview.mjs
[ -f "$r" ] || fail "$r is missing"
[ -x "$r" ] || fail "$r is not executable"
node --check "$r" || fail "$r is not valid JavaScript"
grep -Fq '_preview.md' "$r" || fail "$r does not render against _preview.md"
grep -Fq 'preview-1440.png' "$r" || fail "$r does not write preview-1440.png"
grep -Fq 'preview-390.png' "$r" || fail "$r does not write preview-390.png"
grep -Fq 'motion.js' "$r" || fail "$r does not load the plugin's motion engine"
grep -Fq 'process.exit(2)' "$r" || fail "$r does not exit 2 with no browser"

echo PASS
