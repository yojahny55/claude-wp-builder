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
#   PLAYWRIGHT_BROWSERS_PATH     an extra Playwright browser cache to search for executables
#   WP_BROWSER_CHROMIUM / _FIREFOX / _WEBKIT
#                                use this executable (bin/lib/browsers.mjs); nothing is
#                                ever downloaded, a missing browser is a skip
#   WP_AUDIT_SUITE_CACHE         the cache dir itself
#
# Usage:
#   bin/audit-suite.sh --url <base-url> [--dir <suite-dir>] [--pages <p1,p2,...>]
#                      [--only a11y|seo|perf|all] [--site <name>] [--probe]
#                      [--max-timeouts <n>] [--workers <n>] [--timeout <seconds>]
#                      [--engines chromium[,firefox][,webkit]] [--settle <seconds>]
#                      [--block-third-party | --no-block-third-party] [--allow-hosts <h1,h2>]
#
# Run settings are flags, not edits to the generated playwright.config.js:
#   --workers     Playwright workers for the DOM and SEO passes (the Lighthouse pass always
#                 runs with one). Default: the template's 4 locally, 1 against production,
#                 where more than 1 is refused.
#   --timeout     per-test timeout in seconds (default: the template's 90).
#   --engines     which engines run the accessibility pass; chromium is required, because it
#                 carries every pass. Default chromium,firefox,webkit (each one that exists).
#   --settle      a page is loaded to `domcontentloaded` and then given at most this long to
#                 go network-idle (default 5). A page with a video embed or a polling widget
#                 never goes idle, and waiting for it timed out every page of such a site.
#   --block-third-party / --no-block-third-party
#                 block every host but the audited one (its www twin and loopback) and
#                 --allow-hosts. Default ON against a local host, where analytics, embeds and
#                 widgets would be real hits on production properties from a clone; OFF
#                 against production unless passed. `.example.com` in --allow-hosts allows
#                 a domain and its subdomains.
# A generated config somebody edited is kept, not overwritten (see "Scaffold" below), but the
# flags are the supported way: they apply to every run and survive a template update.
#
# The audited host is always the one in --url: it reaches the suite as BASE_URL in the
# environment, and the persistent audit.config.js is never rewritten to hold it. A request to
# a production host (any public host, or one the manifest's `environments` marks role prod)
# only ever goes out through bin/prod-gate.sh: when this script is not already running under
# the gate it re-runs itself through it. After --max-timeouts (default 3, or
# WP_AUDIT_MAX_TIMEOUTS) page timeouts in a row the run stops and exits 2 with the cause.
#
# Exit codes (house convention):
#   0  the suite ran and results/run.json was written
#   4/5  the production gate refused (host marked blocked / busy); nothing was sent
#   1  a real failure -- the suite could not run, or the conversion refused its own output
#   2  clean skip -- node or an existing Chromium is unavailable, --probe found nothing to run,
#      or the host stopped answering (the "UNMEASURED:" line names the cause)
#   3  crash
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
template="$here/templates/audit-suite"

orig_args=("$@")
max_timeouts="${WP_AUDIT_MAX_TIMEOUTS:-3}"
url=""
dir=".wp-audit/suite"
pages=""
only="all"
site=""
probe=0
workers=""
timeout_s=""
engines="chromium,firefox,webkit"
settle_s="5"
block=""
allow_hosts=""

