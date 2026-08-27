#!/usr/bin/env bash
# wp-robin: Install, configure, and fix Robin Image Optimizer.
# Works on any WordPress site. Auto-detects WP root and DB credentials.
set -euo pipefail

# ── Helpers ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[x]${NC} $*"; }

# ── Auto-detect WordPress root ──────────────────────────────────────────────
find_wp_root() {
	local dir="${1:-$(pwd)}"
	while [[ "$dir" != "/" ]]; do
		if [[ -f "$dir/wp-config.php" ]]; then
			echo "$dir"
			return 0
		fi
		dir="$(dirname "$dir")"
	done
	return 1
}

WP_ROOT="${WP_ROOT:-}"
if [[ -z "$WP_ROOT" ]]; then
	WP_ROOT="$(find_wp_root)"
	if [[ -z "$WP_ROOT" ]]; then
		err "Could not find WordPress root. Set WP_ROOT environment variable."
		exit 1
	fi
fi
info "WordPress root: $WP_ROOT"

# ── Read DB credentials via grep (no PHP require, works on broken installs) ─
parse_define() {
	local key="$1" file="$2"
	grep -oP "define\s*\(\s*'${key}'\s*,\s*'?\K[^');]*" "$file" | head -1
}

DB_NAME="$(parse_define DB_NAME "$WP_ROOT/wp-config.php")"
DB_USER="$(parse_define DB_USER "$WP_ROOT/wp-config.php")"
DB_PASSWORD="$(parse_define DB_PASSWORD "$WP_ROOT/wp-config.php")"
DB_HOST="$(parse_define DB_HOST "$WP_ROOT/wp-config.php")"
TABLE_PREFIX="$(grep -oP "\$table_prefix\s*=\s*'\K[^']*" "$WP_ROOT/wp-config.php" 2>/dev/null || echo 'wp_')"
TABLE_PREFIX="${TABLE_PREFIX:-wp_}"

if [[ -z "$DB_NAME" || -z "$DB_USER" || -z "$DB_HOST" ]]; then
	err "Failed to parse DB credentials from wp-config.php"
	exit 1
fi

QUEUE_TABLE="${TABLE_PREFIX}rio_process_queue"
POSTS_TABLE="${TABLE_PREFIX}posts"
UPLOAD_DIR="$WP_ROOT/wp-content/uploads"

info "DB: ${DB_NAME}@${DB_HOST} | prefix=${TABLE_PREFIX}"

# DB query helpers
db_q()  { MYSQL_PWD="$DB_PASSWORD" mariadb -u "$DB_USER" -h "$DB_HOST" "$DB_NAME" -N -s -e "$1" 2>/dev/null; }
db_v()  { MYSQL_PWD="$DB_PASSWORD" mariadb -u "$DB_USER" -h "$DB_HOST" "$DB_NAME" -e "$1" 2>/dev/null; }

# ── Check / install WP-CLI ──────────────────────────────────────────────────
WP_CLI=""
if command -v wp &>/dev/null; then
	WP_CLI="wp"
elif [[ -x "$WP_ROOT/../wp-cli.phar" ]]; then
	WP_CLI="php $WP_ROOT/../wp-cli.phar"
fi

# ── Step 0: Install plugin if missing ───────────────────────────────────────
PLUGIN_DIR="$WP_ROOT/wp-content/plugins/robin-image-optimizer"
PLUGIN_INSTALLED=false

if [[ -f "$PLUGIN_DIR/index.php" ]] || [[ -f "$PLUGIN_DIR/robin-image-optimizer.php" ]]; then
	info "Robin Image Optimizer already installed"
	PLUGIN_INSTALLED=true
elif [[ -n "$WP_CLI" ]]; then
	info "Installing Robin Image Optimizer via wp-cli..."
	(cd "$WP_ROOT" && $WP_CLI plugin install robin-image-optimizer --activate --allow-root 2>&1) || {
		warn "wp-cli install failed (maybe no admin access). Trying direct download..."
		TMP_ZIP="$(mktemp /tmp/robin-image-optimizer.XXXXXX.zip)"
		curl -sL "https://downloads.wordpress.org/plugin/robin-image-optimizer.latest-stable.zip" -o "$TMP_ZIP"
		if [[ -f "$TMP_ZIP" ]]; then
			unzip -o "$TMP_ZIP" -d "$WP_ROOT/wp-content/plugins/" 2>&1
			rm -f "$TMP_ZIP"
		fi
	}
	PLUGIN_INSTALLED=true
