- **`/wp-contribute pr` runs the OCR review before the push, and fix flows check the git tree.**
  The local flow opened PRs without the diff review CI already runs, and `review` (a skill
  review) read as if it were that step; both now say what each one does, and a missing `ocr`
  stops the flow instead of being installed. `/wp-update` and the `/wp-audit` fix step now
  show foreign uncommitted changes and ask before editing, commit by path, stop on a mass
  deletion before committing, and report the unreviewed commit count at the end.
