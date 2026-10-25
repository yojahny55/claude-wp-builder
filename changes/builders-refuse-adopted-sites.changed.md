- **Builders stop on adopted sites.** `/wp-init`, `/wp-section`, `/wp-seed`, `/wp-yolo`,
  `/wp-header`, `/wp-footer`, `/wp-page`, `/wp-cpt`, `/wp-settings`, `/wp-tailwind-migrate`
  and the three `/wp-cinematic-*` builders assume a starter theme and never read `origin`,
  so on an adopted site (a third-party theme) they could overwrite it or generate a theme that
  does not belong. Each now runs the new `wp-config.mjs require-origin` first, which exits `5`
  on an adopted manifest; `--force-adopted` overrides it on purpose. `/wp-audit`, `/wp-debug`,
  `/wp-update`, `/wp-clone` and the other non-builders are not gated.
