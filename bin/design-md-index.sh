#!/usr/bin/env bash
# Rebuilds references/design-md/INDEX.md from each vendored DESIGN.md's front
# matter. Industry and tone are read from the description line by keyword; a
# file the heuristics cannot classify gets "general" / "unknown" and a human
# edits the row. Run after refreshing the catalogue.
set -euo pipefail
cd "$(dirname "$0")/.."
d=skills/wp-demo-craft/references/design-md
{
  cat <<'EOF'
# Catalogue index

One row per vendored DESIGN.md. Pick two or three nearest matches by industry
and tone; read only those files. Never copy a row's tokens verbatim into a client
DESIGN.md: the catalogue is vocabulary, the client docs are the source.

| domain | industry | tone | display | accent |
|---|---|---|---|---|
EOF
  for f in "$d"/*/DESIGN.md; do
    dom=$(basename "$(dirname "$f")")
    desc=$(awk '/^description:/ { sub(/^description: */, ""); print; exit }' "$f")
    accent=$(awk '/^  primary: / { gsub(/"/, "", $2); print $2; exit }' "$f")
    canvas=$(awk '/^  canvas: / { gsub(/"/, "", $2); print $2; exit }' "$f")
    display=$(awk '/fontFamily:/ { sub(/^ *fontFamily: */, ""); print; exit }' "$f")
    tone=unknown
    case "$canvas" in
      '#0'*|'#1'*|'#2'*) tone=dark ;;
      '#f'*|'#F'*|'#e'*|'#E'*|'#ffffff') tone=light ;;
    esac
    industry=general
    case "$(echo "$desc" | tr 'A-Z' 'a-z')" in
      *fintech*|*bank*|*payment*|*finance*) industry=finance ;;
      *developer*|*devtool*|*api*|*infrastructure*) industry=devtools ;;
      *saas*|*product*|*software*) industry=saas ;;
      *commerce*|*shop*|*retail*|*store*) industry=commerce ;;
      *agency*|*studio*|*portfolio*) industry=agency ;;
      *health*|*medical*|*wellness*) industry=health ;;
      *travel*|*hotel*|*hospitality*) industry=hospitality ;;
      *car*|*automotive*|*vehicle*) industry=automotive ;;
    esac
    echo "| $dom | $industry | $tone | ${display:-unknown} | ${accent:-unknown} |"
  done
} > "$d/INDEX.md"
echo "wrote $d/INDEX.md"
