#!/usr/bin/env bash
# Menu locations: registration, assignment, verification and rendering must name the same
# locations, per i18n strategy, for both starters.
#
# What shipped: both starters registered and rendered `primary-<lang>` (hyphen), while
# /wp-init and /wp-header told the agent to register `primary_en` (underscore), /wp-seed
# assigned menus to `primary_en`/`footer_en` and /wp-finalize verified those names — so a
# suffix site's nav rendered nothing (`fallback_cb => false`), with HTTP 200 and no notice.
# Under polylang /wp-init registered a bare `primary` while the starter templates still
# asked for `primary-<lang>`: no nav on either language. Templates now ask
# `__starter___nav_location()` in inc/i18n.php, which each strategy's file answers.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/checks/lib/expand-command.sh; expand_command commands/wp-seed.md; wp_seed=$EXPANDED
. tests/checks/lib/expand-command.sh; expand_command commands/wp-finalize.md; wp_finalize=$EXPANDED
. tests/checks/lib/expand-command.sh; expand_command commands/wp-init.md; wp_init=$EXPANDED
fail() { echo "FAIL: $*"; exit 1; }
flat() { tr '\n' ' ' | sed 's/  */ /g'; }
words() { tr ' ' '\n' | sed '/^$/d' | sort -u | tr '\n' ' ' | sed 's/ $//'; }

# Region of a markdown file between two anchors; the whole file when the start anchor is
# gone, so a renamed heading widens the scope instead of muting the check.
region() { # <file> <start-regex> <end-regex>
  local out
  out=$(awk -v s="$2" -v e="$3" '$0 ~ s {f=1; next} f && $0 ~ e {exit} f {print}' "$1")
  [ -n "$out" ] && printf '%s\n' "$out" || cat "$1"
}

# --- 1. what each starter registers, renders, and what its i18n layer answers ----
declare -A REG=( [__tailwind__]=starter-theme/__tailwind__/inc/theme-setup.php
                 [__cinematic__]=starter-theme/__cinematic__/functions.php )
suffix_set=""
bases=""
for st in __tailwind__ __cinematic__; do
  f=${REG[$st]}
  reg=$(awk '/register_nav_menus\(/{f=1} f{print} f && /^ *(\)|\]);/{exit}' "$f" \
        | grep -oE "^ *'[a-z0-9_-]+' *=>" | grep -oE "[a-z0-9_-]+" | words)
  [ -n "$reg" ] || fail "$f registers no menu locations -- this check would be vacuous"
  for loc in $reg; do
    [[ $loc =~ ^[a-z]+-(en|es)$ ]] || fail "$st registers '$loc'; a suffix starter's locations are <location>-<lang>, hyphenated"
  done

  # Every theme_location in the starter goes through the helper -- never a literal or a
  # concatenation, which is right on one strategy and renders nothing on the other.
  lit=$(grep -rnE "'theme_location' *=> *['\"]|'(primary|footer)[-_]' *\." "starter-theme/$st" --include=*.php || true)
  [ -z "$lit" ] || fail "$st builds a menu location by hand instead of asking __starter___nav_location():"$'\n'"$lit"

  # On tailwind, header.php and footer.php are placeholders that /wp-header and /wp-footer
  # replace, so what those two prompts render counts as rendered there too.
  srcs=("starter-theme/$st")
  [ "$st" = __tailwind__ ] && srcs+=(commands/wp-header.md commands/wp-footer.md)
  rendered=$(grep -rhoE "nav_location\( *'[a-z]+' *\)" "${srcs[@]}" --include=*.php --include=*.md \
             | grep -oE "'[a-z]+'" | tr -d "'" | words)
  [ -n "$rendered" ] || fail "no $st template asks __starter___nav_location() for a location"
  st_bases=$(printf '%s\n' $reg | sed 's/-[a-z]*$//' | words)
  [ "$rendered" = "$st_bases" ] \
    || fail "$st renders locations [$rendered] but registers [$st_bases] -- a registered location nothing renders is an empty slot in wp-admin, a rendered one nothing registers is no menu"

  # What the helper actually returns, on each strategy, for each rendered base.
  if command -v php >/dev/null 2>&1; then
    for base in $rendered; do
      for lang in en es; do
        got=$(php tests/checks/lib/nav-location.php "starter-theme/$st/inc/i18n.php" "$lang" "$base") \
          || fail "$st inc/i18n.php: $got"
        [ "$got" = "$base-$lang" ] || fail "$st's suffix nav_location('$base') answers '$got' on ?lang=$lang, not the registered '$base-$lang'"
        got=$(php tests/checks/lib/nav-location.php "starter-theme/_i18n-variants/$st.php" "$lang" "$base") \
          || fail "$st Polylang variant: $got"
        [ "$got" = "$base" ] || fail "$st's Polylang nav_location('$base') answers '$got', not the bare '$base' that strategy registers"
      done
    done
  else
    echo "SKIP: php not found -- the helpers' answers were not run, only grepped"
    grep -qF "return \$location . '-' ." "starter-theme/$st/inc/i18n.php" || fail "$st's suffix nav_location() does not build <location>-<lang>"
    grep -qF 'return $location;' "starter-theme/_i18n-variants/$st.php" || fail "$st's Polylang nav_location() does not return the bare name"
  fi

  if [ -z "$suffix_set" ]; then suffix_set=$reg; bases=$rendered
  else
    [ "$reg" = "$suffix_set" ] || fail "the starters register different locations ([$suffix_set] vs [$reg]) -- the commands below state one list for both"
  fi
