#!/usr/bin/env bash
# Fifteen properties of the wp-s3 scripts, every one of them wrong once, measured against
# a real S3-compatible server and a real WordPress, and cheap to break again by editing
# the obvious line. Each numbered section below asserts the property of the same number.
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
#   5. The alias belongs in a private configuration file. MC_HOST_<alias> is a URL whose
#      credentials the client does not percent-decode, so encoding them broke every
#      secret holding a reserved character, and `alias set` would put the secret in argv.
#   6. Credentials are quoted for PHP where they are written, not assembled in the shell.
#   7. Neither direction may ever clobber: no --overwrite, no --remove.
#   8. WooCommerce's logs and the form attachments never leave the disk.
#   9. The revert's closing summary survives a site that had no config to park.
#  10. Every `wp` call in the revert is asked once and reused.
#  11. A commented-out define() is not configuration.
#  12. "The require block was hand-edited" is not the same failure as "the rewrite failed".
#  13. A vendor/ tree is not the version that was asked for.
#  14. A transfer is judged by comparing both sides, not by the client's exit code.
#  15. Plugin code is verified against a pinned commit before it is installed.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

setup=skills/wp-s3/scripts/s3-setup.sh
media=skills/wp-s3/scripts/s3-media.sh
revert=skills/wp-s3/scripts/s3-revert.sh
lib=skills/wp-s3/scripts/lib-mirror.sh
verify=skills/wp-s3/scripts/verify-transfer.py
creds=skills/wp-s3/scripts/check-credentials.php

tmp_config="$(mktemp -t wp-s3-check-XXXXXX.php)"
trap 'rm -f "$tmp_config"' EXIT

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
# 5. The alias never goes through MC_HOST_<alias>, and the secret never through argv.
#    Measured against a real server: the client does NOT percent-decode the credentials
#    in that URL, so encoding them broke every secret holding /, @, +, %, # or ?, and a
#    secret holding `:` could not be expressed either way. A config file in a 0700
#    directory carries all of them.
# ---------------------------------------------------------------------------
! grep -Eq '^[^#]*MC_HOST_' "$media" \
  || fail "$media puts the credentials in MC_HOST_<alias>, a URL whose secret the client does not percent-decode"
! grep -Eq '^[^#]*mcli alias set|^[^#]*\$MCLI" alias set' "$media" \
  || fail "$media passes the secret to 'alias set', where ps shows it to every user on the machine"
grep -Fq 'MC_CONFIG_DIR' "$media" \
  || fail "$media does not point the client at a private configuration directory"
grep -Fq 'chmod 700' "$media" \
  || fail "$media does not restrict the configuration directory it writes the secret into"

# ---------------------------------------------------------------------------
# 6. The credentials are quoted for PHP where they are written. A secret holding a
#    single quote used to end the string early, and `php -l` then condemned a file that
#    already had the credentials in it.
# ---------------------------------------------------------------------------
grep -Fq 'php_single_quoted' "$setup" \
  || fail "$setup builds the PHP credential literals without escaping them"

# ---------------------------------------------------------------------------
# 7. Neither direction may ever clobber. This is what makes a repeated run safe,
#    and it is one flag away from being untrue.
# ---------------------------------------------------------------------------
# The flag is matched as a standalone argument token on a line with its comment stripped,
# not by "the line does not start with #": a continuation line, a quoted string or a
# command whose first token is the flag would all slip past that heuristic, and this guard
# is the one that keeps a repeated run safe.
# Only a `#` that starts a line or follows whitespace opens a comment here; one inside a
# URL or a colour literal does not, and stripping from it would delete the rest of a line
# that may carry the very flag this guard looks for.
code_only() { sed 's/\(^\|[[:space:]]\)#.*$/\1/' "$1"; }
for f in "$media" "$lib" "$revert"; do
  for flag in --overwrite --remove; do
    ! code_only "$f" | grep -Eq "(^|[[:space:]\"'\(\$])${flag}([[:space:]\"'\)]|$)" \
      || fail "$f passes $flag to the client"
  done
done

