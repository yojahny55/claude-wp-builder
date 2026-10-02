#!/usr/bin/env bash
# wp-quiet.sh <command...> -- run a WP-CLI command and print its stdout without the PHP
# diagnostics a noisy plugin writes there. Keeps the command's exit code.
#
#   bin/wp-quiet.sh wp --path=/srv/http/site option get home
#
# Strips, from stdout only: "[PHP ]Notice|Warning|Deprecated|Strict Standards: ... on line N"
# (or "... in /path") lines, their "<b>...</b>" HTML form, and the "Stack trace:" / "#N ..." /
# "thrown in ..." lines that follow one. A "#N" line is dropped only right after a diagnostic.
# stderr is untouched, so a real error still reaches the caller. This hides diagnostics; it
# does not fix them.
set -uo pipefail
[ $# -gt 0 ] || { echo "usage: wp-quiet.sh <wp command...>" >&2; exit 64; }
"$@" | perl -ne '
  # Only a line carrying a PHP diagnostic marker is noise. A bare "Warning: sale ends" or a
  # "#1 Best seller" title is real output and survives.
  my $diag = /^(?:PHP\s+)?(?:Notice|Warning|Deprecated|Strict Standards|Fatal error)\b.*?:/
    && (/ on line \d+/ || /\bin \//);
  my $html = /^(?:<br \/>\s*)?<b>(?:Notice|Warning|Deprecated|Strict Standards)<\/b>:/;
  if ($diag || $html) { $trace = 1; next; }
  if (/^\s*Stack trace:/ || ($trace && /^\s*(?:#\d+ |thrown in )/)) { $trace = 1; next; }
  $trace = 0;
  print;'
exit "${PIPESTATUS[0]}"
