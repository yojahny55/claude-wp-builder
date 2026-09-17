#!/usr/bin/env bash
# A CSS background-image is not an <img>, so nothing that rewrites <img> tags reaches it —
# including Robin Image Optimizer's default `picture` delivery mode, which is what an
# optimized site usually runs. On a real site that meant a background served at 942KB
# while its WebP sibling on disk was 342KB.
#
# Three contracts, one per layer:
#   1. the starter emits the background through a helper that names the .webp sibling in an
#      image-set(), with the plain url() first as the fallback, and resolves BOTH sibling
#      names — `foto.png.webp` (Robin, most bulk optimizers) and `foto.webp` (WordPress);
#   2. the wp-template agent tells builders to use it instead of a bare url();
#   3. the wp-robin skill states that `picture` does not cover CSS, with the page-cache
#      caveat on `url` mode and the server-side alternative for a stylesheet.
set -uo pipefail
cd "$(dirname "$0")/../.."

perf=starter-theme/__tailwind__/inc/performance.php
agent=agents/wp-template.md
skill=skills/wp-robin/SKILL.md
audit=agents/wp-audit-performance.md
for f in "$perf" "$agent" "$skill" "$audit"; do
  [ -f "$f" ] || { echo "FAIL: $f is missing"; exit 1; }
done

# 1. Starter helper.
grep -Fq 'function __starter___background_image(' "$perf" \
  || { echo "FAIL: $perf has no __starter___background_image() helper"; exit 1; }
grep -Fq "background-image:url(" "$perf" \
  || { echo "FAIL: $perf does not emit the plain url() fallback line first"; exit 1; }
grep -Fq "image-set(" "$perf" \
  || { echo "FAIL: $perf does not emit an image-set() with the WebP branch"; exit 1; }
# A double quote inside type() would end the style attribute the value is printed in.
grep -Fq "type('image/webp')" "$perf" \
  || { echo "FAIL: $perf does not single-quote the image-set() type() — a double quote ends the style attribute"; exit 1; }
grep -Fq 'function __starter___webp_sibling_url(' "$perf" \
  || { echo "FAIL: $perf has no shared WebP sibling resolver"; exit 1; }
# Both naming conventions. Checking only the replaced-extension one is why an optimized
# library could look entirely unoptimized on the front end.
grep -Fq "\$relative . '.webp'" "$perf" \
  || { echo "FAIL: $perf does not check the appended sibling name (foto.png.webp) that Robin writes"; exit 1; }
grep -Fq "'.webp', \$relative" "$perf" \
  || { echo "FAIL: $perf does not check the replaced-extension sibling name (foto.webp) that WordPress writes"; exit 1; }
# The buffer must go through the resolver, not re-derive one naming convention of its own.
grep -Fq '__starter___webp_sibling_url( $text )' "$perf" \
  || { echo "FAIL: $perf's output buffer does not use the shared sibling resolver — it would cover only one naming convention"; exit 1; }
# Local uploads URLs only.
grep -Fq 'wp_get_upload_dir()' "$perf" \
  || { echo "FAIL: $perf resolves siblings without anchoring on the uploads directory"; exit 1; }

# The buffer must leave a declaration the helper already decided about alone: rewriting
# the fallback url() would hand a browser without image-set() a WebP it may not decode.
grep -Fq "') type('" "$perf" \
  || { echo "FAIL: $perf's buffer does not recognize the helper's image-set() candidates"; exit 1; }
grep -Fq "');background-image:image-set(" "$perf" \
  || { echo "FAIL: $perf's buffer does not recognize the helper's plain url() fallback, and would rewrite it"; exit 1; }
grep -Fq "'#(^|/)\\.\\.(/|\$)#', \$relative" "$perf" \
  || { echo "FAIL: $perf does not refuse a parent segment before touching the filesystem"; exit 1; }
grep -Fq 'function __starter___css_url(' "$perf" \
  || { echo "FAIL: $perf does not percent-encode CSS-syntax characters in the url() token"; exit 1; }

# 2. Agent guidance.
grep -Fq 'prefix_background_image' "$agent" \
  || { echo "FAIL: $agent does not tell templates to print backgrounds through the helper"; exit 1; }
grep -Fq 'esc_attr()' "$agent" \
  || { echo "FAIL: $agent does not state that the helper's value is already escaped"; exit 1; }

# 3. Skill documentation.
grep -Fq 'webp_delivery_mode' "$skill" \
  || { echo "FAIL: $skill does not document Robin's delivery modes"; exit 1; }
grep -Fq 'Vary: Accept' "$skill" \
  || { echo "FAIL: $skill offers the server-side rule without the Vary: Accept caveat"; exit 1; }
grep -Fq 'page cache' "$skill" \
  || { echo "FAIL: $skill does not state the page-cache caveat on url delivery mode"; exit 1; }

# 4. The audit check that would have caught it.
grep -Fq 'PERF-056' "$audit" \
  || { echo "FAIL: $audit has no check for a CSS background whose WebP sibling is never served"; exit 1; }

# 5. Behavior, not wording: the greps above all pass on a helper that probes outside
# uploads, that leaves a parenthesis loose in the url() token, or whose output buffer
# overwrites the fallback the helper deliberately emitted. Run the code.
behavior="$(dirname "$0")/lib/webp-backgrounds-behavior.php"
[ -f "$behavior" ] || { echo "FAIL: $behavior is missing — the behavioral half of this check cannot run"; exit 1; }
if ! command -v php >/dev/null 2>&1; then
  # Not PASS: the three defects this file exists to catch are unverified without it,
  # and a green line would report coverage the run does not have.
  echo "SKIP: php not found — the greps above passed, the behavioral test did not run"
  exit 0
fi
out=$(php "$behavior" 2>&1) || { echo "FAIL: behavioral test failed:"; echo "${out:-(no output — php exited non-zero with nothing on stdout or stderr)}"; exit 1; }
[ "$out" = "OK" ] || { echo "FAIL: behavioral test did not report OK:"; echo "${out:-(no output)}"; exit 1; }

echo "PASS"
