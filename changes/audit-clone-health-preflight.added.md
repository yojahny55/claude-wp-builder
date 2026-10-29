- **/wp-audit checks that a local clone serves its own pages before any agent runs.** A clone
  of a site served by nginx has no `.htaccess`, so on the local Apache every permalink 404ed
  while the home page answered 200, and the page measurements of the run were silently wrong
  until a person asked. `bin/clone-preflight.sh` (Step 2.3) requests a post, a page and a
  category archive on the audited host and requires 200, reports whether the host answers http
  or https (passed to every agent as `Audited scheme:`), diagnoses a missing, empty or
  WordPress-less `.htaccess` (noting that `wp rewrite flush --hard` writes nothing under
  WP-CLI), and, only after the user agrees, backs up the file and appends the stock rewrite
  block as a local-only change kept out of git. If it fails and the user declines, page-based
  checks are `UNMEASURED` with the reason.
