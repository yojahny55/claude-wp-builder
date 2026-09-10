#!/usr/bin/env bash
# The composition library must pass the same gate a craft build must pass.
#
# `impeccable detect` ignores bare section.html/section.css fragments: it scans
# zero files and exits 0, so a check that pointed it at compositions/ would be
# green while testing nothing. Two compositions shipped an infinite loop
# animation for exactly that reason. This assembles each composition into a
# complete document, scans, and refuses a zero-scan result.
set -euo pipefail
cd "$(dirname "$0")/.."

COMPS="skills/wp-demo-craft/compositions"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

count=0
for dir in "$COMPS"/*/; do
  name="$(basename "$dir")"
  [ -f "$dir/section.html" ] || continue
  [ -f "$dir/section.css" ] || continue
  {
    printf '<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">'
    printf '<title>%s</title><style>\n' "$name"
    cat "$dir/section.css"
    printf '\n</style></head><body>\n'
    cat "$dir/section.html"
    printf '\n</body></html>\n'
  } > "$WORK/$name.html"
  count=$((count + 1))
done

if [ "$count" -eq 0 ]; then
  echo "composition-gate: assembled 0 compositions — nothing was scanned" >&2
  exit 1
fi
echo "composition-gate: assembled $count compositions"

npx -y impeccable@4 detect "$WORK" --json > "$WORK/findings.json" 2>/dev/null || true

python3 - "$WORK/findings.json" "$count" <<'PY'
import json, sys, collections
path, expected = sys.argv[1], int(sys.argv[2])
try:
    data = json.load(open(path))
except Exception as exc:
    print("composition-gate: detector produced no parseable JSON: %s" % exc, file=sys.stderr)
    raise SystemExit(1)
findings = data if isinstance(data, list) else data.get("findings", data)
blocking = [f for f in findings
            if f.get("category") == "slop" and f.get("severity") == "warning"]
by_comp = collections.defaultdict(list)
for f in blocking:
    by_comp[f.get("file", "?").split("/")[-1].replace(".html", "")].append(
        f.get("antipattern", "?"))
if blocking:
    for comp in sorted(by_comp):
        print("composition-gate: %s fails the slop gate: %s"
              % (comp, ", ".join(sorted(set(by_comp[comp])))), file=sys.stderr)
    raise SystemExit(2)
print("composition-gate: %d compositions, 0 slop findings at warning severity" % expected)
PY
