# Testing

How the contract checks in `tests/checks/` run, what CI adds on top of them, and what none of it covers. `CLAUDE.md` keeps the commands; the reasoning lives here.

Each check is a standalone bash script that prints `PASS` or exits non-zero. No runner, no framework.

```bash
bash tests/checks/wp-yolo-gate.sh                    # one check
bash tests/run.sh                                    # all checks, in parallel (-j N, --exclude "...")
for f in tests/checks/*.sh; do bash "$f"; done       # all checks, serially
```

The browser checks (`demo-verify-engines.sh` and the others that drive a browser) need a
`playwright-core` and an existing Playwright Chromium/Firefox build. Without them they still
print `PASS`, but the skip line says the browser path was NOT exercised. To run them for real
without installing anything, point `PLAYWRIGHT_CORE` at a playwright-core already on the
machine, for example the one inside a global `@playwright/test`:

```bash
PLAYWRIGHT_CORE="$(npm root -g)/@playwright/test/node_modules/playwright-core" \
  bash tests/checks/demo-verify-engines.sh
```

`tests/checks/wp-polylang-live.sh` is the only test that touches a real site; it exits 0 with
`SKIP` unless `PLL_TEST_SITE` points at a WordPress root with Polylang active
(`PLL_TEST_SRC`/`PLL_TEST_DST`/`PLL_TEST_THIRD` override the languages; the third language is
created and deleted by the suite and is guarded by a pre-existence probe).

`.github/workflows/ci.yml` runs all of it on every pull request: the checks above (all of
them, aggregated — it does not stop at the first red), `node --check` on `bin/*.mjs`,
`php -l` on every PHP file, `bash -n` on every `bin/`, `skills/` and `tests/` shell script (plus a
blocking `shellcheck`, see `.shellcheckrc`), and `bin/doc-sync-check.sh`. Run the checks yourself before
claiming a change works. Shell scripts that run `sudo`, `rm` or `sed` on user-derived input are
tested with hostile arguments through the stub PATH in `tests/lib/stub-path.sh`
(`tests/checks/hostile-input-env-setup.sh` is the model). CI is the net under that, not a replacement for it.

**Mutation pass (manual, not a check).** `bash tests/mutation.sh [-n 15] [-s seed] [-c "a.sh b.sh"]`
samples contract checks that grep `need <file> "<token>"` (seeded, so a run repeats), copies the
repo to a temp dir, deletes the first line holding one required token and expects the check to
FAIL on the copy; a check that still passes is a survivor (its token also sits in a comment or
another line). The real tree is never touched. Only checks with a literal path and plain token
are eligible. `tests/checks/mutation-harness.sh` proves the harness catches a mutant and leaves
the tree unchanged. `seeded-defects.sh` compares against the committed `recorded-findings.json`
(plus a case with one finding removed) so the comparison logic always runs; `SEEDED_FINDINGS`
still compares a real audit run.

**The PHP lint is version-pinned, and that is the point.** It lints at **7.4** — the floor
`skills/wp-polylang/scripts/*.php` carry, because they run via `wp eval-file` inside
whatever WordPress the client has — with `starter-theme/__cinematic__/` held to **8.0**,
the floor it declares in its own `style.css`. The runner's default PHP is 8.x, and `php -l`
under 8.x accepts `match`, union types and nullsafe calls, every one of which is a fatal
parse error on 7.4; linting at the default would be green and wrong, which is worse than
not linting, because it reads as proof. Nothing in the tree uses 8.0-only syntax today, so
adding some fails CI and raising a floor stays a deliberate act.

**CI now stands up a WordPress, for one thing.** `tests/fixtures/wp/provision.sh` builds a
disposable install — pinned WordPress, Polylang and SCF, against a database from a CI
service container or a throwaway docker container locally — and
`tests/checks/wp-polylang-integration.sh` runs the ACF translation path inside it, then
tears the whole thing down. It skips unless `WP_FIXTURE=1`, because provisioning downloads
WordPress and making that the price of running the suite would mean people stop running it.

