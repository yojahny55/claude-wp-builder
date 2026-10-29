#!/usr/bin/env bash
# Findings with design_impact: true must be approved before they are applied. The page that
# asks was built by hand three times and corrected each time: no before/after pictures, no
# choices inside the page, no way to copy the answers; the pasted text was then parsed by eye.
# bin/decision-sheet.mjs builds the page and parses the answers. This check runs --parse
# (no browser) and, when a Chromium is available, renders a card from a local fixture and
# asserts the injected "after" out-specifies the existing rule.
set -uo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }
tool=bin/decision-sheet.mjs
[ -f "$tool" ] || fail "$tool is missing"

fix=skills/wp-audit-run/references/fix.md
grep -Fq 'bin/decision-sheet.mjs' "$fix" || fail "$fix does not point at the decision sheet"
flat=$(tr '\n' ' ' < "$fix" | sed 's/  */ /g')
for needle in '--parse' 'Never apply a `visual` finding without an answer' '`accepted`'; do
  printf '%s' "$flat" | grep -Fq -- "$needle" || fail "$fix lost: $needle"
done
grep -Fq 'decision-sheet.mjs' README.md || fail "README bin table has no decision-sheet.mjs row"
grep -Fq 'decision-sheet.mjs' CLAUDE.md || fail "CLAUDE.md bin list has no decision-sheet.mjs"

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
export PATH="${PATH}"

