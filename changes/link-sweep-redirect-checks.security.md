- **`bin/link-sweep.mjs` checks every redirect hop, not only the original link.** Redirects
  were followed automatically, so a link on the site that redirected to the clone-origin host
  was requested without `--follow-clone-origin`, and a redirect to a link-local or metadata
  address was followed. Redirects are now followed by hand (at most 5 hops) and each target is
  checked first:
  the clone origin needs `--follow-clone-origin`; link-local and metadata addresses are refused
  by their literal spelling (IPv4-mapped IPv6 such as `::ffff:169.254.169.254`, and
  `fd00:ec2::254`, included) and, for a hostname, by every address it resolves to at check time;
  a private or loopback host (literal or resolved) is refused unless the swept site is itself
  on one. A failed lookup leaves the link `unmeasured` with the reason. DNS rebinding between
  that lookup and the request itself is not closed. A refused hop leaves the link `unmeasured`
  with the reason.
