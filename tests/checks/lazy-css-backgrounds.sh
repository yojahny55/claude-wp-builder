#!/usr/bin/env bash
# A CSS `background-image` has no `loading` attribute, so every decorative background a
# template prints is downloaded with the first paint however far below the fold it sits.
# On a real build four of them (120-320KB each) were 2.3MB of the 3.7MB first paint.
#
# Four contracts, one per layer, plus the two traps that cost the most time when this was
# first built and that a well-meaning rewrite removes without noticing:
#   1. the starter emits the declaration into a data attribute and repeats every one of
#      them inside a <noscript><style> block, so a visitor without JavaScript is unharmed;
#   2. the bundle paints them, and tests `document.readyState` before trusting a `load`
#      listener — a deferred bundle on a cached page runs AFTER the load event, so the
#      listener alone never fires and the idle backgrounds stay unpainted for the visit;
#   3. the wp-template agent tells builders to use it, and forbids it on the hero, which is
#      the LCP element — deferring that one makes the metric it was meant to fix worse;
#   4. the audit can find the defect in a theme nobody built with this starter.
set -uo pipefail
# -e is off (several greps are allowed to miss), so the one command whose failure would
# change what every path below resolves against answers for itself.
cd "$(dirname "$0")/../.." || { echo "FAIL: cannot cd to the repository root"; exit 1; }

perf=starter-theme/__tailwind__/inc/performance.php
js=starter-theme/__tailwind__/assets/js/src/index.js
agent=agents/wp-template.md
skill=skills/wp-theme-standards/SKILL.md
audit=agents/wp-audit-performance.md
for f in "$perf" "$js" "$agent" "$skill" "$audit"; do
  [ -f "$f" ] || { echo "FAIL: $f is missing"; exit 1; }
done

# 1. Starter helpers.
grep -Fq 'function __starter___lazy_background_attr(' "$perf" \
  || { echo "FAIL: $perf has no __starter___lazy_background_attr() helper"; exit 1; }
grep -Fq 'function __starter___print_lazy_background_noscript(' "$perf" \
  || { echo "FAIL: $perf has no noscript printer — with JavaScript disabled every deferred background is simply lost"; exit 1; }
grep -Fq "add_action( 'wp_footer', '__starter___print_lazy_background_noscript'" "$perf" \
  || { echo "FAIL: $perf never hooks the noscript printer to wp_footer, so it never runs"; exit 1; }
# The declaration must be BUILT by the WebP-aware emitter, not re-authored here: a second
# place that writes `background-image:url(…)` is a second place to forget the .webp branch.
grep -Fq '__starter___background_image( $url )' "$perf" \
  || { echo "FAIL: $perf does not build the deferred declaration with __starter___background_image(), so a deferred background loses the WebP branch"; exit 1; }
grep -Fq '<noscript><style>' "$perf" \
  || { echo "FAIL: $perf does not print the held-back declarations inside a <noscript><style> block"; exit 1; }

# TRAP 1, asserted on the emitter and on the reason. The key cannot travel in `id`:
# these sections usually carry one already and a parser drops a second `id` on the same
# element, which leaves the noscript rule selecting nothing while the page still looks
# correct with JavaScript on — a regression no screenshot with JS enabled can see.
grep -Fq 'data-__starter__-bg-id="' "$perf" \
  || { echo "FAIL: $perf does not key the noscript rule on a data attribute"; exit 1; }
grep -Eq 'drops a second .id.|second .id. on the same' "$perf" \
  || { echo "FAIL: $perf does not state WHY the key is a data attribute and not an id — the next edit moves it back to id"; exit 1; }

# 2. The bundle. The readyState test is the second trap and the one most likely to be
# "cleaned up" into a plain load listener.
grep -Fq "data-__starter__-bg" "$js" \
  || { echo "FAIL: $js never reads the data-__starter__-bg attribute the helper emits"; exit 1; }
grep -Fq 'IntersectionObserver' "$js" \
  || { echo "FAIL: $js paints no background through an IntersectionObserver"; exit 1; }
