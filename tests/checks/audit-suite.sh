#!/usr/bin/env bash
# Tier 3 was gated on whether the session running the audit happened to have a browser
# automation tool. The same project therefore measured differently depending on who audited
# it, and nothing could run where nobody was watching.
#
# templates/audit-suite/ is a real Playwright project -- axe-core for accessibility,
# Lighthouse for scores and Core Web Vitals, three engines for the cross-browser criterion.
# bin/audit-suite.sh scaffolds and runs it; scripts/to-run.js converts what it measured into
# the run file bin/audit-report.mjs renders.
#
# What is asserted here is the seam, because that is what breaks silently. The suite is
# vendored and answers to its own tests upstream; the bridge is the plugin's, and a bridge
# that drops ownership or invents a check id produces a report that looks right and is not.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

suite=templates/audit-suite
runner=bin/audit-suite.sh
bridge="$suite/scripts/to-run.js"
c=commands/wp-audit.md

for f in "$runner" "$bridge" "$suite/audit.config.js" "$suite/package.json" "$suite/VENDORED-FROM.txt"; do
  [ -f "$f" ] || fail "$f is missing"
done
[ -x "$runner" ] || fail "$runner is not executable -- the command invokes it directly"

# ---------------------------------------------------------------------------
# 1. The vendored tree is complete and says where it came from
# ---------------------------------------------------------------------------
# A vendored tree with no provenance is a fork nobody knows they are maintaining.
grep -Fq 'origin:' "$suite/VENDORED-FROM.txt" || fail "$suite/VENDORED-FROM.txt names no origin"
grep -Eq '^commit: [0-9a-f]{7,40}$' "$suite/VENDORED-FROM.txt" \
  || fail "$suite/VENDORED-FROM.txt records no source commit, so nothing can tell which version this is"

for spec in tests/audit.spec.js tests/seo-tech.spec.js tests/performance.spec.js; do
  [ -f "$suite/$spec" ] || fail "$suite/$spec is missing -- the suite cannot run its pass"
done
for lib in plan.js report-data.js audit-helpers.js seo-tech.js lighthouse-report.js; do
  [ -f "$suite/lib/$lib" ] || fail "$suite/lib/$lib is missing"
done

# Every npm script the runner invokes has to exist, or the pass silently does nothing and
# the suite reports a site with no findings.
for script in test:a11y test:seo test:perf; do
  grep -Fq "\"$script\"" "$suite/package.json" || fail "$suite/package.json has no \"$script\" script"
  grep -Fq "$script" "$runner" || fail "$runner never runs $script"
done

# Lighthouse measures the machine as much as the page, which is why the performance pass
# runs on its own. --workers=1 is what makes that true inside the pass.
grep -Fq -- '--workers=1' "$suite/package.json" \
  || fail "$suite/package.json runs the Lighthouse pass in parallel -- a contended machine is not a slow page"

# No real host survives into the template that ships in this repo. The denylist cannot BE
# the client names -- writing them here to prove they are absent publishes them in this
# file, in this repo's history, and in the diff of every pull request that touches it. The
# check looks for the shape of the leak instead.
#
# Scope: the two files that carry the site under audit. audit.config.js holds siteName,
# baseURL and the selectors somebody wrote against a real DOM, and .env.example holds the
# URL beside the credentials -- that is where a client's host lands when a suite is copied
# from one project to the next. The vendored lib/ and tests/ carry their upstream authors'
# own invented hosts, which are not ours to rewrite and not a leak.
#
# RFC 2606 and RFC 6761 reserve example.com/net/org, .example, .test, .invalid and
# .localhost precisely so a fixture can name a host without naming anyone.
for f in audit.config.js .env.example; do
  [ -f "$suite/$f" ] || continue
  leaked=$(grep -hoE 'https?://[A-Za-z0-9.-]+' "$suite/$f" \
    | sed -E 's#^https?://##; s#^www\.##' \
    | grep -vE '^(localhost|127\.0\.0\.1)$' \
    | grep -vE '(^|\.)(example\.(com|net|org)|example|test|invalid|localhost)$' \
    | sort -u || true)
  if [ -n "$leaked" ]; then
    printf 'FAIL: %s names a host that is not a reserved example domain:\n' "$suite/$f"
    printf '  %s\n' $leaked
    printf 'This template ships in the repo and in every PR diff -- scrub it to example.com.\n'
    exit 1
  fi
