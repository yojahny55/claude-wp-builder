- **`woo-launch-integration` no longer fails at random on the wrong-host assertion.** Its
  snapshot of the store's options counted `cron` and Action Scheduler's
  `action_scheduler_lock_*`, which WordPress rewrites on its own while the fixture serves
  requests, so "a wrong --confirm changed the store" failed once with no change to the
  launch (a rerun passed). Those scheduler options are left out, any other changed option
  still fails, and a failure now names the options that changed.
