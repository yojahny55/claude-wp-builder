#!/usr/bin/env bash
# The project path must reach `bash -c` as a positional argument, never interpolated into
# the -c string: a path with a single quote, $() or spaces would otherwise break the
# quoting or run as shell. Two halves: no site interpolates it any more, and every
# wp-config.mjs call, run for real with a hostile path, hands the script that exact path.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

# 1. Static: no `bash -c "...wp-config.mjs ... '${PROJECT_PATH}'..."` left.
if grep -rnE "bash -c \"node [^\"]*wp-config\.mjs[^\"]*PROJECT_PATH" commands skills >"$tmp/hits"; then
  fail "wp-config.mjs call still interpolates the path into a bash -c string:
$(cat "$tmp/hits")"
fi

# 1b. Static: no `bash -c "..."` in the plugin interpolates a project path or the web user,
# whatever the command (test -f, mkdir, cd, setfacl, wp core download, eval-file, store-kit).
if grep -rnE 'bash -c "[^"]*\$\{?(PROJECT_PATH|WEB_USER)' commands skills agents >"$tmp/hits"; then
  fail "a bash -c string still interpolates PROJECT_PATH or WEB_USER:
$(cat "$tmp/hits")"
fi

# 2. Behavioral: a stub wp-config.mjs records its argv, one per line.
mkdir -p "$tmp/plugin/bin"
cat >"$tmp/plugin/bin/wp-config.mjs" <<'JS'
import { writeFileSync } from 'node:fs';
writeFileSync(process.env.ARGV_OUT, process.argv.slice(2).join('\n') + '\n');
JS
hostile="$tmp/it's \$(touch $tmp/PWNED) a \`touch $tmp/PWNED2\`; dir"
# Single-quote it the way the gate block tells the reader to: each ' becomes '\''
quoted="'${hostile//\'/\'\\\'\'}'"

n=0
while IFS= read -r line; do
  line=${line%\\}
  cmd=${line//\$\{CLAUDE_PLUGIN_ROOT\}/$tmp/plugin}
  cmd=${cmd//\'\$\{PROJECT_PATH\}\'/$quoted}
  rm -f "$tmp/argv"
  ARGV_OUT="$tmp/argv" bash -c "$cmd" >/dev/null 2>&1 || true
  [ ! -e "$tmp/PWNED" ] && [ ! -e "$tmp/PWNED2" ] || fail "hostile path executed: $line"
  [ "$(sed -n 2p "$tmp/argv")" = "$hostile" ] \
    || fail "script did not receive the path intact: $line (got: $(sed -n 2p "$tmp/argv"))"
  n=$((n + 1))
done < <(grep -rhE "^bash -c 'node \"\\\$1/bin/wp-config\.mjs\" [a-z-]+ \"\\\$2\"[^']*' _ " commands skills | sort -u)
[ "$n" -ge 3 ] || fail "only $n wp-config.mjs call shapes exercised"

# 3. Behavioral, the other call shapes: every fixed single-quoted `-c` line that takes the path
# (or the web user) as an argument, run with stub binaries and the hostile path as a real
# directory. $WP stays a command plus flags that the child shell must still expand.
mkdir -p "$tmp/stub" "$tmp/plugin/skills/wp-woocommerce/scripts"
for b in docker-compose ddev lando npx setfacl wp; do
  cat >"$tmp/stub/$b" <<'SH'
#!/usr/bin/env bash
{ echo "CMD:$(basename "$0")"; echo "PWD:$PWD"; printf 'ARG:%s\n' "$@"; } >>"$ARGV_OUT"
SH
  chmod +x "$tmp/stub/$b"
done
printf '#!/usr/bin/env bash\nprintf "ARG:%%s\\n" "$@" >>"$ARGV_OUT"\n' >"$tmp/plugin/bin/store-kit-sync.sh"
mkdir -p "$hostile"
export WP="$tmp/stub/wp --allow-root"
webuser="we'b \$(touch $tmp/PWNED3)"
webq="'${webuser//\'/\'\\\'\'}'"

m=0
while IFS= read -r line; do
  line=${line%\\}
  cmd=${line//\$\{CLAUDE_PLUGIN_ROOT\}/$tmp/plugin}
  cmd=${cmd//\'\$\{WEB_USER\}\'/$webq}
  cmd=${cmd//\'\$\{PROJECT_PATH\}\'/$quoted}
  rm -f "$tmp/argv"; : >"$tmp/argv"
  out=$(PATH="$tmp/stub:$PATH" ARGV_OUT="$tmp/argv" bash -c "$cmd" 2>&1) || fail "call failed: $line ($out)"
  [ ! -e "$tmp/PWNED" ] && [ ! -e "$tmp/PWNED2" ] && [ ! -e "$tmp/PWNED3" ] \
    || fail "hostile value executed: $line"
  case $line in
    *"test -f"*) [ "$out" = NOT_FOUND ] || fail "test -f did not see the path intact: $line ($out)" ;;
    *"mkdir -p"*) [ -d "$hostile/wp-content/uploads" ] || fail "mkdir did not use the path intact: $line" ;;
    *"cd \"\$1\""*) grep -Fxq "PWD:$hostile" "$tmp/argv" || fail "cd did not land in the path: $line" ;;
    *setfacl*) grep -Fxq "ARG:g:$webuser:rwX" "$tmp/argv" && grep -Fxq "ARG:$hostile/wp-content" "$tmp/argv" \
         || fail "setfacl args not intact: $line" ;;
    *store-kit-sync*) grep -Fxq "ARG:$hostile/wp-content/plugins" "$tmp/argv" || fail "store-kit-sync path not intact: $line"
         case $line in *'$WP '*) grep -Fxq 'ARG:--allow-root' "$tmp/argv" || fail "\$WP flags were lost after store-kit-sync: $line" ;; esac ;;
    *'$WP '*) grep -Fxq 'ARG:--allow-root' "$tmp/argv" || fail "\$WP flags were lost: $line"
         grep -Fq "$hostile" "$tmp/argv" || fail "wp did not receive the path intact: $line" ;;
    *) fail "unrecognized call shape, no assertion covers it: $line" ;;
  esac
  m=$((m + 1))
done < <(grep -rhE "^(WP=\"\\\$WP\" )?bash -c '[^']*\\\$[12][^']*' _ .*(PROJECT_PATH|WEB_USER)" commands skills \
         | grep -v 'wp-config\.mjs' | sort -u)
[ "$m" -ge 12 ] || fail "only $m non-wp-config call shapes exercised"

echo PASS