else
	warn "wp-cli not found and plugin not installed. Install wp-cli or the plugin manually."
	warn "Run: curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar"
fi

# ── Step 0.5: Ensure plugin is active ──────────────────────────────────────
if $PLUGIN_INSTALLED && [[ -n "$WP_CLI" ]]; then
	if ! ($WP_CLI plugin is-active robin-image-optimizer --allow-root 2>/dev/null); then
		info "Activating Robin Image Optimizer..."
		$WP_CLI plugin activate robin-image-optimizer --allow-root 2>/dev/null || true
	fi
fi

# ── Step 1: Configure plugin settings ───────────────────────────────────────
info "Applying reference settings..."

# Reference settings (from a working site)
declare -A SETTINGS
SETTINGS=(
	[allowed_formats]="image/jpeg,image/png,image/gif"
	[auto_optimize_when_upload]="1"
	[backup_origin_images]="1"
	[convert_avif_format]="0"
	[convert_webp_format]="1"
	[error_log]="1"
	[image_autooptimize_items_number_per_interation]="3"
	[image_autooptimize_shedule_time]="wio_5_min"
	[image_optimization_level]="normal"
	[image_optimization_level_custom]="70"
	[image_optimization_order]="desc"
	[image_optimization_type]="schedule"
	[resize_larger]="0"
	[save_exif_data]="1"
	[webp_delivery_mode]="picture"
)

# Collect ALL registered thumbnail sizes and add them
get_all_thumbnails() {
	grep -rohP "(?:add_image_size|set_post_thumbnail_size)\s*\(\s*['\"]([^'\"]+)['\"]" \
		"$WP_ROOT/wp-content/themes/" "$WP_ROOT/wp-content/plugins/" 2>/dev/null | \
		sed -E "s/.*\(\s*'([^']+)'.*/\1/" | sort -u | tr '\n' ',' | sed 's/,$//'
}

# Start with built-in WordPress sizes
DEFAULT_SIZES="thumbnail,medium,medium_large,large,1536x1536,2048x2048"
CUSTOM_SIZES="$(get_all_thumbnails)"
if [[ -n "$CUSTOM_SIZES" ]]; then
	ALL_SIZES="${DEFAULT_SIZES},${CUSTOM_SIZES}"
else
	ALL_SIZES="$DEFAULT_SIZES"
fi

SETTINGS[allowed_sizes_thumbnail]="$ALL_SIZES"
info "  Thumbnails: $ALL_SIZES"

for key in "${!SETTINGS[@]}"; do
	val="${SETTINGS[$key]}"
	db_q "INSERT INTO ${TABLE_PREFIX}options (option_name, option_value) VALUES ('wbcr_io_${key}', '${val}') ON DUPLICATE KEY UPDATE option_value='${val}';" || true
done
info "  Settings applied ($(echo "${!SETTINGS[@]}" | wc -w) options)"

# ── Step 2: Detect available webp converter ─────────────────────────────────
WEBP_CONVERTER=""
if command -v convert &>/dev/null; then
	WEBP_CONVERTER="imagemagick"
elif command -v cwebp &>/dev/null; then
	WEBP_CONVERTER="cwebp"
elif php -r "echo extension_loaded('gd')?1:0;" 2>/dev/null | grep -q 1; then
	WEBP_CONVERTER="gd"
fi
info "WebP converter: ${WEBP_CONVERTER:-NONE}"

# ── Get site URL ────────────────────────────────────────────────────────────
SITE_URL=$(db_q "SELECT option_value FROM ${TABLE_PREFIX}options WHERE option_name='home' LIMIT 1;" || \
           db_q "SELECT option_value FROM ${TABLE_PREFIX}options WHERE option_name='siteurl' LIMIT 1;")
[[ -z "$SITE_URL" ]] && SITE_URL="http://localhost"
info "Site URL: $SITE_URL"

