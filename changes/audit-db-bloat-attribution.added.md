- **PERF-071 to PERF-074 attribute database bloat to the plugin that causes it.** PERF-061 to
  PERF-064 count rows but never say whose they are, so a real store kept 1.9 million pending
  Action Scheduler actions from ad-platform plugins that were never connected (about 2 GB), 739,000
  temporary options from one cart-recovery plugin, a 289,340-row Rank Math 404 log, and 23
  autoloaded options of removed plugins. PERF-071 groups pending actions by group and hook prefix
  and flags a backlog over 10,000 or one whose plugin is off or removed. PERF-072 flags one name
  prefix over 10,000 `options` rows. PERF-073 sizes `rank_math_404_logs` and reads the monitor
  mode and limit (PERF-060 only checks the table exists). PERF-074 lists autoloaded options whose
  owner is not installed. All reads, every fix needs approval and a backup, and a clone-suppressed
  plugin counts as active so a clone and production agree. `tests/checks/audit-db-bloat.sh` covers
  them.
