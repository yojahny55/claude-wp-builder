- **Seven commands have room to grow again.** `/wp-create`, `/wp-audit` and `/wp-init`
  sat 20 to 62 bytes under the size ceilings their `*-run` checks enforce, and
  `/wp-clone`, `/wp-tailwind-migrate`, `/wp-yolo` and `/wp-seed` were within 1.3 KB.
  Detail that only some runs read moved to each command's `skills/<command>-run/references/`
  (filesystem permissions and the `detect` output for `/wp-create`, manifest drift for
  `/wp-audit`, menu registration for `/wp-init`, the clone's mail capture, the Tailwind
  migration's visual golden, the seed's placeholder pages), and `/wp-yolo` lost repeated
  rationale. Every command now has at least 2 KB under its ceiling; no ceiling moved.
