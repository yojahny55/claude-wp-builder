#!/usr/bin/env bash
# Installs and configures S3 Uploads on a WordPress root. Does NOT activate the plugin
# and does NOT move a single media file: /wp-s3-media does that, afterwards.
#
# Every value arrives as a flag except the secret, which arrives in the environment as
# S3_UPLOADS_SECRET_VALUE. A secret in argv is readable by any user on the machine
# through `ps`, and ends up in the shell history of whoever pastes the command.
#
# Usage:
#   S3_UPLOADS_SECRET_VALUE=... bash s3-setup.sh \
#       --wp-root /path/to/wordpress \
#       --bucket <bucket> --region <region> \
#       --bucket-url https://media.example.com \
#       [--endpoint https://s3.example.com] \
#       [--auth instance|key] [--key <access-key-id>] \
#       [--version 3.0.13] [--skip-plugin-install]

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_VERSION="3.0.13"

WP_ROOT=""
BUCKET=""
REGION=""
BUCKET_URL=""
ENDPOINT=""
AUTH="key"
KEY=""
SKIP_INSTALL="no"

die() { echo "ERROR: $*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --wp-root)    WP_ROOT="${2:-}"; shift 2 ;;
        --bucket)     BUCKET="${2:-}"; shift 2 ;;
        --region)     REGION="${2:-}"; shift 2 ;;
        --bucket-url) BUCKET_URL="${2:-}"; shift 2 ;;
        --endpoint)   ENDPOINT="${2:-}"; shift 2 ;;
        --auth)       AUTH="${2:-}"; shift 2 ;;
        --key)        KEY="${2:-}"; shift 2 ;;
        --version)    PLUGIN_VERSION="${2:-}"; shift 2 ;;
        --skip-plugin-install) SKIP_INSTALL="yes"; shift ;;
        *) die "unknown option: $1" ;;
    esac
done

WP_ROOT="${WP_ROOT%/}"
[[ -n "$WP_ROOT" ]] || die "--wp-root is required"
[[ -f "$WP_ROOT/wp-config.php" ]] || die "$WP_ROOT is not a WordPress root: no wp-config.php there"
[[ -n "$BUCKET" ]]     || die "--bucket is required"
[[ -n "$REGION" ]]     || die "--region is required"
[[ -n "$BUCKET_URL" ]] || die "--bucket-url is required"

case "$AUTH" in
    instance)
        [[ -z "${S3_UPLOADS_SECRET_VALUE:-}" ]] || die "--auth instance takes no secret"
        ;;
    key)
        [[ -n "$KEY" ]] || die "--auth key needs --key"
        [[ -n "${S3_UPLOADS_SECRET_VALUE:-}" ]] || die "--auth key needs S3_UPLOADS_SECRET_VALUE in the environment"
        ;;
    *) die "--auth must be 'instance' or 'key'" ;;
esac

# These three land inside single-quoted PHP literals that the template already carries the
# quotes for, so a quote or a backslash in one would break the file rather than be stored.
# None of them can legitimately contain either: bucket names and regions are alphanumeric
# with dashes, and a URL escapes both.
for value in "$BUCKET" "$REGION" "$BUCKET_URL" "$ENDPOINT"; do
    case "$value" in
        *\'*|*\\*) die "a quote or a backslash in '$value' cannot be written to s3-config.php" ;;
    esac
done

# The bucket URL is what every media URL is built from. A trailing slash produces
# double slashes in every src on the site.
BUCKET_URL="${BUCKET_URL%/}"
ENDPOINT="${ENDPOINT%/}"

CONFIG="$WP_ROOT/s3-config.php"
MU_DIR="$WP_ROOT/wp-content/mu-plugins"
PLUGIN_DIR="$WP_ROOT/wp-content/plugins/S3-Uploads"
STAMP="$(date +%Y%m%d-%H%M%S)"

echo "== S3 Uploads setup on $WP_ROOT =="

# ---------------------------------------------------------------- 1. the plugin

# Since 3.0.10 the release no longer ships vendor/, and without it the plugin fatals on
# activation: the AWS SDK is simply not there. A directory is therefore not evidence of
# an installed plugin; vendor/autoload.php is.
install_vendor() {
    command -v composer >/dev/null || die "composer is required: $PLUGIN_DIR has no vendor/ and the release does not ship one"

    # A composer.lock dependency declares ext-iconv, which several distributions leave
    # out of the PHP they ship. The plugin never calls iconv() at runtime — the polyfill
    # that requires it is only reached through Symfony's console, which does not run
    # here — so the platform requirement is ignored rather than installed.
    local args=( install --no-dev --optimize-autoloader --no-interaction )
    if ! php -m | grep -qix iconv; then
        echo "   PHP has no iconv extension: installing with --ignore-platform-req=ext-iconv"
        args+=( --ignore-platform-req=ext-iconv )
    fi

    ( cd "$PLUGIN_DIR" && composer "${args[@]}" ) \
        || die "composer install failed in $PLUGIN_DIR"

    [[ -f "$PLUGIN_DIR/vendor/autoload.php" ]] \
        || die "composer finished but $PLUGIN_DIR/vendor/autoload.php is still missing"
}