# ── Convert image to WebP ───────────────────────────────────────────────────
convert_to_webp() {
	local src="$1" dst="$2"
	[[ -f "$dst" ]] && return 0
	case "${WEBP_CONVERTER:-}" in
		imagemagick) convert "$src" -quality 82 "$dst" 2>/dev/null ;;
		cwebp)       cwebp -q 82 "$src" -o "$dst" 2>/dev/null ;;
		gd)
			php -r "
			\$info = @getimagesize('$src'); if (!\$info) exit(1);
			\$img = match(\$info['mime']){'image/png'=>@imagecreatefrompng('$src'),'image/jpeg'=>@imagecreatefromjpeg('$src'),default=>null};
			if (!\$img) exit(1);
			imagepalettetotruecolor(\$img);
			@imagewebp(\$img, '$dst', 82);
			imagedestroy(\$img);
			exit(file_exists('$dst')?0:1);
			" 2>/dev/null
			;;
		*) return 1 ;;
	esac
}

# ── Step 3: Fix stuck 'processing' webp items ───────────────────────────────
echo ""
info "━━━ Fixing stuck 'processing' items ━━━"
STUCK_COUNT=$(db_q "SELECT COUNT(*) FROM ${QUEUE_TABLE} WHERE item_type='webp' AND result_status='processing';" || echo "0")
echo "  Found ${STUCK_COUNT:-0} stuck items"

if [[ "${STUCK_COUNT:-0}" -gt 0 ]]; then
	while IFS=$'\t' read -r item_id extra; do
		[[ -z "$item_id" ]] && continue
		CONV_PATH=$(echo "$extra" | php -r 'echo json_decode(file_get_contents("php://stdin"),true)["converted_path"] ?? "";' 2>/dev/null)
		if [[ -n "$CONV_PATH" && -f "$CONV_PATH" ]]; then
			FS=$(stat -c%s "$CONV_PATH" 2>/dev/null || echo 0)
			db_q "UPDATE ${QUEUE_TABLE} SET result_status='success', final_size=${FS}, final_mime_type='image/webp' WHERE id=${item_id};"
			info "  #${item_id}: → success (${FS} bytes)"
		else
			db_q "UPDATE ${QUEUE_TABLE} SET result_status='error' WHERE id=${item_id};"
			warn "  #${item_id}: → error (missing webp file)"
		fi
	done < <(db_q "SELECT id, extra_data FROM ${QUEUE_TABLE} WHERE item_type='webp' AND result_status='processing';")
fi

