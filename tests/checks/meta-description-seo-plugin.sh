#!/usr/bin/env bash
# The tailwind starter printed its own <meta name="description"> on the front page with no
# early return for an SEO plugin, so a site running Rank Math (which /wp-create's plugin
# profiles install) shipped two description tags. The detection already existed -- the
# wp-agentic-surfaces agent's <prefix>_seo_plugin_owns_schema(), which identity JSON-LD
# returns on -- and wp-theme-standards taught a second, narrower one (two constants, no
# SEOPress). There is now one guard: the starter defines it, the meta description returns on
# it, and inc/agentic.php declares it only for a theme that lacks it (twice is a fatal).
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

agent=agents/wp-agentic-surfaces.md
ref=skills/wp-theme-standards/references/head-and-performance.md
guard_fn='__starter___seo_plugin_owns_schema'

# --- every theme-printed description tag returns on the guard first -------------------
hits=$(grep -rlF 'name="description"' starter-theme --include=*.php || true)
[ -n "$hits" ] || echo "note: no starter prints a meta description -- only the guard itself is checked"
for f in $hits; do
  # The wp_head callback that prints it: from the nearest preceding add_action( 'wp_head'
  # to the print. The guard must return inside it, before the tag.
  block=$(awk '/add_action\( *.wp_head./{buf=""} {buf=buf $0 "\n"} /name="description"/{print buf; exit}' "$f")
  printf '%s' "$block" | grep -qE "add_action\( *.wp_head." \
    || fail "$f prints a meta description outside a wp_head callback this check can read"
  printf '%s' "$block" | tr '\n' ' ' | grep -qE "if \( *$guard_fn\(\) *\) \{ *return;" \
    || fail "$f prints <meta name=\"description\"> without first returning on $guard_fn() -- beside Rank Math, Yoast or SEOPress that is two description tags"
done

# --- one detection: defined once in the starter, identical to the agent's -------------
tw=starter-theme/__tailwind__/functions.php
[ "$(grep -rcE "^function $guard_fn\(" starter-theme --include=*.php | awk -F: '{s+=$2} END{print s+0}')" = 1 ] \
  || fail "the starters do not define $guard_fn() exactly once"
grep -qE "^function $guard_fn\(" "$tw" || fail "$tw does not define $guard_fn(), which its meta description returns on"
# Reads the agent's fenced PHP as source: from `function <name>(` to the first `;` after
# `return`. Prose between the two would be read as code; the empty-body guard below fails
# rather than comparing nothing, and a mismatch prints both bodies.
body() { # <file> <function-name-regex>: the guard's return expression, whitespace-normalised
  awk -v fn="$2" '$0 ~ "function " fn "\\(" {f=1; next} f && /return/{r=1} r{print} r && /;/{exit}' "$1" \
    | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//'
}
b_tw=$(body "$tw" "$guard_fn")
b_ag=$(body "$agent" '<prefix>_seo_plugin_owns_schema')
[ -n "$b_tw" ] && [ -n "$b_ag" ] || fail "could not read the guard's body from $tw or $agent -- this check would be vacuous"
[ "$b_tw" = "$b_ag" ] || fail "the starter's $guard_fn() and $agent's detect different plugins:"$'\n'"  starter: $b_tw"$'\n'"  agent:   $b_ag"
for p in RANK_MATH_VERSION WPSEO_VERSION SEOPRESS_VERSION; do
  case "$b_tw" in *"$p"*) ;; *) fail "$guard_fn() no longer detects $p" ;; esac
done

# A second detection is how the two drifted: no other SEO-plugin constant check in a starter.
other=$(grep -rnE "defined\( *'(RANK_MATH|WPSEO|SEOPRESS)_VERSION' *\)" starter-theme --include=*.php | grep -vF "$tw:" || true)
[ -z "$other" ] || fail "a starter detects an SEO plugin outside $guard_fn():"$'\n'"$other"

# --- the agent declares it only for a theme that lacks it ------------------------------
grep -qF "if ( ! function_exists( '<prefix>_seo_plugin_owns_schema' ) ) {" "$agent" \
  || fail "$agent declares <prefix>_seo_plugin_owns_schema() unguarded -- on a theme built from the tailwind starter, which defines it, that is a 'Cannot redeclare' fatal"

# --- the skill teaches the same guard, not two constants --------------------------------
grep -qF 'if (prefix_seo_plugin_owns_schema()) {' "$ref" \
  || fail "$ref's meta description does not return on prefix_seo_plugin_owns_schema()"
grep -qF "defined('WPSEO_VERSION') || defined('RANK_MATH_VERSION')" "$ref" \
  && fail "$ref still detects an SEO plugin by two constants, which misses SEOPress"
true

echo PASS
