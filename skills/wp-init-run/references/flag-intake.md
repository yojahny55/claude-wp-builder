# /wp-init — Step 0.4

`commands/wp-init.md` sends the run here at Step 0.4 (Flag intake). Follow it in order; nothing in it is optional background.

Parse these flags from `$ARGUMENTS` before asking anything. This is the single owner of their
values; `/wp-cinematic-init` hands off through exactly this list and no other.

| Flag | Effect |
|---|---|
| `--path=<dir>` | Sets `${PROJECT_PATH}`, the WordPress project root. |
| `--mode=cinematic` or `--starter=__cinematic__` | Presets `$TEMPLATE = cinematic` and marks the run as **entered from `/wp-cinematic-init`**: no dispatch back, no kit resolution, no agent, scenes or seeding. |
| `--template=cinematic` | Presets `$TEMPLATE = cinematic` only. It does NOT mark a caller (a user can type it directly), so the run still dispatches to `/wp-cinematic-init`. `--template=tailwind` presets `$TEMPLATE = tailwind`. `--template=basic` is the `tailwind` alias. |
| `--acf-flavor=scf` or `--acf-flavor=acf-pro` | Presets `$CF_PLUGIN`: `scf` stays `scf`, `acf-pro` becomes `acf` (the value Step 0.6 records). |
| `--no-hybrid` | Passed through to the cinematic branch: no trailing flex sections. Hybrid is on when the flag is absent, and there is no `--hybrid` spelling. |

A preset value is final: **skip Step 0.5 when `$TEMPLATE` is preset and Step 0.6 when `$CF_PLUGIN` is
preset**, and do not ask again. An empty `--acf-flavor=` counts as absent (ask Step 0.6). A non-empty unknown value for
either flag is an error: print it and stop, rather than silently asking.