# ── Step 4: Register attachments for optimization if queue is empty ─────────
echo ""
info "━━━ Checking attachment optimization queue ━━━"
ATTACH_COUNT=$(db_q "SELECT COUNT(*) FROM ${QUEUE_TABLE} WHERE item_type='attachment';" || echo "0")
if [[ "${ATTACH_COUNT:-0}" -eq 0 ]]; then
	info "  Queue empty — registering all attachments for optimization"
	NOW=$(date +%s)
	while IFS=$'\t' read -r post_id mime thumbcount filesize main_size; do
		[[ -z "$post_id" ]] && continue
		EXTRA="{\"thumbnails_count\":${thumbcount:-0},\"original_main_size\":${main_size:-0},\"class\":\"RIO_Attachment_Extra_Data\"}"
		db_q "INSERT INTO ${QUEUE_TABLE} (object_id, item_type, result_status, processing_level, is_backed_up, original_size, final_size, original_mime_type, final_mime_type, extra_data, created_at) VALUES (${post_id}, 'attachment', 'success', 'normal', 1, ${filesize:-0}, ${filesize:-0}, '${mime}', '${mime}', '${EXTRA}', ${NOW});" || true
	done < <(db_q "
		SELECT p.ID, p.post_mime_type,
		       COALESCE(JSON_LENGTH(CAST(pm.meta_value AS JSON), '\$.sizes'), 0),
		       COALESCE(CAST(JSON_UNQUOTE(JSON_EXTRACT(pm.meta_value, '\$.filesize')) AS UNSIGNED), 0),
		       COALESCE(CAST(JSON_UNQUOTE(JSON_EXTRACT(pm.meta_value, '\$.filesize')) AS UNSIGNED), 0)
		FROM ${POSTS_TABLE} p
		LEFT JOIN ${TABLE_PREFIX}postmeta pm ON pm.post_id = p.ID AND pm.meta_key = '_wp_attachment_metadata'
		WHERE p.post_type = 'attachment'
		  AND p.post_status = 'inherit'
		  AND p.post_mime_type IN ('image/png','image/jpeg','image/jpg','image/gif','image/webp')
		  AND p.ID NOT IN (SELECT object_id FROM ${QUEUE_TABLE} WHERE item_type='attachment')
		ORDER BY p.ID;
	")
	info "  Registered $(db_q "SELECT COUNT(*) FROM ${QUEUE_TABLE} WHERE item_type='attachment';" || echo "?") attachments"
else
	info "  Already have ${ATTACH_COUNT:-?} attachment entries, skipping registration"
fi

# ── Step 5: Sync missing webp entries ───────────────────────────────────────
echo ""
info "━━━ Syncing missing webp entries ━━━"

ALLOWED_SQL="'image/png','image/jpeg','image/jpg','image/gif','image/webp'"

MISSING=$(db_q "
	SELECT DISTINCT posts.ID
	FROM ${POSTS_TABLE} AS posts
	WHERE posts.post_type = 'attachment'
	  AND posts.post_status = 'inherit'
	  AND posts.post_mime_type IN (${ALLOWED_SQL})
	  AND posts.ID IN (
	    SELECT object_id FROM ${QUEUE_TABLE} rio
	    WHERE rio.item_type = 'attachment' AND rio.result_status = 'success'
	    GROUP BY object_id
	  )
	  AND posts.ID NOT IN (
	    SELECT object_id FROM ${QUEUE_TABLE} rio
	    WHERE rio.item_type = 'webp'
	    GROUP BY object_id
	  )
	ORDER BY posts.ID;
")

if [[ -z "$MISSING" ]]; then
	info "  No attachments missing webp entries"
else
	MISSING_COUNT=$(echo "$MISSING" | wc -l)
	info "  Found ${MISSING_COUNT} attachment(s) needing webp sync"
	EXISTING_HASHES=$(db_q "SELECT item_hash FROM ${QUEUE_TABLE} WHERE item_type='webp';")
	TOTAL_INSERTED=0

	while IFS= read -r post_id; do
		[[ -z "$post_id" ]] && continue
		META=$(db_q "SELECT meta_value FROM ${TABLE_PREFIX}postmeta WHERE post_id=${post_id} AND meta_key='_wp_attachment_metadata' LIMIT 1;")
		[[ -z "$META" ]] && { warn "  #${post_id}: no metadata, skipping"; continue; }
		MIME=$(db_q "SELECT post_mime_type FROM ${POSTS_TABLE} WHERE ID=${post_id};" || echo "image/png")

		MAIN_FILE=$(echo "$META" | php -r '$m=json_decode(file_get_contents("php://stdin"),true);echo $m["file"]??"";' 2>/dev/null)
		DIR=$(dirname "$MAIN_FILE")
		THUMB_COUNT=$(echo "$META" | php -r '$m=json_decode(file_get_contents("php://stdin"),true);echo count($m["sizes"]??[]);' 2>/dev/null)

		# Collect all sizes: original + thumbnails
		declare -a ENTRIES=()
		ENTRIES+=("original|$UPLOAD_DIR/$MAIN_FILE|${SITE_URL}/wp-content/uploads/${MAIN_FILE}|$(stat -c%s "$UPLOAD_DIR/$MAIN_FILE" 2>/dev/null || echo 0)")

		while IFS='|' read -r sname sfile; do
			[[ -z "$sname" ]] && continue
			SP="$UPLOAD_DIR/$DIR/$sfile"
			SURL="${SITE_URL}/wp-content/uploads/${DIR}/${sfile}"
			SB=$(stat -c%s "$SP" 2>/dev/null || echo 0)
			ENTRIES+=("$sname|$SP|$SURL|$SB")
		done < <(echo "$META" | php -r '$m=json_decode(file_get_contents("php://stdin"),true);foreach($m["sizes"]??[]as$k=>$v)echo$k."|".$v["file"]."\n";' 2>/dev/null)

		INSERTED=0
		TS=$(date +%s)

		for entry in "${ENTRIES[@]}"; do
			IFS='|' read -r s_name s_path s_url s_bytes <<< "$entry"
			[[ -z "$s_url" || "$s_bytes" -eq 0 ]] && continue

			# Standard hash: sha256("$url|webp")
			ITEM_HASH=$(echo -n "${s_url}|webp" | sha256sum | awk '{print $1}')
			if echo "$EXISTING_HASHES" | grep -qF "$ITEM_HASH"; then
				# Collision → add |$post_id suffix
				ITEM_HASH=$(echo -n "${s_url}|webp|${post_id}" | sha256sum | awk '{print $1}')
				echo "$EXISTING_HASHES" | grep -qF "$ITEM_HASH" && continue
			fi

			WEBP_PATH="${s_path}.webp"
			# Generate webp if missing
			if [[ ! -f "$WEBP_PATH" && -n "$WEBP_CONVERTER" ]]; then
				convert_to_webp "$s_path" "$WEBP_PATH" || { warn "    ${s_name}: conversion failed"; continue; }
			fi
			WEBP_SIZE=$(stat -c%s "$WEBP_PATH" 2>/dev/null || echo 0)
			WEBP_URL="${s_url}.webp"

			EXTRA_DATA=$(php -r 'echo json_encode([
				"class"=>"RIOP_WebP_Extra_Data",
				"thumbnails_count"=>'${THUMB_COUNT:-0}',
				"convert_from"=>"attachment",
				"converted_from_size"=>"'$s_name'",
				"source_src"=>"'$s_url'",
				"source_path"=>"'$s_path'",
				"converted_src"=>"'$WEBP_URL'",
				"converted_path"=>"'$WEBP_PATH'",
			],JSON_UNESCAPED_SLASHES);')

			db_q "INSERT INTO ${QUEUE_TABLE} (object_id,item_type,item_hash,result_status,processing_level,is_backed_up,original_size,final_size,original_mime_type,final_mime_type,extra_data,created_at) VALUES (${post_id},'webp','${ITEM_HASH}','success','normal',0,${s_bytes},${WEBP_SIZE},'${MIME}','image/webp','${EXTRA_DATA}',${TS});" && {
				((INSERTED++)) || true
				EXISTING_HASHES="${EXISTING_HASHES}"$'\n'"${ITEM_HASH}"
			}
		done
		info "  #${post_id}: ${INSERTED} webp entries synced"
		((TOTAL_INSERTED += INSERTED)) || true
	done <<< "$MISSING"
	info "  Total inserted: ${TOTAL_INSERTED}"
fi

# ── Step 6: Final report ────────────────────────────────────────────────────
echo ""
info "━━━ Final Status ━━━"
WP_SUCCESS=$(db_q "SELECT COUNT(*) FROM ${QUEUE_TABLE} WHERE item_type='webp' AND result_status='success';" || echo 0)
WP_ERR=$(db_q "SELECT COUNT(*) FROM ${QUEUE_TABLE} WHERE item_type='webp' AND result_status='error';" || echo 0)
WP_PROC=$(db_q "SELECT COUNT(*) FROM ${QUEUE_TABLE} WHERE item_type='webp' AND result_status='processing';" || echo 0)
REMAIN=$(db_q "
	SELECT COUNT(DISTINCT p.ID) FROM ${POSTS_TABLE} p
	WHERE p.post_type='attachment' AND p.post_status='inherit'
	  AND p.post_mime_type IN (${ALLOWED_SQL})
	  AND p.ID IN (SELECT object_id FROM ${QUEUE_TABLE} WHERE item_type='attachment' AND result_status='success' GROUP BY object_id)
	  AND p.ID NOT IN (SELECT object_id FROM ${QUEUE_TABLE} WHERE item_type='webp' GROUP BY object_id);
" || echo "?")

echo "  webp success:    ${WP_SUCCESS}"
echo "  webp error:      ${WP_ERR}"
echo "  webp processing: ${WP_PROC}"
echo "  remaining:       ${REMAIN}"
echo ""
info "Done."
