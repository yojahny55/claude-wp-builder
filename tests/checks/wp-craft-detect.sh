#!/usr/bin/env bash
# Impeccable's detector is the deterministic half of the loop: 61 rules, no
# model, exit codes a build can act on. It is an external package this repo
# does not install, vendor or configure, so a missing binary, an offline
# machine or a rate-limited registry must never look like a clean scan — this
# pins the major-version guard (impeccable@1 404s; @4 is the real latest) and
# the distinct "could not run" message that keep that failure mode from
# passing as zero findings. It also pins the real finding shape: the tool has
# no P0 severity, only a category (slop/quality) and an advisory flag, and a
# nonzero exit does not by itself mean findings — exit 2 means findings, exit
# 1 means a target could not be scanned. If the command stops naming any of
# this, the refuse list that used to live in taste.md is enforced nowhere.
set -euo pipefail
cd "$(dirname "$0")/../.."
fail() { echo "FAIL: $*"; exit 1; }

c=commands/wp-demo-verify.md
d=commands/wp-demo.md

grep -Eq 'impeccable@4' "$c" || fail "$c does not pin the detector to the real major version (4, not the nonexistent 1)"
grep -Fq -- '--json' "$c" || fail "$c does not ask the detector for JSON"
grep -Fq 'impeccable.json' "$c" || fail "$c does not save detector findings under .verify"
grep -Fq 'slop' "$c" || fail "$c does not gate on the real 'slop' category"
# The advisory tier is documented by the tool but was never reproduced against
# this library, so the command must state it conditionally rather than as
# observed fact. Anchored to the conditional, not to the bare word: 'advisory'
# alone stays green if the hedge is deleted and the tier reasserted as certain.
grep -Fq 'if the tool emits an advisory tier' "$c" \
  || fail "$c states the advisory tier as observed fact instead of conditionally"
if grep -Fq 'P0' "$c"; then fail "$c still says P0, a severity impeccable never emits"; fi
grep -Fq 'demo/VERIFY.md' "$c" || fail "$c does not write the score card"
grep -Eqi 'external (package|dependency)' "$c" || fail "$c does not say the detector is an external dependency this repo does not vendor"
grep -Eqi 'could not run|could not be performed' "$c" || fail "$c does not fail loudly, and distinctly from zero findings, when the detector cannot run at all"
for line in 'First paint complete' 'One peak' 'Squint test' 'Contrast, read from the frame' 'Mobile headline' 'Adjacent feelings' 'Name-swap'; do
  grep -Fq "$line" "$c" || fail "$c rubric is missing: $line"
done
grep -Fq 'feel check' "$c" || fail "$c dropped the feel check that the old Step 4 required"
grep -Fq 'impeccable detect' "$d" || fail "$d does not run the detector inside the craft loop"

# The three kinds must be distinguishable in the walker itself, not just named in
# prose. `reveal` publishing nothing samplable is why dead-scroll fired on every
# library-built section; conflating that with real dead scroll is the defect.
v=bin/demo-verify.mjs
# Every pin below greps a JS file, and a JS file has comments: writing
# `<broken code> // <original line>` leaves a plain grep for the original green
# while the code it names is gone. All ~27 pins on this file fell to that, one of
# them re-opening the dead-engine regression round 3 of Task 3 closed. So grep a
# comment-stripped copy instead of the source, and a parked literal stops being a
# match. Block comments first; then a `//` run that is neither part of a URL
# (`http://`) nor an escaped slash inside a regex literal (`\/\/`).
vs="$(mktemp)"
trap 'rm -f "$vs"' EXIT
perl -0pe 's{/\*.*?\*/}{}gs' "$v" | perl -pe 's{(?<![:\\/])//.*$}{}' > "$vs"
grep -Fq "kind: 'unobserved'" "$vs" \
  || fail "$v does not emit an unobserved finding, so an unreadable section is still reported as dead"
grep -Fq "kind: 'no-engine'" "$vs" \
  || fail "$v does not emit a no-engine finding, so a page with no devices still walks clean"
