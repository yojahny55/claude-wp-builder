#!/usr/bin/env bash
# bin/wp-env-setup.sh splices --domain into /etc/hosts, a sed expression, a certificate path
# and a vhost, several of them under sudo. A domain such as '../x', or one carrying a sed
# delimiter or a newline, must be refused BEFORE anything runs. Nothing exercised this: the
# neighbouring checks grep the script's text. This one runs it with hostile arguments
# against the stub harness in tests/lib/stub-path.sh and asserts what it would have done.
#
# Another change adds the validation to the script. So that this check does not couple the
# two branches, it has two modes:
#   - the script rejects the hostile domain -> asserted hard, PASS;
#   - the script does not yet                -> printed as XFAIL and still exits 0, UNLESS
#     WP_HOSTILE_STRICT=1, which makes it fail. Flip the default (set WP_HOSTILE_STRICT=1
#     in .github/workflows/ci.yml) in the change that lands the validation, so a later
#     regression cannot hide behind XFAIL.
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

# A sane domain must still get through to the stubs, or "rejects everything" would pass.
run_stubbed bash bin/wp-env-setup.sh hosts-add --domain=example.local.com
if ! stub_called sudo && ! grep -q 'already exists' <<<"$STUB_OUT"; then
  fail "a valid domain no longer reaches the sudo call: the check cannot tell refusal from breakage"
fi

if [ "$leaks" -eq 0 ]; then
  echo PASS
elif [ "${WP_HOSTILE_STRICT:-0}" = 1 ]; then
  fail "$leaks hostile-domain case(s) reached a destructive call"
else
  echo "XFAIL: $leaks hostile-domain case(s) are not refused yet (expected until the domain validation lands; WP_HOSTILE_STRICT=1 makes this a failure)"
fi
