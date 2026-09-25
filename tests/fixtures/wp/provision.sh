#!/usr/bin/env bash
# Stand up a disposable WordPress and print its path.
#
# Every check in tests/checks/ before this one asserts on prose or on pure PHP. Nothing
# proved that a generated site, a seeded field or a translation script behaves correctly
# against a real WordPress -- CLAUDE.md says so in as many words, and the gap is why
# tests/checks/wp-polylang-live.sh needs an operator to supply PLL_TEST_SITE by hand and
# skips for everyone else. This script removes the "by hand".
#
# It is provisioning, not an assertion. It downloads WordPress and plugins from
# wordpress.org, which is the one place in this repository that reaches the network on
# purpose: a WordPress fixture cannot exist without a WordPress. Nothing it installs is
# asserted against a remote service, every assertion runs against the local install, and
# the versions are pinned below so a release upstream cannot change a result here.
#
# Usage:
#   eval "$(tests/fixtures/wp/provision.sh)"   # exports WP_FIXTURE_DIR and WP_FIXTURE_CLI
#   tests/fixtures/wp/provision.sh --teardown "$WP_FIXTURE_DIR"
#
# Connection details come from the environment so the same script serves a local docker
# container and a CI service container without branching:
#   WP_FIXTURE_DB_HOST (default 127.0.0.1:3307)  WP_FIXTURE_DB_USER (default root)
#   WP_FIXTURE_DB_PASS (default wp-fixture)      WP_FIXTURE_DB_NAME (default generated)
set -euo pipefail

# Pinned for the reason the plugin versions below are: an upstream release must never
# change what a check here reports. The database is pinned to a MINOR line for the same
# reason -- `mariadb:11` is a mutable tag, and a minor bump can move collation defaults
# and optimizer behaviour under a suite whose whole purpose is to be reproducible.
PINNED_WP="7.1.2"
PINNED_POLYLANG="3.8.9"
PINNED_SCF="6.9.5"
PINNED_CF7="6.1.7"
# Store fixtures only (WP_FIXTURE_STORE=1). WooCommerce 11.2 ships 2026-10-06; moving these is
# its own deliberate change, like every pin here.
PINNED_WOOCOMMERCE="11.1.2"
PINNED_STRIPE="11.0.0"
PINNED_TURNSTILE="1.43.2"

DB_HOST="${WP_FIXTURE_DB_HOST:-127.0.0.1:3307}"
DB_USER="${WP_FIXTURE_DB_USER:-root}"
DB_PASS="${WP_FIXTURE_DB_PASS:-wp-fixture}"
CONTAINER="${WP_FIXTURE_CONTAINER:-wp-fixture-mysql}"

die() { echo "provision: $*" >&2; exit 1; }
note() { echo "provision: $*" >&2; }

