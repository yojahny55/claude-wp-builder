#!/usr/bin/env bash
# Edge cases of four bin tools, each of which gave a wrong answer in silence:
#   css-contour-lint   an unknown flag or `--rule=x` ran every rule; `\bclear` matched
#                      `clearfix`; a border-only compound read a solid base class as transparent
#   contrast-propose   rgb()/rgba() gave NaN and "no shade reaches it"; bad input printed a stack
#   assets-fresh       `{}` or a mistyped key printed FRESH having checked nothing
#   theme-template-check  `widgets` assumed assets/js/src/index.js
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
command -v node >/dev/null || { echo "SKIP: node not installed"; exit 0; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
rc() { local c=0; "$@" > "$tmp/out" 2>&1 || c=$?; echo "$c"; }

# ── css-contour-lint ────────────────────────────────────────────────────────
lint=bin/css-contour-lint.mjs
mkdir -p "$tmp/css"; printf '.a{margin:0}\n' > "$tmp/css/a.css"
[ "$(rc node "$lint" "$tmp/css" --bogus)" = 2 ] || fail "unknown flag not a usage error"
grep >/dev/null -Fc 'unknown option: --bogus' "$tmp/out" || fail "unknown flag not named"
[ "$(rc node "$lint" "$tmp/css" --rule=nope)" = 2 ] || fail "--rule=nope not a usage error"
[ "$(rc node "$lint" "$tmp/css" --rule=thin-border)" = 0 ] || fail "--rule=thin-border refused"
sed -n 1p "$tmp/out" | grep >/dev/null -Fc 'PASS: thin-border (' || fail "--rule=thin-border did not narrow the rules: $(sed -n 1p "$tmp/out")"
mkdir -p "$tmp/rule"; printf '.btn{border:1px solid #333;border-radius:4px}\n' > "$tmp/rule/a.css"
[ "$(rc node "$lint" "$tmp/rule" --rule=search-clear)" = 0 ] || fail "--rule=search-clear ran thin-border too"
[ "$(rc node "$lint" "$tmp/rule" --rule=thin-border)" = 1 ] || fail "--rule=thin-border did not run its rule"

mkdir -p "$tmp/cf"
# Both outcomes fail the lint; the message says whether a clear control was recognised.
printf '<form><div class="row clearfix"><input type="search" name="s"></div></form>\n' > "$tmp/cf/s.php"
[ "$(rc node "$lint" "$tmp/cf" --rule search-clear)" = 1 ] || fail "clearfix page not flagged at all"
grep >/dev/null -Fc 'no custom clear control' "$tmp/out" || fail "clearfix was read as a clear control: $(cat "$tmp/out")"
for cls in clear btn-clear 'search clear'; do
  printf '<form><input type="search" name="s"><button type="button" class="%s">x</button></form>\n' "$cls" > "$tmp/cf/s.php"
  [ "$(rc node "$lint" "$tmp/cf" --rule search-clear)" = 1 ] || fail "class=\"$cls\" page not flagged"
  grep >/dev/null -Fc 'with a custom clear control' "$tmp/out" || fail "class=\"$cls\" is no longer a clear control: $(cat "$tmp/out")"
done

mkdir -p "$tmp/bg"
printf '.btn{background:#0a58ca;color:#fff}\n.btn.btn-primary{border:1px solid #fff;border-radius:6px}\n' > "$tmp/bg/a.css"
[ "$(rc node "$lint" "$tmp/bg")" = 0 ] || fail "a compound over a solid base class was read as transparent: $(cat "$tmp/out")"
printf '.btn{color:#fff}\n.btn.btn-primary{border:1px solid #fff;border-radius:6px}\n' > "$tmp/bg/a.css"
[ "$(rc node "$lint" "$tmp/bg")" = 1 ] || fail "a compound with no solid base was not flagged"

# ── contrast-propose ────────────────────────────────────────────────────────
cp=bin/contrast-propose.mjs
for p in 'rgb(216,92,51):#fff' 'rgba(216, 92, 51, 1):#ffffff' 'rgb(216 92 51):#fff' '#d85:#fff' '#d85c33ff:#fff'; do
  [ "$(rc node "$cp" --pair "$p")" = 0 ] || fail "contrast-propose refused $p"
  grep >/dev/null -Fc 'NaN' "$tmp/out" && fail "NaN for $p"
  grep >/dev/null -Fc 'no shade reaches it' "$tmp/out" && fail "no shade for $p"
done
node "$cp" --pair '#d85c33:#fff' | sed -n 3p | cut -d'|' -f3,5 > "$tmp/ref"
node "$cp" --pair 'rgb(216,92,51):#fff' | sed -n 3p | cut -d'|' -f3,5 > "$tmp/rgb"
cmp -s "$tmp/ref" "$tmp/rgb" || fail "rgb() and the same hex disagree"
# alpha: a translucent foreground is flattened onto its background, so it scores lower than opaque
a=$(node "$cp" --pair '#d85c3380:#fff' | sed -n 3p | cut -d'|' -f3 | tr -d ' ')
b=$(node "$cp" --pair '#d85c33:#fff' | sed -n 3p | cut -d'|' -f3 | tr -d ' ')
awk -v a="$a" -v b="$b" 'BEGIN{exit !(a+0 < b+0)}' || fail "alpha was ignored ($a vs $b)"
for args in "" "--pair" "--axe" "--pair zzz:#fff" "--pair #fff" "--pair #fff:#000:x" "--axe /nonexistent.json" "--nope"; do
  # shellcheck disable=SC2086
  [ "$(rc node "$cp" $args)" = 2 ] || fail "contrast-propose [$args] did not exit 2"
  grep >/dev/null -Fc 'at file:' "$tmp/out" && fail "contrast-propose [$args] printed a stack"
  grep >/dev/null -Fc 'ERROR:' "$tmp/out" || fail "contrast-propose [$args] gave no clear error"
done

# ── assets-fresh ────────────────────────────────────────────────────────────
af=bin/assets-fresh.mjs
th="$tmp/theme"; mkdir -p "$th/assets"
for j in '{}' '{"cut":{"a.css":{"source":"b.css","hash":"x"}}}' '{"sheets":{},"cuts":{}}' '{"cuts":[]}'; do
  echo "$j" > "$th/assets/build.json"
  [ "$(rc node "$af" "$th")" = 2 ] || fail "assets-fresh exit not 2 for $j"
  grep >/dev/null -Fc 'FRESH' "$tmp/out" && fail "assets-fresh printed FRESH for $j"
  grep >/dev/null -Fc 'critical cuts not checked' "$tmp/out" || fail "assets-fresh did not say the cuts were not checked for $j"
done
printf 'a{}' > "$th/s.css"; printf 'c{}' > "$th/c.css"
h=$(sha256sum "$th/s.css" | cut -d' ' -f1); ch=$(sha256sum "$th/c.css" | cut -d' ' -f1)
printf '{"cuts":{"c.css":{"source":"s.css","hash":"%s","cutHash":"%s"}}}' "$h" "$ch" > "$th/assets/build.json"
[ "$(rc node "$af" "$th")" = 0 ] || fail "a manifest with a matching cutHash is not fresh"
printf 'c{x}' > "$th/c.css"
[ "$(rc node "$af" "$th")" = 1 ] || fail "an edited cut was not stale"
grep >/dev/null -Fc 'content changed since it was generated' "$tmp/out" || fail "edited cut not named"
printf '{"cuts":{"c.css":{"source":"s.css","hash":"%s"}}}' "$h" > "$th/assets/build.json"
[ "$(rc node "$af" "$th")" = 0 ] || fail "a manifest without cutHash broke"

# ── theme-template-check: widgets entry ─────────────────────────────────────
tc=bin/theme-template-check.mjs
t="$tmp/t"; cp -R tests/fixtures/theme-template-check "$t"
mkdir -p "$t/assets/scripts"; rm -rf "$t/assets/js/src"
printf '?>\n<button role="tab">A</button>\n' >> "$t/index.php"
echo 'export {};' > "$t/assets/scripts/index.js"; echo 'export {};' > "$t/assets/scripts/tabs.js"
[ "$(rc node "$tc" "$t" --rule widgets)" = 1 ] || fail "widgets passed without the import"
grep >/dev/null -Fc 'assets/js/src/index.js' "$tmp/out" || fail "the message does not name the file it searched"
grep >/dev/null -Fc -- '--entry' "$tmp/out" || fail "the message does not say how to name another entry"
echo "import './tabs.js';" > "$t/assets/scripts/index.js"
[ "$(rc node "$tc" "$t" --rule widgets --entry assets/scripts/index.js)" = 0 ] || fail "--entry not honoured: $(cat "$tmp/out")"
printf '{"scripts":{"build":"wp-scripts build assets/scripts/index.js --output-path=assets/js/dist"}}' > "$t/package.json"
[ "$(rc node "$tc" "$t" --rule widgets)" = 0 ] || fail "entry not detected from package.json: $(cat "$tmp/out")"
echo 'export {};' > "$t/assets/scripts/index.js"
[ "$(rc node "$tc" "$t" --rule widgets)" = 1 ] || fail "detected entry without the import passed"
grep >/dev/null -Fc 'assets/scripts/index.js (from package.json)' "$tmp/out" || fail "message does not name the detected entry"
[ "$(rc node "$tc" "$t" --entry)" = 2 ] || fail "--entry without a value is not a usage error"

echo PASS
