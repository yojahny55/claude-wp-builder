#!/usr/bin/env bash
set -euo pipefail
# /wp-init must never offer a starter template whose directory is missing.
#
# This existed as a documented "Known gap" for months: __starter__ was removed
# in 3600552 as superseded by Tailwind, but wp-init kept offering "Basic
# Starter" as option 1 AND as the Enter-key default -- so the single most
# likely path through the command copied a directory that is not there.
# A grep-for-the-wording check would not have caught it; this compares the
# command against the filesystem.
. tests/checks/lib/expand-command.sh; expand_command commands/wp-init.md; cmd=$EXPANDED
test -f "$cmd" || { echo "FAIL: $cmd missing"; exit 1; }

# Every `cp -r .../starter-theme/<x>/` target must exist. Scoped to actual cp
# lines: prose may legitimately NAME a removed starter while explaining why it
# is gone, and failing on that would punish the documentation.
targets=$(grep -E '^\s*cp -r ' "$cmd" | grep -oP 'starter-theme/\K__[a-z]+__(?=/)' | sort -u)
[[ -n "$targets" ]] || { echo "FAIL: wp-init copies no starter theme at all -- this check would be vacuous"; exit 1; }

for t in $targets; do
  [[ -d "starter-theme/$t" ]] || {
    echo "FAIL: /wp-init copies starter-theme/$t/, which does not exist"
    echo "      present: $(ls -d starter-theme/__*__ 2>/dev/null | xargs -n1 basename | tr '\n' ' ')"
    exit 1
  }
done

# Whatever the Enter-key default is, it must resolve to a real directory too.
default=$(grep -oP '^Default: `\K[a-z]+' "$cmd" | head -1)
[[ -n "$default" ]] || { echo "FAIL: no template default declared in $cmd"; exit 1; }
case "$default" in
  tailwind)  d=starter-theme/__tailwind__ ;;
  cinematic) d=starter-theme/__cinematic__ ;;
  *)         echo "FAIL: template default '$default' maps to no known starter directory"; exit 1 ;;
esac
[[ -d "$d" ]] || { echo "FAIL: the default template '$default' points at $d, which does not exist"; exit 1; }

# --- Placeholder tokens: a starter may only use what /wp-init Step 4 replaces. ---
# The cinematic starter shipped __TEXTDOMAIN__ and __VERSION__, which Step 4 never
# replaced, so every generated cinematic theme carried the literal tokens in its
# style.css, functions.php and nav. The allowed set is read from Step 4's own
# numbered list, so adding a replacement there widens it and nothing else does.
allowed=$(sed -n '/^## Step 4: Replace All Placeholders/,/^## Step 4\.5/p' "$cmd" \
  | grep -oP '^\d+\. `\K__[A-Za-z_]+?__(?=` )' | sort -u)
[[ $(grep -c . <<<"$allowed") -ge 4 ]] || { echo "FAIL: could not read the placeholder list from /wp-init Step 4 (got: $allowed)"; exit 1; }
# __cinematic__ and __tailwind__ are the starter directory names, not placeholders.
magic='__DIR__|__FILE__|__LINE__|__NAMESPACE__|__CLASS__|__FUNCTION__|__METHOD__|__TRAIT__|__COMPILER_HALT_OFFSET__|__cinematic__|__tailwind__'
strip=$(printf '%s\n' $allowed | sed 's/.*/s#&##g/' | paste -sd';')
while IFS= read -r f; do
  left=$(sed -E "$strip" "$f" | grep -oE "__[A-Za-z][A-Za-z_]*__" | grep -Ev "^($magic)$" | sort -u | tr '\n' ' ' || true)
  [[ -z "$left" ]] || { echo "FAIL: $f uses placeholder(s) /wp-init Step 4 never replaces: $left"; exit 1; }
done < <(grep -rIl . starter-theme --exclude-dir=node_modules --exclude-dir=vendor)

# --- /wp-init flag intake: /wp-cinematic-init hands off through these flags. ---
# The hand-off passed --mode/--starter/--acf-flavor/--path that /wp-init parsed none of,
# so it re-asked the template (and could dispatch back to /wp-cinematic-init, a loop),
# and the hybrid flag was spelled --hybrid in one file and --no-hybrid in the other.
for flag in '--path=' '--mode=cinematic' '--starter=__cinematic__' '--acf-flavor=' '--no-hybrid'; do
  grep -Fq -- "$flag" <<<"$(sed -n '/^## Step 0\.4: Flag intake/,/^## Step 0\.5/p' "$cmd")" \
    || { echo "FAIL: /wp-init Step 0.4 flag intake does not parse $flag"; exit 1; }
  grep -Fq -- "$flag" <(sed -n '/^argument-hint:/p' commands/wp-init.md) || { echo "FAIL: wp-init argument-hint lacks $flag"; exit 1; }