while [ $# -gt 0 ]; do
  case "$1" in
    --url) url="${2:?--url needs a value}"; shift 2 ;;
    --dir) dir="${2:?--dir needs a value}"; shift 2 ;;
    --pages) pages="${2:?--pages needs a value}"; shift 2 ;;
    --only) only="${2:?--only needs a value}"; shift 2 ;;
    --site) site="${2:?--site needs a value}"; shift 2 ;;
    --max-timeouts) max_timeouts="${2:?--max-timeouts needs a value}"; shift 2 ;;
    --workers) workers="${2:?--workers needs a value}"; shift 2 ;;
    --timeout) timeout_s="${2:?--timeout needs a value}"; shift 2 ;;
    --engines) engines="${2:?--engines needs a value}"; shift 2 ;;
    --settle) settle_s="${2:?--settle needs a value}"; shift 2 ;;
    --block-third-party) block=1; shift ;;
    --no-block-third-party) block=0; shift ;;
    --allow-hosts) allow_hosts="${2:?--allow-hosts needs a value}"; shift 2 ;;
    --probe) probe=1; shift ;;
    # Not a flag of this script: the engines are --engines. Said here because it was tried.
    --project|--project=*) echo "audit-suite: there is no --project; choose engines with --engines chromium[,firefox][,webkit]" >&2; exit 1 ;;
    *) echo "unknown argument: $1" >&2; exit 1 ;;
  esac
done

case "$only" in a11y|seo|perf|all) : ;; *) echo "--only must be a11y, seo, perf or all" >&2; exit 1 ;; esac
case "$max_timeouts" in ''|*[!0-9]*|0) echo "--max-timeouts must be a positive integer" >&2; exit 1 ;; esac
export WP_AUDIT_MAX_TIMEOUTS="$max_timeouts"
case "$workers" in ''|[1-9]|[1-9][0-9]) : ;; *) echo "--workers must be a positive integer" >&2; exit 1 ;; esac
case "$timeout_s" in ''|[1-9]|[1-9][0-9]|[1-9][0-9][0-9]|[1-9][0-9][0-9][0-9]) : ;; *) echo "--timeout must be a positive number of seconds" >&2; exit 1 ;; esac
case "$settle_s" in [0-9]|[1-9][0-9]) : ;; *) echo "--settle must be 0-99 seconds" >&2; exit 1 ;; esac
engines="$(printf '%s' "$engines" | tr '[:upper:]' '[:lower:]' | tr -d ' ')"
IFS=, read -r -a engine_list <<< "$engines"
for e in "${engine_list[@]}"; do
  case "$e" in chromium|firefox|webkit) : ;; *) echo "--engines: unknown engine '$e' (chromium, firefox, webkit)" >&2; exit 1 ;; esac
done
case ",$engines," in *,chromium,*) : ;; *) echo "--engines must include chromium: it carries every pass, the others only repeat the accessibility pass" >&2; exit 1 ;; esac

# A public host is production, and production runs fail2ban, CrowdSec and ModSecurity. The
# template's 4 workers mean 4 browsers loading full pages at once, which is about 400
# requests in a burst. An audit that hit production that way, beside six other agents, got
# the auditing IP banned. Against a public host every pass runs with one worker: the same
# tests and the same metrics, only paced. A local host keeps the template's parallelism.
url_host="${url#*://}"; url_host="${url_host%%/*}"; url_host="${url_host%%\?*}"; url_host="${url_host%%#*}"; url_host="${url_host##*@}"
url_host="$(printf '%s' "$url_host" | tr '[:upper:]' '[:lower:]')"
pw_args=(--workers=1)
case "$url_host" in
  localhost|localhost:*|*.localhost|*.localhost:*|*.local|*.local:*|*.local.com|*.local.com:*|*.test|*.test:*|\[::1\]*|0.0.0.0|0.0.0.0:*) pw_args=() ;;
  *)
    # Private ranges apply to a dotted IPv4 address only, by octet, as in prod-gate.sh:
    # a prefix glob would also give `10.example.com` the local parallelism.
    ip="${url_host%%:*}"
    case "$ip" in
      *[!0-9.]*) ;;
      *.*.*.*)
        IFS=. read -r o1 o2 _ <<< "$ip"
        case "$o1" in
          10|127) pw_args=() ;;
          192) [ "$o2" = 168 ] && pw_args=() ;;
          172) [ "${o2:-0}" -ge 16 ] && [ "${o2:-0}" -le 31 ] && pw_args=() ;;
        esac ;;
    esac ;;
esac

