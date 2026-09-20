#!/usr/bin/env bash
# Takes a site back off S3, in the order that keeps the media reachable throughout.
#
#   bash s3-revert.sh /path/to/wordpress [--keep-remote-media]
#
# The media come down BEFORE the configuration goes away: without s3-config.php there is
# no bucket name, no region and no credentials left to fetch them with. Nothing in the
# bucket is deleted.

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

die() { echo "ERROR: $*" >&2; exit 1; }

WP_ROOT="${1:-}"
if [[ $# -ge 1 ]]; then shift 1; fi
SKIP_DOWNLOAD="no"
for arg in "$@"; do
    case "$arg" in
        --keep-remote-media) SKIP_DOWNLOAD="yes" ;;
        *) die "unknown option: $arg" ;;
    esac
done

WP_ROOT="${WP_ROOT%/}"
[[ -n "$WP_ROOT" ]] || { echo "Usage: $0 <wp-root> [--keep-remote-media]" >&2; exit 2; }
[[ -f "$WP_ROOT/wp-config.php" ]] || die "$WP_ROOT is not a WordPress root"

CONFIG="$WP_ROOT/s3-config.php"
LOCAL="$WP_ROOT/wp-content/uploads"
MU="$WP_ROOT/wp-content/mu-plugins/s3-uploads-endpoint.php"
STAMP="$(date +%Y%m%d-%H%M%S)"

[[ -d "$LOCAL" ]] || die "no $LOCAL"
[[ -w "$LOCAL" ]] || die "$LOCAL is not writable: the media cannot come back to disk"

# ---------------------------------------------------------------- 1. stop rewriting
# Asked once and reused by step 3: every `wp` call on a site WP-CLI cannot read prints a
# multi-line "This does not seem to be a WordPress installation" into the middle of the
# steps, and an inactive plugin needs neither call.
PLUGIN_ACTIVE=no
if command -v wp >/dev/null 2>&1; then
    # The subcommand only exists while the plugin is loaded, so asking for it on an
    # inactive plugin prints "'s3-uploads' is not a registered wp command" — an error
    # message for the one case that needs no work at all.
    if ( cd "$WP_ROOT" && wp plugin is-active S3-Uploads >/dev/null 2>&1 ); then
        PLUGIN_ACTIVE=yes
        echo "1. wp s3-uploads disable"
        ( cd "$WP_ROOT" && wp s3-uploads disable ) || echo "   (rewriting was already off)"
    else
        echo "1. The plugin is not active: nothing to disable."
    fi
else
    PLUGIN_ACTIVE=unknown
    echo "1. WP-CLI not found. Run this yourself before continuing:"
    echo "     cd $WP_ROOT && wp s3-uploads disable && wp plugin deactivate S3-Uploads"
fi

# ---------------------------------------------------------------- 2. media back to disk
if [[ "$SKIP_DOWNLOAD" == "yes" ]]; then
    echo "2. Download skipped by --keep-remote-media."
    echo "   Anything uploaded since the migration exists ONLY in the bucket."
elif [[ -f "$CONFIG" ]]; then
    echo "2. Bringing the media back to disk"
    # A partial download here is the failure that loses files, so the transfer verifies
    # itself and this script stops if it did not finish.
    bash "$SKILL_DIR/scripts/s3-media.sh" download "$WP_ROOT" \
        || die "the download did not finish. Nothing has been removed; fix this and run again."
else
    echo "2. No s3-config.php: nothing to download from."
fi

# ---------------------------------------------------------------- 3. deactivate
if [[ "$PLUGIN_ACTIVE" == "yes" ]]; then
    echo "3. wp plugin deactivate S3-Uploads"
    ( cd "$WP_ROOT" && wp plugin deactivate S3-Uploads ) || echo "   (deactivation failed; do it in Plugins)"
elif [[ "$PLUGIN_ACTIVE" == "unknown" ]]; then
    echo "3. Deactivate the plugin yourself: it is the command printed in step 1."
else
    echo "3. Nothing to deactivate."
fi

# ---------------------------------------------------------------- 4. unhook the config
if grep -q "s3-config.php" "$WP_ROOT/wp-config.php"; then
    cp -p "$WP_ROOT/wp-config.php" "$WP_ROOT/wp-config.php.bak-$STAMP"
    set +e
    python3 - "$WP_ROOT/wp-config.php" <<'PY'
import os, re, sys
path = sys.argv[1]
with open(path) as handle:
    text = handle.read()
