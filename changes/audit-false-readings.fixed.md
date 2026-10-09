- **Three readings that reported defects a site did not have.** The `wp-agentic-surfaces`
  markdown template now puts back the page `<h1>` when a theme prints it before `<main>`, and turns a
  form into "Form on this page. Fields: ..." instead of stripping it, so a contact page whose
  `<main>` holds only a form is no longer empty. `wp-audit-a11y` reads focus styles after the
  focus transition ends: a theme that animates its outline was reported with the colour from
  the middle of the animation. `/wp-clone` Step 6.2 warns that Elementor's local Google Fonts
  CSS under uploads keeps the original host's URLs, so the clone renders a fallback font and a
  visual comparison with production shows false differences.