# A host is production when it is public (above) or when the manifest's `environments` says
# role prod for it. Without that key the public-host rule is the whole criterion.
# shellcheck source=lib/host-key.sh
. "$here/bin/lib/host-key.sh"
gate_host="$(host_key "$url")"
manifest_prod=0
manifest="${WP_CREATE_JSON:-.wp-create.json}"
if [ -n "$url_host" ] && [ -f "$manifest" ] && command -v node >/dev/null 2>&1; then
  node - "$manifest" "${gate_host#www.}" <<'NODE' && manifest_prod=1
const [file, host] = process.argv.slice(2);
let env;
try { env = JSON.parse(require('fs').readFileSync(file, 'utf8')).environments; } catch (e) { console.error(`audit-suite: WARNING: ${file} is unreadable (${e.message}); the production check by manifest was skipped -- fix it, or pass --prod`); process.exit(1); }
const entries = Array.isArray(env) ? env : Object.entries(env || {}).map(([name, v]) => (typeof v === 'object' && v ? { name, ...v } : { name, url: v }));
const hostOf = (v) => { try { return new URL(/^[a-z]+:\/\//i.test(v) ? v : `https://${v}`).hostname.toLowerCase().replace(/^www\./, ''); } catch { return ''; } };
const prod = entries.some((e) => e && /^prod(uction)?$/i.test(String(e.role || e.name || ''))
  && [e.url, e.host, e.domain].filter(Boolean).some((v) => hostOf(String(v)) === host));
process.exit(prod ? 0 : 1);
NODE
fi
is_prod=0
prod_flag=()
if [ "$manifest_prod" -eq 1 ] || [ ${#pw_args[@]} -gt 0 ]; then is_prod=1; fi
if [ "$manifest_prod" -eq 1 ]; then pw_args=(--workers=1); prod_flag=(--prod); fi

# --workers replaces the default above, except that production stays at one: the burst of
# parallel browsers is what got an auditing IP banned, whoever asks for it.
if [ -n "$workers" ]; then
  if [ "$is_prod" -eq 1 ] && [ "$workers" -gt 1 ]; then
    echo "audit-suite: refusing --workers $workers against production host $url_host -- production runs with one worker" >&2
    exit 1
  fi
  pw_args=(--workers="$workers")
fi
# --timeout reaches every pass but Lighthouse's, which sets its own per test.
if [ -n "$timeout_s" ]; then pw_args+=(--timeout="$((timeout_s * 1000))"); fi

# Third parties: blocked by default from a local host, opt-in against production. A run that
# measures production as visitors get it keeps the third parties unless told otherwise.
if [ -z "$block" ]; then
  if [ "$is_prod" -eq 1 ]; then block=0; else block=1; fi
fi

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

# Browsers are resolved, never installed: `playwright install` downloads a build pinned to
# one Playwright revision, and on a machine whose policy forbids it the audit died on the
# install instead of measuring. bin/lib/browsers.mjs finds an executable that already exists
# (Playwright's caches, then the system Chromium). Chromium carries every pass; Firefox and
# WebKit only add the cross-browser pass, so their absence is a notice, not a skip. Each
# lookup logs the executable and revision it chose on stderr, left visible on purpose: a
# build of another revision than the driving Playwright pins is the first suspect when a
# launch fails.
# browsers.mjs exits 2 when it finds nothing; any other failure is the lookup itself
# crashing (an old Node, a broken checkout) and must not read as "no browser".
find_browser() {
  local out rc=0
  out="$(node "$here/bin/lib/browsers.mjs" "$1")" || rc=$?
  case "$rc" in
    0) printf '%s' "$out" ;;
    2) ;;
    *) echo "audit-suite: bin/lib/browsers.mjs failed (exit $rc) looking up $1; its error is above" >&2; exit 1 ;;
  esac
}
chromium_exe="$(find_browser chromium)" || exit 1
firefox_exe="$(find_browser firefox)" || exit 1
webkit_exe="$(find_browser webkit)" || exit 1
if [ -z "$chromium_exe" ]; then
  echo "audit-suite: no existing Chromium found (Playwright cache or system chromium; set WP_BROWSER_CHROMIUM) -- reporting Tier 3 unmeasured. Nothing is downloaded."
  exit 2
fi

if [ "$probe" -eq 1 ]; then
  echo "audit-suite: node $(node --version), npm $(npm --version), template present, chromium $chromium_exe${firefox_exe:+, firefox $firefox_exe}${webkit_exe:+, webkit $webkit_exe}"
  exit 0
fi

[ -n "$url" ] || { echo "audit-suite: --url is required" >&2; exit 1; }

# No request to a production host leaves this script ungated, whoever called it. The gate
# exports WP_AUDIT_GATE_HELD=<host> to its child, so a run the caller already wrapped goes
# on without taking the host's lock a second time (flock would wait on itself).
if [ "$is_prod" -eq 1 ] && [ "${WP_AUDIT_GATE_HELD:-}" != "$gate_host" ]; then
  echo "audit-suite: $gate_host is a production host -- re-running through bin/prod-gate.sh"
  exec "$here/bin/prod-gate.sh" ${prod_flag[@]+"${prod_flag[@]}"} "$url" -- "$0" ${orig_args[@]+"${orig_args[@]}"}
fi

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
# The refusal names what it found: the usual cause is a log or a note somebody wrote into the
# directory before its first run, and "not empty" alone sent a run off to guess which file.
if [ -n "$(ls -A "$dir" 2>/dev/null || true)" ] && [ ! -f "$dir/VENDORED-FROM.txt" ]; then
  stray="$(ls -A "$dir" | head -n 10 | sed 's/^/    /')"
  count="$(ls -A "$dir" | wc -l | tr -d ' ')"
  cat >&2 <<EOF
audit-suite: $dir is not empty and carries no VENDORED-FROM.txt, so it is not a suite this
  scaffolded. It holds $count entr$([ "$count" = 1 ] && echo y || echo ies)$([ "$count" -gt 10 ] && echo ', the first 10'):
$stray
  Refusing: this step removes lib/, tests/, scripts/, regression/, package.json and others by
  name, and those names exist in plenty of directories that are not a suite.
  Move those files out (a run log belongs outside the suite directory), or point --dir at an
  empty directory or at one a previous run scaffolded.
EOF
  exit 1
fi

# The Playwright configs and global-setup.js are where somebody tunes a run by hand (workers,
# timeouts, projects), and refreshing them unconditionally discarded those edits at the start
# of the very run they were made for, without a word. So each one is refreshed only while it
# is still what the scaffold wrote: .scaffold-sums records the checksum of each as copied, and
# a file whose checksum no longer matches is kept, with a notice. A scaffold older than that
# record has no checksum to compare, so a config that differs from the template is kept too:
# keeping an outdated file is recoverable, discarding an edit is not. Delete a kept file to
# take the template's again. Everything else is the template's and is always refreshed.
sums="$dir/.scaffold-sums"
sum_of() { cksum < "$1" | awk '{print $1}'; }
recorded_sum() { if [ -f "$sums" ]; then awk -v f="$1" '$2 == f {print $1}' "$sums"; fi; }
new_sums=""
for item in lib guard tests scripts regression playwright.config.js playwright.guard.config.js playwright.regression.config.js global-setup.js package.json package-lock.json .gitignore .env.example README.md VENDORED-FROM.txt; do
  [ -e "$template/$item" ] || continue
  case "$item" in
    playwright.config.js|playwright.guard.config.js|playwright.regression.config.js|global-setup.js)
      if [ -f "$dir/$item" ] && ! cmp -s "$dir/$item" "$template/$item"; then
        held="$(recorded_sum "$item")"
        if [ -z "$held" ] || [ "$held" != "$(sum_of "$dir/$item")" ]; then
          echo "audit-suite: keeping your edited $dir/$item (the template's is $template/$item; delete yours to take it). Prefer --workers, --timeout, --engines and --block-third-party: they need no edit."
          # The kept file's record stays as it was (or absent), so it reads as edited next run too.
          [ -n "$held" ] && new_sums="$new_sums$held $item"$'\n'
          continue
        fi
      fi
      new_sums="$new_sums$(sum_of "$template/$item") $item"$'\n'
      ;;
  esac
  rm -rf "${dir:?}/$item"
  cp -r "$template/$item" "$dir/$item"
done
printf '%s' "$new_sums" > "$sums"

if [ ! -f "$dir/audit.config.js" ]; then
  cp "$template/audit.config.js" "$dir/audit.config.js"
  echo "audit-suite: wrote $dir/audit.config.js from the template -- set its selectors against the real DOM"
fi

# The audited host follows this invocation, never the file. audit.config.js is persistent
# state: rewriting baseURL in it meant a hand edit or an earlier run could leave the next one
# pointed at another host, and a suite once ran against production that way. So baseURL is
# only read here (a mismatch is reported), BASE_URL goes out through the environment, and an
# override line at the end of the config makes it win in every spec that reads audit.baseURL.
# The page list and site name are still written, as before.
rm -f "$dir/results/unmeasured.json" "$dir/results/unmeasured-pages.json"
export BASE_URL="$url"
if ! BASE_URL="$url" PAGES="$pages" SITE="$site" node - "$dir/audit.config.js" <<'NODE'
const fs = require('fs');
const file = process.argv[2];
let source = fs.readFileSync(file, 'utf8');
const quote = (value) => JSON.stringify(String(value));

// Every rewrite asserts its pattern matched. A regex that quietly matches nothing leaves
// the previous baseURL in place and the suite measures the wrong site -- exits 0, reports
// findings, names no error. That is the exact failure this file exists to close, and it is
// reachable on any re-run, because audit.config.js is deliberately never overwritten.
// The assertion is on the match, not on the text changing: a re-run against the same URL
// and site name rewrites each value to itself, and that is a no-op, not a failure.
const rewrite = (text, pattern, replacement, what) => {
  if (!pattern.test(text)) {
    throw new Error(
      `${file} has no assignable "${what}" -- expected \`${what}: '<value>'\`. `
      + 'Fix the file or delete it and let the scaffold re-seed it; leaving it would audit the wrong site.',
    );
  }
  return text.replace(pattern, replacement);
};

const held = /(\bbaseURL:\s*)(['"])(.*?)\2/.exec(source);
if (!held) {
  throw new Error(
    `${file} has no assignable "baseURL" -- expected \`baseURL: '<value>'\`. `
    + 'Fix the file or delete it and let the scaffold re-seed it; leaving it would audit the wrong site.',
  );
}
const hostOf = (value) => { try { return new URL(value).host.toLowerCase(); } catch { return value; } };
if (hostOf(held[3]) !== hostOf(process.env.BASE_URL)) {
  console.error(`audit-suite: ${file} holds baseURL ${held[3]} but --url is ${process.env.BASE_URL}; auditing --url (BASE_URL), the file is not edited`);
}
if (!source.includes('WP_AUDIT_BASE_URL_OVERRIDE')) {
  source = `${source.replace(/\s*$/, '\n')}\n// BASE_URL (set per run by bin/audit-suite.sh) wins over the baseURL above.\nif (process.env.BASE_URL) module.exports.baseURL = process.env.BASE_URL; // WP_AUDIT_BASE_URL_OVERRIDE\n`;
}
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
  echo "audit-suite: could not prepare $dir/audit.config.js for $url" >&2
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
  if [ ! -d "$WP_AUDIT_SUITE_NODE_MODULES" ]; then
    echo "audit-suite: WP_AUDIT_SUITE_NODE_MODULES=$WP_AUDIT_SUITE_NODE_MODULES is not a directory" >&2
    exit 1
  fi
  # Absolute and physical. The link below resolves a relative target against $dir, not
  # against the directory the check above ran in, so a relative value would pass the check
  # and leave a dangling link.
  modules="$(cd "$WP_AUDIT_SUITE_NODE_MODULES" && pwd -P)"
  echo "audit-suite: using the packages in $modules (WP_AUDIT_SUITE_NODE_MODULES)"
else
  # The cache is keyed by the template's package.json. A dependency bump therefore installs
  # into a new directory instead of mutating the one older projects are still symlinked to.
  # The lockfile is part of the key: same package.json with different pins is a different tree.
  [ -f "$template/package-lock.json" ] || {
    echo "audit-suite: $template/package-lock.json is missing -- refusing an unlocked install (it would resolve whatever is newest). Nothing is installed." >&2
    exit 1
  }
  key="$(cat "$template/package.json" "$template/package-lock.json" | cksum | awk '{print $1}')"

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
      cp "$template/package.json" "$template/package-lock.json" "$staging/"
      # `npm ci` installs exactly what the lockfile pins and fails if it disagrees with
      # package.json. No browser is fetched: PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD is belt and braces.
      if ! (cd "$staging" && PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm ci --no-audit --no-fund --silent); then
        echo "audit-suite: npm ci failed -- the browser suite cannot run here"
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

# An override that already is this suite's node_modules -- packages installed there by hand --
# is used in place. Replacing it with a link would first delete the operator's packages and
# then point the link at itself.
if [ -d "$dir/node_modules" ] && [ ! -L "$dir/node_modules" ] \
  && [ "$(cd "$dir/node_modules" && pwd -P)" = "$modules" ]; then
  :
else
  rm -rf "$dir/node_modules"
  ln -s "$modules" "$dir/node_modules"
fi

# Load the CLI before asking it to do anything. A package tree that exists but cannot resolve
# its own imports fails every later step with the same MODULE_NOT_FOUND, and each of those
# steps would name its own symptom instead of the cause. Exit 1, not 2: this is a broken
# install on a machine that has Node, not a machine without one.
if ! out="$(cd "$dir" && npx --no-install playwright --version 2>&1)"; then
  echo "audit-suite: the Playwright CLI in $modules does not load:" >&2
  printf '%s\n' "$out" | grep -m3 -E 'Error|Cannot find' >&2 || printf '%s\n' "$out" | tail -3 >&2
  exit 1
fi

# Every launch in the suite -- the runner's projects, Lighthouse's own Chromium, the form
# login -- gets the resolved executable through a preload, because the vendored files pass
# none and are compared against their upstream (bin/lib/pw-executables.cjs says how).
[ -f "$here/bin/lib/pw-executables.cjs" ] \
  || { echo "audit-suite: $here/bin/lib/pw-executables.cjs is missing; the plugin checkout is incomplete" >&2; exit 1; }
# Resolved again, now that the suite's own playwright-core exists: the first pass runs
# before the install, so pinnedRevisions() had no manifest to read and could only take the
# newest cached build. With PLAYWRIGHT_CORE set, the revision this suite pins wins, and a
# cache that lacks it says MISMATCH instead of failing later at launch.
export PLAYWRIGHT_CORE="$modules/playwright-core"
chromium_exe="$(find_browser chromium)" || exit 1
firefox_exe="$(find_browser firefox)" || exit 1
webkit_exe="$(find_browser webkit)" || exit 1
if [ -z "$chromium_exe" ]; then
  echo "audit-suite: no existing Chromium found (Playwright cache or system chromium; set WP_BROWSER_CHROMIUM) -- reporting Tier 3 unmeasured. Nothing is downloaded."
  exit 2
fi
export WP_AUDIT_CHROMIUM="$chromium_exe" WP_AUDIT_FIREFOX="$firefox_exe" WP_AUDIT_WEBKIT="$webkit_exe"
case "${NODE_OPTIONS:-}" in
  *pw-executables.cjs*) ;;
  # Quoted: node splits NODE_OPTIONS on whitespace, and a plugin installed under a path
  # with a space would otherwise kill every node process in the suite at startup.
  *) export NODE_OPTIONS="${NODE_OPTIONS:+$NODE_OPTIONS }--require \"$here/bin/lib/pw-executables.cjs\"" ;;
esac
echo "audit-suite: chromium $chromium_exe"

# The run settings the preload applies inside the vendored files (bin/lib/pw-executables.cjs).
export WP_AUDIT_SETTLE_MS="$((settle_s * 1000))"
if [ "$block" = 1 ]; then
  export WP_AUDIT_BLOCK_THIRD_PARTY=1 WP_AUDIT_ALLOW_HOSTS="$allow_hosts"
  allowed="$(node -e 'const t=require(process.argv[1]);console.log(t.allowlistFor(process.argv[2],process.argv[3]).join(", "))' "$here/bin/lib/third-party.cjs" "$url" "$allow_hosts")"
  echo "audit-suite: third-party hosts blocked; allowed: $allowed"
else
  export WP_AUDIT_BLOCK_THIRD_PARTY=0
  echo "audit-suite: third-party hosts are NOT blocked (pass --block-third-party to block them)"
fi

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
# Lighthouse measures the machine as much as the page, so the performance pass runs alone
# and never beside the DOM/axe suite. This is the same rule wp-audit-standards states for a
# hand-run Lighthouse, enforced here rather than left to whoever reads it.
status=0
aborted=""
# The timeout guard (guard/timeout-guard.js, a reporter in playwright.guard.config.js) writes
# results/unmeasured.json after N page timeouts in a row. Once it exists nothing else is sent.
check_abort() {
  if [ -z "$aborted" ] && [ -f "$dir/results/unmeasured.json" ]; then
    aborted="$(node -e 'console.log(JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")).reason||"page timeouts")' "$dir/results/unmeasured.json" 2>/dev/null || echo "page timeouts")"
  fi
  [ -n "$aborted" ]
}
run_pass() {
  check_abort && return 0
  echo "audit-suite: $1"
  local args=(${pw_args[@]+"${pw_args[@]}"})
  # The Lighthouse pass keeps its own --workers=1 (npm takes the last value given, so a
  # --workers here would override it) and sets its own per-test timeout.
  if [ "$2" = test:perf ]; then args=(); fi
  (cd "$dir" && npm run --silent "$2" -- ${args[@]+"${args[@]}"}) || status=1
  check_abort || true
}

