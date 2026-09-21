#!/usr/bin/env bash
# Scaffold and run the browser audit suite for one project.
#
# Tier 3 used to be gated on whether the session running the audit happened to have a
# browser automation tool. That makes the same project measure differently depending on who
# audits it, and it cannot run anywhere nobody is watching. This scaffolds a real Playwright
# project from templates/audit-suite/, runs it against a live URL, and converts its results
# into the run file bin/audit-report.mjs already renders.
#
# The suite is heavy -- Playwright's browsers plus Lighthouse -- so the install is shared.
# PLAYWRIGHT_BROWSERS_PATH points every project at one cache, and node_modules is symlinked
# from a cache directory rather than installed per project. A per-project install would make
# the second audit on a machine cost as much as the first, which is how a gate stops being
# run.
#
# Environment:
#   WP_AUDIT_SUITE_NODE_MODULES  use this package directory (e.g. `npm root -g`) instead of
#                                the managed install; it must hold the template's packages
#   PLAYWRIGHT_BROWSERS_PATH     browser cache; defaults to the suite's own under the cache dir
#   WP_AUDIT_SUITE_CACHE         the cache dir itself
#
# Usage:
#   bin/audit-suite.sh --url <base-url> [--dir <suite-dir>] [--pages <p1,p2,...>]
#                      [--only a11y|seo|perf|all] [--site <name>] [--probe]
#
# Exit codes (house convention):
#   0  the suite ran and results/run.json was written
#   1  a real failure -- the suite could not run, or the conversion refused its own output
#   2  clean skip -- node or the browsers are unavailable, or --probe found nothing to run
#   3  crash
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
template="$here/templates/audit-suite"

url=""
dir=".wp-audit/suite"
pages=""
only="all"
site=""
probe=0

while [ $# -gt 0 ]; do
  case "$1" in
    --url) url="${2:?--url needs a value}"; shift 2 ;;
    --dir) dir="${2:?--dir needs a value}"; shift 2 ;;
    --pages) pages="${2:?--pages needs a value}"; shift 2 ;;
    --only) only="${2:?--only needs a value}"; shift 2 ;;
    --site) site="${2:?--site needs a value}"; shift 2 ;;
    --probe) probe=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done

case "$only" in a11y|seo|perf|all) : ;; *) echo "--only must be a11y, seo, perf or all" >&2; exit 1 ;; esac

# ---------------------------------------------------------------------------
# Probe
# ---------------------------------------------------------------------------
# Exit 2, not 1. A machine without Node is not a failed audit, it is an audit that has to
# report Tier 3 UNMEASURED -- and the difference matters, because a 1 here would make
# /wp-audit report a broken suite on every machine that simply does not have one.
if ! command -v node >/dev/null 2>&1; then
  echo "audit-suite: node is not available -- the browser suite cannot run here"
  exit 2
fi
if ! command -v npm >/dev/null 2>&1; then
  echo "audit-suite: npm is not available -- the browser suite cannot run here"
  exit 2
fi
[ -d "$template" ] || { echo "audit-suite: $template is missing" >&2; exit 1; }

if [ "$probe" -eq 1 ]; then
  echo "audit-suite: node $(node --version), npm $(npm --version), template present"
  exit 0
fi