pattern = re.compile(
    r"if \(\s*file_exists\(\s*__DIR__ \. '/s3-config\.php'\s*\)\s*\) \{\s*"
    r"require __DIR__ \. '/s3-config\.php';\s*\}\s*\n*",
    re.MULTILINE,
)
new, count = pattern.subn("", text)
if count == 0:
    sys.stderr.write("WARNING: the require block was edited by hand; remove it yourself.\n")
    sys.exit(3)
# Written to a neighbouring file and renamed: a process killed halfway through a
# plain write leaves wp-config.php truncated, which is a white screen until
# someone restores the backup by hand.
tmp = path + ".wp-s3-tmp"
with open(tmp, "w") as handle:
    handle.write(new)
    handle.flush()
    os.fsync(handle.fileno())
os.replace(tmp, path)
PY
    status=$?
    set -e
    if [[ $status -ne 0 && $status -ne 3 ]]; then
        # Not the hand-edited case: the rewrite itself failed. A read-only $WP_ROOT is the
        # one measured here — the temporary file cannot be created, python raises
        # PermissionError and exits 1 — and telling that operator to go and delete a block
        # nobody touched sends them to fix the wrong thing.
        die "could not rewrite wp-config.php (python exited $status; its error is above).
       Nothing has been renamed and the site still works. Fix that and run again
       (backup: wp-config.php.bak-$STAMP)."
    fi
    if [[ $status -eq 3 ]]; then
        # Stopping here leaves the site working: wp-config.php still requires a
        # config that is still in place. Carrying on would rename that config out
        # from under a require nobody could remove automatically, which is a fatal
        # on the next request whenever the hand-edited block dropped the
        # file_exists() guard.
        die "the require block in wp-config.php was edited by hand and could not be removed.
       Nothing has been renamed and the site still works. Remove this block yourself:
           if ( file_exists( __DIR__ . '/s3-config.php' ) ) { require __DIR__ . '/s3-config.php'; }
       then run this script again (backup: wp-config.php.bak-$STAMP)."
    fi
    php -l "$WP_ROOT/wp-config.php" >/dev/null || die "wp-config.php no longer parses; restore wp-config.php.bak-$STAMP"
    echo "4. Removed the require from wp-config.php (backup: wp-config.php.bak-$STAMP)"
else
    echo "4. wp-config.php does not require s3-config.php."
fi

# ---------------------------------------------------------------- 5. park, do not delete
# Renamed rather than deleted: the bucket is still there, and turning this back on
# should cost one `mv`, not another round of credentials.
if [[ -f "$CONFIG" ]]; then
    mv "$CONFIG" "$CONFIG.disabled"
    echo "5. s3-config.php -> s3-config.php.disabled"
fi
if [[ -f "$MU" ]]; then
    mv "$MU" "$MU.disabled"
    echo "   mu-plugin -> s3-uploads-endpoint.php.disabled"
fi

# ---------------------------------------------------------------- 6. what this cannot undo
# Only when there is a config to read: on a site that had none, the reader exits non-zero,
# `pipefail` carries that into the assignment and errexit ends the script one line before
# the summary it exists to print.
BUCKET_URL=""
if [[ -f "$CONFIG.disabled" ]]; then
    BUCKET_URL="$(php "$SKILL_DIR/scripts/read-s3-config.php" "$CONFIG.disabled" --names 2>/dev/null \
        | sed -n 's/^S3_UPLOADS_BUCKET_URL: //p')"
fi
# Guarded like every other `wp` call here: without WP-CLI the bare invocation prints
# "command not found" into the middle of the commands printed below.
SITE_URL='https://www.example.com'
if command -v wp >/dev/null 2>&1; then
    SITE_URL="$(cd "$WP_ROOT" && wp option get siteurl 2>/dev/null || echo 'https://www.example.com')"
fi

cat <<TXT

Done. Two things this script does not touch, because both are site data rather than
configuration:

  Elementor stores absolute media URLs inside its own data. If they were rewritten on
  the way in, reverse them:
    cd $WP_ROOT
    wp elementor replace-urls '${BUCKET_URL:-<bucket-url>}/uploads' '${SITE_URL}/wp-content/uploads'
    wp elementor flush-css

  WooCommerce: set the file download method back to what it was, and drop the bucket URL
  from Settings -> Products -> Approved download directories.

The bucket still holds every object. Delete nothing there until the site has been
checked.
TXT
