#!/usr/bin/env bash
set -euo pipefail
s=skills/wp-polylang/SKILL.md
test -f "$s" || { echo "FAIL: $s missing"; exit 1; }
head -1 "$s" | grep -q '^---$' || { echo "FAIL: no frontmatter"; exit 1; }
grep -q '^name: wp-polylang$' "$s" || { echo "FAIL: no name in frontmatter"; exit 1; }
grep -q '^description:' "$s" || { echo "FAIL: no description"; exit 1; }

# The API contract this whole feature rests on must be documented.
for token in pll_set_post_language pll_save_post_translations \
             pll_set_term_language pll_save_term_translations \
             pll_get_post_translations 'wp eval-file'; do
  grep -q "$token" "$s" || { echo "FAIL: SKILL.md missing '$token'"; exit 1; }
done

# The failure mode the skill exists to prevent must be named explicitly.
grep -qi 'post_translations' "$s" || { echo "FAIL: does not mention the post_translations taxonomy"; exit 1; }
grep -qi 'wp-bilingual' "$s" || { echo "FAIL: does not relate itself to wp-bilingual"; exit 1; }

c=commands/wp-polylang.md
test -f "$c" || { echo "FAIL: $c missing"; exit 1; }
head -1 "$c" | grep -q '^---$' || { echo "FAIL: command has no frontmatter"; exit 1; }
grep -q 'allowed-tools:' "$c" || { echo "FAIL: no allowed-tools"; exit 1; }
grep -q 'argument-hint:' "$c" || { echo "FAIL: no argument-hint"; exit 1; }
for token in pll-setup.php pll-export.php pll-import.php pll-verify.php \
             'wp eval-file' wp-polylang; do
  grep -q "$token" "$c" || { echo "FAIL: command doc missing '$token'"; exit 1; }
done
grep -q 'wp plugin install polylang' "$c" || { echo "FAIL: command doc does not install Polylang"; exit 1; }

# ── Polylang i18n variants ──────────────────────────────────────────────────
# The contract test. Templates call these helpers and never get_field()
# directly, so a Polylang project works only as long as its i18n-polylang.php
# exposes EXACTLY what its own i18n.php does -- one missing helper is a fatal
# error on a real page, and one extra is a helper no template can rely on.
#
# Asserted PER STARTER, not across them: __tailwind__ and __cinematic__ have
# deliberately different contracts (nine helpers vs three), so a single global
# list would be wrong for both.
for starter in __tailwind__ __cinematic__; do
  base="starter-theme/$starter/inc/i18n.php"
  poly="starter-theme/_i18n-variants/$starter.php"

  [[ -f "$base" ]] || { echo "FAIL: $starter has no inc/i18n.php to mirror"; exit 1; }
  [[ -f "$poly" ]] || { echo "FAIL: no Polylang i18n variant for $starter"; exit 1; }

  php -l "$poly" >/dev/null 2>&1 || { echo "FAIL: the $starter Polylang variant is not valid PHP"; exit 1; }

  # The variant must NOT be shipped inside the theme tree: /wp-init copies the
  # whole starter directory, so a second file declaring the same functions
  # would ride along into every project and fatal the moment anything globs
  # inc/*.php. tests/checks/tailwind-starter.sh refuses that state outright.
  [[ ! -f "starter-theme/$starter/inc/i18n-polylang.php" ]] || {
    echo "FAIL: $starter ships a Polylang variant inside its own inc/ -- it must live in starter-theme/_i18n-variants/"
    exit 1
  }

  base_fns="$(grep -oP '^function \K[a-z_0-9]+' "$base" | sort)"
  poly_fns="$(grep -oP '^function \K[a-z_0-9]+' "$poly" | sort)"

  [[ -n "$base_fns" ]] || { echo "FAIL: no functions found in $starter/inc/i18n.php -- this check would be vacuous"; exit 1; }

  if [[ "$base_fns" != "$poly_fns" ]]; then
    echo "FAIL: $starter's Polylang variant does not expose the same helpers as its i18n.php"
    echo "  only in i18n.php:          $(comm -23 <(echo "$base_fns") <(echo "$poly_fns") | tr '\n' ' ')"
    echo "  only in the Polylang variant: $(comm -13 <(echo "$base_fns") <(echo "$poly_fns") | tr '\n' ' ')"
    exit 1
  fi

  # The variant must actually consult Polylang, not just be a copy of the
  # _suffix file under a different name.
  grep -q 'pll_current_language' "$poly" || {
    echo "FAIL: the $starter Polylang variant never calls pll_current_language() -- it is not a Polylang variant"
    exit 1
  }
  # And it must degrade instead of fataling when Polylang is inactive.
  grep -q "function_exists( *'pll_current_language' *)" "$poly" || {
    echo "FAIL: the $starter Polylang variant calls Polylang without guarding for it being inactive"
    exit 1
  }
