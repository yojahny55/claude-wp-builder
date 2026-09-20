#!/usr/bin/env bash
# Moves wp-content/uploads between a site and its bucket, and verifies that it moved.
#
#   bash s3-media.sh upload   /path/to/wordpress [--dry-run]
#   bash s3-media.sh download /path/to/wordpress [--dry-run]
#
# Reads the connection out of the site's own s3-config.php, so there is no second place
# to keep in sync. Never uses --overwrite or --remove: an object that already exists is
# reported as a conflict and left alone, which is what makes a repeated run safe.

set -euo pipefail
set -f   # no globbing: the --exclude patterns must reach the client verbatim

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib-mirror.sh
source "$SKILL_DIR/scripts/lib-mirror.sh"

die() { echo "ERROR: $*" >&2; exit 1; }

DIRECTION="${1:-}"
WP_ROOT="${2:-}"
# Consume only what is there: `shift 2` on a single argument fails and leaves the
# direction in "$@", where the option loop below reports it as an unknown option
# instead of printing the usage.
if [[ $# -ge 2 ]]; then shift 2; else shift $#; fi

DRY=()
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY=( --dry-run ) ;;
        *) die "unknown option: $arg" ;;
    esac
done

case "$DIRECTION" in
    upload|download) ;;
    *) echo "Usage: $0 upload|download <wp-root> [--dry-run]" >&2; exit 2 ;;
esac

WP_ROOT="${WP_ROOT%/}"
[[ -n "$WP_ROOT" ]] || die "a WordPress root is required"
[[ -f "$WP_ROOT/wp-config.php" ]] || die "$WP_ROOT is not a WordPress root"
CONFIG="$WP_ROOT/s3-config.php"
[[ -f "$CONFIG" ]] || die "no s3-config.php in $WP_ROOT: run /wp-s3 first"

LOCAL="$WP_ROOT/wp-content/uploads"
[[ -d "$LOCAL" ]] || die "no $LOCAL"

command -v php >/dev/null || die "php is required to read s3-config.php"
MCLI="$(require_mcli "$SKILL_DIR/bin")" || exit 1
export MCLI

# The secret reaches this shell through a pipe and stays in the environment. It is never
# written to a file and never printed.
S3_UPLOADS_ENDPOINT=""
S3_UPLOADS_KEY=""
S3_UPLOADS_SECRET=""
S3_UPLOADS_USE_INSTANCE_PROFILE=""
eval "$(php "$SKILL_DIR/scripts/read-s3-config.php" "$CONFIG" --export)"

[[ -n "${S3_UPLOADS_BUCKET:-}" ]] || die "S3_UPLOADS_BUCKET is not set in $CONFIG"
[[ -n "${S3_UPLOADS_REGION:-}" ]] || die "S3_UPLOADS_REGION is not set in $CONFIG"

if [[ -z "$S3_UPLOADS_KEY" || -z "$S3_UPLOADS_SECRET" ]]; then
    if [[ -n "${S3_MEDIA_KEY:-}" && -n "${S3_MEDIA_SECRET:-}" ]]; then
        # An instance profile signs the plugin's own requests, but the client cannot
        # assume that role: it needs a key pair of its own for this one transfer.
        S3_UPLOADS_KEY="$S3_MEDIA_KEY"
        S3_UPLOADS_SECRET="$S3_MEDIA_SECRET"
    else
        cat >&2 <<TXT
ERROR: $CONFIG has no key pair.

This site authenticates with the server's IAM role, which signs the plugin's requests
but cannot be handed to a separate client. Two ways forward:

  1. Temporary credentials for this transfer only, never written to disk:
       read -rs S3_MEDIA_SECRET && export S3_MEDIA_SECRET
       S3_MEDIA_KEY=<access-key-id> bash $0 $DIRECTION $WP_ROOT

  2. WP-CLI, which uses the role, for the upload direction only:
       cd $WP_ROOT && wp s3-uploads upload-directory wp-content/uploads uploads --verbose
     It reports no summary, so count the result afterwards:
       wp s3-uploads ls uploads | wc -l
TXT
        exit 1
    fi
fi

# The endpoint is optional: without it the bucket is on AWS.
if [[ -n "$S3_UPLOADS_ENDPOINT" ]]; then
    HOST_URL="$S3_UPLOADS_ENDPOINT"
else
    HOST_URL="https://s3.${S3_UPLOADS_REGION}.amazonaws.com"
fi

# A key or secret can contain /, @ or +, all of which change the meaning of the URL the
# client parses, so both are percent-encoded.
ALIAS_URL="$(
    S3_UPLOADS_KEY="$S3_UPLOADS_KEY" S3_UPLOADS_SECRET="$S3_UPLOADS_SECRET" HOST_URL="$HOST_URL" \
    python3 - <<'PY'
import os
from urllib.parse import quote, urlsplit
host = urlsplit(os.environ["HOST_URL"])
user = quote(os.environ["S3_UPLOADS_KEY"], safe="")
secret = quote(os.environ["S3_UPLOADS_SECRET"], safe="")
print(f"{host.scheme}://{user}:{secret}@{host.netloc}")
PY
)"
export MC_HOST_wps3="$ALIAS_URL"
unset S3_UPLOADS_SECRET S3_MEDIA_SECRET

# S3_UPLOADS_BUCKET may carry a prefix ("bucket/site-prefix"); the client takes that path
# as written.
REMOTE="wps3/${S3_UPLOADS_BUCKET}/uploads"

# Logs, caches and the optimizer's untouched originals. They cost storage, they are never
# served, and wc-logs is the one directory a misconfigured bucket policy would expose.
EXCLUDES=(
    --exclude "wc-logs/*"
    --exclude "cache/*"
    --exclude "wio_backup/*"
    --exclude "wrio/*"
)

if [[ "$DIRECTION" == "upload" ]]; then
    SOURCE="$LOCAL"; TARGET="$REMOTE"
else
    SOURCE="$REMOTE"; TARGET="$LOCAL"
    # New files must stay writable by the web server's group, or the next upload from
    # the admin fails on a directory it cannot write into.
    umask 002
fi

echo "$DIRECTION: $SOURCE -> $TARGET"
[[ ${#DRY[@]} -gt 0 ]] && echo "(dry run: nothing is transferred)"

run_mirror "$SOURCE" "$TARGET" "${DRY[@]}" "${EXCLUDES[@]}"
