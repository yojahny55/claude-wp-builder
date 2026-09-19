#!/usr/bin/env bash
# validateManifest() and validateProfile() used to check that a field was PRESENT and stop
# there. Three things got through, all found by probing the validators directly rather than
# by any check failing:
#
#   wp_cli.wrapper: []        -- not undefined, null or '', so "required" was satisfied.
#                                It is interpolated into a shell command by every command
#                                that runs WP-CLI, so the failure surfaced as a mangled
#                                command line, not as a bad manifest.
#   wordpress.url: {}         -- same shape, and it reaches `wp search-replace`.
#   manifest_version: "99"    -- Number.isInteger("99") is false, so detectVersion read it
#                                as ABSENT, absent means legacy 1, and a manifest from a
#                                future plugin was offered for migration DOWN to this one.
#                                A pair of quotes defeated the future-version guard.
#   tested: 42                -- an allowed profile key with no defined meaning and no
#                                validation: a compatibility claim that bound nobody.
#
# These assertions call the exported functions directly. A manifest fixture on disk would
# exercise the CLI's file handling too, which other checks already own; what was missing
# here is the rule itself.
set -uo pipefail

cd "$(dirname "$0")/../.." || exit 1
fails=0
fail() { printf 'FAIL: %s\n' "$1"; fails=$((fails + 1)); }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

cat > "$work/probe.mjs" <<'EOF'
import { validateManifest, validateProfile, versionProblem, testedVerdicts } from './bin/lib/manifest.mjs';

const ok = {
  manifest_version: 3,
  project: { name: 'Demo', slug: 'demo', path: '/tmp/demo' },
  environment: { type: 'local', engine: 'wp-env' },
  wordpress: { url: 'http://demo.test' },
  wp_cli: { wrapper: 'wp' },
  theme: { slug: 'demo-theme' },
  languages: { primary: 'en' },
};
const set = (base, path, value) => {
  const next = structuredClone(base);
  const keys = path.split('.');
  let cur = next;
  while (keys.length > 1) cur = cur[keys.shift()];
  cur[keys[0]] = value;
  return next;
};

const out = [];
const emit = (name, value) => out.push(`${name}\t${value}`);

emit('baseline-clean', validateManifest(ok).length === 0 ? 'yes' : `no: ${validateManifest(ok).join('; ')}`);
emit('wrapper-array', validateManifest(set(ok, 'wp_cli.wrapper', [])).length > 0 ? 'rejected' : 'ACCEPTED');
emit('url-object', validateManifest(set(ok, 'wordpress.url', {})).length > 0 ? 'rejected' : 'ACCEPTED');
emit('slug-number', validateManifest(set(ok, 'project.slug', 7)).length > 0 ? 'rejected' : 'ACCEPTED');
emit('version-string', validateManifest(set(ok, 'manifest_version', '99')).length > 0 ? 'rejected' : 'ACCEPTED');
emit('version-float', validateManifest(set(ok, 'manifest_version', 1.5)).length > 0 ? 'rejected' : 'ACCEPTED');
emit('version-zero', validateManifest(set(ok, 'manifest_version', 0)).length > 0 ? 'rejected' : 'ACCEPTED');
// Absence still means "predates versioning" -- the legacy projects this must not break.
const legacy = structuredClone(ok);
delete legacy.manifest_version;
emit('version-absent', versionProblem(legacy) === null ? 'allowed' : 'REJECTED');
emit('version-absent-valid', validateManifest(legacy).length === 0 ? 'yes' : 'no');
// An optional context field renders into the generated block the same way.
emit('demo-mode-object', validateManifest({ ...ok, 'demo mode': {} }).length > 0 ? 'rejected' : 'ACCEPTED');

const profile = (tested) => ({ name: 'p', plugins: [{ slug: 'contact-form-7', tested }] });
emit('tested-42', validateProfile(profile(42)).length > 0 ? 'rejected' : 'ACCEPTED');
emit('tested-word', validateProfile(profile('latest')).length > 0 ? 'rejected' : 'ACCEPTED');
emit('tested-version', validateProfile(profile('6.4')).length === 0 ? 'accepted' : 'REJECTED');
emit('tested-patch', validateProfile(profile('6.4.2')).length === 0 ? 'accepted' : 'REJECTED');
emit('tested-range', validateProfile(profile('6.0 - 6.6')).length === 0 ? 'accepted' : 'REJECTED');
emit('tested-backwards', validateProfile(profile('6.6 - 6.0')).length > 0 ? 'rejected' : 'ACCEPTED');
emit('tested-absent', validateProfile({ name: 'p', plugins: [{ slug: 'x' }] }).length === 0 ? 'accepted' : 'REJECTED');

