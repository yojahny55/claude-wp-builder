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


def scan(path):
    findings = []
    src = re.sub(r"/\*.*?\*/", "", open(path, encoding="utf-8").read(), flags=re.S)
    groups = collections.defaultdict(list)

    for sel, body in re.findall(r"([^{}]+)\{([^}]*animation-range[^}]*)\}", src):
        m = re.search(r"animation-range:\s*([^;]+)", body)
        if not m:
            continue
        sel = " ".join(sel.split())
        if not re.search(INDEXED, sel):
            continue
        if ":nth-child(" in sel:
            findings.append(
                "%s: `%s` indexes a stagger by :nth-child, which counts the parent's "
                "OTHER children -- one sibling of another type shifts every rung. "
                "offer-table's plans are <th> after a <td> corner cell and were off by "
                "one in the shipped markup: plan 1 got the rule written for plan 2 and "
                "the :nth-child(1) rule matched nothing. Use :nth-of-type"
                % (path, sel)
            )
        key = re.sub(INDEXED, ":nth-N", sel)
        idx = int(re.search(INDEXED, sel).group(2))
        groups[key].append((idx, m.group(1).strip()))

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
        base = key.split(":nth-N")[0]
        nxt = top + 1
        guard = re.escape(base) + r":nth-of-type\((?:n\+)?" + str(nxt) + r"\)"
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