grep -Fq "rootMargin: '600px 0px'" "$js" \
  || { echo "FAIL: $js observes with no forward rootMargin — the visitor scrolls into an empty band before the request starts"; exit 1; }
grep -Fq "document.readyState === 'complete'" "$js" \
  || { echo "FAIL: $js trusts a window 'load' listener with no readyState test — a deferred bundle on a cached page runs after that event and the idle backgrounds are never painted"; exit 1; }
# The no-IntersectionObserver path must paint, not skip: a browser without the API would
# otherwise show every deferred section with no background at all.
grep -Fq "!('IntersectionObserver' in window)" "$js" \
  || { echo "FAIL: $js has no fallback for a browser without IntersectionObserver"; exit 1; }
# …and it must paint only what the observer would have observed. An idle element sits
# inside the first viewport, so a bare lazyBackgrounds.forEach(paint) here paints it
# during the initial parse and the idle flag means nothing on the very browsers this
# path exists for.
flatjs=$(tr '\n' ' ' < "$js" | sed 's/  */ /g')
printf '%s' "$flatjs" | grep -Fq "in window)) { lazyBackgrounds.forEach(paint); }" \
  && { echo "FAIL: $js paints idle backgrounds eagerly in the no-IntersectionObserver fallback"; exit 1; }
printf '%s' "$flatjs" | grep -Fq "hasAttribute('data-__starter__-bg-idle')" \
  || { echo "FAIL: $js does not keep idle backgrounds deferred in the no-IntersectionObserver fallback"; exit 1; }
# paint() must read the attribute into a variable and bail when it is gone. Appending
# `null` to cssText is what a second paint of the same node does otherwise.
printf '%s' "$flatjs" | grep -Eq "const declaration = el.getAttribute\('data-__starter__-bg'\); if \(!declaration\)" \
  || { echo "FAIL: $js paint() is not idempotent — a second call appends the string null to the element style"; exit 1; }
# Appended, not assigned: these sections can carry an inline style already.
printf '%s' "$flatjs" | grep -Fq 'el.style.cssText += declaration;' \
  || { echo "FAIL: $js assigns cssText instead of appending, dropping any inline style the template set"; exit 1; }

# 3. The agent contract. Flattened first: a correct re-wrap can split any of these phrases
# across two physical lines, including at a hyphen.
flatagent=$(tr '\n' ' ' < "$agent" | sed 's/  */ /g')
printf '%s' "$flatagent" | grep -Fq 'prefix_lazy_background_attr(' \
  || { echo "FAIL: $agent never names prefix_lazy_background_attr(), so no builder ever defers a background"; exit 1; }
# Directed, not a bare 'hero' token the file is full of: the sentence has to forbid the
# hero specifically. A deferred LCP element is a slower page than the one before the fix.
printf '%s' "$flatagent" | grep -Eq 'Never the hero|never the hero|[Nn]ever (use )?this for the hero' \
  || { echo "FAIL: $agent does not forbid deferring the hero — the LCP element is the one background this must never touch"; exit 1; }
printf '%s' "$flatagent" | grep -Fq 'prefix_print_lazy_background_noscript(' \
  || { echo "FAIL: $agent does not tell builders the noscript hook must stay while the helper is in use"; exit 1; }

# 4. Documented in the skill agents read, and findable by the audit.
grep -Fq 'prefix_lazy_background_attr(' "$skill" \
  || { echo "FAIL: $skill does not list the deferred-background helper among the performance helpers"; exit 1; }
grep -Fq 'PERF-057' "$audit" \
  || { echo "FAIL: $audit has no PERF-057 row for a non-deferred decorative background"; exit 1; }
flatau=$(tr '\n' ' ' < "$audit" | sed 's/  */ /g')
printf '%s' "$flatau" | grep -Fq 'Do NOT report the hero' \
  || { echo "FAIL: $audit does not exclude the hero from PERF-057 — the auto-fix would defer the LCP element"; exit 1; }

echo "PASS: deferred decorative backgrounds are emitted, painted, documented and auditable"
