#!/usr/bin/env bash
# Four properties of the wp-s3 scripts that were wrong once, measured against a real
# S3-compatible server, and are cheap to break again by editing the obvious line:
#
#   1. The credential check must NOT be `wp s3-uploads verify`. That subcommand is
#      registered by the plugin, and setup deliberately leaves the plugin deactivated, so
#      it answers "'s3-uploads' is not a registered wp command" on every first run — a
#      check that can only ever fail is worse than no check, because its failure is read
#      as bad credentials.
#   2. An installed plugin is vendor/autoload.php, not a directory. Releases since 3.0.10
#      ship no vendor/ tree, so a download that succeeded and a composer run that failed
#      leave a directory behind; treating that as installed configures a site around a
#      plugin that fatals the moment it is activated.
#   3. composer must tolerate a PHP with no iconv extension, which several distributions
#      ship. The dependency that declares ext-iconv is never reached at runtime.
#   4. A download must not call an empty remote listing a verified transfer. The client
#      exits 0 and prints nothing for an alias it does not know, so "no objects" and
#      "could not list" arrive identically.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

setup=skills/wp-s3/scripts/s3-setup.sh
media=skills/wp-s3/scripts/s3-media.sh
revert=skills/wp-s3/scripts/s3-revert.sh
lib=skills/wp-s3/scripts/lib-mirror.sh
verify=skills/wp-s3/scripts/verify-transfer.py
creds=skills/wp-s3/scripts/check-credentials.php

for f in "$setup" "$media" "$revert" "$lib" "$verify" "$creds"; do
  [ -f "$f" ] || fail "$f is missing"
done

for f in "$setup" "$media" "$revert" "$lib"; do
  bash -n "$f" || fail "$f is not valid bash"
done
python3 -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" "$verify" \
  || fail "$verify is not valid python"
php -l "$creds" >/dev/null || fail "$creds does not parse"

# ---------------------------------------------------------------------------
# 1. Credentials are proved with the plugin off.
# ---------------------------------------------------------------------------
grep -Fq 'check-credentials.php' "$setup" \
  || fail "$setup does not run check-credentials.php, so nothing proves the credentials before the plugin is activated"
# Running it is the defect; printing it as the command to run after activation is correct
# advice, so `echo` lines are exempt.
! grep -E '^[^#]*wp s3-uploads verify' "$setup" | grep -qv 'echo' \
  || fail "$setup runs 'wp s3-uploads verify', which cannot work while the plugin is deactivated — that is the whole reason check-credentials.php exists"
grep -Fq 'listObjectsV2' "$creds" \
  || fail "$creds does not list the bucket, so it proves nothing about the credentials"
grep -Fq 'S3-Uploads/vendor/autoload.php' "$creds" \
  || fail "$creds does not use the SDK the plugin bundles, so a pass would not mean the plugin can connect"

# ---------------------------------------------------------------------------
# 2 and 3. What counts as an installed plugin, and the iconv escape hatch.
# ---------------------------------------------------------------------------
grep -Fq 'vendor/autoload.php' "$setup" \
  || fail "$setup never checks for vendor/autoload.php: a bare directory is not an installed plugin"
grep -Fq -- '--ignore-platform-req=ext-iconv' "$setup" \
  || fail "$setup cannot install the dependencies on a PHP without iconv, where composer refuses the lock file"

# ---------------------------------------------------------------------------
# 4. An empty listing is not a verified download.
# ---------------------------------------------------------------------------
grep -Fq 'listed no objects at all' "$verify" \
  || fail "$verify no longer refuses an empty remote listing on a download, so a transfer that moved nothing reports success"

# ---------------------------------------------------------------------------
# 5. Neither direction may ever clobber. This is what makes a repeated run safe,
#    and it is one flag away from being untrue.
# ---------------------------------------------------------------------------
for f in "$media" "$lib" "$revert"; do
  ! grep -Eq '^[^#]*--overwrite' "$f" \
    || fail "$f passes --overwrite to the client"
  ! grep -Eq '^[^#]*--remove' "$f" \
    || fail "$f passes --remove to the client"
done

# ---------------------------------------------------------------------------
# 6. The transfer is still judged by comparing both sides, not by the client's
#    exit code or its summary table.
# ---------------------------------------------------------------------------
grep -Fq 'verify-transfer.py' "$lib" \
  || fail "$lib no longer compares both sides after a transfer"

echo PASS
