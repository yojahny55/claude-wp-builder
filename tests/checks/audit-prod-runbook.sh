#!/usr/bin/env bash
# /wp-audit production runbook: the replay record of every applied fix renders as ordered
# production steps, with an nginx rule for every .htaccess fix and PHP-served endpoint.
#
# What shipped before: the replay log covered settings only, and every session wrote its
# "for production" list and its server steps by hand. On one adopted site deployed to nginx,
# .htaccess fixes (sensitive files, gzip/Expires, the WebP rewrite) were reported done and
# did nothing there; /llms.txt and /.well-known/* answered 404/403 because nginx served or
# denied them before WordPress; and a physical robots.txt in the web root shadowed the
# dynamic route and carried the local host.
#
# This check renders a fixture record through bin/audit-runbook.mjs and asserts the section
# order, the nginx snippets, the not-applied marking and that no local host leaks, then
# greps the prose that tells fix agents to write the record.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

gen=bin/audit-runbook.mjs
rules=skills/wp-audit-run/references/server-rules.md
fix=skills/wp-audit-run/references/fix.md
[ -f "$gen" ] || fail "$gen is missing"
[ -f "$rules" ] || fail "$rules is missing"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
site="$tmp/site"
mkdir -p "$site/wp-content/themes/child-theme/inc" "$tmp/out"
cat > "$site/.wp-create.json" <<'JSON'
{
  "wordpress": { "url": "https://www.demo.test" },
  "project": { "domain": "demo.test" },
  "stack": { "builder": "elementor", "cache": "none" },
  "environments": {
    "prod": { "role": "prod", "url": "https://www.example.org", "server": "nginx",
              "page_cache": "fastcgi-cache", "sync": { "tool": "envsync", "transport": "https" } }
  }
}
JSON
echo 'Sitemap: https://www.demo.test/sitemap_index.xml' > "$site/robots.txt"
echo '<?php // served at /llms.txt' > "$site/wp-content/themes/child-theme/inc/agentic.php"
cat > "$tmp/out/replay.json" <<'JSON'
{ "replay_version": 1, "entries": [
  { "check": "PERF-001", "kind": "code", "file": "wp-content/themes/child-theme/assets/fonts/a.woff2",
    "applied_in": "local", "applied_on": { "local": true, "prod": false } },
  { "check": "GEO-A01", "kind": "code", "file": "wp-content/themes/child-theme/inc/agentic.php",
    "endpoint": "/llms.txt", "needs_server_rule": true, "applied_in": "local", "applied_on": { "local": true, "prod": false } },
  { "check": "SEO-010", "kind": "db-option", "resource": "option:rank-math-options-general",
    "command": "$WP option patch update rank-math-options-general robots_txt_content 'Sitemap: https://www.demo.test/sitemap_index.xml' --path=/srv/x",
    "previous value": "", "applied_in": "local", "applied_on": { "local": true, "prod": false } },
  { "check": "SEO-020", "kind": "post-meta", "resource": "post:12.rank_math_description",
    "command": "wp post meta update 12 rank_math_description 'Text'", "previous value": null,
    "ids": [12], "selector": "wp post list --post_type=post --field=ID --name=<slug>",
    "applied_in": "local", "applied_on": { "local": true, "prod": false } },
  { "check": "SEC-030", "kind": "wp-config", "resource": "constant:DISALLOW_FILE_EDIT",
    "command": "wp config set DISALLOW_FILE_EDIT true --raw --type=constant", "previous value": null,
    "applied_in": "local", "applied_on": { "local": true, "prod": false } },
  { "check": "SEC-012", "kind": "server", "file": ".htaccess", "server_rule": "block-sensitive-files",
    "needs_server_rule": true, "applied_in": "local", "applied_on": { "local": true, "prod": false } },
  { "check": "PERF-020", "kind": "server", "file": ".htaccess", "server_rule": "compression",
    "needs_server_rule": true, "applied_in": "local", "applied_on": { "local": true, "prod": false } },
  { "check": "GEO-A05", "kind": "server", "file": ".htaccess", "endpoint": "/.well-known/",
    "needs_server_rule": true, "applied_in": "local", "applied_on": { "local": true, "prod": false } },
  { "check": "PERF-030", "kind": "post-deploy", "command": "wp media regenerate --only-missing --yes",
    "applied_in": "local", "applied_on": { "local": true, "prod": false } }
] }
JSON

