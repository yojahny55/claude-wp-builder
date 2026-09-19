#!/usr/bin/env bash
# Render the motion fixtures and compare them to approved baselines.
#
# The last leg of I06: "Save approved demo/theme screenshot pairs matching fonts, content,
# viewports, animation states. Report image differences reviewable tolerances." The pairs
# here are the same page with the motion engine running and with it stood down, plus the
# engine's own states along a scroll -- including the reduced-motion fallback I06 names.
#
# WHY A CONTAINER, and not the runner's own Chrome like motion-devices.sh:
#   That check asserts on the DOM, which is stable across browser versions. This one
#   asserts on PIXELS, which are not. CI renders with /usr/bin/google-chrome from
#   ubuntu-latest -- a browser that updates itself, on an image that migrates to Ubuntu 26
#   in October. Baselines taken against a moving renderer fail every time Chrome ships a
#   font or antialiasing change, so "the baseline changed" would mean "Chrome changed" far
#   more often than "the UI changed", and a gate that cries wolf is a gate people mute.
#   Pinning the renderer is the same discipline the WordPress fixture already applies to
#   mariadb:11.4 -- every version pinned so an upstream release cannot change a result.
#
# SKIPs without docker, for the reason the WordPress fixture skips without WP_FIXTURE:
# making a 2 GB image pull the price of running the suite means people stop running it.
set -euo pipefail
cd "$(dirname "$0")/../.."

fail() { echo "FAIL: $*"; exit 1; }

IMAGE="mcr.microsoft.com/playwright:v1.63.0-noble"
BASELINES="tests/baselines/motion"
# 0.1% of pixels. Not a knob to turn when this goes red: a real regression moves far more
# than this, and antialiasing noise from the pinned renderer moves far less (measured at
# 0.0000% across repeat runs). Raising it is a decision to see less, and belongs in a
# commit message rather than in a moment of frustration.
TOLERANCE="0.1"

shooter=tests/fixtures/motion/shoot.mjs
comparer=tests/fixtures/motion/compare.mjs
for f in "$shooter" "$comparer" "$BASELINES/RENDERED-BY.txt"; do
  [ -f "$f" ] || fail "$f is missing"
  [ -r "$f" ] || fail "$f exists but cannot be read"
done

# The baselines record which renderer produced them. If this check ever runs against a
# different one, the pixels below are not comparable and the right answer is to say so
# rather than to report a diff nobody can act on.
recorded="$(tr -d '[:space:]' < "$BASELINES/RENDERED-BY.txt")"
[ "$recorded" = "$IMAGE" ] || fail "baselines were rendered by '$recorded' but this check uses '$IMAGE'"

if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
  echo "SKIP: docker is not available -- cannot render against the pinned browser"
  if [ -n "${VISUAL_REQUIRE_BROWSER:-}" ]; then
    fail "docker is unavailable, but VISUAL_REQUIRE_BROWSER is set -- this environment is supposed to have it"
  fi
  exit 0
fi

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "SKIP: $IMAGE is not pulled locally (docker pull $IMAGE)"
  if [ -n "${VISUAL_REQUIRE_BROWSER:-}" ]; then
    fail "$IMAGE is missing, but VISUAL_REQUIRE_BROWSER is set"
  fi
  exit 0
fi

[ -d node_modules/playwright-core ] || fail "node_modules is not installed (npm install)"
[ -d node_modules/pixelmatch ] || fail "pixelmatch is not installed (npm install)"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
shots="$work/shots"
diffs="$work/diffs"
mkdir -p "$shots" "$diffs"

# --user keeps the PNGs owned by the caller rather than root: this mounts the repository,
# and a check that leaves root-owned files behind in a working tree is a check that breaks
# the next unrelated command.
docker run --rm \
  --user "$(id -u):$(id -g)" \
  -v "$PWD:/w" -v "$work:/out" \
  -w /w \
  "$IMAGE" \
  bash -c 'CHROME_PATH="$(ls -d /ms-playwright/chromium-*/chrome-linux*/chrome 2>/dev/null | head -1)"
           # An empty CHROME_PATH would fall through the launcher ladder to a system Chrome
           # this image does not have, and the run would SKIP -- reporting success for a
           # check that rendered nothing. Measured: the directory is chrome-linux64 here,
           # and the first glob written for chrome-linux matched nothing and did exactly
           # that.
           [ -n "$CHROME_PATH" ] || { echo "no chromium inside the image"; exit 1; }
           export CHROME_PATH
           node tests/fixtures/motion/shoot.mjs /out/shots' \
  || fail "rendering inside $IMAGE failed"

[ -f "$shots/shots.json" ] || fail "the shooter produced no manifest"

if ! node "$comparer" "$shots" "$BASELINES" "$diffs" "$TOLERANCE"; then
  # Copied out of the temp dir that the trap is about to delete -- a failing visual check
  # whose evidence is deleted on exit is a check nobody can act on.
  keep="tests/baselines/.failed-diffs"
  rm -rf "$keep"
  mkdir -p "$keep"
  cp "$diffs"/*.png "$diffs"/report.json "$keep"/ 2>/dev/null || true
  echo "FAIL: rendered output differs from the approved baselines"
  echo "      diff images and report.json written to $keep/"
  echo "      to approve: review them, replace the baseline PNGs, and commit with a"
  echo "      message whose first line starts 'baseline: <why>' (see baseline-approval.sh)"
  exit 1
fi

echo "PASS: rendered motion fixtures match the approved baselines (tolerance ${TOLERANCE}%)"
