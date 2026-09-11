#!/usr/bin/env bash
# bin/image-gen.mjs spends money. Every assertion here therefore runs with no
# key and no network: what is verified is that the script asks for the right
# thing, never asks twice for the same thing, refuses an ambiguous plan before
# issuing a request, and cannot put an API key into its own output. The slot
# list and the crop are read off each composition's own <img> tag, so these
# assertions pin that the reader still finds them — a regex regression there
# would silently request square heroes and nothing else would notice.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

g=bin/image-gen.mjs
[ -x "$g" ] || fail "$g is missing or not executable"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/assets/img"

# Reads one field out of the rewritten plan file, so the assertions below
# test the artifact the next step actually consumes, not stdout formatting.
pj() { node -e '
  const p = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
  const v = process.argv[2].split(".").reduce((o, k) => o?.[k], p);
  console.log(typeof v === "object" ? JSON.stringify(v) : v);
' "$tmp/.image-plan.json" "$1"; }

plan_with() {
  cat > "$tmp/.image-plan.json" <<JSON
{"provider": "google/gemini-3.1-flash-image",
 "sections": $1,
 "assets_on_disk": []}
JSON
}

# 1. Slot discovery: the three image-bearing compositions yield exactly four slots.
plan_with '[{"page":"index","section":"hero","composition":"hero-bleed"},
             {"page":"index","section":"features","composition":"feature-zigzag"},
             {"page":"about","section":"hero","composition":"hero-split"}]'
node "$g" plan --demo "$tmp" >/dev/null || fail "plan exited non-zero on a valid plan file"
n=$(pj gaps.length)
[ "$n" = 4 ] || fail "expected 4 image slots across hero-bleed, feature-zigzag and hero-split; got $n"

# 1b. Zero-occurrence control: a composition with no <img> yields no slots.
#     Without this, a reader that returned a constant 4 would pass the line above.
plan_with '[{"page":"index","section":"faq","composition":"faq-list"}]'
node "$g" plan --demo "$tmp" >/dev/null || fail "plan exited non-zero on an image-free composition"
n=$(pj gaps.length)
[ "$n" = 0 ] || fail "faq-list declares no <img>, so it must yield 0 slots; got $n"

# 2. The crop is read off the markup, not assumed. hero-split is 1200x1500.
plan_with '[{"page":"about","section":"hero","composition":"hero-split"}]'
node "$g" plan --demo "$tmp" >/dev/null || fail "plan exited non-zero on the hero-split crop assertion"
a=$(pj gaps.0.aspect)
[ "$a" = "4:5" ] || fail "hero-split declares 1200x1500 so the aspect must be 4:5; got $a"
s=$(pj gaps.0.size)
[ "$s" = "2K" ] || fail "hero-split declares width 1200, so the smallest size >= 1200 is 2K; got $s"

# 2b. hero-bleed is 2400x1600 and must be capped at 2K rather than escalating to 4K.
plan_with '[{"page":"index","section":"hero","composition":"hero-bleed"}]'
node "$g" plan --demo "$tmp" >/dev/null || fail "plan exited non-zero on the hero-bleed cap assertion"
a=$(pj gaps.0.aspect)
[ "$a" = "3:2" ] || fail "hero-bleed declares 2400x1600 so the aspect must be 3:2; got $a"
s=$(pj gaps.0.size)
[ "$s" = "2K" ] || fail "hero-bleed declares width 2400 but the cap is 2K; got $s"