# The other half of the split, and the one that costs more when it is wrong:
# drive() is required to publish --motion-p for the SCRUB devices, so a stalled
# section carrying one with nothing samplable is an engine that never ran, not a
# device the harness cannot read. Routing that to advisory shipped a broken page
# green — the exact file://-blocked-module failure this branch exists to fix.
grep -Fq 'frame.samplable === 0 && !b.scrub' "$vs" \
  || fail "$v routes a scrubbed section with nothing samplable to advisory, so a page whose motion engine never ran exits 0"
grep -Fq "data-motion') === 'reveal'" "$vs" \
  || fail "$v does not sample the reveal device, so every reveal-only section reports dead scroll"
for f in skills/wp-demo-craft/references/verify.md commands/wp-demo-verify.md; do
  grep -Fq 'unobserved' "$f" || fail "$f does not document the unobserved finding"
  grep -Fq 'no-engine' "$f" || fail "$f does not document the no-engine finding"
done

# A stall walk asks "did the signature change across N samples", which is the
# right question for a scrubbed device and the wrong shape for reveal: reveal is
# a one-shot entry transition a few pixels long, so a sparse walk catches it by
# luck and a miss is the false dead-scroll this whole finding exists to avoid.
# Reveal is judged by two samples instead, and the walk's own dead-scroll push
# must stay behind the scrubbed branch or the false positive comes straight back.
grep -Fq "const SCRUB = ['pin', 'pan', 'kinetic', 'wipe', 'drift']" "$vs" \
  || fail "$v does not tell a scrubbed section from an entry-driven one, so both take the same sampling window"
# Anchored on the call site and its consequence, never on the identifier: the
# whole two-point block was once deleted with the function left defined, and a
# `grep -Fq revealState` stayed green while dead-scroll-for-reveal ceased to
# exist. The second sample proves the block is called twice; the -A1 pair proves
# the comparison still pushes a finding when the two samples match.
grep -Fq 'const after = await page.evaluate(revealState, b.idx);' "$vs" \
  || fail "$v does not take the second reveal sample, so the two-point check cannot run and a sparse walk reports dead scroll on a section that reveals"
grep -A1 -F 'if (after === before)' "$vs" | grep -Fq "kind: 'dead-scroll'" \
  || fail "$v does not report dead-scroll when both reveal samples match, so a reveal that never fires walks clean"
# The predicate itself. Comparing computed opacity/transform let a decorative
# @keyframes on the reveal's own children counterfeit a live reveal; only a
# ViewTimeline-driven animation is the device's contract. `none` is what keeps an
# unwired reveal from returning '' and being skipped by the `before !== ''` guard.
grep -Fq 'a.timeline instanceof ViewTimeline' "$vs" \
  || fail "$v judges reveal by computed style, so ambient motion on the same children spoofs a section with no reveal wired at all"
# revealState's own device query, both halves. Renaming the attribute value
# ('revealx') collects zero devices, `out` stays empty, both samples read '' and
# every section is skipped by the `before !== ''` guard: reveal detection is
# silent with every assertion above it intact.
grep -Fq "if (root.matches('[data-motion=\"reveal\"]')) devices.push(root);" "$vs" \
  || fail "$v does not collect a section that is itself the reveal device, so a reveal on the section root is never sampled"
grep -Fq "root.querySelectorAll('[data-motion=\"reveal\"]').forEach((el) => devices.push(el));" "$vs" \
  || fail "$v does not query [data-motion=\"reveal\"] inside the section, so a renamed selector collects no devices and reveal detection silently stops"
grep -Fq "out.push('none')" "$vs" \
  || fail "$v returns an empty reveal state for a child with no scroll-driven animation, so an unwired reveal is skipped instead of reported"
