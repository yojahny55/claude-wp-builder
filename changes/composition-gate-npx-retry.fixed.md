- **The composition gate retries the detector once on an empty payload.** `impeccable@4`
  is resolved against the registry on every run, so a dropped connection left an empty
  findings file and failed the gate (and its check) as "could not scan", then passed on the
  next run. An empty answer is now retried once; any JSON the detector returns is used as is.