done

# --- 2. no command, agent or skill names a location the starters never register --
under=$(grep -rnE '\b(primary|footer|mobile)_(en|es|<lang>|\{lang\})\b' commands agents skills CLAUDE.md docs/commands.md || true)
[ -z "$under" ] || fail "an underscore menu location, which neither starter registers:"$'\n'"$under"
lit=$(grep -rnE "'theme_location' *=> *['\"]" commands agents skills || true)
[ -z "$lit" ] || fail "an instruction hands the agent a hand-built theme_location instead of prefix_nav_location():"$'\n'"$lit"
grep -qF "prefix_nav_location('primary')" commands/wp-header.md \
  || fail "wp-header.md no longer tells wp-template to render prefix_nav_location('primary')"
grep -qF "prefix_nav_location('footer')" commands/wp-footer.md \
  || fail "wp-footer.md no longer tells wp-template to render prefix_nav_location('footer')"
asked=$(grep -rhoE "nav_location\( *'[a-z]+' *\)" commands agents skills | grep -oE "'[a-z]+'" | tr -d "'" | words)
for b in $asked; do
  case " $bases " in *" $b "*) ;; *) fail "an instruction renders nav_location('$b'), a location neither starter registers" ;; esac
done
# A register_nav_menus() example in an instruction registers only what the starters register.
# A reference still listing `mobile-en` after the starter dropped it hands /wp-finalize's
# "every registered location has a menu" gate a location nothing assigns.
regd=$(grep -rhoE "^ *'[a-z]+-(en|es)' *=> *__\(" commands agents skills | grep -oE "[a-z]+-(en|es)" | words)
for l in $regd; do
  case " $suffix_set " in *" $l "*) ;; *) fail "an instruction registers '$l', a location neither starter registers" ;; esac
done

