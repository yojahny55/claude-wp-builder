#!/usr/bin/env python3
"""Scan composition CSS for stagger ladders that put their rungs out of order.

usage: ladder-scan.py <compositions-dir>
       prints one finding per line; exits 0 always (the caller decides)

A "ladder" is the set of `animation-range` declarations that stagger one repeating
element, grouped by the selector with its `:nth-*(N)` index removed. Three
independent faults put a ladder's rungs out of order, and fixing one leaves the
others, so all three are reported here.

This lives beside the check rather than inside it because the grouping needs real
parsing: the same ladder is spread over N rules, and which rules belong to which
ladder is not a grep.

THE ONE THING THIS FILE CANNOT KNOW is whether a ladder's children are all the same
element type. `:nth-of-type` is the right index when they are and is unavailable when
they are not -- a flow of a label, a link and a step has no type to count. The CSS
does not say which it is, so the exemption is authored rather than guessed, and it
has to carry its reason. See ALLOW below.
"""
import collections
import glob
import os
import re
import sys

# `entry X%` and `cover X%` are not comparable. The entry phase spans
# min(elementH, viewportH) of scroll; the cover phase spans viewportH + elementH.
# So `entry 100%` sits at min(h,vh)/(vh+h) of cover -- measured across eight
# element/viewport pairs at exactly that value, ranging from cover 11.8% to 47.1%.
ENTRY_100_MIN_COVER = "11.8"
ENTRY_100_MAX_COVER = "47.1"

PHASES = r"\b(entry|exit|cover|contain)\b"
INDEXED = r":nth-(child|of-type)\((\d+)\)"

# An author may keep `:nth-child` for a ladder whose children are genuinely of mixed
# type, by writing, in a comment in the same file:
#
#   /* ladder-scan: allow-nth-child .cnext > * -- label, link and step in one flow,
#      so there is no element type to index by */
#
# The selector must match the ladder's own base and the reason after `--` must not be
# empty. A bare marker is refused: the point is to record a judgement someone can
# check, not to provide a way to silence the scan.
ALLOW = re.compile(
    r"ladder-scan:\s*allow-nth-child\s+(?P<sel>[^\n]*?)\s*--\s*(?P<why>\S[^*]*)",
)


def allowances(raw):
    """selector base -> reason, from the comments of one file."""
    out = {}
    for m in ALLOW.finditer(raw):
        out[" ".join(m.group("sel").split())] = " ".join(m.group("why").split())
    return out


def scan(path):
    findings = []
    raw = open(path, encoding="utf-8").read()
    allowed = allowances(raw)
    src = re.sub(r"/\*.*?\*/", "", raw, flags=re.S)
    groups = collections.defaultdict(list)
    bases_by_key = {}

    # Excluding `@` keeps an at-rule header from being mistaken for a selector;
    # the same scan still sees the ordinary rules nested inside its braces.
    for sel, body in re.findall(r"([^{}@]+)\{([^}]*animation-range[^}]*)\}", src):
        m = re.search(r"animation-range:\s*([^;]+)", body)
        if not m:
            continue
        rng = m.group(1).strip()
        # `normal` is the explicit untimed guard for children past a ladder. It
        # is not another rung and must not raise the expected next index.
        if rng == "normal":
            continue
        sel = " ".join(sel.split())
        if not re.search(INDEXED, sel):
            continue
        key = re.sub(INDEXED, ":nth-N", sel)
        base = key.split(":nth-N")[0].strip()
        bases_by_key[key] = base
        if ":nth-child(" in sel and base not in allowed:
            findings.append(
                "%s: `%s` indexes a stagger by :nth-child, which counts the parent's "
                "OTHER children -- one sibling of another type shifts every rung. "
                "offer-table's plans are <th> after a <td> corner cell and were off by "
                "one in the shipped markup: plan 1 got the rule written for plan 2 and "
                "the :nth-child(1) rule matched nothing. Use :nth-of-type, or if these "
                "children are genuinely of mixed type say so with a `ladder-scan: "
                "allow-nth-child %s -- <why>` comment" % (path, sel, base)
            )
        groups[key].append((int(re.search(INDEXED, sel).group(2)), rng))

    for key, rungs in sorted(groups.items()):
        phases = set()
        for _, rng in rungs:
            phases |= set(re.findall(PHASES, rng))
        if len(phases) > 1:
            findings.append(
                "%s: the ladder `%s` mixes %s endpoints. Those scales are not "
                "comparable -- `entry 100%%` lands between cover %s%% and cover %s%% "
                "depending on element and viewport height -- so the rungs are in order "
                "only at the geometry they were written against. One phase keyword per "
                "ladder" % (path, key, " and ".join(sorted(phases)),
                            ENTRY_100_MIN_COVER, ENTRY_100_MAX_COVER)
            )

        top = max(i for i, _ in rungs)
        base = bases_by_key[key]
        nxt = top + 1
        # A ladder exempted above indexes by child, so its catch-all does too.
        index = "nth-child" if base in allowed else "nth-of-type"
        guard = re.escape(base) + r"\s*:" + index + r"\(\s*(?:n\s*\+\s*)?" + str(nxt) + r"\s*\)"
        if not re.search(guard, src):
            findings.append(
                "%s: the ladder `%s` runs to %d and nothing reaches a %dth. That one "
                "inherits `animation-range: normal` (= `cover 0%% cover 100%%`), a range "
                "unrelated to the stagger, so it animates out of sequence with every "
                "rung that has an explicit one. Give it the untimed arrived state"
                % (path, key, top, nxt)
            )
    return findings


def main():
    root = sys.argv[1]
    out = []
    for f in sorted(glob.glob(os.path.join(root, "*", "section.css"))):
        out += scan(f)
    if out:
        print("\n".join(out))


if __name__ == "__main__":
    main()