# ---------------------------------------------------------------------------
# 8. The two directories a wrong bucket policy would expose never leave the disk:
#     WooCommerce's logs and the form attachments people upload.
# ---------------------------------------------------------------------------
for dir in wc-logs wpcf7_uploads; do
  grep -Fq -- "--exclude \"$dir/*\"" "$media" \
    || fail "$media no longer excludes $dir/ from the transfer"
done

# ---------------------------------------------------------------------------
# 9. The revert's closing summary is what tells the operator about Elementor's stored
#     URLs and WooCommerce's download settings, so it must survive a site that had no
#     config to park: the reader exits non-zero there, and `pipefail` used to carry that
#     into an assignment that errexit turned into a silent stop one line short.
# ---------------------------------------------------------------------------
grep -Fq 'if [[ -f "$CONFIG.disabled" ]]; then' "$revert" \
  || fail "$revert reads the parked config without checking that there is one"

# ---------------------------------------------------------------------------
# 10. Every `wp` call in the revert is asked once and reused. WP-CLI prints a
#     three-line "This does not seem to be a WordPress installation" for a site it
#     cannot read, and it used to land between step 2 and step 4 of a run that had
#     already reported the plugin inactive in step 1.
# ---------------------------------------------------------------------------
grep -Fq 'PLUGIN_ACTIVE' "$revert" \
  || fail "$revert calls 'wp plugin deactivate' without reusing what step 1 already learned"


# ---------------------------------------------------------------------------
# 11. A commented-out define() is not configuration. PHP keeps the FIRST define() of a
#    name, so matching the first occurrence is right for code — but the reader matched
#    it textually, and the line an operator leaves above the new one while rotating a
#    bucket or a key is a comment. It handed every caller the stale value while the site
#    served from the new one, and the transfer then verified clean against the wrong
#    bucket: a wrong answer with no error anywhere.
# ---------------------------------------------------------------------------
reader=skills/wp-s3/scripts/read-s3-config.php
grep -Fq 'token_get_all' "$reader" \
  || fail "$reader matches define() over the raw file again: a commented-out line reads as configuration"
printf '%s\n' '<?php' "// define( 'S3_UPLOADS_BUCKET', 'stale' );" \
  "define( 'S3_UPLOADS_BUCKET', 'live' );" > "$tmp_config"
[ "$(php "$reader" "$tmp_config" --names)" = "S3_UPLOADS_BUCKET: live" ] \
  || fail "$reader reads a commented-out define() as the site's configuration"

# ---------------------------------------------------------------------------
# 12. The revert must tell "the block was hand-edited" apart from "the rewrite failed".
#     Python exits 3 for the first and 1 for any unhandled exception — a read-only
#     $WP_ROOT is the measured one — and both used to print the same message, sending
#     that operator to delete a block nobody had touched.
# ---------------------------------------------------------------------------
grep -Fq 'status -eq 3' "$revert" \
  || fail "$revert treats every non-zero exit from the rewrite as a hand-edited require block"

# ---------------------------------------------------------------------------
# 13. A vendor/ tree is not the version that was asked for. Re-running with --version to
#     pin or upgrade was a silent no-op against whatever a previous run left behind.
# ---------------------------------------------------------------------------
grep -Fq 'installed_version' "$setup" \
  || fail "$setup skips the install without comparing what is there against --version"

# ---------------------------------------------------------------------------
# 14. The transfer is still judged by comparing both sides, not by the client's
#     exit code or its summary table.
# ---------------------------------------------------------------------------
grep -Fq 'verify-transfer.py' "$lib" \
  || fail "$lib no longer compares both sides after a transfer"

# ---------------------------------------------------------------------------
# 15. Plugin code is verified before it is installed. This tree runs on every request
#     to the site once the plugin is activated, and a tag can be moved upstream. The
#     clone is checked against a pinned commit — the hash of the tree itself, which
#     git refuses to produce from anything else — and the tarball path, which carries
#     no such anchor, is refused unless the operator asks for it by name.
# ---------------------------------------------------------------------------
grep -Fq 'PLUGIN_COMMIT' "$setup" \
  || fail "$setup installs the plugin without checking what arrived against a pinned commit"
grep -Fq -- '--unverified-download' "$setup" \
  || fail "$setup has no named way to accept an unverifiable download, so it either refuses always or checks nothing"

echo PASS
