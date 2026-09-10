#!/usr/bin/env bash
# The composition library must pass the same gate a craft build must pass.
#
# `impeccable detect` ignores bare section.html/section.css fragments: it scans
# zero files and exits 0, so a check that pointed it at compositions/ would be
# green while testing nothing. Two compositions shipped an infinite loop
# animation for exactly that reason. This assembles each composition into a
# complete document, scans, and refuses a zero-scan result.
#
# A file existing is not the same as a file having content, and `impeccable`
# cannot tell the two apart either: a directory of 0-byte HTML files reports the
# identical `[]` / exit 0 as one with real, clean markup (checked by hand — the
# tool's JSON and human output both carry no "files scanned" count at all). So
# `[ -f ... ]` alone is not a scan guard: a truncated section.html/section.css
# would satisfy it and inflate the count the same as real content, and this gate
# — and the check wired to it — would go green while scanning nothing.
# MIN_HTML_BYTES/MIN_CSS_BYTES/MIN_DOC_BYTES are this script's own defence
# against that, since the detector offers none.
set -euo pipefail
cd "$(dirname "$0")/.."

# COMPS_DIR exists so the gate can be pointed at a synthetic library and proved to
# still fail — a gate only asserted to pass is a gate nobody has watched fail.
# Real runs never set it.
COMPS="${COMPS_DIR:-skills/wp-demo-craft/compositions}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# The smallest real fragments today are page-head's: section.html at 346 bytes,
# section.css at 1172. The thresholds below sit far enough under both that no
# real composition can trip them, and far enough over 0 that a `truncate -s0`
# of either fragment — one, or both, on one composition or all of them — cannot
# pass as content. MIN_DOC_BYTES is the same margin applied to the assembled
# whole (empty wrapper alone is 130 bytes), as a second, independent check on
# the exact bytes handed to the detector rather than on the inputs that built it.
MIN_HTML_BYTES=50
MIN_CSS_BYTES=100
MIN_DOC_BYTES=512

count=0
empty=""
for dir in "$COMPS"/*/; do
  name="$(basename "$dir")"
  [ -f "$dir/section.html" ] || continue
  [ -f "$dir/section.css" ] || continue
  html_bytes=$(wc -c < "$dir/section.html")
  css_bytes=$(wc -c < "$dir/section.css")
  if [ "$html_bytes" -lt "$MIN_HTML_BYTES" ] || [ "$css_bytes" -lt "$MIN_CSS_BYTES" ]; then
    empty="$empty $name(html=${html_bytes}b,css=${css_bytes}b)"
    continue
  fi
  {
    printf '<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">'
    printf '<title>%s</title><style>\n' "$name"
    cat "$dir/section.css"
    printf '\n</style></head><body>\n'
    cat "$dir/section.html"
    printf '\n</body></html>\n'
  } > "$WORK/$name.html"
  doc_bytes=$(wc -c < "$WORK/$name.html")
  if [ "$doc_bytes" -lt "$MIN_DOC_BYTES" ]; then
    empty="$empty $name(assembled=${doc_bytes}b)"
    rm -f "$WORK/$name.html"
    continue
  fi
  count=$((count + 1))
done

if [ -n "$empty" ]; then
  echo "composition-gate: refused near-empty or truncated content — section.html/section.css/assembled document below the sane minimum:$empty" >&2
  exit 1
fi

if [ "$count" -eq 0 ]; then
  echo "composition-gate: assembled 0 compositions — nothing was scanned" >&2
  exit 1
fi

echo "composition-gate: assembled $count compositions (each >= $MIN_DOC_BYTES bytes on disk)"

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
