#!/usr/bin/env bash
# design-md-index.sh and domains-import.sh must never leave a versioned file
# truncated when python or awk fails midway; design-md-index.sh matches `api` and
# `car` as whole words; composition-gate.sh fails on a composition with a missing
# fragment. Everything runs on a temporary copy, never on the real tree, and
# without the network (a stub git stands in for the upstream fetch).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

mk_tree() { # $1 = dir
  mkdir -p "$1/bin" "$1/skills/wp-demo-craft/references/domains" "$1/skills/wp-demo-craft/references/design-md"
  cp "$ROOT/bin/design-md-index.sh" "$ROOT/bin/domains-import.sh" "$ROOT/bin/composition-gate.sh" "$1/bin/"
}

# A failing python3/awk placed first on PATH. Everything else resolves normally.
mkdir "$T/failbin"
for n in python3 awk; do printf '#!/bin/sh\necho "stub %s failure" >&2\nexit 1\n' "$n" > "$T/failbin/$n"; chmod +x "$T/failbin/$n"; done

# A stub git that fakes the upstream checkout: init/fetch/checkout/rev-parse only.
mkdir "$T/gitbin"
cat > "$T/gitbin/git" <<'GIT'
#!/bin/bash
if [ "$1" = init ]; then mkdir -p "${@: -1}"; exit 0; fi
if [ "$1" = -C ]; then
  dir="$2"; shift 2
  case "$1" in
    fetch) exit 0 ;;
    checkout)
      mkdir -p "$dir/src/ui-ux-pro-max/data"
      echo "licence text" > "$dir/LICENSE"
      printf 'Product Type,Keywords,Landing Page Pattern,Key Considerations,Primary Style Recommendation\nSaaS,"a,b",hero,none,Flat\n' > "$dir/src/ui-ux-pro-max/data/products.csv"
      echo '{"records":[]}' > "$dir/src/ui-ux-pro-max/data/data-provenance.json"
      exit 0 ;;
    rev-parse) echo 0123456789abcdef; exit 0 ;;
  esac
fi
exit 1
GIT
chmod +x "$T/gitbin/git"

# --- domains-import.sh: a python failure leaves SOURCE.txt, LICENSE, domains.csv intact
W="$T/di"; mk_tree "$W"
D="$W/skills/wp-demo-craft/references/domains"
echo "OLD-CSV" > "$D/domains.csv"; echo "OLD-SRC" > "$D/SOURCE.txt"; echo "OLD-LIC" > "$D/LICENSE"
if PATH="$T/failbin:$T/gitbin:$PATH" bash "$W/bin/domains-import.sh" >/dev/null 2>&1; then fail "domains-import succeeded with failing python3"; fi
[ "$(cat "$D/domains.csv")" = OLD-CSV ] || fail "domains.csv changed after a mid-run failure"
[ "$(cat "$D/SOURCE.txt")" = OLD-SRC ] || fail "SOURCE.txt changed after a mid-run failure"
[ "$(cat "$D/LICENSE")" = OLD-LIC ] || fail "LICENSE changed after a mid-run failure"
[ -z "$(find "$D" -name '.*.new' -o -name '.*XXXXXX' | sed -n 1p)" ] || fail "temp files left behind in domains/"
# and the success path still writes all three
PATH="$T/gitbin:$PATH" bash "$W/bin/domains-import.sh" >/dev/null 2>&1 || fail "domains-import failed on the happy path"
[ "$(sed -n 1p "$D/domains.csv")" = "domain,keywords,page_pattern,considerations,confidence" ] || fail "domains.csv not rebuilt"
[ "$(cat "$D/LICENSE")" = "licence text" ] || fail "LICENSE not refreshed"
grep >/dev/null -c '^Commit: 0123456789abcdef' "$D/SOURCE.txt" || fail "SOURCE.txt not refreshed"

# --- design-md-index.sh: an awk failure leaves INDEX.md intact
W="$T/ix"; mk_tree "$W"
X="$W/skills/wp-demo-craft/references/design-md"
mkdir -p "$X/apiish" "$X/cardco" "$X/carco" "$X/rapidco"
dm() { printf -- '---\ndescription: %s\ncolors:\n  primary: "#123456"\n  canvas: "#ffffff"\n---\n' "$2" > "$X/$1/DESIGN.md"; }
dm apiish "Docs for the public API"
dm cardco "Credit card rewards, rapid capital, careful care"
dm carco "Used car dealer"
dm rapidco "Rapid capital"
echo "OLD-INDEX" > "$X/INDEX.md"
if PATH="$T/failbin:$PATH" bash "$W/bin/design-md-index.sh" >/dev/null 2>&1; then fail "design-md-index succeeded with failing awk"; fi
[ "$(cat "$X/INDEX.md")" = OLD-INDEX ] || fail "INDEX.md changed after a mid-run failure"
[ -z "$(find "$X" -maxdepth 1 -name '.INDEX.md.*' | sed -n 1p)" ] || fail "temp file left behind in design-md/"
bash "$W/bin/design-md-index.sh" >/dev/null 2>&1 || fail "design-md-index failed on the happy path"
row() { grep "^| $1 |" "$X/INDEX.md"; }
[ "$(row apiish | cut -d'|' -f3 | tr -d ' ')" = devtools ] || fail "whole-word api not matched"
[ "$(row carco | cut -d'|' -f3 | tr -d ' ')" = automotive ] || fail "whole-word car not matched"
[ "$(row cardco | cut -d'|' -f3 | tr -d ' ')" = general ] || fail "card/care/capital/rapid matched car or api"
[ "$(row rapidco | cut -d'|' -f3 | tr -d ' ')" = general ] || fail "rapid matched api"

# --- composition-gate.sh: a composition missing a fragment fails (exit 1), offline
W="$T/cg"; mk_tree "$W"
C="$W/comps"; mkdir -p "$C/good" "$C/nohtml" "$C/nocss"
head -c 400 /dev/zero | tr '\0' 'a' > "$C/good/section.html"; head -c 400 /dev/zero | tr '\0' 'a' > "$C/good/section.css"
head -c 400 /dev/zero | tr '\0' 'a' > "$C/nohtml/section.css"
head -c 400 /dev/zero | tr '\0' 'a' > "$C/nocss/section.html"
set +e
out=$(COMPS_DIR="$C" bash "$W/bin/composition-gate.sh" 2>&1); rc=$?
set -e
[ "$rc" -eq 1 ] || fail "composition-gate exit $rc, expected 1, with missing fragments"
case "$out" in *nohtml*) ;; *) fail "nohtml not named in the refusal" ;; esac
case "$out" in *nocss*) ;; *) fail "nocss not named in the refusal" ;; esac

echo PASS