# The block's own guard, pinned by polarity AND by what it gates. Inverting one
# character (`!b.scrub` → `b.scrub`) or wrapping the condition in `false &&`
# leaves both assertions above matching — the two samples are still adjacent and
# intact — while reveal detection disappears entirely and deadreveal/falsealive
# drop to exit 0. Anchoring the first sample under the exact condition is what
# makes either edit fail here by name.
grep -A3 -F 'if (!b.scrub && !reduced && belowFold >= 0) {' "$vs" \
  | grep -Fq 'const before = await page.evaluate(revealState, b.idx);' \
  || fail "$v does not gate the two-point reveal check on exactly '!b.scrub && !reduced && belowFold >= 0' with the first sample inside it, so inverting or disabling that guard silently switches reveal detection off"
# The GSAP fallback path. motion.js drives reveal with rAF tweens when the
# browser has no view(), and those are invisible to getAnimations(), so the
# predicate must return the unjudged sentinel there rather than read none|none
# and call a working section dead.
# Pinned with the `!` and the early return, never on the bare CSS.supports() call:
# dropping one character inverts the guard, revealState returns the unjudged
# sentinel on every browser that DOES support view() — which is every browser the
# harness runs on — and reveal detection ceases entirely with the suite green.
grep -Fq "if (!CSS.supports('animation-timeline', 'view()')) return '';" "$vs" \
  || fail "$v judges reveal on a browser with no view(), where motion.js drives it in GSAP and getAnimations() sees nothing, so a working section is reported dead — or the guard's polarity was inverted, which switches reveal detection off on every browser that has view()"
grep -Fq "animation-timeline', 'view()" skills/wp-demo-craft/references/verify.md \
  || fail "skills/wp-demo-craft/references/verify.md does not record that reveal is unjudged without view() support, so the limit reads as a bug"
grep -Fq '} else if (b.scrub) {' "$vs" \
  || fail "$v pushes dead-scroll from the walk for an entry-driven section, which is the false positive the two-point sample replaces"
for f in skills/wp-demo-craft/references/verify.md commands/wp-demo-verify.md; do
  grep -Fq 'below the fold and fully entered' "$f" \
    || fail "$f does not document that a section with no scrubbed device is judged by two samples, not by the walk"
done

# Advisory has to mean advisory in the exit code, not only in prose: a round that
# fails on what the harness could not see is the false positive under another
# name. The split lives in one named set so a new advisory kind joins a list.
# Anchored on the whole literal set, not just 'unobserved': that also catches
# container-noop landing in the set by mistake, which would silently stop it
# from blocking the round it exists to fail.
grep -Fq "const ADVISORY = new Set(['unobserved', 'external-module'])" "$vs" \
  || fail "$v does not name exactly unobserved and external-module as its advisory kinds, so either a new advisory kind was added without updating this or container-noop landed in the set and stopped blocking"
grep -Fq 'exitCode = blocking === 0 ? 0 : 1' "$vs" \
  || fail "$v exits on the total finding count, so an advisory-only run still fails the round"
grep -Fq "' [advisory]'" "$vs" \
  || fail "$v does not label advisory findings in the printed line, so a reader cannot see why a run with findings exited 0"
grep -Fq 'nothing blocking, ' "$vs" \
  || fail "$v does not distinguish an advisory-only run from a run with nothing to report"
for f in skills/wp-demo-craft/references/verify.md commands/wp-demo-verify.md; do
  grep -Fq 'advisory-only run exits 0' "$f" \
    || fail "$f does not document that an advisory-only run exits 0"
  # The artifact has to be self-describing, or every consumer carries its own
  # copy of the kind list and that copy goes stale when a kind joins ADVISORY.
  grep -Fq '"advisory": true' "$f" \
    || fail "$f does not document the advisory flag on findings.json rows, so a consumer has to match on the kind instead"
  grep -Fq 'page-wide judgments, printed per section' "$f" \
    || fail "$f still reads as if unobserved/no-engine were per-section facts; both counters come from a document-wide query"
done
grep -Fq 'f.advisory = true' "$vs" \
  || fail "$v writes findings.json without the advisory flag, so the label exists only on stdout"
