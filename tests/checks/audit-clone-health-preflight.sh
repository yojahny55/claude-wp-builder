#!/usr/bin/env bash
# An audit ran on a local Apache clone of an nginx-served site. The clone had no .htaccess, so
# every internal URL answered 404 while home answered 200; the page measurements were wrong
# until a person asked about it. `wp rewrite flush --hard` wrote nothing (WP-CLI does not
# detect mod_rewrite), and the vhost answered HTTP only, so an https check was invalid.
# bin/clone-preflight.sh must find that before any agent runs, offer the stock block without
# writing it unasked, and keep the written file local-only. This runs the script for real
# against a fake `wp` and a localhost HTTP server, and greps the prose that makes the audit
# call it, pass the scheme on, and mark page checks UNMEASURED when it fails.
set -euo pipefail
cd "$(dirname "$0")/../.."
root=$(pwd)
fail() { echo "FAIL: $*"; exit 1; }
need() { grep -Fq -- "$2" "$1" || fail "$1 lacks: $2"; }

s=bin/clone-preflight.sh
[ -x "$s" ] || fail "$s missing or not executable"
command -v python3 >/dev/null 2>&1 || { echo "SKIP: python3 not available"; echo PASS; exit 0; }
command -v curl >/dev/null 2>&1 || { echo "SKIP: curl not available"; echo PASS; exit 0; }

t=$(mktemp -d); pid=""
trap '[ -n "$pid" ] && kill "$pid" 2>/dev/null; rm -rf "$t"' EXIT
mkdir -p "$t/site" "$t/bin"

# Fake server: / is always 200; any other path is 200 only once the docroot's .htaccess has
# the WordPress block, like Apache with mod_rewrite does.
cat > "$t/srv.py" <<PY
import http.server, os, sys
site = sys.argv[1]
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        ok = self.path == "/"
        try:
            ok = ok or "BEGIN WordPress" in open(os.path.join(site, ".htaccess")).read()
        except OSError:
            pass
        self.send_response(200 if ok else 404)
        self.send_header("Server", "Apache/2.4")
        self.end_headers()
    def log_message(self, *a): pass
s = http.server.HTTPServer(("127.0.0.1", 0), H)
print(s.server_address[1], flush=True)
s.serve_forever()
PY
python3 "$t/srv.py" "$t/site" > "$t/port" &
pid=$!
for _ in $(seq 1 50); do [ -s "$t/port" ] && break; sleep 0.1; done
port=$(cat "$t/port"); [ -n "$port" ] || fail "fake server did not start"

# Fake wp: URLs name the clone's production-era host, to prove they are re-rooted.
cat > "$t/bin/wp" <<'SH'
#!/usr/bin/env bash
case "$*" in
  "option get permalink_structure") echo "${FAKE_STRUCT-/%postname%/}" ;;
  *"eval echo ABSPATH;"*) echo "$FAKE_ROOT/" ;;
  *"post list --post_type=post"*) echo "http://site.example/a-post/" ;;
  *"post list --post_type=page"*) echo "http://site.example/a-page/" ;;
  *"term list"*) echo 7 ;;
  *"get_term_link"*) echo "http://site.example/category/news/" ;;
esac
SH
chmod +x "$t/bin/wp"
export FAKE_ROOT="$t/site"
run() { bash "$root/$s" --url "http://127.0.0.1:$port" --wp "$t/bin/wp" --root "$t/site" "$@"; }

# 1. No .htaccess: home 200, internal 404 -> exit 4, diagnosis names the file, nothing written.
out=$(run) && fail "missing .htaccess exited 0"
echo "$out" | grep -Fq 'scheme=http' || fail "scheme not reported"
echo "$out" | grep -Fq 'probe_post=404' || fail "post probe did not see the 404"
echo "$out" | grep -Fq 'htaccess=missing' || fail "missing .htaccess not detected"
echo "$out" | grep -Fq 'diagnosis=htaccess-missing' || fail "wrong diagnosis"
[ ! -e "$t/site/.htaccess" ] || fail "script wrote .htaccess without --write-htaccess"

# 2. Plain permalinks are named, not blamed on rewrites.
out=$(FAKE_STRUCT= run) && fail "plain permalinks case exited 0 with 404s"
echo "$out" | grep -Fq 'permalinks=plain' || fail "plain permalinks not reported"
echo "$out" | grep -Fq 'diagnosis=plain-permalinks' || fail "plain permalinks not diagnosed"

# 3. An existing file with no WordPress block is backed up and extended, never overwritten.
printf 'Options -Indexes\n' > "$t/site/.htaccess"
out=$(run) && fail "no-wp-block case exited 0"
echo "$out" | grep -Fq 'htaccess=no-wp-block' || fail "no-wp-block not detected"
out=$(run --write-htaccess) || fail "--write-htaccess did not end healthy"
echo "$out" | grep -Fq 'backup=' || fail "no backup reported"
ls "$t/site"/.htaccess.bak-* >/dev/null 2>&1 || fail "backup file missing"
grep -Fq 'Options -Indexes' "$t/site/.htaccess" || fail "existing rules were lost"
grep -Fq '# BEGIN WordPress' "$t/site/.htaccess" || fail "stock block not written"
echo "$out" | grep -Fq 'diagnosis=ok' || fail "not healthy after the write"

# 4. Local-only: a git work tree gets an info/exclude entry, never a .gitignore edit.
rm -f "$t/site"/.htaccess*
git -C "$t/site" init -q
out=$(run --write-htaccess) || fail "write into a git tree failed"
echo "$out" | grep -Fq 'local_only=' || fail "local-only status not reported"
git -C "$t/site" check-ignore -q .htaccess || fail ".htaccess not excluded locally"
[ ! -e "$t/site/.gitignore" ] || fail "script edited .gitignore"

# 5. Unreachable host.
out=$(bash "$root/$s" --url "http://127.0.0.1:1" --wp "$t/bin/wp" --root "$t/site") && fail "dead host exited 0"
echo "$out" | grep -Fq 'diagnosis=host-unreachable' || fail "dead host not diagnosed"

# Prose: the audit calls it before dispatch, passes the scheme, asks first, and never goes on quietly.
. tests/checks/lib/expand-command.sh; expand_command commands/wp-audit.md
a=$EXPANDED
need "$a" '### Clone health preflight'
need "$a" 'bin/clone-preflight.sh'
need "$a" 'before any agent is dispatched'
need "$a" 'Audited scheme:'
need "$a" '--write-htaccess'
need "$a" 'only after the user said yes'
need "$a" 'wp rewrite flush --hard'
need "$a" 'UNMEASURED: clone does not serve internal URLs'
need "$a" 'local-only'
need skills/wp-audit-run/references/dispatch.md '- Audited scheme:'
need bin/wp-config.mjs '.htaccess.bak-*'
echo PASS
