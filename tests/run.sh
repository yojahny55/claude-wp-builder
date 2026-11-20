#!/usr/bin/env bash
# Run the contract checks in tests/checks/*.sh in parallel and account for each honestly.
#
#   bash tests/run.sh                         every check, one job per core
#   bash tests/run.sh -j 4                    four at a time
#   bash tests/run.sh --exclude "a.sh b.sh"   skip these paths (space separated)
#   bash tests/run.sh tests/checks/x.sh ...   only these (any path, not just tests/checks)
#
# Every check runs, then the run reports. Exiting on the first red would hand back one
# defect per round trip -- a PR that broke three contracts would take three pushes to
# discover it broke three contracts. Exits 1 if any check failed.
#
# Each check's output goes to a temp dir and is classified from its exit status and text:
#   exit != 0                                        FAIL
#   exit 0 and a line starting with SKIP, or any     SKIP
#     line containing "NOT exercised"
#   anything else                                    PASS
#
# Exit 0 is not the same fact as "this check measured something". Checks take a skip path
# when an optional dependency is absent -- wp-polylang-live.sh without PLL_TEST_SITE,
# craft-kit-sync.sh without the kit, wp-library.sh without the MCP corpus, and the browser
# checks without a browser, which print "PASS (static only -- ... NOT exercised ...)" --
# and each used to exit 0 and be counted in PASS. The aggregate then read as full coverage
# while some of it had not run. They are legitimately optional, so this does not fail the
# run; it separates the count, so "118 passed" cannot quietly mean 115 passed and 3
# declined. A job that must have a browser says so with CHECKS_REQUIRE_BROWSER=1, which
# turns those checks' skip path into a failure.
#
# CI passes --exclude for the checks owned by their own jobs, which give them the
# WordPress and the browser they need. Running them in the aggregate too would execute them
# a second time per CI run -- and worse, the aggregate has neither, so each would take its
# skip path, exit 0 and be counted as a pass. See the skip_here note in ci.yml.
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1

jobs_n=$(nproc 2>/dev/null || echo 2)
exclude=""
files=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    -j) jobs_n=${2:?-j needs a number}; shift 2 ;;
    -j*) jobs_n=${1#-j}; shift ;;
    --exclude) exclude=${2-}; shift 2 ;;
    --exclude=*) exclude=${1#--exclude=}; shift ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    -*) printf 'run.sh: unknown option %s\n' "$1" >&2; exit 2 ;;
    *) files+=("$1"); shift ;;
  esac
done
case "$jobs_n" in ''|*[!0-9]*|0) printf 'run.sh: -j needs a positive number\n' >&2; exit 2 ;; esac
[ "${#files[@]}" -gt 0 ] || files=(tests/checks/*.sh)

selected=()
for f in "${files[@]}"; do
  case " $exclude " in *" $f "*) continue ;; esac
  selected+=("$f")
done
[ "${#selected[@]}" -gt 0 ] || { printf 'run.sh: no checks to run\n' >&2; exit 2; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

run_one() {
  local i=$1 f=$2 t0 t1 rc
  t0=${EPOCHREALTIME//[.,]/}
  bash "$f" >"$work/$i.out" 2>&1 </dev/null
  rc=$?
  t1=${EPOCHREALTIME//[.,]/}
  printf '%s\n' "$rc" >"$work/$i.rc"
  printf '%s\n' "$(( (t1 - t0) / 1000 ))" >"$work/$i.ms"
}

start=${EPOCHREALTIME//[.,]/}
i=0
for f in "${selected[@]}"; do
  # Hold at -j jobs in flight; wait -n returns as soon as any one finishes.
  while [ "$(jobs -rp | wc -l)" -ge "$jobs_n" ]; do wait -n 2>/dev/null || true; done
  run_one "$i" "$f" &
  i=$((i + 1))
done
wait
end=${EPOCHREALTIME//[.,]/}

pass=0; failed=(); skipped=(); times=()
for i in "${!selected[@]}"; do
  f=${selected[$i]}
  rc=$(cat "$work/$i.rc" 2>/dev/null || echo 1)
  ms=$(cat "$work/$i.ms" 2>/dev/null || echo 0)
  if [ "$rc" -ne 0 ]; then
    failed+=("$i")
  elif grep -Eq '^SKIP|NOT exercised' "$work/$i.out"; then
    skipped+=("$i")
  else
    pass=$((pass + 1))
  fi
  times+=("$ms $f")
done

secs() { printf '%d.%01ds' "$(($1 / 1000))" "$((($1 % 1000) / 100))"; }

for i in "${failed[@]}"; do
  f=${selected[$i]}
  if [ -n "${GITHUB_ACTIONS:-}" ]; then printf '::group::FAIL %s\n' "$f"; else printf '== FAIL %s\n' "$f"; fi
  tail -30 "$work/$i.out"
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    printf '::endgroup::\n'
    printf '::error file=%s::%s failed\n' "$f" "$f"
  fi
done

printf '\nslowest:\n'
printf '%s\n' "${times[@]}" | sort -rn | head -5 | while read -r ms f; do
  printf '  %8s  %s\n' "$(secs "$ms")" "$f"
done

printf '\nPASS=%d SKIP=%d FAIL=%d  (%s wall, -j %d)\n' "$pass" "${#skipped[@]}" "${#failed[@]}" \
  "$(secs $(((end - start) / 1000)))" "$jobs_n"
if [ "${#skipped[@]}" -gt 0 ]; then
  printf 'skipped checks (optional dependency absent, NOT counted as passing):\n'
  for i in "${skipped[@]}"; do printf '  %s  (%s)\n' "${selected[$i]}" "$(secs "$(cat "$work/$i.ms")")"; done
fi
if [ "${#failed[@]}" -gt 0 ]; then
  printf 'failing checks:\n'
  for i in "${failed[@]}"; do printf '  %s  (%s)\n' "${selected[$i]}" "$(secs "$(cat "$work/$i.ms")")"; done
  exit 1
fi