if [[ "$SKIP_INSTALL" == "yes" ]]; then
    echo "1. Plugin install skipped."
elif [[ -f "$PLUGIN_DIR/vendor/autoload.php" ]]; then
    echo "1. $PLUGIN_DIR is already installed with its vendor/ tree; leaving it alone."
elif [[ -d "$PLUGIN_DIR" ]]; then
    # Half an install: the download worked and composer did not. Finishing it is safer
    # than reporting success over a plugin that fatals the moment it is activated.
    echo "1. $PLUGIN_DIR exists without vendor/: completing the install"
    install_vendor
    echo "   Completed at $PLUGIN_DIR (not activated)."
else
    command -v curl >/dev/null || die "curl is required to download the plugin"
    command -v tar  >/dev/null || die "tar is required to unpack the plugin"
    echo "1. Downloading S3-Uploads $PLUGIN_VERSION"
    tmp="$(mktemp -d -t wp-s3-XXXXXX)"
    trap 'rm -rf "$tmp"' EXIT
    curl -fsSL -o "$tmp/s3-uploads.tar.gz" \
        "https://github.com/humanmade/S3-Uploads/archive/refs/tags/${PLUGIN_VERSION}.tar.gz" \
        || die "could not download S3-Uploads $PLUGIN_VERSION"
    tar -xzf "$tmp/s3-uploads.tar.gz" -C "$tmp"
    mv "$tmp/S3-Uploads-${PLUGIN_VERSION}" "$PLUGIN_DIR"

    [[ -f "$PLUGIN_DIR/vendor/autoload.php" ]] || install_vendor
    echo "   Installed at $PLUGIN_DIR (not activated)."
fi

# ---------------------------------------------------------------- 2. s3-config.php
if [[ -f "$CONFIG" ]]; then
    cp -p "$CONFIG" "$CONFIG.bak-$STAMP"
    echo "2. Existing s3-config.php backed up to s3-config.php.bak-$STAMP"
fi

if [[ -n "$ENDPOINT" ]]; then
    ENDPOINT_BLOCK="// S3-compatible server. On AWS this constant is left undefined and the bundled
// mu-plugin then does nothing.
define( 'S3_UPLOADS_ENDPOINT', '${ENDPOINT}' );
"
else
    ENDPOINT_BLOCK=""
fi

# The secret can contain / and &, so it is substituted with an exact string replacement
# rather than with sed — and it is quoted for PHP where it is written, not assembled by
# hand in the shell: a secret holding a single quote or a backslash would otherwise end
# the PHP string early, and the `php -l` below would condemn a file that already has the
# credentials in it.
BUCKET="$BUCKET" REGION="$REGION" BUCKET_URL="$BUCKET_URL" \
ENDPOINT_BLOCK="$ENDPOINT_BLOCK" AUTH="$AUTH" KEY="$KEY" \
SECRET="${S3_UPLOADS_SECRET_VALUE:-}" \
python3 - "$SKILL_DIR/templates/s3-config.php.tpl" "$CONFIG" <<'PY'
import os, sys

src, dest = sys.argv[1], sys.argv[2]


def php_single_quoted(value):
    # Inside '...' PHP only honours \' and \\ ; everything else is literal.
    return "'" + value.replace("\\", "\\\\").replace("'", "\\'") + "'"


if os.environ["AUTH"] == "instance":
    auth_block = (
        "// The server's IAM role supplies the credentials: no secret on disk.\n"
        "define( 'S3_UPLOADS_USE_INSTANCE_PROFILE', true );"
    )
else:
    auth_block = (
        "define( 'S3_UPLOADS_KEY',    %s );\n"
        "define( 'S3_UPLOADS_SECRET', %s );"
        % (php_single_quoted(os.environ["KEY"]), php_single_quoted(os.environ["SECRET"]))
    )

values = {
    "BUCKET": os.environ["BUCKET"],
    "REGION": os.environ["REGION"],
    "BUCKET_URL": os.environ["BUCKET_URL"],
    "ENDPOINT_BLOCK": os.environ["ENDPOINT_BLOCK"],
}

