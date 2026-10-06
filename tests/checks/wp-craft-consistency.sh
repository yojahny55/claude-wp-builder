#!/usr/bin/env bash
# wp-demo-craft: the references must agree with each other and with the code they
# describe. Every assertion here is a contradiction that shipped:
#
# - design-md.md defaulted --motion-rise to 22px while devices.md called anything under
#   ~35px invisible and every composition fell back to 44px.
# - devices.md offered a `cascade` device motion.js never implemented (a silent no-op),
#   and its "attribute contract, exactly as declared" omitted data-motion-peak and
#   data-motion-rail, both of which the engine reads.
# - taste.md told authors to use --space-1..11, --font-measure, --shadow-e1/2/3,
#   --transition-ease-out and .scrim--lead/--trail, none of which exist anywhere; and two
#   compositions read a --color-muted no DESIGN.md defines. An undefined var() is invalid
#   at computed-value time and fails silently.
# - devices.md said a signature move is not required while uniqueness.md and /wp-demo
#   require one.
# - process-rail put its heading inside the pan rail, the exact advice devices.md retracts
#   because it pans the section's label off screen.
# - the scroll budget was written three ways (devices.md, "8-14vh", "8 to 14
#   viewport-heights") while SKILL.md calls devices.md the only place it is written.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

R=skills/wp-demo-craft/references
C=skills/wp-demo-craft/compositions
M=starter-theme/__tailwind__/assets/js/src/motion.js
for f in "$R/design-md.md" "$R/devices.md" "$R/taste.md" "$R/feel.md" "$R/uniqueness.md" \
         "$R/compositions.md" "$C/README.md" "$M"; do
  [ -f "$f" ] || fail "$f is missing"
done

# --- the token set: design-md.md's names, plus what the engine publishes -----------
tokens=$(grep -oE '`--[a-z0-9-]+`' "$R/design-md.md" | tr -d '`' | sort -u)
[ "$(printf '%s\n' "$tokens" | wc -l)" -ge 16 ] || fail "$R/design-md.md no longer lists the token set"
allowed=$(printf '%s\n--motion-p\n--motion-mx\n--motion-my\n' "$tokens")

# taste.md names only tokens that exist.
for t in $(grep -oE '`--[a-z0-9-]+' "$R/taste.md" | tr -d '`' | sort -u); do
  printf '%s\n' "$allowed" | grep -Fxq -- "$t" || fail "$R/taste.md tells the author to use $t, which no DESIGN.md or engine defines"
done
grep -Fq 'engine already switches' "$R/taste.md" && fail "$R/taste.md claims an engine behaviour no engine has"
for cls in $(grep -oE '\.scrim--[a-z]+|\.grain\b' "$R/taste.md" | sort -u); do
  grep -rqF -- "${cls#.}" "$C" || fail "$R/taste.md names $cls, which no composition defines"
done

# Every composition var() with no fallback resolves: a token, an engine value, or a
# property the same file declares.
for css in "$C"/*/section.css; do
  for t in $(grep -oE 'var\(--[a-z0-9-]+\)' "$css" | sed 's/^var(//; s/)$//' | sort -u); do
    printf '%s\n' "$allowed" | grep -Fxq -- "$t" && continue
    grep -Eq -- "(^|[;{[:space:]])$t[[:space:]]*:" "$css" && continue
    fail "$css reads var($t) with no fallback, and no DESIGN.md defines it"
  done
done

# --- --motion-rise: one default, above the amplitude floor -------------------------
rise=$(grep -E '^\| `--motion-rise` \|' "$R/design-md.md" | grep -oE '`[0-9]+px`' | tr -d '`px')
[ -n "$rise" ] || fail "$R/design-md.md has no --motion-rise default row"
[ "$rise" -ge 35 ] || fail "$R/design-md.md defaults --motion-rise to ${rise}px, under the ~35px floor devices.md calls invisible"
fallback=$(grep -rhoE 'var\(--motion-rise, *[0-9]+px\)' "$C"/*/section.css | grep -oE '[0-9]+' | sort | uniq -c | sort -rn | awk 'NR==1{print $2}')
[ "$rise" = "$fallback" ] || fail "$R/design-md.md defaults --motion-rise to ${rise}px but the compositions fall back to ${fallback}px"

# --- the attribute contract matches the engine, both directions ---------------------
contract=$(awk '/^```/{n++; next} n==1' "$R/devices.md")
for a in $(grep -oE 'data-motion-[a-z]+' "$M" | sort -u); do
  printf '%s\n' "$contract" | grep -Fq -- "$a" || fail "motion.js reads $a but the devices.md attribute contract omits it"
done
for a in $(printf '%s\n' "$contract" | grep -oE 'data-motion-[a-z]+' | sort -u); do
  grep -Fq -- "$a" "$M" || fail "devices.md declares $a, which motion.js never reads"
done
engine=$( { grep -oE "kind === '[a-z]+'" "$M" | grep -oE "'[a-z]+'"; grep -oE 'data-motion="[a-z]+"' "$M" | grep -oE '"[a-z]+"'; } | tr -d "'\"" | sort -u)
declared=$(printf '%s\n' "$contract" | grep -oE 'data-motion="[a-z|]+"' | head -1 | tr -d '"' | sed 's/^data-motion=//' | tr '|' '\n' | sort -u)
[ "$engine" = "$declared" ] || fail "the devices.md data-motion list ($(echo $declared)) does not match the devices motion.js binds ($(echo $engine))"
# The interior-page floor offers only devices that exist (count is dispatched by its attribute).
floor=$(awk '/scroll-reactive device that is not/{p=1} p{print} /All of them cost/{exit}' "$R/devices.md")
for d in $(printf '%s\n' "$floor" | grep -oE '`[a-z]+`' | tr -d '`' | sort -u); do
  [ "$d" = count ] && continue
  printf '%s\n' "$engine" | grep -Fxq "$d" || fail "devices.md offers \`$d\` as a scroll-reactive device; motion.js does not implement it, so it is a silent no-op"