done

# /wp-init must offer the choice, and record it.
grep -q '_i18n-variants' "commands/wp-init.md" || { echo "FAIL: /wp-init never installs a Polylang i18n variant"; exit 1; }
grep -qi 'polylang' "commands/wp-init.md" || { echo "FAIL: /wp-init does not mention Polylang at all"; exit 1; }

# The two i18n models must not be described as mutually exclusive any more.
grep -q 'no WPML, no Polylang' "skills/wp-bilingual/SKILL.md" && {
  echo "FAIL: wp-bilingual still claims the plugin does not support Polylang"
  exit 1
}

# ── /wp-header: the two dispatched prompts must branch on i18n strategy ────
# The merge left Step 4's wp-template prompt and Step 6's wp-acf prompt
# suffix-shaped and unconditional: per-language menu locations and `_es`
# duplicates, ordered no matter the strategy. A polylang project obeying them
# registers locations Step 7 does not create and fields Polylang cannot
# serve. Each needle is scoped to its step's QUOTED lines — the only text a
# dispatched agent ever sees — so a passing prose mention elsewhere cannot
# satisfy it, and the prose is flattened so a re-wrap cannot break it. Each
# FAIL names the token to restore; a deliberate rephrase must update this
# check, the same contract as the frozen bullet labels in
# tests/checks/wp-init-tailwind.sh.
step_quotes() { # <from-step> <to-step>
  awk "/^## Step $1:/,/^## Step $2:/" commands/wp-header.md \
    | grep '^[[:space:]]*>' | sed 's/^[[:space:]]*>//' \
    | tr '\n' ' ' | sed 's/  */ /g'
}
for spec in "4 5" "6 7"; do
  set -- $spec
  raw=$(awk "/^## Step $1:/,/^## Step $2:/" commands/wp-header.md)
  printf '%s\n' "$raw" | tail -1 | grep -q "^## Step $2:" \
    || { echo "FAIL: wp-header's Step $1 region is not terminated by its '## Step $2:' heading — every assertion scoped to it would silently degrade to a file-wide grep"; exit 1; }
done
h4=$(step_quotes 4 5)
h6=$(step_quotes 6 7)
printf '%s' "$h4" | grep -qF 'pll_the_languages' \
  || { echo "FAIL: wp-header's Step 4 prompt never hands the wp-template agent pll_the_languages() for the polylang switcher — under polylang the header would build a suffix-model switcher over pages that have no suffix URLs"; exit 1; }
printf '%s' "$h4" | grep -qF 'the bare location' \
  || { echo "FAIL: wp-header's Step 4 prompt never tells wp-template to use the bare nav location under polylang — the agent writes 'primary_' . prefix_get_current_lang(), a location Step 7 does not register on that strategy"; exit 1; }
printf '%s' "$h6" | grep -qF 'no `_<lang>` duplicate' \
  || { echo "FAIL: wp-header's Step 6 prompt never tells wp-acf that polylang emits no _<lang> duplicate fields — the agent writes _es variants Polylang cannot serve, and /wp-finalize Check 2 then reports a bilingual failure on correct work"; exit 1; }

