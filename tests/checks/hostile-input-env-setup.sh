#!/usr/bin/env bash
# bin/wp-env-setup.sh splices --domain into /etc/hosts, a sed expression, a certificate path
# and a vhost, several of them under sudo. A domain such as '../x', or one carrying a sed
# delimiter or a newline, must be refused BEFORE anything runs. Nothing exercised this: the
# neighbouring checks grep the script's text. This one runs it with hostile arguments
# against the stub harness in tests/lib/stub-path.sh and asserts what it would have done.
#
# The script rejects a hostile domain before anything runs; any case that reaches a
# destructive stub is a failure, with no soft mode, so removing the validation turns CI red.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/lib/stub-path.sh
fail() { echo "FAIL: $*"; exit 1; }
stub_path_init; trap stub_path_cleanup EXIT

# The harness itself: a stub must log and not execute.
run_stubbed sudo rm -rf /definitely/not/touched
stub_called sudo || fail "harness: the sudo stub did not log its call"
[ ! -e /definitely/not/touched ] || fail "harness: sudo stub executed its command"
run_stubbed sed -i s/a/b/ /nonexistent
[ "$STUB_RC" = 0 ] && stub_called sed || fail "harness: in-place sed was not intercepted"
run_stubbed sed s/a/b/ <<<"a"
[ "$STUB_OUT" = b ] || fail "harness: plain sed no longer works"

hostile=('../x' 'a/b' 'x;touch y' 'x$(id)' 'x/../../etc' 'a.local.com
b' '-rf')
cmds=(hosts-add hosts-remove ssl-generate)
leaks=0
verbose_cap=6   # print per-case detail for the first few leaks only; the count still fails the check
for cmd in "${cmds[@]}"; do
  for d in "${hostile[@]}"; do
    run_stubbed bash bin/wp-env-setup.sh "$cmd" "--domain=$d"
    calls=$(stub_destructive_calls)
    if [ -n "$calls" ] || [ "$STUB_RC" = 0 ]; then
      leaks=$((leaks + 1))
      if [ -n "$calls" ]; then echo "LEAK: $cmd triggered destructive calls" >&2
      else echo "NOTE: $cmd exited 0 without refusing (no validation?)" >&2; fi
      [ "$leaks" -gt "$verbose_cap" ] || echo "note: $cmd --domain=$(printf %q "$d") was not refused (rc=$STUB_RC)" >&2
      [ -z "$calls" ] || [ "$leaks" -gt "$verbose_cap" ] || printf '%s\n' "$calls" | sed 's/^/        would run: /' >&2
    fi
  done
done

# A sane domain must still get through to the stubs on every command, or "rejects everything"
# would pass. The domain is unique per run so a real /etc/hosts entry cannot satisfy the check.
sane="sanity-$$.local.com"
# hosts-remove is a no-op for an absent entry, so it is excluded: it makes no call to observe.
for cmd in hosts-add ssl-generate; do
  run_stubbed bash bin/wp-env-setup.sh "$cmd" "--domain=$sane"
  [ -s "$STUB_LOG" ] || fail "$cmd: a valid domain reaches no stubbed call: the check cannot tell refusal from breakage"
done

if [ "$leaks" -eq 0 ]; then
  echo PASS
else
  fail "$leaks hostile-domain case(s) reached a destructive call"
fi