# --------------------------------------------------------------------------------------
# Teardown. Deliberately unconditional and deliberately first: a fixture left behind holds
# a database and a few hundred megabytes, and the run that fails is the run that strands
# one. Same reasoning as /wp-clone deleting both ends of its dump.
# --------------------------------------------------------------------------------------
if [ "${1:-}" = "--teardown" ]; then
  dir="${2:-}"
  [ -n "$dir" ] || die "--teardown needs the fixture directory"
  if [ -f "$dir/wp-config.php" ]; then
    name=$(grep -oP "define\(\s*'DB_NAME',\s*'\K[^']+" "$dir/wp-config.php" 2>/dev/null || true)
    if [ -n "$name" ]; then
      mysql -h "${DB_HOST%%:*}" -P "${DB_HOST##*:}" -u "$DB_USER" -p"$DB_PASS" \
        -e "DROP DATABASE IF EXISTS \`$name\`" 2>/dev/null || note "could not drop $name"
    fi
  fi
  case "$dir" in
    /tmp/*|/var/tmp/*) rm -rf "$dir" ;;
    *) die "refusing to rm -rf a fixture outside /tmp: $dir" ;;
  esac
  exit 0
fi

command -v wp >/dev/null 2>&1 || die "wp-cli is not on PATH"
command -v mysql >/dev/null 2>&1 || die "the mysql client is not on PATH"

# --------------------------------------------------------------------------------------
# The database. WP_FIXTURE_DB_HOST pointing at something already running (a CI service
# container) is used as-is; otherwise start a throwaway container. Never the developer's
# own MySQL: this creates and drops databases, and doing that on a machine whose other
# databases are somebody's actual work is not a risk a test suite gets to take.
# --------------------------------------------------------------------------------------
if ! mysqladmin -h "${DB_HOST%%:*}" -P "${DB_HOST##*:}" -u "$DB_USER" -p"$DB_PASS" ping >/dev/null 2>&1; then
  command -v docker >/dev/null 2>&1 || die "no database at $DB_HOST and docker is not available to start one"
  if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
    note "starting $CONTAINER"
    docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
    docker run -d --name "$CONTAINER" \
      -e MYSQL_ROOT_PASSWORD="$DB_PASS" \
      -p "${DB_HOST##*:}:3306" \
      mariadb:11.4 >/dev/null || die "could not start the database container"
  fi
  for _ in $(seq 1 60); do
    mysqladmin -h "${DB_HOST%%:*}" -P "${DB_HOST##*:}" -u "$DB_USER" -p"$DB_PASS" ping >/dev/null 2>&1 && break
    sleep 2
  done
  mysqladmin -h "${DB_HOST%%:*}" -P "${DB_HOST##*:}" -u "$DB_USER" -p"$DB_PASS" ping >/dev/null 2>&1 \
    || die "the database at $DB_HOST never came up"
fi

DB_NAME="${WP_FIXTURE_DB_NAME:-wpfix_$(date +%s)_$$}"
DIR=$(mktemp -d /tmp/wp-fixture-XXXXXX)
chmod 700 "$DIR"

# Everything below can fail, and the two things worth cleaning up -- the directory and the
# database -- are both created before the slowest and likeliest failure, the download. A
# caller cannot tear down what it was never told about: this script prints WP_FIXTURE_DIR
# only on success, so a failure part way used to leave a directory and a database behind
# with nothing holding their names. Observed: the run where the pinned WP-CLI URL 404'd
# stranded both in CI, and a local /tmp accumulated them one failed run at a time.
#
# So the failure path is this script's own responsibility. Cleared on success, just before
# the exports are printed, because from that point the caller owns the fixture and tearing
# it down here would delete the thing it just asked for.
PARTIAL_DIR="$DIR"
PARTIAL_DB="$DB_NAME"
cleanup_partial() {
  status=$?
  [ "$status" -eq 0 ] && [ -z "${PARTIAL_DIR:-}" ] && exit 0
  if [ -n "${PARTIAL_DB:-}" ]; then
    mysql -h "${DB_HOST%%:*}" -P "${DB_HOST##*:}" -u "$DB_USER" -p"$DB_PASS" \
      -e "DROP DATABASE IF EXISTS \`$PARTIAL_DB\`" 2>/dev/null || true
  fi
  if [ -n "${PARTIAL_DIR:-}" ]; then
    case "$PARTIAL_DIR" in
      /tmp/wp-fixture-*) rm -rf "$PARTIAL_DIR" ;;
    esac
  fi
  exit $status
}
trap cleanup_partial EXIT INT TERM

mysql -h "${DB_HOST%%:*}" -P "${DB_HOST##*:}" -u "$DB_USER" -p"$DB_PASS" \
  -e "CREATE DATABASE \`$DB_NAME\`" || die "could not create $DB_NAME"

WP="wp --path=$DIR --allow-root"

# --allow-root because CI runs as root and wp-cli refuses otherwise; the fixture is
# disposable and owns nothing worth protecting from itself.
$WP core download --version="$PINNED_WP" --quiet || die "core download failed"
$WP config create --dbname="$DB_NAME" --dbuser="$DB_USER" --dbpass="$DB_PASS" \
  --dbhost="$DB_HOST" --quiet || die "config create failed"
$WP core install --url=http://localhost:8080 --title="Fixture" \
  --admin_user=admin --admin_password=admin --admin_email=fixture@example.invalid \
  --skip-email --quiet || die "core install failed"

# Pinned, because an upstream release must never change what a check here reports.
$WP plugin install polylang --version="$PINNED_POLYLANG" --activate --quiet \
  || die "polylang install failed"
$WP plugin install secure-custom-fields --version="$PINNED_SCF" --activate --quiet \
  || die "secure-custom-fields install failed"
# Installed for every fixture rather than behind a flag. It costs a couple of seconds, and
# the alternative -- a per-plugin opt-in mechanism -- is more moving parts than the saving
# is worth while three checks share one provisioner.
$WP plugin install contact-form-7 --version="$PINNED_CF7" --activate --quiet \
  || die "contact-form-7 install failed"

# A store, for the checks that ask for one. WooCommerce creates tables and pages and hooks
# nearly everything, so the Polylang and CF7 checks never get it: each tests only itself.
if [ "${WP_FIXTURE_STORE:-0}" = "1" ]; then
  $WP plugin install woocommerce --version="$PINNED_WOOCOMMERCE" --activate --quiet || die "woocommerce install failed"
  $WP plugin install woocommerce-gateway-stripe --version="$PINNED_STRIPE" --activate --quiet || die "stripe install failed"
  $WP plugin install simple-cloudflare-turnstile --version="$PINNED_TURNSTILE" --activate --quiet || die "turnstile install failed"
  bash "$(cd "$(dirname "$0")/../../.." && pwd)/bin/store-kit-sync.sh" "$DIR/wp-content/plugins" >/dev/null \
    || die "store-kit copy failed"
  $WP plugin activate store-kit --quiet || die "store-kit activation failed"
  # WordPress reads an unset WP_ENVIRONMENT_TYPE as production; a fixture is local.
  $WP config set WP_ENVIRONMENT_TYPE local --type=constant --quiet || die "could not mark the fixture local"
fi

# Offline from here on. Everything above needed the network to download WordPress and its
# plugins; nothing after this line may. The guard is a must-use plugin, so no plugin
# reactivation or option write can turn it off, and it logs every host it refuses to
# wp-content/net-guard.log -- which is how a check learns what tried to call out.
here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$DIR/wp-content/mu-plugins"
cp "$here/net-guard.php" "$DIR/wp-content/mu-plugins/00-net-guard.php" \
  || die "could not install the network guard"

# Handing ownership to the caller: from here a failure must not delete the fixture.
PARTIAL_DIR=""
PARTIAL_DB=""

echo "export WP_FIXTURE_DIR='$DIR'"
echo "export WP_FIXTURE_CLI='$WP'"