# The command contradicted itself: an exit-code line that predates the advisory
# split, three lines from the line that documents it.
if grep -Fq '`0` no machine findings, `1` findings printed' commands/wp-demo-verify.md; then
  fail "commands/wp-demo-verify.md still documents the pre-advisory exit codes, contradicting its own advisory-only-run line"
fi
grep -Fq 'Fold every **blocking** finding' commands/wp-yolo.md \
  || fail "commands/wp-yolo.md folds every finding into the fix list, advisory ones included, so the split it consumes does not reach the one command that acts on it"
grep -Fq 'parallax' skills/wp-demo-craft/references/verify.md \
  || fail "skills/wp-demo-craft/references/verify.md does not record that parallax is left unjudged, so the limit reads as a bug"

# An @container rule whose subject has no container-type ancestor never applies
# and says nothing about it: six such blocks shipped in one build and were only
# found from screenshots. The finding must exist, and it must be blocking (the
# advisory-set assertion above already pins that).
grep -Fq "kind: 'container-noop'" "$vs" \
  || fail "$v does not lint @container rules with no container-type ancestor"
# The walk must start one level above the queried element: a container query
# never matches the container the queried element establishes itself, so
# starting at the element instead of its parent misses that case silently.
# The rule filter itself. Renaming the class it matches ('CSSContainerRuleX') makes
# the loop `continue` on every rule in every sheet: the lint is permanently silent,
# every line of it still present, and the run exits 0.
grep -Fq "if (rule.constructor.name !== 'CSSContainerRule') continue;" "$vs" \
  || fail "$v does not filter styleSheet rules on exactly CSSContainerRule, so a renamed or altered comparison skips every rule and the container lint is permanently silent"
# EVERY match, not the first. `querySelectorAll` -> `querySelector` reinstates a
# blocking false positive on valid CSS: a selector matching several elements
# applies the moment ONE of them sits inside a container, and judging it by the
# first match reported the rule as dead whenever that first match was the one
# outside. A gate that fails a round on correct CSS is the failure this branch
# exists to cure, recreated inside the cure.
grep -Fq 'try { els = document.querySelectorAll(sel); } catch { continue; }' "$vs" \
  || fail "$v judges an @container selector by its first match only, so a rule that genuinely applies to a later match is reported as dead and blocks a round on valid CSS"
# And its polarity one line down. `if (!els.length) continue;` -> `if (els.length)
# continue;` skips every selector that actually resolves, which is all of them,
# and the lint goes permanently silent. Anchored under the query that produces
# `els`, so the guard cannot be satisfied by an identical line elsewhere.
grep -A1 -F 'try { els = document.querySelectorAll(sel); } catch { continue; }' "$vs" \
  | grep -Fq 'if (!els.length) continue;' \
  || fail "$v does not skip only the selectors that match nothing after querySelectorAll, so inverting that guard skips every selector that does match and the container lint goes silent"
# The whole match list has to be walked. `for (const el of els)` -> `[els[0]]`
# restores first-match judgement with querySelectorAll still in place above.
grep -Fq 'for (const el of els) {' "$vs" \
  || fail "$v does not walk every element matching the selector, so the lint is back to judging a rule by one match while still calling querySelectorAll"
grep -Fq 'let node = el.parentElement;' "$vs" \
  || fail "$v starts the container-type ancestor walk at the element itself, so an element that establishes its own container is wrongly cleared instead of reported"
# One match inside a container clears the rule for all of them. Dropping this
# break is harmless; inverting the search so a LATER match without a container
# re-clears `found` is not, and the `if (found) break;` under the ancestor walk
# is what states the any-match rule in code.
grep -Fq 'if (found) break;' "$vs" \
  || fail "$v does not stop at the first match with a container ancestor, so a later match outside one can undo the rule's applicability"
