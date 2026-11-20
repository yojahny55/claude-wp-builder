- **`bin/link-sweep.mjs` checks every redirect hop and the original link itself.** Redirects
  were followed automatically, so a link on the site that redirected to the clone-origin host
  was requested without `--follow-clone-origin`, and a redirect to a link-local or metadata
  address was followed. Redirects are now followed by hand (at most 5 hops) and each target is
  checked first, and the original link is checked the same way before its first request (a page
  linking straight to a metadata address or a private host from a public site is `unmeasured`):
  the clone origin needs `--follow-clone-origin`; link-local and metadata addresses are refused
  by their literal spelling (IPv4-mapped IPv6 such as `::ffff:169.254.169.254`, and
  `fd00:ec2::254`, included) and, for a hostname, by every address it resolves to at check time;
  a private or loopback host (literal or resolved) is refused unless the swept site is itself
  on one, which is judged by what the site's host resolves to (a dev name that `/etc/hosts`
  points at loopback is local) and not by its spelling alone. A failed lookup leaves the link `unmeasured` with the reason. DNS rebinding between
  that lookup and the request itself is not closed. A refused hop leaves the link `unmeasured`
  with the reason.