done
grep -Fq 'The eight devices' "$R/devices.md" && fail "devices.md heads its device list with a count that does not match it"

# demo-verify's static-page gate decides "something here reacts to scrolling" from its own
# list of names, and kept `cascade` after the contract dropped it: a page carrying
# data-motion="cascade" passed the gate while nothing on it moved. Its set must be devices
# motion.js implements -- `count` by the attribute motion.js dispatches it on, which the
# gate must read too -- and must be the floor above, not a second opinion on it.
V=bin/demo-verify.mjs
sr=$(grep -oE 'SCROLL_REACTIVE_DEVICES = new Set\(\[[^]]*\]\)' "$V" | grep -oE "'[a-z]+'" | tr -d "'" | sort -u)
[ -n "$sr" ] || fail "$V has no recognisable SCROLL_REACTIVE_DEVICES set -- this check would be vacuous"
for d in $sr; do
  if [ "$d" = count ]; then
    grep -Fq "querySelectorAll('[data-motion-count]')" "$M" \
      || fail "$V counts \`count\` as scroll-reactive, but motion.js no longer dispatches it on data-motion-count"
    grep -Fq "querySelectorAll('[data-motion-count]')" "$V" \
      || fail "$V counts \`count\` as scroll-reactive but never reads data-motion-count, the attribute motion.js dispatches it on"
    continue
  fi
  printf '%s\n' "$engine" | grep -Fxq "$d" \
    || fail "$V counts \`$d\` as scroll-reactive; motion.js does not implement it, so a page carrying it passes static-page with nothing moving"
done
want=$(printf '%s\n' "$floor" | grep -oE '`[a-z]+`' | tr -d '`' | grep -vx reveal | sort -u)
[ "$sr" = "$want" ] \
  || fail "$V's scroll-reactive set ($(echo $sr)) is not the devices.md interior floor ($(echo $want))"

# --- the signature move is required, in every file that mentions it ------------------
grep -Fq 'Every build invents one bespoke interaction' "$R/uniqueness.md" \
  || fail "$R/uniqueness.md no longer requires the signature move"
grep -Fq 'does not require one' "$R/devices.md" && fail "devices.md says the signature move is optional; uniqueness.md and /wp-demo require it"
grep -Fq '`uniqueness.md` §4) usually lives inside it' "$R/feel.md" \
  || fail "feel.md does not point at uniqueness.md §4 for the signature move"
tr '\n' ' ' < "$R/feel.md" | grep -Fq '(defined in `devices.md`)' \
  && fail "feel.md sends the reader to devices.md for the signature move"

# --- process-rail keeps its heading out of the rail ---------------------------------
pr="$C/process-rail/section.html"
awk '/data-motion-rail/{p=1} p{print} /<\/ol>/{p=0}' "$pr" | grep -q '<h2' \
  && fail "$pr puts the section heading inside the pan rail, which pans the label off screen (devices.md, pan)"
grep -q '<h2' "$pr" || fail "$pr has no section heading"
n=$(grep -c 'class="process-rail__step"' "$pr")
[ "$n" -ge 5 ] || fail "$pr carries $n steps; devices.md says pan needs five items or more"
grep -Fq 'needs five items or more' "$R/devices.md" || fail "devices.md lost the pan item minimum process-rail is held to"
grep -Fq 'five steps or more' "$C/process-rail/README.md" || fail "process-rail/README.md does not state the five-step minimum"
grep -Fq 'fewer than three' "$C/process-rail/README.md" && fail "process-rail/README.md still allows a three-step rail"

# --- the budget is written once -----------------------------------------------------
grep -Eq '8-14vh|8 to 14 viewport' "$R/taste.md" "$R/feel.md" \
  && fail "taste.md or feel.md restates the scroll budget with its own number; devices.md is the one place it is written"
grep -Fq 'four viewport-heights' "$R/compositions.md" \
  && fail "compositions.md restates the budget; devices.md is the one place it is written"

# --- pointers that pointed nowhere, and counts that were wrong ----------------------
grep -Fq '§10' "$R/taste.md" && fail "taste.md points at a devices.md §10 that does not exist"
grep -Fq 'pre-build checks in SKILL.md' "$R/feel.md" && fail "feel.md points at SKILL.md pre-build checks that do not exist"
grep -Fq 'Span 3+' "$R/feel.md" && fail "feel.md's pacing table allows a pin over devices.md's 3.0 cap"
grep -Fq '57 of the 67' "$R/design-md.md" && fail "design-md.md carries a catalogue count that was wrong"
grep -Fq 'Ten of the thirteen' "$R/compositions.md" && fail "compositions.md carries a composition count that was wrong"

# --- the role table: one row per line -------------------------------------------------
awk '/^\| role \| composition/{p=1} p && /^\|/{ n=gsub(/\|/,"|"); if (n != 6) { print NR; exit 1 } } p && !/^\|/{exit}' "$C/README.md" >/dev/null \
  || fail "$C/README.md's role table has a line that is not exactly one row"

# --- plugin paths are never relative --------------------------------------------------
grep -rn --include=*.md 'node bin/' skills/wp-demo-craft | grep -v '/references/design-md/' \
  && fail "a craft file runs a plugin script by a relative path; use \${CLAUDE_PLUGIN_ROOT}/bin/"
grep -Eq '(^|[^/])skills/wp-demo-craft/' commands/wp-polish.md \
  && fail "commands/wp-polish.md names a craft file by a relative path"

echo PASS