done

# A denylist that passes because it is empty is worth nothing, so prove the rule bites.
probe=$(mktemp -d)
cp "$suite/audit.config.js" "$probe/audit.config.js"
sed -i "s|https://example.com|https://a-real-client.example-not-reserved.ca|" "$probe/audit.config.js"
leak_probe=$(grep -hoE 'https?://[A-Za-z0-9.-]+' "$probe/audit.config.js" \
  | sed -E 's#^https?://##; s#^www\.##' \
  | grep -vE '(^|\.)(example\.(com|net|org)|example|test|invalid|localhost)$' | sort -u || true)
rm -rf "$probe"
[ -n "$leak_probe" ] || fail "the host check does not flag a non-reserved domain, so it would pass on a real client host"

# ---------------------------------------------------------------------------
# 2. Every JavaScript file parses
# ---------------------------------------------------------------------------
while IFS= read -r f; do
  node --check "$f" >/dev/null 2>&1 || fail "$f does not parse"
done < <(find "$suite" -name '*.js' -not -path '*/node_modules/*')

# ---------------------------------------------------------------------------
# 3. The bridge, exercised
# ---------------------------------------------------------------------------
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cp -r "$suite/." "$tmp/"
mkdir -p "$tmp/results/audit"

cat > "$tmp/results/audit/home.json" <<'JSON'
{"page":"Home","results":[
 {"c":"46","name":"Title length","status":"warn","evidence":"6 chars","rec":"Aim for 64-70"},
 {"c":"51","name":"robots.txt","status":"fail","evidence":"Disallow: /","rec":"Remove the Disallow"},
 {"c":"32","name":"Typography","status":"fail","evidence":"3 families","rec":"Unify"},
 {"c":"45","name":"Contrast","status":"fail","evidence":"3.1:1","rec":"Raise to 4.5:1"},
 {"c":"2","name":"Error messages","status":"manual","evidence":"human judgement","rec":""},
 {"c":"44","name":"html lang","status":"pass","evidence":"lang=es"}
]}
JSON

(cd "$tmp" && node scripts/to-run.js --out results/run.json >/dev/null) \
  || fail "$bridge failed on a valid results directory"
run="$tmp/results/run.json"
[ -s "$run" ] || fail "$bridge wrote no run file"

# The run file is only useful if the renderer accepts it. This is the seam: anything the
# bridge omits shows up here as a refusal rather than three releases later as a blank cell.
(cd "$tmp" && node "$OLDPWD/bin/audit-report.mjs" --run results/run.json --out report --format md >/dev/null) \
  || fail "bin/audit-report.mjs refused the run file $bridge produced -- the two have drifted"

# A pass is not a finding, and a manual criterion is neither a pass nor a failure.
node -e '
const run = require(process.argv[1]);
const ids = run.findings.map(f => f.check);
const fail = (m) => { console.error(m); process.exit(1); };
if (ids.includes("UX-044")) fail("a passing criterion was emitted as a finding");
if (!ids.includes("UX-051")) fail("a failing criterion was dropped");
if (!ids.includes("UX-046")) fail("a warning criterion was dropped");
if (!run.unmeasured.some(u => u.check === "UX-002")) fail("a manual criterion was not reported as unmeasured");
if (run.findings.some(f => !f.ownership)) fail("a finding crossed the bridge with no ownership");
if (run.findings.some(f => !/^(UX|PERF-LH|A11Y-AXE)-/.test(f.check))) fail("a finding carries a check id in no known namespace");
const byId = Object.fromEntries(run.findings.map(f => [f.check, f]));
// The criterion that lives in an option is the one that must not read as a code fix: a
// robots.txt or a Rank Math setting applied on a local clone does not travel with a commit.
if (byId["UX-051"].ownership !== "setting") fail("UX-051 (robots.txt) is not owned as a setting");
if (byId["UX-045"].ownership !== "code") fail("UX-045 (contrast) is not owned as code");
if (byId["UX-046"].ownership !== "content") fail("UX-046 (title text) is not owned as content");
if (byId["UX-032"].ownership !== "manual") fail("UX-032 (typography judgement) is not owned as manual");
if (byId["UX-051"].severity !== "CRITICAL") fail("an indexability failure is not CRITICAL");
' "$run" || fail "the bridge mistranslated the classification the suite already made"

