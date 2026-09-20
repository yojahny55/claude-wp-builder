#!/usr/bin/env python3
"""Confirms a transfer by comparing what is on each side, not by trusting a summary.

The client reports pending bytes for objects it deliberately refused to overwrite, so
"nothing pending" is both too strict — a byte-identical file already on disk counts as
pending forever — and too weak, since it was measured reporting success after writing 7
of 38 objects. Listing both sides and comparing names and sizes answers the question the
operator actually has: is every file on the other side.

Exit 0 when every expected file is present at the same size, 1 otherwise, 2 when the
listing failed or came back empty on a download, which cannot be told apart from a
listing that silently did not work.
"""

import argparse
import fnmatch
import json
import os
import subprocess
import sys


def excluded(path, patterns):
    return any(fnmatch.fnmatch(path, p) for p in patterns)


def local_files(root, patterns):
    found = {}
    for dirpath, _dirnames, filenames in os.walk(root):
        for name in filenames:
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, root)
            if excluded(rel, patterns):
                continue
            try:
                found[rel] = os.path.getsize(full)
            except OSError:
                continue
    return found


# A listing that never answers is the failure mode with no error message: a blackholed
# route or an unresponsive backend leaves the caller blocked under `set -e` with nothing
# to read. Overridable because a first listing of a very large bucket is legitimately
# slow.
LIST_TIMEOUT = int(os.environ.get("WP_S3_LIST_TIMEOUT", "300"))


def remote_files(mcli, remote, patterns):
    try:
        proc = subprocess.run(
            [mcli, "ls", "--recursive", "--json", remote],
            capture_output=True, text=True, timeout=LIST_TIMEOUT,
        )
    except subprocess.TimeoutExpired:
        sys.stderr.write(
            "ERROR: listing %s did not answer within %d seconds. Nothing was verified.\n"
            "       Raise WP_S3_LIST_TIMEOUT if the bucket is genuinely that large.\n"
            % (remote, LIST_TIMEOUT)
        )
        sys.exit(2)
    if proc.returncode != 0:
        sys.stderr.write("ERROR: could not list %s\n%s\n" % (remote, proc.stderr.strip()))
        sys.exit(2)

    found = {}
    for line in proc.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError:
            continue
        if row.get("status") == "error":
            sys.stderr.write("ERROR: the listing reported %s\n" % row.get("error", row))
            sys.exit(2)
        key = row.get("key")
        if not key or key.endswith("/"):
            continue
        if excluded(key, patterns):
            continue
        found[key] = row.get("size", -1)
    return found


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--direction", choices=("upload", "download"), required=True)
    ap.add_argument("--local", required=True)
    ap.add_argument("--remote", required=True)
    ap.add_argument("--mcli", required=True)
    ap.add_argument("--exclude", action="append", default=[])
    args = ap.parse_args()

    local = local_files(args.local, args.exclude)
    remote = remote_files(args.mcli, args.remote, args.exclude)

    # An empty listing is not the same kind of fact on each side. Walking a local
    # directory that holds nothing is a reliable answer; a remote listing that comes back
    # empty can also mean the client could not read it, and it says so with exit 0 and no
    # output — an unknown alias produces exactly that. Calling that a verified download
    # would sign off on a transfer that moved nothing.
    if args.direction == "download" and not remote:
        sys.stderr.write(
            "ERROR: %s listed no objects at all. Nothing was verified: either the prefix is\n"
            "       empty or the listing failed silently. Check the alias and the path.\n"
            % args.remote
        )
        return 2

    # Only one side is authoritative, and which one depends on the direction: an upload
    # must account for every local file, a download for every object. The other side
    # holding extra files is not a failure — that is how an environment that was not
    # migrated in this run looks.
    expected, actual, where = (
        (local, remote, "the bucket") if args.direction == "upload"
        else (remote, local, "disk")
    )

    missing = [p for p in expected if p not in actual]
    wrong = [
        (p, expected[p], actual[p])
        for p in expected
        if p in actual and actual[p] != expected[p] and expected[p] >= 0 and actual[p] >= 0
    ]

    if not missing and not wrong:
        if not expected:
            print("Nothing to verify: the source side holds no files.")
        else:
            print("Verified: %d files present on %s, sizes match." % (len(expected), where))
        return 0

    if missing:
        sys.stderr.write("ERROR: %d file(s) did not reach %s, for example:\n" % (len(missing), where))
        for p in sorted(missing)[:5]:
            sys.stderr.write("  %s\n" % p)
    if wrong:
        sys.stderr.write("ERROR: %d file(s) differ in size:\n" % len(wrong))
        for p, want, got in sorted(wrong)[:5]:
            sys.stderr.write("  %s: %d bytes expected, %d on %s\n" % (p, want, got, where))
    return 1


if __name__ == "__main__":
    sys.exit(main())
