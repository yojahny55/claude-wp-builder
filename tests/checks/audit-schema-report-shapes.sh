#!/usr/bin/env bash
# In a real audit run four of the five agents wrote their reports in shapes the reader did not
# expect, and the array-only reader dropped them silently, so Step 6.8 saw checks as never
# reported. Pinned here: `not_applicable` / `unmeasured` as a map keyed by check id, a report
# with no `category` taking it from its `wp-audit-<x>.json` file name, and scan notes (a vendor
# directory's contents) leaving `findings` for `vendor_notes` instead of counting as findings.
set -euo pipefail
. "$(dirname "$0")/../lib/assert.sh"
require_tool node
cd "$(dirname "$0")/../.."
root=$PWD
t=$(mktemp -d); trap 'rm -rf "$t"' EXIT

# --- fixtures -----------------------------------------------------------------------------
# Map-shaped N/A and UNMEASURED rows, string and object values, plus the array form.
cat > "$t/maps.json" <<'JSON'
{"category":"seo","checks_executed":["SEO-001"],
 "not_applicable":{"SEO-021":"no SEO plugin","SEO-022":{"reason":"x"}},
 "unmeasured":{"PERF-010":"needs production: no public URL"}}
JSON
cat > "$t/arrays.json" <<'JSON'
{"category":"seo","not_applicable":[{"check":"SEO-021","reason":"no SEO plugin"}],
 "unmeasured":[{"check":"PERF-010","reason":"needs production: no public URL"}]}
JSON
# Category from the file name; an explicit category wins; an unknown name stays null.
echo '{"checks_executed":["WP-001"]}' > "$t/wp-audit-practices.json"
echo '{"checks_executed":["SEC-001"]}' > "$t/wp-audit-security.json"
mkdir "$t/explicit" "$t/other"
echo '{"category":"seo","checks_executed":["SEO-001"]}' > "$t/explicit/wp-audit-security.json"
echo '{"checks_executed":["SEO-001"]}' > "$t/other/other.json"
# Scan notes in findings, top-level notes, and a catalog id with status INFO.
cat > "$t/notes.json" <<'JSON'
{"category":"best-practices",
 "findings":[
  {"check":"VENDOR","status":"INFO","severity":"INFO","message":"vendor notes: mu-plugins holds only net-guard"},
  {"check":"NOTE-X","status":"INFO","severity":"INFO","message":"second scan note"}],
 "notes":["a"],"vendor_notes":["b"]}
JSON
cat > "$t/catalog-info.json" <<'JSON'
{"category":"best-practices",
 "findings":[{"check":"WP-020","status":"INFO","severity":"INFO","message":"query_posts used"}]}
JSON

# --- assertions ---------------------------------------------------------------------------
out=$(T="$t" ROOT="$root" node --input-type=module -e '
const { loadReports, normalizeReport } = await import(process.env.ROOT + "/bin/lib/audit-schema.mjs");
import { join } from "node:path";
const t = process.env.T;
const errs = [];
const eq = (what, got, want) => { if (JSON.stringify(got) !== JSON.stringify(want)) errs.push(`${what}: got ${JSON.stringify(got)}, want ${JSON.stringify(want)}`); };
const norm = (f) => loadReports(join(t, f)).map((r) => ({ ...normalizeReport(r.report, r.label), raw: r.report }))[0];
const rows = (a) => (a || []).map((r) => [r.check, r.reason ?? null]);

const m = norm("maps.json");
eq("na map rows", rows(m.na), [["SEO-021", "no SEO plugin"], ["SEO-022", "x"]]);
eq("unmeasured map rows", rows(m.unmeasured), [["PERF-010", "needs production: no public URL"]]);
const a = norm("arrays.json");
eq("na array rows", rows(a.na), [["SEO-021", "no SEO plugin"]]);
eq("unmeasured array rows", rows(a.unmeasured), [["PERF-010", "needs production: no public URL"]]);

eq("practices file name", norm("wp-audit-practices.json").category, "best-practices");
eq("security file name", norm("wp-audit-security.json").category, "security");
eq("explicit category wins", norm("explicit/wp-audit-security.json").category, "seo");
eq("unknown file name", norm("other/other.json").category, null);

const n = norm("notes.json");
eq("scan notes are not findings", n.findings.map((f) => f.check), []);
eq("scan notes are not problems", n.problems, []);
for (const want of ["vendor notes: mu-plugins holds only net-guard", "second scan note", "a", "b"])
  if (!n.vendor_notes.includes(want)) errs.push(`vendor_notes lacks "${want}": ${JSON.stringify(n.vendor_notes)}`);
const c = norm("catalog-info.json");
eq("catalog id with INFO is not moved", c.vendor_notes, []);
if (c.problems.length !== 1 || !/status/.test(c.problems[0])) errs.push(`catalog id with INFO must yield one status problem: ${JSON.stringify(c.problems)}`);
if (errs.length) { console.log(errs.join("\n")); process.exit(1); }
' 2>&1) || fail "audit-schema report shapes:
$out"

# --- end to end: the coverage gate counts a map's ids as N/A, not as never reported ---------
mkdir "$t/run"
echo '{"checks_executed":["SEO-001"],"not_applicable":{"SEO-021":"no SEO plugin"}}' > "$t/run/wp-audit-seo.json"
rc=0; json=$(node bin/audit-coverage.mjs --results "$t/run" --json) || rc=$?
[ "$rc" -le 1 ] || fail "audit-coverage rejected a category-less report with a map-shaped not_applicable (exit $rc)"
printf '%s' "$json" | node -e '
const j = JSON.parse(require("fs").readFileSync(0, "utf8"));
const c = j.categories.find((x) => x.category === "seo");
if (!c) { console.log("category seo was not resolved from the file name"); process.exit(1); }
if (c.na !== 1) { console.log(`na is ${c.na}, want 1`); process.exit(1); }
if (c.never_run.includes("SEO-021")) { console.log("SEO-021 still listed as never run"); process.exit(1); }
' || fail "coverage gate did not honor a map-shaped not_applicable"

echo PASS
