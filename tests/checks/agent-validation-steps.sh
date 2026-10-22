#!/usr/bin/env bash
# wp-acf and wp-cf7 generate PHP under fine-grained rules and run on haiku; wp-normalize
# (opus) writes the manifest the whole build follows. Their tests grep prose, so a file that
# does not parse -- or a manifest that does not -- shipped unnoticed. Each agent now ends in a
# mandatory validation step it can actually run, so each must hold Bash, name the step, and
# keep it as the LAST section (a step buried mid-file is skipped).
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

for a in wp-acf wp-cf7 wp-normalize; do
  f=agents/$a.md
  grep -Eq '^tools:.*\bBash\b' "$f" || fail "$f has no Bash, so its validation step cannot run"
  grep -Fq '## Final validation' "$f" || fail "$f has no final validation section"
  last=$(grep -n '^## ' "$f" | tail -1)
  case "$last" in *'Final validation'*) ;; *) fail "$f: the final validation is not its last section ($last)";; esac
done
grep -Fq 'php -l' agents/wp-acf.md || fail "wp-acf does not lint the fields files"
grep -Fq 'php -l' agents/wp-cf7.md || fail "wp-cf7 does not lint the seeder"
grep -Fq 'wp-config.mjs validate' agents/wp-acf.md || fail "wp-acf does not re-run the manifest gate"
grep -Fq 'wp-config.mjs validate' agents/wp-cf7.md || fail "wp-cf7 does not re-run the manifest gate"
grep -Fq '.yolo-manifest.json' agents/wp-normalize.md && grep -Fq 'JSON.parse' agents/wp-normalize.md \
  || fail "wp-normalize does not parse the manifest it wrote"
grep -Fq 'for this step **only**' agents/wp-normalize.md || fail "wp-normalize's Bash grant lost its scope limit"
echo PASS
