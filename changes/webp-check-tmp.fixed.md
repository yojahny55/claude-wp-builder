- **`webp-on-upload` no longer fails at random under `tests/run.sh -j 8`.** Its check for
  leftover temporary files ran `find` over the shared `/tmp` while parallel checks deleted
  their own files there; `find` then exited 1, and under `set -e` the check stopped with no
  message (4 of 47 runs during a parallel suite). Each case now runs PHP with a private
  `TMPDIR` and looks only there, so a leftover file still fails it and a neighbour cannot.