That job is the only place here that reaches the network on purpose: a WordPress fixture
cannot exist without a WordPress. Every version is pinned so an upstream release cannot
change a result, and nothing it installs is asserted against — every assertion runs against
the local install.
And only while provisioning: once the downloads are done, `tests/fixtures/wp/net-guard.php`
is installed as a must-use plugin that refuses every host but loopback and logs each attempt
to `wp-content/net-guard.log`, so no fixture check can pass or fail because a real service
answered.

It pays for itself. Its first two runs found two defects no contract grep and no pure test
could reach: `get_field_object()` returns false on a post with no value for the field, so
the translation writer skipped every write to a brand-new counterpart; and
`PLL()->model->add_language()` is defined only on `PLL_Admin_Model`, which Polylang
instantiates only when `is_admin()` is true — never under `wp eval-file`, which is how
every script in `skills/wp-polylang/scripts/` is documented to run.

The same fixture backs `tests/checks/wp-cf7-delivery.sh`, which posts to Contact Form 7's
own REST endpoint and asserts what arrived: mail is captured by a `pre_wp_mail` must-use
plugin, so a valid submission's mail can be read and checked while nothing can reach a real
inbox, and a submission missing a required field must be refused *and* send nothing. A form
that renders perfectly and delivers nothing costs a client enquiries before anyone notices,
and no grep over `agents/wp-cf7.md` can see it.

**Screenshots are compared against approved baselines, inside a pinned renderer.**
`tests/checks/visual-baselines.sh` renders the motion fixtures and a colour-and-type page
(`tests/fixtures/motion/type.html`) and diffs them against committed PNGs, reporting the percentage of differing pixels on every shot rather than
only on a failure — the tolerance is 0.1%, and a number nobody can see is a number nobody
can argue with. It runs inside `mcr.microsoft.com/playwright:v1.63.0-noble`, not the
runner's Chrome, because pixels do not survive a browser upgrade the way a DOM assertion
does; `RENDERED-BY.txt` records the image and the check refuses to compare across a
different one.

Three limits come with it, and all three are the shape of the thing rather than bugs.
**The pairs are motion-engine pairs, not demo/theme pairs** — I06 asks for a demo compared
against the theme built from it, and that needs a generated site, which is still the gap
below. **Only settled states are photographed**, because determinism requires waiting for
motion to stop: breaking the reveal so it never hides its children changes nothing any
baseline can see, and `motion-devices.sh` catches that one instead, by name. **A one-step
colour tint on text is below what pixels see.** The type page has four mutants, each one
token changed (body text two grey steps lighter, the heading's family, the button colour,
the lead's size), and the comparer fails unless every one differs from the baseline by
more than the tolerance (measured 0.37% to 2.06%). One grey step on thin glyphs measures
0.0000%, under pixelmatch's per-pixel threshold; that change belongs to the parity gate
and `bin/style-diff.mjs`, which compare computed styles. A failed run keeps the diffs and
the rendered shots in a `.failed-diffs/` folder under `tests/baselines/`, ignored by git; approving a new or
changed baseline means copying its PNG from `rendered/` in a `baseline: <why>` commit.

Still not covered: a generated site end to end, the broken-site corpus with expected audit
findings, and browser artifacts for failed functional scenarios. A green CI means the
contracts still say what they should, the code still parses, and the ACF translation path
still agrees with a real WordPress.

## Writing a check

Source `tests/lib/assert.sh` instead of redefining helpers: `fail`, `skip` (prints `SKIP: ...`,
exit 0, which `run.sh` counts apart from PASS), `need_token FILE TOKEN [MSG]` and
`require_tool php python3 curl`, which skips when a tool is missing. CI sets
`CHECKS_REQUIRE_TOOLS=1` so a runner that lost php fails instead of skipping. Checks start
with `set -euo pipefail` and `cd ... || exit 1`, and must be executable in git.
`assert-lib-adoption.sh` fails a new check that defines its own `fail()`; the older ones are
frozen in `tests/checks/lib/fail-allowlist.txt` and leave it as they are migrated.
