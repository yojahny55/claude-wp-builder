#!/usr/bin/env bash
# Mutation pass over the contract checks. A manual / optional-CI tool, NOT a check.
#
#   bash tests/mutation.sh                     15 checks, seed 1
#   bash tests/mutation.sh -n 30 -s 7          bigger sample, another seed
#   bash tests/mutation.sh -c "a.sh b.sh"      only these checks (names under tests/checks/)
#
# Most checks are `need FILE "token"` greps over commands/, agents/ and skills/. A grep that
# also matches a comment or another file keeps passing when the contract wording is gone,
# and nothing says so. For each sampled check this copies the repo to a temp dir (the real
# tree is never touched), deletes the first line holding one token the check requires, and
# expects the check to FAIL on the copy. A check that still passes is a survivor: a mutant it
# does not detect. One mutant per check; the token is picked by the seed, so a run repeats.
# Only checks whose `need()` takes (file, token) and calls with a literal path and a plain
# quoted token are eligible. Exit 0 when nothing survived, 1 otherwise, 2 on bad usage.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2
root=$PWD

n=15 seed=1 only=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -n) n=${2:-}; shift 2 ;;
    -s) seed=${2:-}; shift 2 ;;
    -c) only=${2:-}; shift 2 ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "mutation.sh: unknown option $1" >&2; exit 2 ;;
  esac
done
case "$n$seed" in ''|*[!0-9]*) echo "mutation.sh: -n and -s need numbers" >&2; exit 2 ;; esac

# Helpers of the form `name() { grep ... "$2" "$1" ...}` (file, token) or `"$1" "$2"` (token,
# file). Prints "<name> <order>" with order f (file first) or t (token first).
helpers_of() {
  grep -E '^(need|has|inc)[[:space:]]*\(\)' "$1" \
    | awk '{ n=$1; sub(/[[:space:]]*\(.*/, "", n)
             if ($0 ~ /grep[^|;]*"\$2"[^|;]*"\$1"/) print n, "f"
             else if ($0 ~ /grep[^|;]*"\$1"[^|;]*"\$2"/) print n, "t" }'
}
# Literal `<helper> <path> "<token>"` calls: prints "<path><TAB><token>".
mutants_of() {
  local name order a b
  while read -r name order; do
    grep -E "^[[:space:]]*${name}[[:space:]]+(\"?[A-Za-z0-9_./-]+\"?[[:space:]]+(\".+\"|'.+')|(\".+\"|'.+')[[:space:]]+\"?[A-Za-z0-9_./-]+\"?)[[:space:]]*(\|\||$)" "$1" \
      | sed -E "s/^[[:space:]]*${name}[[:space:]]+//; s/[[:space:]]*(\|\|.*)?\$//" \
      | while IFS= read -r rest; do
          if [ "$order" = f ]; then
            a=${rest%%[[:space:]]*}; b=${rest#*[[:space:]]}
          else
            a=${rest##*[[:space:]]}; b=${rest%[[:space:]]*}
          fi
          a=${a#\"}; a=${a%\"}
          case "$b" in \"*\") b=${b#\"}; b=${b%\"} ;; \'*\') b=${b#\'}; b=${b%\'} ;; *) continue ;; esac
          case "$b" in *'$'*|*'`'*|*'\\'*|*'"'*|'') continue ;; esac
          case "$a" in */*) printf '%s\t%s\n' "$a" "$b" ;; esac
        done
  done < <(helpers_of "$1")
}
eligible() { [ -n "$(helpers_of "$1")" ]; }

all=()
if [ -n "$only" ]; then
  for c in $only; do all+=("$c"); done
else
  for f in tests/checks/*.sh; do
    b=$(basename "$f"); [ "$b" = mutation-harness.sh ] && continue
    eligible "$f" && [ -n "$(mutants_of "$f")" ] && all+=("$b")
  done
fi
[ "${#all[@]}" -gt 0 ] || { echo "mutation.sh: no eligible check" >&2; exit 2; }
mapfile -t picked < <(printf '%s\n' "${all[@]}" | LC_ALL=C sort | shuf --random-source=<(yes "$seed") | head -n "$n")

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
git ls-files -z -co --exclude-standard | tar --null -T - -cf - 2>/dev/null | tar -xf - -C "$tmp"

killed=0 survived=() skipped=0
for c in "${picked[@]}"; do
  mapfile -t ms < <(mutants_of "tests/checks/$c")
  if [ "${#ms[@]}" -eq 0 ]; then skipped=$((skipped + 1)); printf 'SKIP     %s (no literal need)\n' "$c"; continue; fi
  idx=$(( $(printf '%s-%s' "$seed" "$c" | cksum | cut -d' ' -f1) % ${#ms[@]} ))
  file=${ms[$idx]%%$'\t'*}; token=${ms[$idx]#*$'\t'}
  target=$tmp/$file
  # need paths are relative to the repo root, where the checks cd to.
  if [ ! -f "$target" ] || ! grep -nF -- "$token" "$target" >/dev/null; then
    skipped=$((skipped + 1)); printf 'SKIP     %s (%s / "%s" not in the copy)\n' "$c" "$file" "$token"; continue
  fi
  ln=$(grep -nF -- "$token" "$target" | sed -n 1p | cut -d: -f1)
  cp -p "$target" "$tmp/.orig"
  sed -i "${ln}d" "$target"
  if (cd "$tmp" && timeout 120 bash "tests/checks/$c" >/dev/null 2>&1); then
    survived+=("$c: deleting $file:$ln (token \"$token\") still passes")
    printf 'SURVIVED %s\n' "$c"
  else
    killed=$((killed + 1)); printf 'killed   %s\n' "$c"
  fi
  cp -p "$tmp/.orig" "$target"
done

printf '\nmutants: %d killed, %d survived, %d skipped (sample %d, seed %d)\n' "$killed" "${#survived[@]}" "$skipped" "${#picked[@]}" "$seed"
if [ "${#survived[@]}" -gt 0 ]; then printf 'survivors:\n'; printf '  %s\n' "${survived[@]}"; exit 1; fi
exit 0
