- **Post-deploy canary in `/wp-update`.** New `bin/canary.mjs` snapshots a live site's key
  pages (status, console errors, failed same-site requests, landmarks) and compares the
  snapshot taken before a push with the one taken after; `/wp-update` Step 8 runs it around
  each staging and production push, and a regression stops the promotion. Before, `/wp-update`
  verified only the root it ran on, so an update that broke the live site after `git push`
  (a 404 stylesheet, a script error) went unnoticed until someone opened the page.