run() { (cd "$site" && node "$OLDPWD/$gen" "$@"); }

# --- 1. render ----------------------------------------------------------------------------
out=$(run --out "$tmp/out" --date 2026-01-02) || fail "generator exited non-zero: $out"
md="$tmp/out/runbook-2026-01-02.md"
[ -f "$md" ] || fail "runbook not written at $md"
grep -Fq "wrote $md" <<<"$out" || fail "generator did not print the absolute path: $out"

# --- 2. section order ---------------------------------------------------------------------
prev=0
for h in '## 1. Pre-deploy checks' '## 2. Code' '## 3. wp-config.php' '## 4. Database' \
         '## 5. Server rules' '## 6. Post-deploy' '## 7. Verification'; do
  n=$(grep -nF -- "$h" "$md" | head -1 | cut -d: -f1)
  [ -n "$n" ] || fail "runbook lacks section: $h"
  [ "$n" -gt "$prev" ] || fail "section out of order: $h"
  prev=$n
done
awk '/^## 4\. /{d=1} d && /^### Options/{o=NR} d && /^### Post meta/{p=NR} END{exit !(o && p && o < p)}' "$md" \
  || fail "database section does not put options before post meta"
awk '/^## 6\. /{s=1} s && /wp elementor flush-css/{f=NR} s && /page cache/{c=NR} END{exit !(f && c && f < c)}' "$md" \
  || fail "post-deploy does not flush Elementor CSS before the page-cache purge"

# --- 3. server rules: nginx equivalents, Apache kept, marked not applied -------------------
for t in 'location = /llms.txt {' 'location ^~ /.well-known/ {' 'gzip on;' \
         'location ~ /\.(?!well-known/) { deny all; }' '```nginx' '```apache' 'RewriteRule . /index.php [L]'; do
  grep -Fq -- "$t" "$md" || fail "runbook lacks server snippet: $t"
done
[ "$(grep -c -- '— \*\*not applied\*\*' "$md")" = 4 ] || fail "every server entry (4) must be marked not applied"
grep -Fq 'need the server owner' "$md" || fail "server rules do not say they need the server owner"
grep -Fq 'fastcgi_cache_path' "$md" || fail "known FastCGI page cache has no purge step"

# --- 4. pre-deploy and DB rewriting -------------------------------------------------------
grep -Fq '**FOUND** `robots.txt` exists in the web root and shadows' "$md" || fail "physical robots.txt not flagged"
grep -Fq '`robots.txt` contains the development host' "$md" || fail "local host inside robots.txt not flagged"
grep -Fq 'git ls-files --error-unmatch -- wp-content/themes/child-theme/assets/fonts/a.woff2' "$md" \
  || fail "new asset is not checked as committed"
grep -Fq 'wp option get stylesheet --url=https://www.example.org' "$md" || fail "theme activation is not checked"
grep -Fq "robots_txt_content 'Sitemap: https://www.example.org/sitemap_index.xml' --url=https://www.example.org" "$md" \
  || fail "db command not rewritten to the production URL"
grep -Fq 'IDs come from the local database' "$md" || fail "post-meta IDs not flagged"
grep -Fq 'curl -s -o /dev/null -w '"'"'%{http_code} %{content_type}\n'"'"' https://www.example.org/llms.txt' "$md" \
  || fail "endpoint has no verification curl"

# --- 5. no local leak ---------------------------------------------------------------------
! grep -Fqi 'demo.test' "$md" || fail "runbook leaks the local host"
! grep -Fq -- '--path=' "$md" || fail "runbook keeps a local --path"
! grep -Fq '$WP' "$md" || fail "runbook keeps the \$WP wrapper"
! grep -Fq "$site" "$md" || fail "runbook leaks the local site root"

# --- 6. language, unknown server, refusals ------------------------------------------------
out=$(run --out "$tmp/out" --date 2026-01-03 --lang es) || fail "es render failed: $out"
grep -Fq '## 5. Reglas de servidor' "$tmp/out/runbook-2026-01-03.md" || fail "--lang es did not translate"
grep -Fq 'no aplicado' "$tmp/out/runbook-2026-01-03.md" || fail "--lang es lacks the not-applied mark"

out=$(run --out "$tmp/out" --date 2026-01-04 --server unknown) || fail "unknown-server render failed"
grep -Fq 'production web server is not recorded' "$tmp/out/runbook-2026-01-04.md" \
  || fail "unknown production server is not called out"
