#!/usr/bin/env bash
# Shared by s3-media.sh and s3-revert.sh.
#
# `mcli mirror` can exit 0 without having transferred everything. It was measured
# writing 7 of 38 objects with no warning, and reporting success while the storage
# backend was down. An exit code is therefore not evidence that the media moved, and
# neither is the summary table it prints, which is printed on failure too.
#
# What is evidence is both sides holding the same files at the same sizes, which is what
# verify-transfer.py compares afterwards.

# run_mirror <source> <target> <mcli options...>
#
# $MCLI must hold the client's path; require_mcli() below finds it. One side is a local
# directory and the other is an alias path; the direction is read from which is which.
run_mirror() {
    local source="$1" target="$2"
    shift 2
    local options=( "$@" )

    local dry=no
    local opt
    for opt in "${options[@]}"; do
        [[ "$opt" == "--dry-run" ]] && dry=yes
    done

    # The log lands in the caller's private configuration directory when there is one, so
    # it is removed by that script's EXIT trap even if the shell dies mid-transfer — a
    # RETURN trap alone leaks the file, and the log carries every object name.
    local log status
    if [[ -n "${MC_CONFIG_DIR:-}" && -d "${MC_CONFIG_DIR:-}" ]]; then
        log="$(mktemp "$MC_CONFIG_DIR/mirror-XXXXXX.log")"
    else
        log="$(mktemp -t wp-s3-mirror-XXXXXX.log)"
    fi
    trap 'rm -f "$log"' RETURN

    # Everything goes to the log; the refusals are kept off the screen and counted
    # instead. Reverting a site is the normal case where every single file is already on
    # the other side, and one <ERROR> line per file reads like a disaster when it is the
    # tool doing exactly what it was told.
    set +e
    "$MCLI" mirror "${options[@]}" "$source" "$target" 2>&1 \
        | tee "$log" \
        | grep -v 'Overwrite not allowed'
    status=${PIPESTATUS[0]}
    set -e

    # A refused overwrite is the tool doing what it was told: neither direction may
    # replace a file that is already there, and a second run of the same transfer refuses
    # every file it already moved. mcli exits non-zero for it, so the exit code alone
    # cannot separate "declined to clobber" from "could not connect".
    local refused other
    refused="$(grep -c 'Overwrite not allowed' "$log" || true)"
    other="$(grep '<ERROR>' "$log" | grep -vc 'Overwrite not allowed' || true)"

    local failed=no
    if [[ $status -ne 0 && "${refused:-0}" -eq 0 ]]; then
        echo "ERROR: mcli mirror exited with code $status." >&2
        failed=yes
    fi

    if [[ "${other:-0}" -gt 0 ]]; then
        echo "ERROR: mcli reported an error during the transfer." >&2
        grep '<ERROR>' "$log" | grep -v 'Overwrite not allowed' | head -5 >&2
        failed=yes
    fi

    if [[ "${refused:-0}" -gt 0 ]]; then
        echo "Note: $refused file(s) already existed on the other side and were left untouched."
        echo "      The comparison below decides whether that is the right result."
    fi

    if [[ "$dry" == "yes" ]]; then
        [[ "$failed" == "no" ]] || return 1
        return 0
    fi

    local direction local_path remote_path
    if [[ -d "$source" ]]; then
        direction=upload;   local_path="$source"; remote_path="$target"
    else
        direction=download; local_path="$target"; remote_path="$source"
    fi

    # Only the --exclude patterns matter to the comparison; the rest of the options are
    # about how the transfer ran, not about what should be on each side afterwards.
    local excludes=() i
    for (( i = 0; i < ${#options[@]}; i++ )); do
        if [[ "${options[i]}" == "--exclude" ]]; then
            excludes+=( --exclude "${options[i+1]}" )
        fi
    done

    # The comparison runs even after a failed transfer, and especially then: a failure is
    # exactly when the operator needs to know how much of it landed. It cannot rescue the
    # run — a failed transfer stays failed whatever the comparison says — but "47 of 812
    # objects arrived" is what makes the next run safe, and the client's own error says
    # nothing about that.
    local verified=0
    python3 "$(dirname "${BASH_SOURCE[0]}")/verify-transfer.py" \
        --direction "$direction" \
        --local "$local_path" \
        --remote "$remote_path" \
        --mcli "$MCLI" \
        "${excludes[@]}" || verified=$?

    if [[ "$failed" == "yes" ]]; then
        echo "The transfer itself failed; the comparison above says what reached the other side." >&2
        return 1
    fi

    return "$verified"
}

# require_mcli <install-dir>
#
# Prints the path of a usable client, or fails. The same binary ships under two names:
# `mc` upstream, `mcli` in the distributions that already use `mc` for something else.
# Looks on PATH under both names first, then in the install directory.
require_mcli() {
    local dir="$1"
    local name

    for name in mcli mc; do
        if command -v "$name" >/dev/null 2>&1; then
            command -v "$name"
            return 0
        fi
    done

    if [[ -x "$dir/mcli" ]]; then
        echo "$dir/mcli"
        return 0
    fi

    echo "ERROR: mcli is not installed." >&2
    echo "Install the single standalone binary and put it on PATH or at $dir/mcli:" >&2
    echo "  curl -fsSLo '$dir/mcli' https://dl.min.io/client/mc/release/linux-amd64/mc" >&2
    echo "  curl -fsSL https://dl.min.io/client/mc/release/linux-amd64/mc.sha256sum" >&2
    echo "  # verify the checksum, then: chmod 755 '$dir/mcli'" >&2
    return 1
}