done
grep -Fq 'Skip this step when Step 0.4 preset `$TEMPLATE`' "$cmd" || { echo "FAIL: Step 0.5 is not skipped when the template is preset"; exit 1; }
grep -Fq 'Skip this step when Step 0.4 preset `$CF_PLUGIN`' "$cmd" || { echo "FAIL: Step 0.6 is not skipped when the plugin is preset"; exit 1; }
grep -Fq 'do NOT dispatch to it again' "$cmd" || { echo "FAIL: /wp-init lost the no-redispatch rule for --mode=cinematic"; exit 1; }
ci=commands/wp-cinematic-init.md
grep -Fq -- '/wp-init --path=<path> --mode=cinematic' "$ci" || { echo "FAIL: $ci does not hand off with the flags /wp-init parses"; exit 1; }
! grep -Fq -- '--starter=__cinematic__ --acf' "$ci" || { echo "FAIL: $ci still passes the redundant --starter flag"; exit 1; }
! grep -Eq -- '^  - name: --hybrid$' "$ci" || { echo "FAIL: $ci still declares --hybrid; the one spelling is --no-hybrid"; exit 1; }
grep -Fq -- '- name: --no-hybrid' "$ci" || { echo "FAIL: $ci does not declare --no-hybrid"; exit 1; }

# Caller markers, conditional --acf-flavor, and no double work in the caller-entered branch.
fi=skills/wp-init-run/references/flag-intake.md
! grep -Eq -- '^\| `--mode=cinematic`, `--starter=__cinematic__` or `--template=cinematic`' "$fi" || { echo "FAIL: $fi lists --template=cinematic as a caller marker"; exit 1; }
grep -Fq -- '`--template=cinematic` | Presets `$TEMPLATE = cinematic` only' "$fi" || { echo "FAIL: $fi does not say --template=cinematic marks no caller"; exit 1; }
grep -Fq -- 'add `--acf-flavor=<value>` only when it was passed here' "$ci" || { echo "FAIL: $ci passes --acf-flavor unconditionally"; exit 1; }
! grep -Fq -- '--acf-flavor=<scf|acf-pro>)' "$ci" || { echo "FAIL: $ci hands off a mandatory --acf-flavor"; exit 1; }
grep -Fq -- 'empty `--acf-flavor=` counts as absent' "$fi" || { echo "FAIL: $fi does not treat an empty --acf-flavor as absent"; exit 1; }
grep -Fq -- '`/wp-init` returns here; continue with Step 2' "$ci" || { echo "FAIL: $ci Step 1 does not say /wp-init returns"; exit 1; }
! grep -Fq -- 'dispatches to step 2 below' "$ci" || { echo "FAIL: $ci still says /wp-init dispatches to step 2"; exit 1; }
branch=$(sed -n '/^### If `\$TEMPLATE = cinematic`/,/^## Step 0\.6/p' "$cmd")
grep -Fq -- 'belong to the caller' <<<"$branch" || { echo "FAIL: /wp-init caller-entered branch does not leave agent/seed to the caller"; exit 1; }
! grep -Eq -- '^[0-9]\. .*(Run the `wp-cinematic` agent|/wp-cinematic-seed)' <<<"$branch" || { echo "FAIL: /wp-init cinematic branch still runs the wp-cinematic agent/seed"; exit 1; }

# Dispatch flags, caller-mode Step 10, and no literal scene/hybrid values in the agent payload.
grep -Fq -- '/wp-cinematic-init --path=${PROJECT_PATH}' <<<"$branch" || { echo "FAIL: /wp-init dispatch to /wp-cinematic-init does not pass --path"; exit 1; }
grep -Fq -- '`--no-hybrid` when given' <<<"$branch" || { echo "FAIL: /wp-init dispatch does not forward --no-hybrid"; exit 1; }
step10=$(sed -n '/^## Step 10/,$p' "$cmd")
grep -Fq -- '**Entered with `--mode=cinematic`' <<<"$step10" || { echo "FAIL: /wp-init Step 10 has no caller-mode wording"; exit 1; }
grep -Fq -- '/wp-cinematic-init --path=<path>`' <<<"$step10" || { echo "FAIL: /wp-init Step 10 has no /wp-cinematic-init --path recovery line"; exit 1; }
! grep -Fq -- '"scene_count": 9' "$ci" || { echo "FAIL: $ci hard-codes scene_count 9"; exit 1; }
! grep -Fq -- '"hybrid": true' "$ci" || { echo "FAIL: $ci hard-codes hybrid true"; exit 1; }
grep -Fq -- '<false when --no-hybrid was passed, else true>' "$ci" || { echo "FAIL: $ci hybrid does not follow --no-hybrid"; exit 1; }

# --- The cinematic starter must be an activatable classic theme. ---
for f in index page single 404; do
  [[ -f starter-theme/__cinematic__/$f.php ]] || { echo "FAIL: starter-theme/__cinematic__/$f.php missing (WordPress refuses a theme without index.php)"; exit 1; }
done
grep -Rqn "templates/cinematic.php" starter-theme/__cinematic__ && { echo "FAIL: the cinematic starter references templates/cinematic.php, which it does not ship"; exit 1; }

echo PASS
