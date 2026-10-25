- **`/wp-audit` no longer applies fixes that change how a site looks without asking.** The fix
  offer split work by owner (code, setting, content) but not by whether the render changes, so
  a "y" also applied CSS focus styles, size and spacing changes and tag or class swaps, which
  were never measured. Findings now carry `design_impact`, shown in the report; those marked
  `true` form a `visual` class that is never counted as auto-fixable, is listed with its
  computed-style and box measurement first, and is applied one at a time and re-measured. When
  the site's builder has a control for the setting, the fix goes to the builder's data (backed
  up first) rather than the theme's CSS, unless the control cannot express it.