# ── /wp-finalize must branch its checks on i18n strategy ────────────────────
# The merge left Check 2 (field _en/_es coverage), Check 4 item 5, Check 7
# item 2 and Layer 2 item 3 suffix-shaped: each one demands _es variants or
# per-language menu locations no matter the strategy, so a correct Polylang
# project fails delivery on all four. Scope each needle to its own check's
# region (on flattened prose, with a terminator proof), so a passing mention
# in another check cannot satisfy it and a re-wrap cannot break it.
fin_pair() { # <from-heading-prefix> <to-heading-prefix>
  local raw
  raw=$(awk "/^### $1/,/^### $2/" commands/wp-finalize.md)
  printf '%s\n' "$raw" | tail -1 | grep -q "^### $2" \
    || { echo "FAIL: wp-finalize's '$1' region is not terminated by its '$2' heading — its assertions would silently degrade to file-wide greps"; exit 1; }
  printf '%s\n' "$raw" | tr '\n' ' ' | sed 's/  */ /g'
}
c2=$(fin_pair 'Check 2' 'Check 3')
c4=$(fin_pair 'Check 4' 'Check 5')
c7=$(fin_pair 'Check 7' 'Tailwind convention')
l2=$(fin_pair 'Demo-parity gate — Layer 2' 'Demo-parity gate — Layer 3')
printf '%s' "$c2" | grep -qF 'Under `polylang`, skip this item' \
  || { echo "FAIL: wp-finalize Check 2 never skips the field-variant item under polylang — it verifies _es variants that a polylang project deliberately does not have, and fails every correct delivery"; exit 1; }
printf '%s' "$c2" | grep -qF 'pll-verify.php' \
  || { echo "FAIL: wp-finalize Check 2 names no polylang coverage check — skipping the suffix item leaves the polylang project with nothing verifying translation coverage at delivery"; exit 1; }
printf '%s' "$c4" | grep -qF 'one bare location per name' \
  || { echo "FAIL: wp-finalize Check 4 still requires per-language menu locations on both strategies — under polylang the theme registers one bare location per name and the check fails it"; exit 1; }
printf '%s' "$c7" | grep -qF 'bare `primary`, `footer` under `polylang`' \
  || { echo "FAIL: wp-finalize Check 7 item 2 still lists only suffix menu locations — under polylang it verifies locations that were never registered"; exit 1; }
printf '%s' "$l2" | grep -qF 'under `polylang`: bare `primary`, `footer`' \
  || { echo "FAIL: wp-finalize Layer 2 still lists only suffix menu locations — under polylang it fails delivery on locations that were never registered"; exit 1; }

# ── /wp-init Step 0.7 must default to polylang, for SEO ────────────────────
# The suffix model serves both languages from one URL off ?lang=/cookie, so a
# crawler only ever sees the primary language and there is nowhere to store a
# translated title. It stays available as a toggle; it is not the default.
s07=$(awk '/^## Step 0.7:/,/^## Pre-Step:/' commands/wp-init.md)
[ -n "$s07" ] || { echo "FAIL: no Step 0.7 region in commands/wp-init.md"; exit 1; }
printf '%s' "$s07" | grep -qF 'Default: `polylang`' \
  || { echo "FAIL: /wp-init Step 0.7 does not default to polylang — a bilingual site scaffolded on Enter gets the suffix model, whose second language cannot be indexed"; exit 1; }
printf '%s' "$s07" | grep -qiE 'hreflang|crawler|SEO' \
  || { echo "FAIL: /wp-init Step 0.7 states no SEO reason for the default — without it the next edit flips it back on 'what existing projects use'"; exit 1; }
printf '%s' "$s07" | grep -qF 'suffix' \
  || { echo "FAIL: /wp-init Step 0.7 dropped the suffix option — it is still the right choice when the second language does not need to rank"; exit 1; }
# Old projects must not be re-read as polylang: the absent-line fallback stays suffix.
grep -qF 'the project predates the choice and is' CLAUDE.md \
  || { echo "FAIL: CLAUDE.md dropped the absent-line fallback — existing suffix projects would be rebuilt as polylang"; exit 1; }
printf '%s' "$s07" | grep -qF '`i18n strategy` line is absent stays `suffix`' \
  || { echo "FAIL: /wp-init Step 0.7 does not say the new default governs new scaffolds only"; exit 1; }

echo PASS
