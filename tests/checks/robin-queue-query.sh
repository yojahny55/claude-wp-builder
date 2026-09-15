#!/usr/bin/env bash
# Two contracts in the wp-robin queue queries, both of which failed silently rather than
# erroring — the worst shape for this script, whose whole job is to undo a false
# "nothing left to do".
#
# 1. TO_BASE64() wraps its output every 76 characters. In batch mode the client escapes
#    those newlines to a literal backslash-n, and base64_decode() drops the backslash but
#    keeps the `n`, which is a valid base64 character. Every row then decodes to garbage,
#    unserialize() fails, the file name comes back empty, and the step reports every
#    attachment as missing from disk while the files are all present. The wrap must be
#    stripped server-side.
#
# 2. The mime types to queue must follow the allowed_formats setting this script writes
#    one step earlier, not a second hardcoded copy of it. The copy carried image/webp,
#    which the setting does not: on a library that is already WebP the step re-encoded
#    every file into <name>.webp.webp, a second lossy pass over an already-lossy source
#    that webp_delivery_mode=picture then serves in place of the original.
set -uo pipefail
cd "$(dirname "$0")/../.."

script=skills/wp-robin/scripts/robin-fix.sh
[ -f "$script" ] || { echo "FAIL: $script is missing"; exit 1; }

grep -Fq "REPLACE(TO_BASE64(pm.meta_value), CHAR(10), '')" "$script" \
  || { echo "FAIL: $script does not strip TO_BASE64() wrapping with CHAR(10) — a string replacement depends on MySQL backslash mode"; exit 1; }
grep -Fq 'str_replace("\\n", "", $p[2] ?? "")' "$script" \
  || { echo "FAIL: $script does not strip client-escaped literal backslash-n sequences before base64 decoding"; exit 1; }

# The mime list must be built once, from the setting. A literal list inside a query is
# the bug: it cannot follow allowed_formats, and nothing downstream notices.
hits=$(grep -n "post_mime_type IN ('image/" "$script" 2>/dev/null || true)
[ -z "$hits" ] \
  || { echo "FAIL: $script hardcodes the mime list in a query instead of deriving it from allowed_formats:"; echo "$hits"; exit 1; }

grep -q 'ALLOWED_SQL+=' "$script" \
  || { echo "FAIL: $script no longer builds ALLOWED_SQL from \${SETTINGS[allowed_formats]}"; exit 1; }
grep -Fq '^(image/png|image/jpeg|image/jpg|image/gif)$' "$script" \
  || { echo "FAIL: $script interpolates allowed_formats into SQL without a strict MIME allowlist"; exit 1; }

# An emptied setting must not widen the query to every attachment on the site.
grep -q '\[\[ -z "\$ALLOWED_SQL" \]\]' "$script" \
  || { echo "FAIL: $script has no fallback for an emptied allowed_formats — the query would match every attachment"; exit 1; }

echo "PASS"