[ -n "$url" ] || { echo "audit-suite: --url is required" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Scaffold
# ---------------------------------------------------------------------------
# The template's own files are refreshed on every run; audit.config.js is not, because it
# carries the selectors somebody inspected the real site to find. Overwriting it each run
# would silently discard that work and re-measure a different site than last time.
mkdir -p "$dir"

# The scaffold deletes and replaces its own files by name -- lib/, tests/, package.json and
# the rest. Those names are ordinary enough that pointing --dir at the wrong place (a
# project root, a shared parent) would delete real work before anything is copied back, and
# `${dir:?}` only guards against the variable being empty. So a non-empty directory has to
# prove it is a previous scaffold before this touches it.
if [ -n "$(ls -A "$dir" 2>/dev/null || true)" ] && [ ! -f "$dir/VENDORED-FROM.txt" ]; then
  cat >&2 <<EOF
audit-suite: $dir is not empty and carries no VENDORED-FROM.txt, so it is not a suite this
  scaffolded. Refusing: this step removes lib/, tests/, scripts/, package.json and others by
  name, and those names exist in plenty of directories that are not a suite.
  Point --dir at an empty directory, or at one a previous run scaffolded.
EOF
  exit 1
fi

for item in lib tests scripts playwright.config.js global-setup.js package.json .gitignore .env.example README.md VENDORED-FROM.txt; do
  [ -e "$template/$item" ] || continue
  rm -rf "${dir:?}/$item"
  cp -r "$template/$item" "$dir/$item"
done

if [ ! -f "$dir/audit.config.js" ]; then
  cp "$template/audit.config.js" "$dir/audit.config.js"
  echo "audit-suite: wrote $dir/audit.config.js from the template -- set its selectors against the real DOM"
fi

# baseURL and the page list are the two values that must follow this invocation rather than
# the file, or a suite copied between projects audits the wrong site and says nothing.
if ! BASE_URL="$url" PAGES="$pages" SITE="$site" node - "$dir/audit.config.js" <<'NODE'
const fs = require('fs');
const file = process.argv[2];
let source = fs.readFileSync(file, 'utf8');
const quote = (value) => JSON.stringify(String(value));

// Every rewrite asserts it changed something. A regex that quietly matches nothing leaves
// the previous baseURL in place and the suite measures the wrong site -- exits 0, reports
// findings, names no error. That is the exact failure this file exists to close, and it is
// reachable on any re-run, because audit.config.js is deliberately never overwritten.
const rewrite = (text, pattern, replacement, what) => {
  const next = text.replace(pattern, replacement);
  if (next === text) {
    throw new Error(
      `${file} has no assignable "${what}" -- expected \`${what}: '<value>'\`. `
      + 'Fix the file or delete it and let the scaffold re-seed it; leaving it would audit the wrong site.',
    );
  }
  return next;
};

source = rewrite(source, /(\bbaseURL:\s*)(['"]).*?\2/, `$1${quote(process.env.BASE_URL)}`, 'baseURL');
if (process.env.SITE) {
  source = rewrite(source, /(\bsiteName:\s*)(['"]).*?\2/, `$1${quote(process.env.SITE)}`, 'siteName');
}
if (process.env.PAGES) {
  const list = process.env.PAGES.split(',').map((p) => p.trim()).filter(Boolean);
  const rendered = `[\n${list.map((p) => `    { path: ${quote(p)}, name: ${quote(p === '/' ? 'home' : p.replace(/^\//, ''))} },`).join('\n')}\n  ]`;

  // Find the array's real end by counting brackets, not by matching to the first `]`.
  // The template's own default list is not flat -- its contact entry nests
  // `form: { fields: [ ... ] }` -- so a non-greedy regex stops at that inner array and
  // leaves the outer one's tail behind as orphaned tokens. The result does not parse, and
  // nothing notices until a Playwright run fails with a syntax error deep in a generated
  // file. Brackets inside strings and comments are skipped for the same reason.
  const match = /\bpages:\s*\[/.exec(source);
  if (!match) throw new Error(`${file} has no "pages:" array to replace`);
  const open = match.index + match[0].length - 1;

  let depth = 0;
  let end = -1;
  let quoteChar = null;
  let comment = null;
  for (let i = open; i < source.length; i += 1) {
    const c = source[i];
    const next = source[i + 1];
    if (comment === 'line') { if (c === '\n') comment = null; continue; }
    if (comment === 'block') { if (c === '*' && next === '/') { comment = null; i += 1; } continue; }
    if (quoteChar) {
      if (c === '\\') { i += 1; continue; }
      if (c === quoteChar) quoteChar = null;
      continue;
    }
    if (c === '/' && next === '/') { comment = 'line'; i += 1; continue; }
    if (c === '/' && next === '*') { comment = 'block'; i += 1; continue; }
    if (c === "'" || c === '"' || c === '`') { quoteChar = c; continue; }
    if (c === '[') depth += 1;
    else if (c === ']') {
      depth -= 1;
      if (depth === 0) { end = i; break; }
    }
  }
  if (end === -1) throw new Error(`${file} has an unterminated "pages:" array`);

  source = source.slice(0, match.index) + `${match[0].slice(0, -1)}${rendered}` + source.slice(end + 1);
}
fs.writeFileSync(file, source);
NODE
then
  echo "audit-suite: could not point $dir/audit.config.js at $url" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Dependencies, shared
# ---------------------------------------------------------------------------
cache="${WP_AUDIT_SUITE_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/claude-wp-builder/audit-suite}"
export PLAYWRIGHT_BROWSERS_PATH="${PLAYWRIGHT_BROWSERS_PATH:-${cache}/browsers}"
mkdir -p "$cache" "$PLAYWRIGHT_BROWSERS_PATH"

# A machine that already has the suite's packages -- a global `npm install -g`, a shared
# toolchain -- names that directory and skips the managed install. It is used as given: the
# operator owns its versions, so it is checked below for whether it loads, not for semver.
if [ -n "${WP_AUDIT_SUITE_NODE_MODULES:-}" ]; then
  modules="$WP_AUDIT_SUITE_NODE_MODULES"
  if [ ! -d "$modules" ]; then
    echo "audit-suite: WP_AUDIT_SUITE_NODE_MODULES=$modules is not a directory" >&2
    exit 1
  fi
  echo "audit-suite: using the packages in $modules (WP_AUDIT_SUITE_NODE_MODULES)"
else
  # The cache is keyed by the template's package.json. A dependency bump therefore installs
  # into a new directory instead of mutating the one older projects are still symlinked to.
  key="$(cksum < "$template/package.json" | awk '{print $1}')"

  # The leaf must be named exactly node_modules. Node resolves a package's own imports from
  # its real path, walking up through directories literally called node_modules, so the
  # symlink from the project does not help once the package is loaded. A leaf named
  # node_modules-<key> is never searched: @playwright/test could not find playwright, and
  # every run died with MODULE_NOT_FOUND while reporting a browser that would not install.
  modules="$cache/$key/node_modules"

  if [ ! -d "$modules" ]; then
    # `mkdir` is the atomic part. Two runs racing a bare `[ ! -d ]` both install, and the
    # second `mv` finds a directory and nests inside it -- producing node_modules/node_modules,
    # no error and no non-zero exit, because `mv` did exactly what it was asked.
    lock="$cache/$key.lock"
    if mkdir "$lock" 2>/dev/null; then
      staging=""
      # Both, and on INT/TERM as well as EXIT. Trapping only the lock left an install-XXXXXX
      # directory orphaned in the shared cache on every abort between mktemp and mv -- and
      # under `set -e` an unguarded `cp` or a Ctrl-C is exactly such an abort.
      trap 'rm -rf "$lock" ${staging:+"$staging"}' EXIT INT TERM
      echo "audit-suite: installing the suite's dependencies once into $modules"
      staging="$(mktemp -d "$cache/install-XXXXXX")"
      cp "$template/package.json" "$staging/package.json"
      if ! (cd "$staging" && npm install --no-audit --no-fund --silent); then
        echo "audit-suite: npm install failed -- the browser suite cannot run here"
        exit 2
      fi
      # Move, do not copy: a half-written cache that a later run treats as complete is worse
      # than no cache, and a rename within one filesystem is the only atomic option here.
      mkdir -p "$cache/$key"
      mv "$staging/node_modules" "$modules" || exit 1
      rm -rf "$staging" "$lock"
      staging=""
      trap - EXIT INT TERM
    else
      echo "audit-suite: another run is installing the same dependencies -- waiting"
      waited=0
      while [ -d "$lock" ] && [ ! -d "$modules" ]; do
        sleep 2
        waited=$((waited + 2))
        # A lock left behind by a killed process must not block every later run forever. Ten
        # minutes is longer than the install and shorter than a working day.
        if [ "$waited" -ge 600 ]; then
          echo "audit-suite: gave up waiting for $lock -- remove it if no install is running" >&2
          exit 1
        fi
      done
      [ -d "$modules" ] || { echo "audit-suite: the other run did not produce $modules" >&2; exit 1; }
    fi
  fi
fi

rm -rf "$dir/node_modules"
ln -s "$modules" "$dir/node_modules"

# Load the CLI before asking it to do anything. A package tree that exists but cannot resolve
# its own imports fails every later step with the same MODULE_NOT_FOUND, and each of those
# steps would name its own symptom instead of the cause. Exit 1, not 2: this is a broken
# install on a machine that has Node, not a machine without one.
if ! out="$(cd "$dir" && npx --no-install playwright --version 2>&1)"; then
  echo "audit-suite: the Playwright CLI in $modules does not load:" >&2
  printf '%s\n' "$out" | grep -m3 -E 'Error|Cannot find' >&2 || printf '%s\n' "$out" | tail -3 >&2
  exit 1
fi

# The install's own output is kept for the failure message. Discarding it is how a module
# that would not resolve was reported as a browser that would not download.
if ! out="$(cd "$dir" && npx --no-install playwright install chromium 2>&1)"; then
  echo "audit-suite: playwright could not install its browser -- reporting Tier 3 unmeasured"
  printf '%s\n' "$out" | tail -5 >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
# Lighthouse measures the machine as much as the page, so the performance pass runs alone
# and never beside the DOM/axe suite. This is the same rule wp-audit-standards states for a
# hand-run Lighthouse, enforced here rather than left to whoever reads it.
status=0
run_pass() {
  echo "audit-suite: $1"
  (cd "$dir" && npm run --silent "$2") || status=1
}

case "$only" in
  a11y) run_pass "accessibility and usability pass" test:a11y ;;
  seo)  run_pass "technical SEO pass" test:seo ;;
  perf) run_pass "Lighthouse pass (alone -- a contended machine is not a slow page)" test:perf ;;
  all)
    run_pass "accessibility and usability pass" test:a11y
    run_pass "technical SEO pass" test:seo
    run_pass "Lighthouse pass (alone -- a contended machine is not a slow page)" test:perf
    ;;
esac

# A failing spec is a finding, not a broken run: the suite reports a site that does not
# comply by failing. What matters is whether it produced results to convert -- but "every
# pass ran clean" and "a pass errored and we converted what was left" are different states,
# and a report built from the second without saying so understates the site.
if [ "$status" -ne 0 ]; then
  echo "audit-suite: at least one pass exited non-zero -- findings below may be incomplete"
fi
if [ ! -d "$dir/results/audit" ] || [ -z "$(ls -A "$dir/results/audit" 2>/dev/null)" ]; then
  echo "audit-suite: the suite produced no results -- nothing to convert"
  exit 1
fi

if ! (cd "$dir" && node scripts/to-run.js --out results/run.json ${site:+--site "$site"}); then
  echo "audit-suite: converting the suite's results to a run file failed"
  exit 1
fi

echo "audit-suite: $dir/results/run.json"
exit 0