grep -Fq 'location = /llms.txt {' "$tmp/out/runbook-2026-01-04.md" || fail "unknown server must still get nginx rules"

refuse() {
  local why=$1 record=$2
  mkdir -p "$tmp/bad"; printf '%s' "$record" > "$tmp/bad/replay.json"
  set +e; run --out "$tmp/bad" --date 2026-01-05 >/dev/null 2>&1; rc=$?; set -e
  [ "$rc" = 1 ] || fail "$why: expected exit 1, got $rc"
  [ ! -f "$tmp/bad/runbook-2026-01-05.md" ] || fail "$why: a runbook was written anyway"
}
refuse "unrecorded local host" '[{"check":"X-1","kind":"db-option","command":"wp option update a http://other.test/x"}]'
refuse "unknown server rule" '[{"check":"X-2","kind":"server","file":".htaccess","server_rule":"made-up"}]'
refuse "db-option with no command" '[{"check":"X-3","kind":"db-option"}]'
refuse "unknown kind" '[{"check":"X-4","kind":"ftp","command":"x"}]'

# --- 6b. OCR findings: compound commands, endpoint without the flag, file names ----------
mkdir -p "$tmp/edge"
cat > "$tmp/edge/replay.json" <<'JSON'
[ { "check": "E-1", "kind": "db-option", "command": "$WP option get a --format=json | jq . && ${WP} option update b 1 --path /srv/x" },
  { "check": "E-2", "kind": "code", "file": "wp-content/themes/t/foo.test.js", "endpoint": "/llms.txt" } ]
JSON
run --out "$tmp/edge" --date 2026-01-07 >/dev/null || fail "a file name ending in .test.js was refused as a host"
e="$tmp/edge/runbook-2026-01-07.md"
grep -Fq 'wp option get a --format=json --url=https://www.example.org | jq . && wp option update b 1 --url=https://www.example.org' "$e" \
  || fail "compound command not rewritten on every wp call"
! grep -Fq -- '--path' "$e" || fail "space-form --path kept"
grep -Fq 'location = /llms.txt {' "$e" || fail "an endpoint without needs_server_rule got no nginx rule"

# --- 7. every rule in the table parses and renders ---------------------------------------
ids=$(grep -oE '^### `[a-z0-9-]+`' "$rules" | tr -d '#` ')
[ "$(wc -w <<<"$ids")" -ge 8 ] || fail "server-rules.md lost rules"
entries=$(for id in $ids; do printf '{"check":"R","kind":"server","file":".htaccess","server_rule":"%s","endpoint":"/x/"},' "$id"; done)
mkdir -p "$tmp/all"; printf '[%s]' "${entries%,}" > "$tmp/all/replay.json"
run --out "$tmp/all" --date 2026-01-06 >/dev/null || fail "a rule in server-rules.md does not render"
[ "$(grep -c '^```nginx' "$tmp/all/runbook-2026-01-06.md")" = "$(wc -w <<<"$ids")" ] \
  || fail "not every rule rendered an nginx block"

# --- 8. prose: fix agents write the record, nginx is never reported done for .htaccess ----
for t in '"kind"' '| `post-meta` |' '| `post-deploy` |' 'needs_server_rule' '`selector`' \
         'bin/audit-runbook.mjs' 'references/server-rules.md' '**Never** count it as' \
         'Never write that list, a runbook or a "server steps" file by hand'; do
  grep -Fq -- "$t" "$fix" || fail "fix.md lacks: $t"
done
! grep -Fq 'Every `setting` fix, and every content fix that writes to the database, is appended' "$fix" \
  || fail "fix.md still limits the replay log to settings"
awk '/^## Step 9: / { s = 1; next } /^## Step [0-9]+:/ && s { exit } s && /audit-runbook\.mjs/ { f = 1 } END { exit !f }' commands/wp-audit.md \
  || fail "wp-audit.md Step 9 does not name the runbook"
grep -Fq 'runbook-<AAAA-MM-DD>.md' skills/wp-audit-run/references/manifest-update.md || fail "summary does not print the runbook"
grep -Fq "'server', 'page_cache'" bin/lib/manifest.mjs || fail "manifest does not accept environments[].server/page_cache"
grep -Fq -- '--server=nginx --page-cache=' skills/wp-environments/SKILL.md || fail "wp-environments does not document --server"
echo PASS