# The DOM/axe pass again in the other engines the config declares. Their results land beside
# Chromium's (<page>.<browser>.json) and the collector keeps each criterion's worst state, so
# a layout or control that only breaks in Firefox or WebKit becomes a finding. An engine with
# no existing executable is skipped with a notice, never installed.
cross_browser() {
  for engine in firefox webkit; do
    check_abort && return 0
    case ",$engines," in *,"$engine",*) : ;; *) echo "audit-suite: $engine pass not requested (--engines $engines)"; continue ;; esac
    exe_var="${engine}_exe"
    if [ -z "${!exe_var}" ]; then
      echo "audit-suite: no existing $engine build found -- $engine pass skipped (nothing is downloaded)"
      continue
    fi
    echo "audit-suite: accessibility and usability pass in $engine"
    (cd "$dir" && npx --no-install playwright test -c playwright.guard.config.js tests/audit.spec.js --project="$engine" ${pw_args[@]+"${pw_args[@]}"}) \
      || { check_abort || { echo "audit-suite: the $engine pass ran and exited non-zero (a failure, not a skip)"; status=1; }; }
  done
}

case "$only" in
  a11y) run_pass "accessibility and usability pass" test:a11y; cross_browser ;;
  seo)  run_pass "technical SEO pass" test:seo ;;
  perf) run_pass "Lighthouse pass (alone -- a contended machine is not a slow page)" test:perf ;;
  all)
    run_pass "accessibility and usability pass" test:a11y
    cross_browser
    run_pass "technical SEO pass" test:seo
    run_pass "Lighthouse pass (alone -- a contended machine is not a slow page)" test:perf
    ;;
esac

if check_abort; then
  echo "audit-suite: UNMEASURED: the browser tier did not complete -- $aborted. No further requests were sent to $url_host."
  exit 2
fi

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
