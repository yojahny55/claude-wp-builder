- **A clone audit and vendor-code noise no longer inflate the headline.** On a local clone,
  SEC-036 is an `INFO` pre-deploy gate (listed as a push blocker, `guid` rows never searched or
  counted), database schema and data findings cap at `WARNING` with "confirm on prod" after
  reading the sync tool's exclude list, transport findings measured on the local server are
  "local server only, unverified on prod" and not counted, the scheme the local host answers is
  probed before HTTP checks, and WP-040 and WP-045 are `INFO`. In `code_scope.read_only`, only
  vulnerability, update and abandoned-plugin checks produce findings; pattern hits collapse into
  one `vendor notes` INFO line per plugin. A finding must carry a catalog code (no shard-local
  labels), and hits with one root cause are grouped before counting.