text = open(src).read()
for key, value in values.items():
    text = text.replace("{{%s}}" % key, value)
text = text.replace("{{AUTH_BLOCK}}", auth_block)

# Written and renamed, never truncated in place: this file holds the credentials, and a
# half-written one is a site that fatals on every request.
tmp = dest + ".wp-s3-tmp"
fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
with os.fdopen(fd, "w") as handle:
    handle.write(text)
    handle.flush()
    os.fsync(handle.fileno())
os.replace(tmp, dest)
PY

chmod 640 "$CONFIG"
php -l "$CONFIG" >/dev/null || die "the generated s3-config.php does not parse"
echo "2. Wrote $CONFIG (0640). Set its group to the web server's if it is not already."

# ---------------------------------------------------------------- 3. wp-config.php
if grep -q "s3-config.php" "$WP_ROOT/wp-config.php"; then
    echo "3. wp-config.php already requires s3-config.php; not touching it."
else
    cp -p "$WP_ROOT/wp-config.php" "$WP_ROOT/wp-config.php.bak-$STAMP"
    python3 - "$WP_ROOT/wp-config.php" <<'PY'
import os, re, sys
path = sys.argv[1]
with open(path) as handle:
    text = handle.read()
block = (
    "if ( file_exists( __DIR__ . '/s3-config.php' ) ) {\n"
    "\trequire __DIR__ . '/s3-config.php';\n"
    "}\n\n"
)
# The require must run before wp-settings.php, which is where WordPress reads the
# constants. After that line it is dead code.
pattern = re.compile(r"^([ \t]*)require_once\s+ABSPATH\s*\.\s*['\"]wp-settings\.php['\"]\s*;",
                     re.MULTILINE)
m = pattern.search(text)
if not m:
    sys.stderr.write("ERROR: no require_once ABSPATH . 'wp-settings.php' line in wp-config.php\n")
    sys.exit(1)
text = text[:m.start()] + block + text[m.start():]
tmp = path + ".wp-s3-tmp"
with open(tmp, "w") as handle:
    handle.write(text)
    handle.flush()
    os.fsync(handle.fileno())
os.replace(tmp, path)
PY
    php -l "$WP_ROOT/wp-config.php" >/dev/null || die "wp-config.php no longer parses; restore wp-config.php.bak-$STAMP"
    echo "3. Added the require to wp-config.php (backup: wp-config.php.bak-$STAMP)"
fi

# ---------------------------------------------------------------- 4. mu-plugin
mkdir -p "$MU_DIR"
cp "$SKILL_DIR/templates/s3-uploads-endpoint.php" "$MU_DIR/s3-uploads-endpoint.php"
chmod 644 "$MU_DIR/s3-uploads-endpoint.php"
php -l "$MU_DIR/s3-uploads-endpoint.php" >/dev/null || die "the mu-plugin does not parse"
echo "4. Installed $MU_DIR/s3-uploads-endpoint.php"

# ---------------------------------------------------------------- 5. keep it out of git
if [[ -f "$WP_ROOT/.gitignore" ]] && ! grep -qx "s3-config.php" "$WP_ROOT/.gitignore"; then
    printf '\n# Holds S3 credentials\ns3-config.php\n' >> "$WP_ROOT/.gitignore"
    echo "5. Added s3-config.php to .gitignore"
fi

# ---------------------------------------------------------------- 6. verify
#
# Not `wp s3-uploads verify`: that command is registered by the plugin, and the plugin is
# deliberately still deactivated at this point, so it would fail on every first run with
# "'s3-uploads' is not a registered wp command". check-credentials.php asks the bucket the
# same question through the same SDK, with the plugin off.
echo
if [[ -f "$PLUGIN_DIR/vendor/autoload.php" ]]; then
    echo "6. Checking the credentials against the bucket"
    php "$SKILL_DIR/scripts/check-credentials.php" "$WP_ROOT" || {
        echo "   The credentials could not list the bucket. Check the bucket name, the region," >&2
        echo "   the endpoint and the key pair before going further." >&2
        exit 1
    }
else
    echo "6. No vendor/ tree to test the credentials with; skipped."
    echo "   After activating the plugin, run: cd $WP_ROOT && wp s3-uploads verify"
fi

cat <<TXT

Done. The plugin is installed and configured, and nothing has moved yet.

Next:
  1. Migrate the existing library:  /wp-s3-media upload $WP_ROOT
  2. Then activate:                 wp plugin activate S3-Uploads && wp s3-uploads enable
  3. WooCommerce with downloadable products, Elementor: see the skill.
TXT
