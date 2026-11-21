- **Network tool edges.** `link-sweep` now reports a redirect cycle (a target already
  requested in the chain) as `broken` with the reason "redirect loop", while a long chain of
  distinct URLs stays `unmeasured` at the 5-hop cap. `h2-proxy` keys its HTML cache on the
  request cookies and `Accept-Language` as well as the URL, so pages that vary by a language
  cookie are no longer served crossed, and it no longer caches responses carrying `Set-Cookie`
  or `Cache-Control: no-store`/`private`. The suite preload keeps the third-party block closed
  when `BASE_URL` is missing (it protects production properties) but now says so on stderr
  instead of blocking every host silently.
