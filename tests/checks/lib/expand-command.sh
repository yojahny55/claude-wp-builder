# Source this file, then call `expand_command commands/<name>.md`; it sets EXPANDED to the
# path of the command as a run reads it: every paragraph that sends the run to
# `skills/<skill>/references/<file>.md` is followed by that file's body.
#
# A big command keeps its step headings and moves each step's detail to a reference file.
# The checks that guard a step's wording still assert it "in the command", and still anchor
# on `## Step N:` headings to scope a grep to one step, so they read the expanded text.
# tests/checks/wp-audit-run.sh is what proves every reference is pointed to at its step.
#
# The output is keyed by a hash of its inputs, so repeated calls reuse one file and no
# check needs an EXIT trap of its own to clean it up.

expand_command() {
  local src=$1 refs dir out sum
  refs=$(grep -oE 'skills/[a-z0-9-]+/references/[a-z0-9-]+\.md' "$src" | awk '!seen[$0]++')
  sum=$( { cat "$src"; for r in $refs; do cat "$r"; done; } | sha256sum | cut -c1-16)
  dir="${TMPDIR:-/tmp}/cwb-expanded"
  out="$dir/$(basename "$src" .md)-$sum.md"
  mkdir -p "$dir"
  if [ ! -s "$out" ]; then
    awk '
      function body(f,   line, n, hdr) {
        # Skip the reference file own header: the title, the sentence naming the step that
        # reads it, and the Contents list. The body starts at the first other line.
        hdr = 1
        while ((getline line < f) > 0) {
          n++
          if (hdr) {
            if (n == 1 || line == "" || line ~ /^`commands\// || line == "## Contents" || line ~ /^- /) continue
            hdr = 0
          }
          print line
        }
        close(f)
        print ""
      }
      {
        print
        if (match($0, /skills\/[a-z0-9-]+\/references\/[a-z0-9-]+\.md/)) pending = substr($0, RSTART, RLENGTH)
        if ($0 == "" && pending != "") { body(pending); pending = "" }
      }
      END { if (pending != "") { print ""; body(pending) } }
    ' "$src" > "$out.$$" && mv "$out.$$" "$out"
  fi
  EXPANDED=$out
}