# The lint's polarity, anchored on the guard expression itself. Both lines above
# survive `if (!found)` -> `if (found)` intact, and that one character inverts
# the lint completely: every correctly written container query is reported as
# dead and every actually dead rule is cleared. A selector is reported when the
# ancestor walk found NO container, never when it found one.
grep -Fq 'if (!found) out.push(sel);' "$vs" \
  || fail "$v does not report a container-query selector only when the ancestor walk found no container-type, so the lint's polarity is inverted: correct compositions are flagged and dead rules are cleared"

# Loading a demo as file:// puts an external module script on an opaque
# origin; Chrome blocks it, the engine never boots, and every page reports
# dead scroll with no trace of why. Serving over HTTP is what removes that
# whole failure class. Anchored on the import statement itself, not just the
# bare word 'createServer': that word also appears at the call site inside
# serve(), so a grep for it alone stays green even with the import deleted
# (a ReferenceError that only surfaces the first time a page is actually
# walked, never here).
grep -Fq "import { createServer } from 'node:http';" "$vs" \
  || fail "$v does not import createServer from node:http, so serving the demo over HTTP throws at runtime the first time a page is walked"
grep -Fq "kind: 'external-module'" "$vs" \
  || fail "$v does not warn when a built demo still carries an external module script that only works when served"
# The query that produces it. The push text above stays intact under
# `[type="module"]` -> `[type="modulex"]`, and the finding then never fires on
# any page: the fixture reports zero findings and exits 0, which is the silent
# pass this task exists to close, reopened by one character.
grep -Fq 'script[type="module"][src]' "$vs" \
  || fail "$v does not query script[type=\"module\"][src], so no external module script is ever detected and the advisory silently never fires"
# Both static checks run behind one per-page gate. Inverting it
# (`if (!staticChecked)` -> `if (staticChecked)`) never runs the block at all,
# because the flag is only ever set inside it — container-noop and
# external-module both disappear with every line of theirs still present, and
# the run exits 0. Anchored on the guard and on the flag being set inside it.
grep -A1 -F 'if (!staticChecked) {' "$vs" | grep -Fq 'staticChecked = true;' \
  || fail "$v does not gate the static checks on '!staticChecked' with the flag set inside, so inverting that guard silently skips container-noop and external-module entirely"
# The demo server decodes the request path. decodeURIComponent throws URIError
# on a malformed escape, and outside the try that throw is uncaught and kills
# the walk mid-run; a demo with a stray '%' in an href is enough.
grep -Fq 'err instanceof URIError ? 400 : 404' "$vs" \
  || fail "$v does not answer 400 on a malformed percent-encoding, so a stray '%' in a demo path throws out of the request handler and kills the walk"
# Path containment, both halves. Stripping leading ../ is not containment: a
# Windows drive-absolute path and a symlink inside the root both land outside it
# and were served, so a page under test could read arbitrary local files through
# the verification server. realpathSync follows the links before the test; the
# test itself is what refuses the result. Pinned as a pair, since either line
# alone is inert: resolving without comparing serves the escape, and comparing
# without resolving misses the symlink.
grep -Fq 'file = realpathSync(resolve(base, rel));' "$vs" \
  || fail "$v does not resolve the request path through realpath, so a symlink inside the demo root pointing outside it is followed and served"
grep -A1 -F 'file = realpathSync(resolve(base, rel));' "$vs" \
  | grep -Fq 'if (file !== base && !file.startsWith(base + sep)) return res.writeHead(404).end();' \
  || fail "$v does not refuse a resolved path outside the demo root with 404, so path containment is not enforced at all and a drive-absolute or symlinked path escapes"
# The relative-isation the containment depends on. Without the leading-separator
# strip, resolve(base, '/index.html') returns the filesystem root's index.html:
# every legitimate request 404s and the walk cannot load a single page.
grep -Fq ".replace(/^[/\\\\]+/, '')" "$vs" \
  || fail "$v does not strip the request path's leading separators before resolving, so resolve() treats it as absolute and no page under the demo root is servable"