// The value is read, not only validated.
emit('verdict-below', testedVerdicts(profile('6.5 - 6.6'), '6.2').some((l) => l.includes('BELOW')) ? 'reported' : 'SILENT');
emit('verdict-above', testedVerdicts(profile('6.0 - 6.2'), '6.9').some((l) => l.includes('ABOVE')) ? 'reported' : 'SILENT');
emit('verdict-inside', testedVerdicts(profile('6.0 - 6.6'), '6.4').length === 0 ? 'quiet' : 'NOISY');
emit('verdict-edge-low', testedVerdicts(profile('6.0 - 6.6'), '6.0').length === 0 ? 'quiet' : 'NOISY');
emit('verdict-edge-high', testedVerdicts(profile('6.0 - 6.6'), '6.6').length === 0 ? 'quiet' : 'NOISY');
// "6.4" and "6.4.0" are the same WordPress; a naive string compare says otherwise.
emit('verdict-segments', testedVerdicts(profile('6.4'), '6.4.0').length === 0 ? 'quiet' : 'NOISY');
emit('verdict-untested', testedVerdicts({ name: 'p', plugins: [{ slug: 'x' }] }, '6.4').some((l) => l.includes('untested')) ? 'reported' : 'SILENT');


// A check id is an address, not a version. `SEC-036@2` says which revision of the rule was
// measured, so a rewritten check stops counting as covered by a run that predates it. A
// bare id means revision 1 -- what every id written before this meant -- so the bare form
// must keep validating or every existing project history becomes invalid.
const withIds = (ids) => ({ ...ok, audit: { checks_run: { security: ids } } });
emit('id-bare', validateManifest(withIds(['SEC-036'])).length === 0 ? 'accepted' : 'REJECTED');
emit('id-revision', validateManifest(withIds(['SEC-036@2'])).length === 0 ? 'accepted' : 'REJECTED');
emit('id-revision-geo', validateManifest(withIds(['GEO-A11@3'])).length === 0 ? 'accepted' : 'REJECTED');
emit('id-revision-zero', validateManifest(withIds(['SEC-036@0'])).length > 0 ? 'rejected' : 'ACCEPTED');
emit('id-revision-word', validateManifest(withIds(['SEC-036@x'])).length > 0 ? 'rejected' : 'ACCEPTED');

console.log(out.join('\n'));
EOF

cp "$work/probe.mjs" ./.probe-types.mjs
result="$(node ./.probe-types.mjs 2>&1)"
status=$?
rm -f ./.probe-types.mjs
if [ "$status" -ne 0 ]; then
  fail "the probe did not run: $result"
  printf 'FAILED %d\n' "$fails"
  exit 1
fi

expect() {
  local name="$1" want="$2" got
  got="$(printf '%s\n' "$result" | awk -F'\t' -v n="$name" '$1 == n { print $2 }')"
  [ "$got" = "$want" ] || fail "$name: expected '$want', got '${got:-<no result>}'"
}

expect baseline-clean       yes
expect wrapper-array        rejected
expect url-object           rejected
expect slug-number          rejected
expect version-string       rejected
expect version-float        rejected
expect version-zero         rejected
expect version-absent       allowed
expect version-absent-valid yes
expect demo-mode-object     rejected
expect tested-42            rejected
expect tested-word          rejected
expect tested-version       accepted
expect tested-patch         accepted
expect tested-range         accepted
expect tested-backwards     rejected
expect tested-absent        accepted
expect verdict-below        reported
expect verdict-above        reported
expect verdict-inside       quiet
expect verdict-edge-low     quiet
expect verdict-edge-high    quiet
expect verdict-segments     quiet
expect verdict-untested     reported
expect id-bare              accepted
expect id-revision          accepted
expect id-revision-geo      accepted
expect id-revision-zero     rejected
expect id-revision-word     rejected

if [ "$fails" -gt 0 ]; then
  printf 'FAILED %d\n' "$fails"
  exit 1
fi
printf 'PASS: manifest and profile validators reject malformed types and versions (29 assertions)\n'
