#!/usr/bin/env bash
# Multi-platform, phase 1: bin/export-platform.mjs writes this plugin's commands in the formats
# Cursor, Gemini CLI and AGENTS.md readers take, without changing a command. This runs all
# three targets against the real commands/ and agents/ and checks what each reader needs:
# one entry or file per command, no ${CLAUDE_PLUGIN_ROOT} left in a command body, Gemini TOML
# that parses with $ARGUMENTS as {{args}}, Cursor rules that are attached on request only, and
# the preamble that tells another agent how to run a subagent step itself.
set -euo pipefail
cd "$(dirname "$0")/../.."
. tests/lib/assert.sh
require_tool node python3

tool=${EXPORT_PLATFORM:-bin/export-platform.mjs}
root=$(pwd)
tmp=$(mktemp -d)
# Compare against the tree as it was before the exporter ran, so uncommitted edits do not fail it.
before=$(git diff -- commands agents skills | sha256sum)
trap 'rm -rf "$tmp"' EXIT

ncmd=$(find commands -maxdepth 1 -name '*.md' | wc -l)
nagent=$(find agents -maxdepth 1 -name '*.md' | wc -l)
[ "$ncmd" -gt 0 ] || fail "no commands to export"

for t in agents-md cursor gemini; do
  node "$tool" --target "$t" "$tmp/$t" --plugin-root "$root" >/dev/null || fail "export-platform --target $t failed"
done

# AGENTS.md: every command and agent, by absolute path.
idx="$tmp/agents-md/AGENTS.md"
[ -f "$idx" ] || fail "agents-md wrote no AGENTS.md"
[ "$(grep -c '^- `/wp-' "$idx")" = "$ncmd" ] || fail "AGENTS.md does not list every command ($ncmd)"
[ "$(grep -cE '^- `wp-[a-z0-9-]+` — ' "$idx")" = "$nagent" ] || fail "AGENTS.md does not list every agent ($nagent)"
grep -F >/dev/null -- "— \`$root/commands/wp-section.md\`" "$idx" || fail "AGENTS.md does not point at the command file by absolute path"
grep -F >/dev/null -- "\`$root/agents/<agent>.md\` and do that work yourself" "$idx" || fail "AGENTS.md does not say how to run a subagent step"

# Cursor: one .mdc per command, attached on request, paths absolute.
rules="$tmp/cursor/.cursor/rules"
[ "$(find "$rules" -name '*.mdc' | wc -l)" = "$ncmd" ] || fail "cursor did not write one rule per command"
for f in "$rules"/*.mdc; do
  [ "$(sed -n 1p "$f")" = '---' ] || fail "$(basename "$f") has no frontmatter"
  grep -F >/dev/null 'alwaysApply: false' "$f" || fail "$(basename "$f") is not attached on request"
  grep -E >/dev/null '^description: ".+"$' "$f" || fail "$(basename "$f") has no description"
  grep -F >/dev/null '${CLAUDE_PLUGIN_ROOT}' "$f" && fail "$(basename "$f") still says \${CLAUDE_PLUGIN_ROOT}"
done
grep -F >/dev/null "$root/skills/wp-section-run/references/" "$rules/wp-section.mdc" || fail "wp-section.mdc lost its absolute reference paths"
grep -F >/dev/null 'do that agent'"'"'s work yourself' "$rules/wp-yolo.mdc" || fail "the cursor rule has no subagent preamble"

# Gemini: GEMINI.md plus one TOML command each, parsed by a real TOML reader.
[ -f "$tmp/gemini/GEMINI.md" ] || fail "gemini wrote no GEMINI.md"
python3 - "$tmp/gemini/.gemini/commands" "$ncmd" <<'PY' || fail "gemini TOML commands are not valid"
import glob, sys
try:
    import tomllib
except ImportError:
    print("SKIP-TOML"); sys.exit(0)
files = sorted(glob.glob(sys.argv[1] + "/*.toml"))
if len(files) != int(sys.argv[2]):
    sys.exit(f"{len(files)} TOML files for {sys.argv[2]} commands")
for f in files:
    d = tomllib.load(open(f, "rb"))
    if set(d) != {"description", "prompt"}:
        sys.exit(f"{f}: keys {sorted(d)}")
    p = d["prompt"]
    if "${CLAUDE_PLUGIN_ROOT}" in p or "$ARGUMENTS" in p:
        sys.exit(f"{f}: an unported placeholder is left")
    if "{{args}}" not in p:
        sys.exit(f"{f}: no {{args}}")
PY

# quoted(): DEL, a C1 control and a lone surrogate still give a string TOML accepts.
TOOL="$(cd "$(dirname "$tool")" && pwd)/$(basename "$tool")" node -e '
  import(process.env.TOOL).then((m) => {
    process.stdout.write("v = " + m.quoted("a\u007fb \ud800 c\u0085 \"q\" \\ d") + "\n");
  });' >"$tmp/q.toml" || fail "quoted() threw"
python3 - "$tmp/q.toml" <<'PY' || fail "quoted() wrote a string TOML rejects: $(cat "$tmp/q.toml")"
import sys
try:
    import tomllib
except ImportError:
    sys.exit(0)
v = tomllib.load(open(sys.argv[1], "rb"))["v"]
assert v == 'a\x7fb � c\x85 "q" \\ d', repr(v)
PY

# Nothing in the plugin changed.
[ "$(git diff -- commands agents skills | sha256sum)" = "$before" ] || fail "export-platform changed a plugin file"

# Exit codes.
rc=0; node "$tool" "$tmp/x" >/dev/null 2>&1 || rc=$?
[ "$rc" = 64 ] || fail "no --target must exit 64 (got $rc)"
rc=0; node "$tool" --target cursor "$tmp/x" --plugin-root "$tmp/empty" >/dev/null 2>&1 || rc=$?
[ "$rc" = 2 ] || fail "a plugin root with no commands/ must exit 2 (got $rc)"

need_token docs/plugin-code.md '`export-platform.mjs`'
need_token BACKLOG.md 'tests/checks/export-platform.sh'
echo "PASS: export-platform writes AGENTS.md, Cursor rules and Gemini commands for every command, paths absolute"
