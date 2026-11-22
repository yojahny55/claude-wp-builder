# /wp-demo-verify — Step 2a

`commands/wp-demo-verify.md` sends the run here at Step 2a. Follow it in order; nothing in it is optional background.

`impeccable` is an external package this repo does not install, vendor or
configure — it is fetched from the npm registry at run time via `npx`, as
`impeccable@latest`: it follows the newest release on purpose, so new rules are
answered rather than frozen out. The price is that a release can change rule
identifiers or the output shape, so anything this step does not recognise is a
detector that could not run, never a clean scan: a top level that is not an
array of findings, a finding that is not an object or lacks `antipattern` or
`file`, a `category` other than `slop`/`quality`, a `severity` other than
`warning`/`advisory`, or an exit code that disagrees with the payload (`2`
without a `warning` finding, `0` with one). `bin/composition-gate.sh` enforces
the same rule for the composition library.

The exit code says whether the scan ran, not how many findings it made: `0`
is a clean or advisory-only scan, `1` means a requested target could not be
scanned at all, `2` means the scan completed and found at least one
non-advisory finding — findings do not fail the process the way a linter's
would, so a nonzero exit does not by itself mean "could not run." Only exit
`1` is that case; treat it, any other exit code, a missing `npx`/no network
reaching the registry, or stdout that fails to parse as JSON the same way:
report **"detector could not run"** and fail the round on that basis, never
read as zero findings. Human-readable text goes to stderr, so the redirect
above captures only the JSON on stdout, which is what findings are counted
from — never the exit code.

Once the array parses: sixty-one deterministic rules, no model, each finding
carrying a `category` (`slop` or `quality`) and a `severity`. A `slop` finding
with `severity: "warning"` fails the round outright, before a screenshot is
taken — that is the AI-tell axis and the real gate. The tool's help also
describes an `advisory` soft-signal tier, though no finding carrying it has
been reproduced here (an em-dash-dense file, which that help names as an
advisory rule, returned zero findings): **if the tool emits an advisory tier,
a finding flagged with it is listed but does not by itself fail the round**,
matching the detector's stated design that advisories never block automation.
The gate does not rest on that, because it keys on `slop` plus `warning`
directly. `quality` findings are listed in the
report and fixed when the rubric below also flags the same section, but do
not by themselves fail a round. A target that is a URL is scanned with
Puppeteer by the detector itself; a file or directory is scanned statically.
Run against the demo that motivated this gate, the detector found twenty
issues, seven of them `slop`; run against this library's own `hero-split`
composition, it returns an empty array.
