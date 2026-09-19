#!/usr/bin/env bash
# Run the ACF path walker, writer and reference re-pointing against a REAL WordPress.
#
# CLAUDE.md has said for a long time that CI does not stand up a WordPress, and that
# nothing here proves a generated site or an audit behaves correctly against a real
# install. This is the first check that does any of it, and it exists because the pure
# test could not: tests/checks/wp-polylang-nesting.sh proves the path logic, and the first
# run of this one immediately found a defect that logic could not contain -- ACF resolves
# a field NAME through the hidden `_<name>` reference meta, so get_field_object() returns
# false on a post with no value for that field, which is every brand-new translation
# counterpart, which is the only case the writer exists to serve.
#
# It SKIPS by default. Provisioning downloads WordPress and two plugins, takes a minute or
# two, and needs a database; making that the price of running the suite would mean people
# stop running the suite. CI opts in, and so can anyone: WP_FIXTURE=1.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

if [ "${WP_FIXTURE:-0}" != "1" ]; then
  echo "SKIP: set WP_FIXTURE=1 to provision a disposable WordPress and run this"
  exit 0
fi

prov=tests/fixtures/wp/provision.sh
[ -r "$prov" ] || fail "$prov is missing or unreadable"

# Both fixtures run against ONE provisioned site. Provisioning is the slow part by an
# order of magnitude, and a second WordPress would buy isolation between two files that
# create their own posts and field groups anyway.
SCRIPTS="tests/fixtures/wp/acf-nesting.php tests/fixtures/wp/acf-refs.php"
for s in $SCRIPTS; do
  [ -r "$s" ] || fail "$s is missing or unreadable"
done

DIR=""
# Tear down on every exit path, including a failed assertion and an interrupt. A fixture
# left behind holds a database and a few hundred megabytes, and the run that strands one
# is always the run that failed.
cleanup() {
  status=$?
  if [ -n "$DIR" ]; then
    bash "$prov" --teardown "$DIR" >/dev/null 2>&1 || echo "  (warning: could not tear down $DIR)"
  fi
  exit $status
}
trap cleanup EXIT INT TERM

env_out=$(bash "$prov") || fail "could not provision a WordPress fixture"
eval "$env_out"
[ -n "${WP_FIXTURE_DIR:-}" ] || fail "the provisioner printed no WP_FIXTURE_DIR"
DIR="$WP_FIXTURE_DIR"

total=0
for script in $SCRIPTS; do
  name=$(basename "$script")
  out=$(wp --path="$DIR" --allow-root eval-file "$script" 2>&1) || {
    echo "$out" | sed 's/^/  /'
    fail "$name reported a failure inside a real WordPress"
  }

  case "$out" in
    *"INTEGRATION OK"*) : ;;
    *) echo "$out" | sed 's/^/  /'; fail "$name did not report INTEGRATION OK" ;;
  esac

  # Do not trust the banner alone. These fixtures report their own result through
  # $GLOBALS, because `wp eval-file` evaluates them inside a WP-CLI method's local scope
  # -- a top-level $failed and a `global $failed` inside a helper are different variables.
  # acf-nesting.php printed INTEGRATION OK with two failures above it on its first run,
  # and a check that believes a banner over the evidence beside it is worth nothing.
  case "$out" in
    *"FAIL ["*) echo "$out" | sed 's/^/  /'; fail "$name printed INTEGRATION OK alongside a FAIL line" ;;
  esac

  n=$(printf '%s' "$out" | grep -c '^ok  ' || true)
  [ "${n:-0}" -gt 0 ] || fail "$name reported OK but asserted nothing"
  total=$(( total + n ))
  echo "  $name: $n assertions"
done

echo "PASS: ACF nesting and reference re-pointing verified inside a real WordPress ($total assertions)"