# ---------------------------------------------------------------------------
# 3b. The page list is rewritten without destroying the file
# ---------------------------------------------------------------------------
# The template's own default `pages:` array is not flat -- its contact entry nests
# `form: { fields: [ ... ] }`. A non-greedy regex stops at that inner `]` and leaves the
# outer array's tail behind as orphaned tokens, so the config no longer parses and nothing
# notices until a Playwright run fails with a syntax error deep in a generated file. This
# is the documented, recommended invocation, against the shipped template.
cfg="$tmp/audit.config.js"
cp "$suite/audit.config.js" "$cfg"
# Run the runner's own config-rewriting step against the shipped template, by extracting
# the heredoc it feeds to node. Calling bin/audit-suite.sh directly would npm install.
cat > "$tmp/rewrite.js" <<'JS'
const fs = require('fs');
const src = fs.readFileSync(process.env.RUNNER, 'utf8');
const marker = "<<'NODE'";
const start = src.indexOf("const fs = require('fs');", src.indexOf(marker));
const body = src.slice(start, src.indexOf('\nNODE\n', start));
process.argv[2] = process.env.CFG;
eval(body);
JS
RUNNER="$runner" CFG="$cfg" BASE_URL="https://example.com" PAGES="/,/a/,/b/" \
  node "$tmp/rewrite.js" || fail "$runner could not rewrite the template config"

node --check "$cfg" >/dev/null 2>&1 \
  || fail "rewriting pages: left $suite/audit.config.js unparseable -- the nested form array truncated the replacement"
node -e '
const c = require(process.argv[1]);
const paths = c.pages.map(p => p.path).join(" ");
if (paths !== "/ /a/ /b/") { console.error("pages are " + paths); process.exit(1); }
if (c.baseURL !== "https://example.com") { console.error("baseURL is " + c.baseURL); process.exit(1); }
if (!c.notFoundPath) { console.error("the tail of the file was eaten: notFoundPath is gone"); process.exit(1); }
' "$cfg" || fail "the rewritten config does not hold what it was given"

# ---------------------------------------------------------------------------
# 4. The runner refuses and skips in the right places
# ---------------------------------------------------------------------------
set +e
bash "$runner" --probe >/dev/null 2>&1; code=$?
set -e
[ "$code" -eq 0 ] || [ "$code" -eq 2 ] \
  || fail "$runner --probe exited $code -- a probe reports availability, it does not fail"

set +e
bash "$runner" >/dev/null 2>&1; code=$?
set -e
[ "$code" -eq 1 ] || fail "$runner without --url exited $code instead of 1"

# A machine with no node is a Tier 3 that cannot be measured, not a broken audit. Exit 2
# keeps /wp-audit reporting UNMEASURED instead of an error on every machine without one.
grep -Fq 'exit 2' "$runner" || fail "$runner never skips cleanly -- a missing browser would read as a failure"
grep -Fq 'PLAYWRIGHT_BROWSERS_PATH' "$runner" \
  || fail "$runner does not share the browser cache, so every project pays the full install"
grep -Fq 'node_modules-$key' "$runner" \
  || fail "$runner does not key the dependency cache to the template, so a version bump would mutate the shared cache in place"
grep -Fq 'audit.config.js' "$runner" || fail "$runner never seeds the per-project configuration"

# The selectors somebody inspected a real DOM to find are work; a scaffold that overwrites
# them every run silently re-measures a different site.
grep -Fq 'if [ ! -f "$dir/audit.config.js" ]' "$runner" \
  || fail "$runner overwrites an existing audit.config.js, discarding the selectors set for this site"

# ---------------------------------------------------------------------------
# 5. The command's contract
# ---------------------------------------------------------------------------
need() { grep -Fq -- "$1" "$c" || fail "$c $2"; }
need '--suite' 'has no --suite flag'
need 'bin/audit-suite.sh' 'never invokes the suite runner'
need 'Tier 3 is available two ways' 'does not say that the suite is a second route to Tier 3'
need 'the same defect twice under two codes' \
  'does not resolve the overlap between a measured finding and a code finding, so both would be reported'

echo "PASS: the suite is vendored with its provenance, its bridge preserves ownership, and the runner skips rather than fails"
