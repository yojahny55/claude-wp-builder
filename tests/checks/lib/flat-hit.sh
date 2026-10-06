# Sourced by the checks that match prose, never run on its own. Each file is flattened to one
# line, so a phrase wrapped across two lines still matches -- and flattened on its own, so a
# match can never span the end of one file and the start of the next.

# flat_of <file>: the file's text on one line, runs of spaces squeezed.
flat_of() { tr '\n' ' ' < "$1" | sed 's/  */ /g'; }

# flat_hit <needle> <file>...: prints every file whose flattened text contains <needle>.
flat_hit() { local n=$1; shift; local f; for f in "$@"; do flat_of "$f" | grep -qF -- "$n" && echo "$f"; done; return 0; }
