#!/usr/bin/env bash
# bin/wp-env-setup.sh used --domain= unvalidated in `sudo rm -f /etc/ssl/certs/$domain.crt`
# (so "../x" or "a/b" walked out of the cert directory), as an unanchored regex in
# `sed -i "/127.0.0.1 $domain/d" /etc/hosts` (removing foo.local also deleted foo.local.es
# and myfoo.local) and in an unanchored `grep -q` (an existing foo.local.es made foo.local
# look already present). ssl-generate also issued a CN-only cert with stderr hidden.
# bin/wp-cinematic-encode.sh pasted --scene= into the PHP of `wp eval`, so a crafted value
# ran code. This check runs both scripts against stubs and fixtures only: sudo, openssl and
# wp are fakes on a temporary PATH, and the hosts file is a temporary copy.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
env_sh=bin/wp-env-setup.sh
enc_sh=bin/wp-cinematic-encode.sh

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/fakebin"
log="$tmp/calls.log"
# sudo never escalates: it logs the call and only really runs sed/tee, which the
# tests point at a temporary hosts file.
cat > "$tmp/fakebin/sudo" <<STUB
#!/usr/bin/env bash
echo "sudo \$*" >> "$log"
case "\$1" in sed|tee) exec "\$@";; esac
exit 0
STUB
for b in openssl wp; do
  printf '#!/usr/bin/env bash\necho "%s $*" >> "%s"\n' "$b" "$log" > "$tmp/fakebin/$b"
done
chmod +x "$tmp/fakebin/"*
export PATH="$tmp/fakebin:$PATH"
export WP_ENV_HOSTS_FILE="$tmp/hosts"

# ---- wp-env-setup.sh: hostile domains are refused before anything acts ------
bad=('../x' 'a/b' 'a b' 'foo.local;rm' 'foo.local$(id)' '-rf' '.foo' 'foo.' 'Foo.local' 'a|b' '*' 'a&b')
for cmd in ssl-generate hosts-add hosts-remove native-remove; do
  for d in "${bad[@]}"; do
    : > "$log"; printf '127.0.0.1 keep.local\n' > "$tmp/hosts"
    if bash "$env_sh" "$cmd" "--domain=$d" >/dev/null 2>&1; then
      fail "$cmd accepted hostile domain '$d'"
    fi
    [ ! -s "$log" ] || fail "$cmd ran commands for hostile domain '$d': $(cat "$log")"
    [ "$(cat "$tmp/hosts")" = '127.0.0.1 keep.local' ] || fail "$cmd changed the hosts file for '$d'"
  done
done
: > "$log"
bash "$env_sh" native-setup --domain='x/../y' --document-root=/tmp/none --web-server=nginx >/dev/null 2>&1 \
  && fail "native-setup accepted a path-like domain"
[ ! -s "$log" ] || fail "native-setup acted before validating the domain"

# ---- hosts-remove only removes the exact name -------------------------------
printf '%s\n' '127.0.0.1 foo.local' '127.0.0.1 foo.local.es' '127.0.0.1 myfoo.local' \
  '127.0.0.1   fooXlocal' '127.0.0.1 keep.local foo.local' > "$tmp/hosts"
bash "$env_sh" hosts-remove --domain=foo.local >/dev/null 2>&1 || fail "hosts-remove failed on a valid domain"
! grep -Fxq '127.0.0.1 foo.local' "$tmp/hosts" || fail "hosts-remove left the exact entry"
for keep in '127.0.0.1 foo.local.es' '127.0.0.1 myfoo.local' '127.0.0.1   fooXlocal'; do
  grep -Fxq -- "$keep" "$tmp/hosts" || fail "hosts-remove also deleted '$keep'"
done

# ---- hosts-add: a longer name is not an existing entry ----------------------
printf '127.0.0.1 foo.local.es\n' > "$tmp/hosts"; : > "$log"
bash "$env_sh" hosts-add --domain=foo.local >/dev/null 2>&1
grep -Fxq '127.0.0.1 foo.local' "$tmp/hosts" || fail "hosts-add skipped foo.local because foo.local.es exists"
bash "$env_sh" hosts-add --domain=foo.local >/dev/null 2>&1
[ "$(grep -Fxc '127.0.0.1 foo.local' "$tmp/hosts")" = 1 ] || fail "hosts-add duplicated an existing entry"

# ---- ssl-generate: SAN present, stderr no longer hidden ---------------------
: > "$log"
bash "$env_sh" ssl-generate --domain=foo.local >/dev/null 2>&1
grep -Fq 'subjectAltName=DNS:foo.local' "$log" || fail "ssl-generate emits no subjectAltName"
! grep -Eq '^\s*-subj.*2>/dev/null' "$env_sh" || fail "ssl-generate still hides openssl stderr"
! grep -Fq -- '-subj "/C=US/ST=Local/L=Local/O=Local Dev/OU=Local Dev/CN=$domain" 2>/dev/null' "$env_sh" \
  || fail "ssl-generate still redirects stderr to /dev/null"

# ---- wp-cinematic-encode.sh: --scene must be numeric before anything runs ---
for s in "1');system('x');//" 'abc' '-1' '1.5' '1 2' '$(id)'; do
  : > "$log"
  if bash "$enc_sh" in.mp4 --theme=. "--scene=$s" >/dev/null 2>&1; then
    fail "wp-cinematic-encode accepted --scene=$s"
  fi
  [ ! -s "$log" ] || fail "wp-cinematic-encode ran wp for --scene=$s"
done
bash "$enc_sh" in.mp4 --theme=. --scene=3 2>&1 | grep -Fq 'must be a positive integer' \
  && fail "wp-cinematic-encode rejected a numeric --scene"
grep -Fq '=~ ^[0-9]+$' "$enc_sh" || fail "wp-cinematic-encode lost its numeric guard"

echo PASS