# A bind that fails must reject, not hang. Without the error handler the promise
# never settles — port exhaustion or a sandbox refusing the bind stops the walk
# with no answer at all, which is the failure shape this branch exists to end,
# and the one that looks like slow progress instead of a crash.
grep -Fq "server.once('error', fail);" "$vs" \
  || fail "$v never rejects the serve() promise, so a failed bind hangs the walk instead of reporting a crash"
grep -A1 -F "server.listen(0, '127.0.0.1', () => {" "$vs" \
  | grep -Fq "server.removeListener('error', fail);" \
  || fail "$v leaves the error handler attached after listen succeeds, so a later runtime error rejects an already-settled promise"
# Anchored on the explanatory phrase from each dedicated bullet, not only the
# bare kind name: both files also name-drop 'external-module' in passing, in
# the sentence that lists the advisory kinds, so a grep for the bare word alone
# stays green even with the dedicated explanatory bullet deleted outright.
for f in skills/wp-demo-craft/references/verify.md commands/wp-demo-verify.md; do
  grep -Fq 'container-noop' "$f" || fail "$f does not document the container-noop finding"
  grep -Fq 'provably never applies' "$f" \
    || fail "$f does not explain that container-noop fails the round because the rule provably never applies"
  grep -Fq 'external-module' "$f" || fail "$f does not document the external-module finding"
  grep -Fq 'double-clicking' "$f" \
    || fail "$f does not explain that external-module is a hazard only when the file is opened directly, not served"
done

# cramped-padding is a `quality` finding that fired 68-90 times per run on the
# client build that motivated this branch, dismissed as a false positive — and
# fires on this library's own untouched compositions too. Anchored on three
# phrases, not the bare kind name alone: a passing name-drop of 'cramped-padding'
# elsewhere in the file (e.g. a future finding list) would satisfy a single bare
# grep while the actual judgement call and its measured evidence stayed missing.
grep -Fq '`cramped-padding` is a known false-positive source.' skills/wp-demo-craft/references/verify.md \
  || fail "verify.md does not record cramped-padding as a known false-positive source"
grep -Fq '68–90 times per run' skills/wp-demo-craft/references/verify.md \
  || fail "verify.md does not cite the measured 68-90-times-per-run rate that justifies dismissing cramped-padding"
grep -Fq '131px/129px' skills/wp-demo-craft/references/verify.md \
  || fail "verify.md does not cite the measured padding (56/57px, 131/129px) that proves cramped-padding false-fired"
# And the floor under the dismissal. Every measurement above is a LARGE padding
# the detector misread; a collapsed token computes to 0px, where cramped-padding
# is the one machine signal that would catch it. Without this clause the file
# teaches builds to dismiss the finding that would have caught its own parked
# defect.
grep -Fq 'a measured padding under roughly 16px' skills/wp-demo-craft/references/verify.md \
  || fail "verify.md dismisses cramped-padding with no lower bound, so a 0px padding from a collapsed token is dismissed alongside the 131px false positives"

# The @container lint's own scope, recorded rather than fixed: a limit nobody
# wrote down is indistinguishable from a bug, and this branch's whole thesis is
# that an untrustworthy gate gets dismissed wholesale.
grep -Fq "each sheet's **top-level** \`cssRules\`" skills/wp-demo-craft/references/verify.md \
  || fail "verify.md does not record that the @container lint reads only top-level cssRules, so an @container nested in @media/@supports/@layer is silently unlinted"
# The first-match limit is retired, not recorded: it was a blocking false
# positive, not an under-report, so the file must say the lint reads every match
# — a stale "first match only" line teaches a build to dismiss a finding that is
# now trustworthy, which is how the 392 dismissed findings happened.
grep -Fq 'walks **every** match (`querySelectorAll`)' skills/wp-demo-craft/references/verify.md \
  || fail "verify.md does not record that the @container lint reads every match of a selector, not just the first"
if grep -Fq 'it judges a selector by `document.querySelector(sel)`' skills/wp-demo-craft/references/verify.md; then
  fail "verify.md still records the retired first-match limit as current behaviour"
fi

echo PASS
