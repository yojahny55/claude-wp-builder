- **Mobile-only elements now get their desktop override.** `wp-css` never stated that an
  element shown only on mobile needs a `min-width` rule to hide it (`display: none`) or to
  dissolve its wrapper (`display: contents`), so such blocks stayed visible or broke the
  inline flow on desktop. The agent now has the rule with an example, a list-and-confirm step
  before it returns, and a check keeps both in place.
