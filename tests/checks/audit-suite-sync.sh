#!/usr/bin/env bash
# templates/audit-suite/ is vendored from the web-portal-audit skill. Vendoring buys a
# plugin that works without that skill installed, and the price is a second copy that can
# drift: a fix made upstream never arrives, or a fix made here never goes back, and both
# copies keep passing their own tests while describing different behavior.
#
# This compares the two whenever the source is present, and SKIPs when it is not, because a
# vendored tree has to keep working on a machine that has never seen its origin -- CI being
# the obvious one.
#
# Only the logic is compared. audit.config.js is per project by definition: the plugin's
# copy is a generic template and the skill's is whatever site was audited last, so requiring
# them to match would either leak a real site into this repo or fail forever. scripts/
# is compared file by file for the same reason -- to-run.js is the plugin's bridge and has
# no upstream counterpart.
#
# Point WP_AUDIT_SUITE_SOURCE at the skill's assets/playwright-template to compare against a
# checkout somewhere else.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

suite=templates/audit-suite
provenance="$suite/VENDORED-FROM.txt"
[ -f "$provenance" ] || fail "$provenance is missing -- a vendored tree with no origin is a fork nobody knows about"

source_dir="${WP_AUDIT_SUITE_SOURCE:-}"
if [ -z "$source_dir" ]; then
  for candidate in \
    "$HOME/.claude/skills/web-portal-audit/assets/playwright-template" \
    "/srv/http/web-portal-audit/assets/playwright-template"; do
    [ -d "$candidate" ] && { source_dir="$candidate"; break; }
  done
fi

if [ -z "$source_dir" ] || [ ! -d "$source_dir" ]; then
  echo "SKIP: the upstream template is not on this machine -- set WP_AUDIT_SUITE_SOURCE to compare"
  exit 0
fi

# The files whose behavior must be identical in both copies. scripts/build-report.js is the
# suite's own report generator; the plugin does not use it, but a divergence there means the
# trees have parted, which is the thing being detected.
tracked=(
  playwright.config.js
  global-setup.js
  scripts/build-report.js
  tests/audit.spec.js
  tests/seo-tech.spec.js
  tests/performance.spec.js
)
while IFS= read -r lib; do
  tracked+=("lib/$(basename "$lib")")
done < <(find "$suite/lib" -name '*.js' | sort)

drifted=()
missing=()
for rel in "${tracked[@]}"; do
  ours="$suite/$rel"
  theirs="$source_dir/$rel"
  if [ ! -f "$theirs" ]; then
    # Upstream removed it, or it never existed there. Either way the vendored copy is now
    # unowned, which is worth saying out loud rather than passing.
    missing+=("$rel")
    continue
  fi
  [ -f "$ours" ] || fail "$ours is missing from the vendored tree but exists upstream"
  cmp -s "$ours" "$theirs" || drifted+=("$rel")
done

# The dependency set is the other thing that has to agree: the same specs against different
# axe or Lighthouse versions produce different findings, and nothing in the file contents
# would show it.
ours_deps=$(node -e 'const p=require("./'"$suite"'/package.json");console.log(JSON.stringify(p.devDependencies))' 2>/dev/null || echo '')
theirs_deps=$(node -e 'const p=require(process.argv[1]);console.log(JSON.stringify(p.devDependencies))' "$source_dir/package.json" 2>/dev/null || echo '')
if [ -n "$ours_deps" ] && [ -n "$theirs_deps" ] && [ "$ours_deps" != "$theirs_deps" ]; then
  drifted+=("package.json devDependencies")
fi

if [ ${#missing[@]} -gt 0 ]; then
  printf 'FAIL: the vendored tree carries files that no longer exist upstream:\n'
  printf '  %s\n' "${missing[@]}"
  printf 'Either restore them upstream or drop them here -- an unowned vendored file is maintained by nobody.\n'
  exit 1
fi

if [ ${#drifted[@]} -gt 0 ]; then
  printf 'FAIL: %d vendored file(s) differ from %s:\n' "${#drifted[@]}" "$source_dir"
  printf '  %s\n' "${drifted[@]}"
  printf 'Changes belong upstream first, then re-vendor and update %s.\n' "$provenance"
  exit 1
fi

echo "PASS: the vendored suite matches ${source_dir}"
