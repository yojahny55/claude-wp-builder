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
        if [[ -n "$S3_UPLOADS_USE_INSTANCE_PROFILE" ]]; then
            WHY="This site authenticates with the server's IAM role, which signs the plugin's requests
but cannot be handed to a separate client."
        else
            WHY="This site has neither a key pair nor S3_UPLOADS_USE_INSTANCE_PROFILE, so there is
nothing here to sign a request with. Check $CONFIG first."
        fi
        cat >&2 <<TXT
ERROR: $CONFIG has no key pair.

$WHY Two ways forward:

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

# The alias goes in a private configuration directory, not in MC_HOST_wps3 and not in
# `mcli alias set`.
#
# MC_HOST_<alias> is a URL, and the client does NOT percent-decode the credentials in it:
# measured against a real server, a secret holding `/`, `@`, `+`, `%`, `#` or `?` worked
# verbatim and failed once encoded, while `:` — the character that separates the key from
# the secret — failed either way. Encoding was therefore wrong for exactly the secrets it
# was meant to protect, and no spelling of that URL can carry a secret with a colon. AWS
# generates secret keys from base64, so `/` and `+` are ordinary in one.
#
# `mcli alias set` takes the secret in argv, where `ps` shows it to every user on the
# machine, which is the thing this script avoids everywhere else. A JSON file in a 0700
# directory does neither: the client reads it through MC_CONFIG_DIR.
MCLI_CONFIG_DIR="$(mktemp -d -t wp-s3-mc-XXXXXX)"
chmod 700 "$MCLI_CONFIG_DIR"
trap 'rm -rf "$MCLI_CONFIG_DIR"' EXIT

S3_UPLOADS_KEY="$S3_UPLOADS_KEY" S3_UPLOADS_SECRET="$S3_UPLOADS_SECRET" HOST_URL="$HOST_URL" \
CONFIG_DIR="$MCLI_CONFIG_DIR" python3 - <<'PY'
import json, os, stat

path = os.path.join(os.environ["CONFIG_DIR"], "config.json")
config = {
    "version": "10",
    "aliases": {
        "wps3": {
            "url": os.environ["HOST_URL"],
            "accessKey": os.environ["S3_UPLOADS_KEY"],
            "secretKey": os.environ["S3_UPLOADS_SECRET"],
            "api": "s3v4",
            "path": "auto",
        }
    },
}
fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, stat.S_IRUSR | stat.S_IWUSR)
with os.fdopen(fd, "w") as handle:
    json.dump(config, handle)
PY

export MC_CONFIG_DIR="$MCLI_CONFIG_DIR"
# Both halves of the credential leave the environment now that they are in the file the
# client reads: the key id is the less sensitive half, not a harmless one, and every child
# process below inherits whatever is still set here.
unset S3_UPLOADS_KEY S3_UPLOADS_SECRET S3_MEDIA_KEY S3_MEDIA_SECRET

# S3_UPLOADS_BUCKET may carry a prefix ("bucket/site-prefix"); the client takes that path
# as written, so a trailing slash would produce an empty path segment and a key that does
# not match what the plugin writes.
REMOTE="wps3/${S3_UPLOADS_BUCKET%/}/uploads"

# Logs, caches, the optimizer's untouched originals, and the form attachments.
#
# None of them is ever served from a media URL, so nothing on the site breaks by their
# absence, and two of them are the directories a mistake in the bucket policy would
# expose: wc-logs holds whatever WooCommerce logged, and wpcf7_uploads holds what people
# attached to a form — CVs, identity documents, invoices. New installs never write there
# (s3-config.php redirects both to local paths), but a site migrating in arrives with
# years of them, and keeping them out of the bucket is the guard that does not depend on
# a policy being right.
EXCLUDES=(
    --exclude "wc-logs/*"
    --exclude "cache/*"
    --exclude "wio_backup/*"
    --exclude "wrio/*"
    --exclude "wpcf7_uploads/*"
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