# --- 3. /wp-init Step 6 registers exactly what the helpers answer, per strategy --
s6=$(region "$wp_init" '^## Step 6:' '^## Step 7:')
s6p=$(printf '%s\n' "$s6" | awk '/^### If `\$I18N = polylang`/{f=1; next} /^### /{f=0} f')
s6s=$(printf '%s\n' "$s6" | awk '/^### If `\$I18N = suffix`/{f=1; next} /^### /{f=0} f')
[ -n "$s6p" ] && [ -n "$s6s" ] || fail "wp-init Step 6 lost its per-strategy branches"
got=$(printf '%s\n' "$s6p" | grep -oE "^- \`'[a-z0-9_-]+' =>" | grep -oE "'[a-z0-9_-]+'" | tr -d "'" | words)
[ "$got" = "$bases" ] || fail "wp-init Step 6 registers [$got] under polylang; the Polylang helpers answer [$bases]"
got=$(printf '%s\n' "$s6s" | grep -oE "^ *- \`'[a-z0-9_-]+' =>" | grep -oE "'[a-z0-9_-]+'" | tr -d "'" | words)
[ "$got" = "$suffix_set" ] || fail "wp-init Step 6 registers [$got] under suffix; the starters register [$suffix_set]"
printf '%s' "$s6" | flat | grep -qF '`functions.php` on `cinematic`' \
  || fail "wp-init Step 6 does not say the cinematic starter registers its menus in functions.php -- it has no inc/theme-setup.php to edit"

# --- 4. /wp-header Step 7 registers the same names ---------------------------------
s7=$(region commands/wp-header.md '^## Step 7:' '^## Step 7[.]5:')
got=$(printf '%s\n' "$s7" | grep -oE "^ *'[a-z0-9_-]+' *=>" | grep -oE "[a-z0-9_-]+" | words)
[ "$got" = "$suffix_set" ] || fail "wp-header Step 7 registers [$got] under suffix; the starters register [$suffix_set]"

# --- 5. /wp-seed Phase 6 assigns to them, per strategy, all of them ---------------
p6=$(region "$wp_seed" '^## Phase 6:' '^## Phase 6[.]5:')
p6p=$(printf '%s\n' "$p6" | awk '/^Everything below this line describes the `suffix` strategy/{exit} {print}')
p6s=$(printf '%s\n' "$p6" | awk 'f{print} /^Everything below this line describes the `suffix` strategy/{f=1}')
[ -n "$p6s" ] || fail "wp-seed Phase 6 lost the line that splits its polylang branch from its suffix branch"
assigned() { grep -oE "menu location assign '[^']+' [a-z0-9_-]+" | awk '{print $NF}' | words; }
got=$(printf '%s\n' "$p6p" | assigned)
[ "$got" = "$bases" ] || fail "wp-seed Phase 6 (polylang) assigns [$got]; the theme registers [$bases]"
got=$(printf '%s\n' "$p6p" | grep -oE "\['nav_menus'\]\[get_stylesheet\(\)\]\['[a-z0-9_-]+'\]" | grep -oE "'[a-z0-9_-]+'\]$" | tr -d "']" | words)
[ "$got" = "$bases" ] || fail "wp-seed Phase 6 (polylang) writes Polylang's per-language slot for [$got]; the theme registers [$bases]"
got=$(printf '%s\n' "$p6s" | assigned)
[ "$got" = "$suffix_set" ] || fail "wp-seed Phase 6 (suffix) assigns [$got]; the starters register [$suffix_set]"

# --- 6. /wp-finalize verifies the same names, per strategy ------------------------
fin=$(flat < "$wp_finalize")
gate=$(printf '%s' "$fin" | grep -oE 'under `suffix`: [^;]*; under `polylang`: bare' || true)
[ -n "$gate" ] || fail "wp-finalize's delivery gate no longer lists the locations per strategy"
got=$(printf '%s' "$gate" | grep -oE '`[a-z0-9_-]+`' | tr -d '`' | grep -vx 'suffix\|polylang' | words)
[ "$got" = "$suffix_set" ] \
  || fail "wp-finalize's delivery gate verifies [$got] under suffix; the starters register [$suffix_set]"
for spec in 'Check 4|Check 5' 'Check 7|Tailwind convention'; do
  chk=$(region "$wp_finalize" "^### ${spec%%|*}" "^### ${spec##*|}" | flat)
  for b in $bases; do
    printf '%s' "$chk" | grep -qF "\`$b-<lang>\`" \
      || fail "wp-finalize ${spec%%|*} does not name \`$b-<lang>\` among the suffix locations it verifies"
  done
done

echo PASS