# --- parse: tolerant of chatter around the block, last answer wins, reject => ledger accepted
cat > "$tmp/ans.txt" <<'TXT'
Here you go:
> DECISIONS v1
> DECISION A11Y-001: approve
DECISION a11y.002: reject | brand colour, keep it
DECISION UX_3: other | make it 4.6 not 4.5
DECISION UX_4: pending
DECISION A11Y-001: postpone | later
DECISION X-9: warm | picked the second shade
END DECISIONS
DECISION ignored-after-block: approve
TXT
out=$(node "$tool" --parse "$tmp/ans.txt") || fail "--parse exited non-zero on a valid block"
chk() { printf '%s' "$out" | node -e '
const j=JSON.parse(require("fs").readFileSync(0,"utf8")), d=Object.fromEntries(j.decisions.map(x=>[x.id,x]));
const bad=[];
if(j.decisions.length!==5)bad.push("count "+j.decisions.length);
if(d["A11Y-001"].status!=="postponed"||d["A11Y-001"].note!=="later")bad.push("last answer");
if(d["a11y.002"].status!=="rejected"||d["a11y.002"].ledger!=="accepted"||d["a11y.002"].note!=="brand colour, keep it")bad.push("reject");
if(d["UX_3"].status!=="other"||!d["UX_3"].note)bad.push("other");
if(d["UX_4"].status!=="pending")bad.push("pending");
if(d["X-9"].status!=="chosen"||d["X-9"].option!=="warm")bad.push("custom option");
if(d["ignored-after-block"])bad.push("line after END counted");
if(!j.warnings.some(w=>/A11Y-001.*more than once/.test(w)))bad.push("no duplicate warning");
if(bad.length){console.log(bad.join(", "));process.exit(1);}'; }
r=$(chk) || fail "--parse result wrong: $r"
printf 'DECISION A: other\n' | node "$tool" --parse - | grep -Fq 'has no note' || fail "empty other note was not warned"
echo 'nothing here' | node "$tool" --parse - >/dev/null 2>&1 && fail "--parse of text with no DECISION exited 0"


# --- escaping and sidecar ids: no browser needed (no page/selector => card without pictures)
cat > "$tmp/esc.json" <<'JSON'
[{"id":"E-1","title":"<img src=x onerror=1>\"&","why":"</textarea><script>alert(1)</script>",
  "options":[{"key":"approve","label":"</textarea><b>x</b>","recommended":true}]}]
JSON
cat > "$tmp/sc.json" <<'JSON'
{"findings":[{"check":"A","design_impact":true,"page":"/x"},{"check":"A","design_impact":true,"page":"/y"},{"design_impact":true},{"check":"Z","design_impact":false}]}
JSON
mkdir -p "$tmp/e1" "$tmp/e2"
node "$tool" build --out "$tmp/e1" --proposals "$tmp/esc.json" --date 2026-01-02 >/dev/null 2>&1
eh="$tmp/e1/decisions-2026-01-02.html"; [ -f "$eh" ] || fail "page with no browser-needing card was not written"
grep -Fq '&lt;img src=x' "$eh" || fail "title was not escaped"
grep -Fq '<img src=x' "$eh" && fail "raw title markup reached the page"
grep -Fq '<script>alert' "$eh" && fail "raw script from a proposal reached the page"
node "$tool" build --out "$tmp/e2" --sidecar "$tmp/sc.json" --date 2026-01-02 >/dev/null 2>&1
ids=$(grep -o 'data-id="[^"]*"' "$tmp/e2/decisions-2026-01-02.html" | tr '\n' ' ')
[ "$ids" = 'data-id="A" data-id="A-2" data-id="finding-3" ' ] || fail "sidecar findings did not get unique ids: $ids"

# --- build needs a browser
core=${PLAYWRIGHT_CORE:-}
if [ -z "$core" ] || [ ! -d "$core" ]; then
  echo "SKIP: no PLAYWRIGHT_CORE, the render half of decision-sheet did not run"; echo "PASS (parse + docs half)"; exit 0
fi
cat > "$tmp/p.html" <<'HTML'
<!doctype html><title>t</title><style>.cta{color:#999;background:#fff;font-size:16px;padding:8px 16px;display:inline-block;transition:color 2s}
body .wrap .cta{color:#888}</style><body><div class="wrap"><a class="cta" href="#">Subscribe</a></div>
HTML
cat > "$tmp/prop.json" <<JSON
[{"id":"A11Y-001","title":"Low contrast CTA","page":"file://$tmp/p.html","selector":".cta","css":".cta{color:#595959}",
  "measured":{"before":{"ratio":"2.8"},"after":{"ratio":"7.0"}},
  "options":[{"key":"approve","label":"Approve","recommended":true},{"key":"reject","label":"Keep"}]},
 {"id":"UX-2","title":"Missing target","page":"file://$tmp/p.html","selector":".nope","css":".x{color:red}"}]
JSON
mkdir -p "$tmp/res"
node "$tool" build --out "$tmp/res" --proposals "$tmp/prop.json" --date 2026-01-02 >"$tmp/build.out" 2>"$tmp/build.err"; rc=$?
if [ "$rc" = 2 ] && grep -Fq 'no existing Chromium' "$tmp/build.err"; then echo "SKIP: no Chromium, the render half did not run"; echo "PASS (parse, escaping, docs)"; exit 0; fi
[ "$rc" = 3 ] || fail "a card with a missing selector must exit 3 (incomplete), got $rc: $(tail -3 "$tmp/build.err")"
html="$tmp/res/decisions-2026-01-02.html"
[ -f "$html" ] && [ -f "${html%.html}.json" ] || fail "page or json not written to --out"
grep -Fq 'data:image/jpeg;base64,' "$html" || fail "no embedded picture"
grep -Fq 'Recommended' "$html" || fail "no recommended badge"
grep -Fq 'type="radio"' "$html" || fail "no radio options"
grep -Fq 'navigator.clipboard' "$html" && grep -Fq "execCommand('copy')" "$html" || fail "copy has no clipboard + fallback"
grep -Fq 'Not measured' "$html" || fail "the missing selector was not flagged as not measured"
# the injected rule beat the higher-specificity existing one, and the transition did not hide it
node -e '
const j=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));
const m=j.proposals[0].measured;
if(m.length!==2)throw new Error("viewports "+m.length);
for(const v of m){ if(v.before.values.color!=="rgb(136, 136, 136)"||v.after.values.color!=="rgb(89, 89, 89)")throw new Error(v.viewport+" "+JSON.stringify(v.before.values)+JSON.stringify(v.after.values)); }
' "${html%.html}.json" || fail "after value not applied over the existing rule (specificity or transition)"
echo "PASS"
