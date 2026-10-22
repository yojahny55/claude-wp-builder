#!/usr/bin/env bash
# Remote environments were unknown to the plugin: the prod gates of /wp-update, /wp-clone and
# /wp-audit compared URLs, the EnvSync lessons (a forced push overwriting what only needed
# adding, a stale saved plan, a token pasted in chat) lived nowhere, and /wp-clone Path A
# dumped an unmeasured, uncompressed, non-resumable database. This check pins the schema (run
# for real), the recipes, the gates and the Path A contract.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
has() { grep -Fq -- "$2" "$1" || fail "$1 lacks: $2"; }

# 1. Schema, exercised for real.
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
node --input-type=module <<'JS' || fail "validateEnvironments does not enforce the schema"
import { validateEnvironments as v } from './bin/lib/manifest.mjs';
const ok = { prod: { role: 'prod', url: 'https://a.example', sync: { tool: 'envsync', transport: 'https', allow_http: false } } };
if (v(ok).length) { console.error(v(ok)); process.exit(1); }
const bad = (e) => { if (!v(e).length) { console.error('accepted', JSON.stringify(e)); process.exit(1); } };
bad({ p: { role: 'live', url: 'https://a.example' } });
bad({ 'bad.name': { role: 'prod', url: 'https://a.example' } });
bad({ first: { role: 'prod', url: 'https://a.example' }, second: { role: 'prod', url: 'https://b.example' } });
bad({ p: { role: 'prod', url: 'a.example' } });
bad({ p: { role: 'prod', url: 'https://a.example', sync: { tool: 'envsync', transport: 'https', token: 'x' } } });
bad({ p: { role: 'prod', url: 'https://a.example', token: 'x' } });
bad({ p: { role: 'prod', url: 'http://a.example', sync: { tool: 'envsync', transport: 'http' } } });
JS

# Missing sync sub-flags should fail with direct usage guidance before the manifest is changed.
cat > "$tmp/.wp-create.json" <<'JSON'
{
  "manifest_version": 3,
  "project": { "name": "Demo", "slug": "demo", "path": "/tmp/demo" },
  "environment": { "type": "local", "engine": "wp-env" },
  "wordpress": { "url": "http://demo.test" },
  "wp_cli": { "wrapper": "wp" },
  "theme": { "slug": "demo-theme" },
  "languages": { "primary": "en" }
}
JSON
set +e
out=$(node bin/wp-config.mjs env-set "$tmp" --name=staging --role=staging --url=https://stage.example --sync=envsync 2>&1)
rc=$?
set -e
[ "$rc" = 1 ] && grep -Fq -- '--sync requires --transport=http|https' <<<"$out" \
  || fail "env-set did not give direct guidance for a missing transport: $out"
set +e
out=$(node bin/wp-config.mjs env-set "$tmp" --name=staging --role=staging --url=https://stage.example --sync=envsync --transport=http 2>&1)
rc=$?
set -e
[ "$rc" = 1 ] && grep -Fq -- '--transport=http requires --allow-http' <<<"$out" \
  || fail "env-set did not give direct guidance for HTTP without opt-in: $out"
has bin/wp-config.mjs "env-set"
grep -Fq 'manifest.environments' bin/lib/adopt.mjs || grep -Fq 'old.environments' bin/lib/adopt.mjs || fail "adopt --replace drops environments"

# 2. Recipes and the token rule.
s=skills/wp-environments/SKILL.md; r=skills/wp-environments/references/sync-environments.md
[ -f "$r" ] || fail "$r missing"
has "$s" "references/sync-environments.md"
has "$s" 'environments[*].role == prod'
for k in '/hash/files' '--only=uploads' '--paths=' '--dry-run' '--exclude-tables' 'explicit confirmation' '--plan=' 'same invocation' 'git check-ignore' 'pasted into the chat'; do
  grep -Fqi -- "$k" "$r" || fail "$r lacks: $k"
done
! grep -Eqi 'token[^a-z]*[:=][^ ]{12,}' "$r" "$s" || fail "a token-looking value is written in the docs"

# 3. Gates read the role and keep the URL fallback.
for f in commands/wp-update.md commands/wp-clone.md skills/wp-audit-run/references/browser-suite.md; do
  grep -Fq 'role: "prod"' "$f" || fail "$f does not gate on role: \"prod\""
  grep -Eqi 'fall ?back|Without `environments`' "$f" || fail "$f lost the URL fallback"
done
has commands/wp-adopt.md "envsync env list"
has commands/wp-adopt.md "env-set"

# 4. Path A: measured, compressed, consistent, resumable.
a=skills/wp-clone-run/references/path-a.md
for k in information_schema 'data_length+index_length' 'top 10' '--single-transaction' '| gzip' 'rsync --partial' 'gunzip -f' '--exclude_tables' 'wp envsync'; do
  has "$a" "$k"
done
! grep -Fq 'scp user@host' "$a" || fail "$a still downloads the dump with scp"
ls changes/*.md >/dev/null 2>&1 || fail "no changelog entries in changes/"

echo PASS
