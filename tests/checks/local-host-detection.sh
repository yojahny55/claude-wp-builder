#!/usr/bin/env bash
# "Local host" was three hand-kept lists (prod-gate, audit-suite, geo-scan) that treated every
# *.local.com name as development, although local.com is a public domain, and that disagreed
# with each other (geo-scan lower-cased nothing and matched `10.*` as a glob). They now share
# bin/lib/local-host.sh: reserved suffixes and private IP literals by octet are local by
# name; any other name is local only when it resolves, entirely, to loopback/private. No
# network: WP_HOSTS_FILE injects the resolution. Also pins the audit-suite results reset and
# prod-gate's flock-less lock.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
has() { grep -Fq -- "$2" "$1" || fail "$1 lacks: $2"; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/hosts" <<'H'
127.0.0.1 www.x.local.com
192.168.1.20 lan.local.com   # private
203.0.113.9 pub.local.com
127.0.0.1 mixed.local.com
203.0.113.9 mixed.local.com
H

# 1. The table. Resolution comes only from WP_HOSTS_FILE.
export WP_HOSTS_FILE="$tmp/hosts"
. bin/lib/local-host.sh
expect() { # <local|public> <host>
  local got=public; host_is_local "$2" && got=local
  [ "$got" = "$1" ] || fail "host_is_local '$2': expected $1, got $got"
}
expect local  www.x.local.com
expect local  https://WWW.X.LOCAL.COM:8443/path
expect local  lan.local.com
expect public pub.local.com
expect public mixed.local.com
expect public unresolved.local.com
expect public www.example.com
expect public local.com
expect local  FOO.LOCAL
expect local  site.test
expect local  localhost
expect local  a.localhost:8080
expect local  db.internal
expect local  nas.lan
expect local  x.home.arpa
expect local  x.example
expect public 10.example.com
expect public 127.example.org
expect local  10.0.0.5
expect local  127.0.0.1
expect local  192.168.1.1
expect local  172.16.0.1
expect local  172.31.255.1
expect public 172.32.0.1
expect public 172.160.0.1
expect public 8.8.8.8
expect local  '[::1]'
expect public ''

# 2. The three scripts use it and no longer carry their own lists.
for f in bin/prod-gate.sh bin/audit-suite.sh bin/geo-scan.sh; do
  has "$f" 'lib/local-host.sh'
  ! grep -Fq '*.local.com' "$f" || fail "$f still hard-codes *.local.com"
done

# 3. prod-gate: a public-resolving *.local.com is gated; a loopback-resolving one is not.
gate="$tmp/gate"
out="$(bash bin/prod-gate.sh --dir "$gate" --delay 0 pub.local.com -- echo ran 2>&1)" || fail "gated run failed: $out"
compgen -G "$gate/pub.local.com*" >/dev/null || fail "pub.local.com was not gated (no state written)"
rm -rf "$gate"
bash bin/prod-gate.sh --dir "$gate" --delay 0 www.x.local.com -- echo ran >/dev/null 2>&1
[ ! -e "$gate/www.x.local.com.lock" ] || fail "loopback-resolving host was gated"

# 4. geo-scan: refuses (exit 3) a local name, and reads FOO.LOCAL and 10.0.0.5 as local.
for h in FOO.LOCAL 10.0.0.5 www.x.local.com; do
  rc=0; bash bin/geo-scan.sh "$h" >/dev/null 2>&1 || rc=$?
  [ "$rc" = 3 ] || fail "geo-scan $h exited $rc, expected 3"
done
rc=0; out="$(bash bin/geo-scan.sh 10.example.com 2>&1)" || rc=$?
case "$out" in *"NOT PUBLIC"*) fail "geo-scan treated 10.example.com as private" ;; esac

# 5. prod-gate without flock: symlink lock, released on exit, dead holder taken over, busy -> 5.
nf="$tmp/noflock"; mkdir "$nf"
for t in bash date awk sleep cat mkdir rm kill tr dirname env mv sort cksum mktemp ls sed grep timeout curl ln readlink ps find rmdir sh; do
  p="$(command -v "$t" 2>/dev/null || true)"; [ -n "$p" ] && ln -s "$p" "$nf/$t"
done
! PATH="$nf" command -v flock >/dev/null 2>&1 || fail "test PATH still has flock"
gate="$tmp/gate2"
gl="$gate/pub.local.com.lock.l"
PATH="$nf" bash bin/prod-gate.sh --dir "$gate" --delay 0 pub.local.com -- echo ran >/dev/null 2>&1 \
  || fail "gate without flock failed"
[ ! -L "$gl" ] || fail "symlink lock not released"
# (1) two runs racing for the same DEAD lock never overlap their commands.
cat > "$tmp/mark.sh" <<'M'
#!/bin/sh
echo "start $$" >> "$1"; sleep 0.3; echo "end $$" >> "$1"
M
for i in 1 2 3 4 5; do
  : > "$tmp/marks"; rm -f "$gl"; ln -s 999999 "$gl"
  for j in 1 2; do PATH="$nf" bash bin/prod-gate.sh --dir "$gate" --delay 0 pub.local.com -- sh "$tmp/mark.sh" "$tmp/marks" >/dev/null 2>&1 & done
  wait
  [ "$(awk '{print $1}' "$tmp/marks" | tr '\n' ' ')" = "start end start end " ] \
    || fail "round $i: commands overlapped under a dead lock: $(tr '\n' ';' < "$tmp/marks")"
done
# (2) a lock owned by a live process: exit 5 after --wait, and the lock is left alone.
sleep 30 & other=$!
rm -f "$gl"; ln -s "$other" "$gl"
rc=0; PATH="$nf" bash bin/prod-gate.sh --dir "$gate" --delay 0 --wait 1 pub.local.com -- echo ran >/dev/null 2>&1 || rc=$?
[ "$rc" = 5 ] || fail "live symlink lock: expected exit 5, got $rc"
# (3) the failed run's trap did not remove somebody else's lock.
[ "$(readlink "$gl")" = "$other" ] || fail "the trap removed a lock it did not own"
kill "$other" 2>/dev/null || true; rm -f "$gl"
has bin/prod-gate.sh 'indistinguishable from the gate'

# 6. audit-suite empties results/audit at the start of a run, that directory only.
has bin/audit-suite.sh "find \"\$dir/results/audit\" -mindepth 1 -maxdepth 1 -name '*.json' -delete"
echo PASS