# 2c. The size tiers are asserted directly, because every composition in the
#     library happens to land on 2K: a CLI-only test cannot distinguish
#     snapSize from `return "2K"`. Verified - that mutation passed the whole
#     suite before this assertion existed.
tiers=$(node -e '
  import("./bin/image-gen.mjs").then((m) => {
    console.log([400, 800, 1200, 2400].map((w) => m.snapSize(w)).join(","));
  });
') || fail "snapSize could not be imported from $g"
[ "$tiers" = "512px,1K,2K,2K" ] \
  || fail "snapSize must pick the smallest tier >= width, capped at 2K; got $tiers"

# 3. A gap satisfied by a real client file costs nothing. Asserted by running
#    with no key at all: a plan made entirely of `use` entries must succeed,
#    which it could not do if it issued a request.
printf 'not-a-real-jpeg' > "$tmp/client-photo.jpg"
plan_with '[{"page":"about","section":"hero","composition":"hero-split"}]'
node "$g" plan --demo "$tmp" >/dev/null || fail "plan exited non-zero staging assertion 3 (use entry)"
node -e '
  const f = process.argv[1], p = JSON.parse(require("fs").readFileSync(f, "utf8"));
  p.gaps[0].use = process.argv[2];
  require("fs").writeFileSync(f, JSON.stringify(p, null, 2));
' "$tmp/.image-plan.json" "$tmp/client-photo.jpg"
( unset GEMINI_API_KEY OPENAI_API_KEY; node "$g" run --demo "$tmp" >/dev/null ) \
  || fail "a plan of only 'use' entries must succeed with no key set"
ls "$tmp/assets/img/client-photo.jpg" >/dev/null 2>&1 \
  || fail "run did not copy the client file into demo/assets/img/"

# 3b. Control: the same gap with a prompt instead of a use needs a key, and
#     says so. Without this, assertion 3 would pass on a run that never checked.
plan_with '[{"page":"about","section":"hero","composition":"hero-split"}]'
node "$g" plan --demo "$tmp" >/dev/null || fail "plan exited non-zero staging assertion 3b (prompt control)"
node -e '
  const f = process.argv[1], p = JSON.parse(require("fs").readFileSync(f, "utf8"));
  p.gaps[0].prompt = "a joiner easing the nosing on an oak stair tread";
  require("fs").writeFileSync(f, JSON.stringify(p, null, 2));
' "$tmp/.image-plan.json"
set +e
( unset GEMINI_API_KEY OPENAI_API_KEY; node "$g" run --demo "$tmp" >/dev/null 2>"$tmp/err" )
rc=$?
set -e
[ "$rc" = 3 ] || fail "a gap needing generation with no key must exit 3; got $rc"
grep -Fq 'GEMINI_API_KEY' "$tmp/err" \
  || fail "the no-key error must name the environment variable to export"

# 4. An ambiguous gap is refused before any request, so an unclear plan cannot
#    cost money. Both set, then neither set.
for mutate in 'p.gaps[0].prompt="x"; p.gaps[0].use="y";' 'p.gaps[0].prompt=""; p.gaps[0].use="";'; do
  plan_with '[{"page":"about","section":"hero","composition":"hero-split"}]'
  node "$g" plan --demo "$tmp" >/dev/null || fail "plan exited non-zero staging assertion 4 (ambiguous gap, $mutate)"
  node -e '
    const f = process.argv[1], p = JSON.parse(require("fs").readFileSync(f, "utf8"));
    eval(process.argv[2]);
    require("fs").writeFileSync(f, JSON.stringify(p, null, 2));
  ' "$tmp/.image-plan.json" "$mutate"
  set +e
  ( unset GEMINI_API_KEY OPENAI_API_KEY; node "$g" run --demo "$tmp" >/dev/null 2>&1 )
  rc=$?
  set -e
  [ "$rc" = 2 ] || fail "an ambiguous gap ($mutate) must exit 2 before any request; got $rc"
done

# 5. A cached plate is not re-billed. The hash is recomputed here in bash from
#    the documented formula rather than read back from the script, so this is a
#    cross-check of the identity and not a tautology.
prompt='stacked and stickered oak boards seasoning in an open timber shed'
h=$(printf '%s' "$prompt|3:2|gemini-3.1-flash-image" | sha256sum | cut -c1-12)
printf 'not-a-real-jpeg' > "$tmp/assets/img/gen-$h.jpg"
plan_with '[{"page":"index","section":"hero","composition":"hero-bleed"}]'
node "$g" plan --demo "$tmp" >/dev/null || fail "plan exited non-zero staging assertion 5 (cache setup)"
node -e '
  const f = process.argv[1], p = JSON.parse(require("fs").readFileSync(f, "utf8"));
  p.gaps[0].prompt = process.argv[2];
  require("fs").writeFileSync(f, JSON.stringify(p, null, 2));
' "$tmp/.image-plan.json" "$prompt"
node "$g" plan --demo "$tmp" >/dev/null || fail "plan exited non-zero staging assertion 5 (cache re-plan)"
[ "$(pj gaps.0.cached)" = "true" ] || fail "a plate whose hash is already on disk must be reported cached"
( unset GEMINI_API_KEY OPENAI_API_KEY; node "$g" run --demo "$tmp" >/dev/null ) \
  || fail "a fully cached plan must succeed with no key set"

# 5b. Control: changing one character of the prompt changes the hash, so the
#     cache must miss and the run must then need a key.
node -e '
  const f = process.argv[1], p = JSON.parse(require("fs").readFileSync(f, "utf8"));
  p.gaps[0].prompt = process.argv[2] + " at dusk";
  require("fs").writeFileSync(f, JSON.stringify(p, null, 2));
' "$tmp/.image-plan.json" "$prompt"
node "$g" plan --demo "$tmp" >/dev/null || fail "plan exited non-zero staging assertion 5b (cache-miss control)"
[ "$(pj gaps.0.cached)" = "false" ] || fail "an edited prompt must miss the cache, not serve the stale plate"

# 6. The key cannot reach the script's own output. Every write funnels through
#    scrub(); these pins are what keep a future adapter from printing a headers
#    object in its error path. Quote-anchored so a renamed helper fails them.
grep -Fq 'function scrub(s) {' "$g" || fail "$g no longer defines scrub()"
grep -Fq 'const say = (s) => console.log(scrub(s));' "$g" \
  || fail "$g's stdout writer no longer scrubs"
grep -Fq 'const warn = (s) => console.error(scrub(s));' "$g" \
  || fail "$g's stderr writer no longer scrubs"
grep -Fq 'warn(e.stack || e.message);' "$g" \
  || fail "$g's top-level catch no longer routes through the scrubbing writer"
# Control: console.log and console.error appear ONLY inside those two writers.
# A direct call anywhere else bypasses the scrub entirely.
# `|| true` is required: grep -c exits 1 on zero matches, and an assignment
# from a failing command substitution aborts under `set -e` -- which would
# skip this very assertion instead of failing it.
# Count EVERY console.* call, not just log|error: console.warn, .info, .debug
# and .trace all write to stdout/stderr and all bypass scrub(), because they
# are direct calls rather than say()/warn(). Verified -- console.warn leaking
# the key in an adapter error path passed the whole suite before this widened.
n=$(grep -c 'console\.' "$g" || true)
[ "$n" = 2 ] || fail "$g must funnel all output through say()/warn(); found $n console calls, expected 2"
# A leak does not need console.*: process.stderr.write reaches fd 2 just as
# well, and the count above cannot see it. Verified -- writing the raw key
# with process.stderr.write in callGoogle's error path passed the entire
# suite before this assertion existed.
if grep -Eq 'process\.(stdout|stderr)\.write' "$g"; then
  fail "$g writes directly to stdout/stderr, bypassing the scrub in say()/warn()"
fi

# 6b. Behavioural: with a key set, a refused plan's output contains no trace of it.
plan_with '[{"page":"about","section":"hero","composition":"hero-split"}]'
node "$g" plan --demo "$tmp" >/dev/null || fail "plan exited non-zero staging assertion 6b (sentinel leak check)"
set +e
GEMINI_API_KEY='SENTINEL_kf82hdA91x' node "$g" run --demo "$tmp" >"$tmp/out" 2>"$tmp/err"
set -e
grep -Fq 'SENTINEL_kf82hdA91x' "$tmp/out" "$tmp/err" \
  && fail "the API key appeared in the script's own output"

# 7. Both vendors are wired, and the endpoints are the current ones. The older
#    Google :generateContent endpoint returns text, not an image, and OpenAI's
#    gpt-image models reject response_format outright.
grep -Fq 'https://generativelanguage.googleapis.com/v1beta/interactions' "$g" \
  || fail "$g does not target the Interactions API"
grep -Fq "'x-goog-api-key'" "$g" || fail "$g does not send the Google auth header"
grep -Fq 'https://api.openai.com/v1/images/generations' "$g" \
  || fail "$g does not target the OpenAI images endpoint"
grep -Fq 'aspect_ratio' "$g" || fail "$g does not request a Google aspect ratio"
grep -Fq 'b64_json' "$g" || fail "$g does not read OpenAI's base64 payload"
# response_format must appear exactly once: in the Google body. The gpt-image
# models reject the parameter outright, so it must never reach OpenAI.
# Counted on a comment-stripped copy, because a pin that matches prose forces
# comments to be worded around it instead of naming the rule. The first
# substitution strips only full-line // comments -- a naive // strip would eat
# the https:// in the endpoint URLs and silently void the endpoint pins above.
# The second strips /* */ block comments wherever they appear, which would
# also eat one inside a string literal; nothing in this file has one, and the
# stripped copy is used for exactly one thing -- counting response_format.
gs="$tmp/image-gen-stripped.mjs"
perl -0pe 's{^\s*//[^\n]*$}{}gm; s{/\*.*?\*/}{}gs' "$g" > "$gs" \
  || fail "could not strip comments from $g"
n=$(grep -c 'response_format' "$gs" || true)
[ "$n" = 1 ] || fail "response_format must appear exactly once (the Google body) and never in the OpenAI body; found $n"

# 8. The command contract. Greps a comment-stripped copy so a rule parked in an
#    HTML comment cannot satisfy the pin - the failure mode that let three
#    `inherits: true` pins pass in v3.2 while the rule sat commented out.
d=commands/wp-demo.md
ds="$tmp/wp-demo-stripped.md"
# Strip HTML comments so a rule parked in <!-- --> cannot satisfy a pin -- the
# failure mode that let three `inherits: true` pins pass in v3.2 while the rule
# sat commented out. Then collapse all whitespace to single spaces, so the pins
# below test what the document SAYS rather than where its line breaks fall:
# pinning line-scoped phrases forces prose to be rewrapped around the checks,
# and a pure reflow would otherwise fail the build claiming a rule is missing.
perl -0pe 's{<!--.*?-->}{}gs; s{\s+}{ }g' "$d" > "$ds" \
  || fail "could not build the stripped copy of $d"
grep -Fq 'image-gen.mjs" plan --demo demo/' "$ds" \
  || fail "$d does not run the image planner"
grep -Fq 'image-gen.mjs" run --demo demo/' "$ds" \
  || fail "$d does not run the image generator after approval"
grep -Fq 'exactly one of `prompt` or `use`' "$ds" \
  || fail "$d does not state the one-field-per-gap rule the script enforces"
grep -Fq 'Costs are estimates, not a bill' "$ds" \
  || fail "$d does not carry the estimate disclaimer into the approval prompt"
grep -Fq '"image provider"' "$ds" \
  || fail "$d does not record the provider in .wp-create.json"
grep -Fq 'never pasted into chat' "$ds" \
  || fail "$d does not state that the key is never pasted into chat"
# 9. The write path. Finding 10: an earlier draft only ever READ "image
#    provider" and nothing ever wrote it, so the feature could never activate.
#    Pin that the doc now records the operator's answer, and that "none" (a
#    decline) is a recognised, non-reasked value -- not just a stray string.
grep -Fq "operator's answer into \`.wp-create.json\`" "$ds" \
  || fail "$d does not write the chosen provider back into .wp-create.json"
grep -Fq '"image provider": "none"' "$ds" \
  || fail "$d does not record and handle a decline as \"image provider\": \"none\""
# Finding 12: "none" has a WRITE half (pinned above: record the decline) and a
# separate READ half (a recorded "none" must generate nothing and never
# re-ask). They live in two different sentences, so one pin cannot cover both
# -- this pin targets the read half specifically, spanning from the `"none"`
# token through the "do not ask again" behaviour in one contiguous phrase, so
# a mutation that severs the connection between them (e.g. rewording "a value
# of `"none"`" to something that drops the token, while leaving the generic
# "handled like the no-key branch" tail untouched) is still caught -- the
# write-half pin above does not see this sentence at all.
grep -Fq '`"none"` records an earlier decline and is handled exactly like the no-key branch above: generate nothing, say so in one line, go to step 6, and do not ask again' "$ds" \
  || fail "$d does not state that a recorded \"none\" generates nothing and is never re-asked"
# Control: the step is inside wp-demo.md and NOT in wp-yolo.md, which must never
# generate. A single shared pin would pass with the step in the wrong command.
# Same comment-strip-and-collapse treatment, so this pin is immune to reflow too.
y=commands/wp-yolo.md
ys="$tmp/wp-yolo-stripped.md"
perl -0pe 's{<!--.*?-->}{}gs; s{\s+}{ }g' "$y" > "$ys" \
  || fail "could not build the stripped copy of $y"
# Explicit `if`, not `grep && fail`: a failing command inside an && list has
# subtle `set -e` semantics, and an assertion must not depend on reading them
# right. Here the desired outcome is grep FAILING, which makes it acute.
if grep -Fq 'image-gen.mjs' "$ys"; then
  fail "$y must never invoke the image generator"
fi
grep -Fq 'never generates images' "$ys" \
  || fail "$y does not state that it never generates images"

echo PASS
