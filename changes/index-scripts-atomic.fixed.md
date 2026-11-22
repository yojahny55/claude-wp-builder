- **Index and import scripts no longer truncate versioned files, and the gate no longer skips a bad composition.**
  `design-md-index.sh` and `domains-import.sh` wrote straight into tracked files, so a
  python or awk failure midway left them truncated (and `domains-import.sh` had already
  replaced the licence and source record). Both now build into temporaries and rename at
  the end, with a trap removing leftovers. `design-md-index.sh` matches `api` and `car` as
  whole words instead of inside "capital", "rapid", "card" or "care", which mislabelled
  industries. `composition-gate.sh` treats a composition missing `section.html` or
  `section.css` as a failure (exit 1, like truncated content) instead of skipping it.
