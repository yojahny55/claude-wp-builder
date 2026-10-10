# Source this file, then call `expand_command commands/<name>.md`; it sets EXPANDED to the
# path of the command as a run reads it: every paragraph that sends the run to
# `skills/<skill>/references/<file>.md` is followed by that file's body.
#
# A big command keeps its step headings and moves each step's detail to a reference file.
# The checks that guard a step's wording still assert it "in the command", and still anchor
# on `## Step N:` headings to scope a grep to one step, so they read the expanded text.
# tests/checks/wp-audit-run.sh is what proves every reference is pointed to at its step.
#
# The output is keyed by a hash of its inputs, this script included, so repeated calls reuse
# one file, a change to the expansion itself is never served from a stale copy, and no check
# needs an EXIT trap of its own to clean it up.
#
# A pointer to a reference that cannot be read exits the calling check. Returning instead
# would leave the caller grepping a missing body, where an assertion of absence passes.

expand_command() {
  local src=$1 refs dir out sum r
  refs=$(grep -oE 'skills/[a-z0-9-]+/references/[a-z0-9-]+\.md' "$src" | awk '!seen[$0]++')
  for r in $refs; do
    [ -r "$r" ] || { echo "expand-command: $src points to missing $r" >&2; exit 1; }
  done
  sum=$( { cat "${BASH_SOURCE[0]}" "$src"; for r in $refs; do cat "$r"; done; } | sha256sum | cut -c1-16)
  dir="${TMPDIR:-/tmp}/cwb-expanded"
  out="$dir/$(basename "$src" .md)-$sum.md"
  mkdir -p "$dir"
  if [ ! -s "$out" ]; then
    awk '
      function body(f,   line, n, hdr, rc) {
        # Skip the reference file own header: the title, the sentence naming the step that
        # reads it, and the Contents list. The body starts at the first other line.
        hdr = 1
        while ((rc = (getline line < f)) > 0) {
          n++
          if (hdr) {
            if (n == 1 || line == "" || line ~ /^`commands\// || line == "## Contents" || line ~ /^- /) continue
            hdr = 0
          }
          print line
        }
        if (rc < 0) { print "expand-command: cannot read " f > "/dev/stderr"; exit 1 }
        close(f)
        print ""
      }
      {
        print
        if (match($0, /skills\/[a-z0-9-]+\/references\/[a-z0-9-]+\.md/)) pending = substr($0, RSTART, RLENGTH)
        if ($0 == "" && pending != "") { body(pending); pending = "" }
      }
      END { if (pending != "") { print ""; body(pending) } }
    ' "$src" > "$out.$$" || { rm -f "$out.$$"; exit 1; }
    mv "$out.$$" "$out"
  fi
  EXPANDED=$out
}
