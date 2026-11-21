#!/usr/bin/env bash
# Stands in for launch.sh in the *.test.sh here: it plays what a real run left.
#   STUB_PLAY=<dir>     the n-th call copies <dir>/<n>/ into the run directory; a HOLD file
#                       there makes a process named as the build hold like MEMPROBE
#   STUB_RECORD=<dir>   runs the real launcher (STUB_REAL) and saves the run's files as
#                       <dir>/<n>/: how the fixtures were captured
#   STUB_STATE=<dir>    the call counter; STUB_RC, STUB_VERSION: what to answer
# What follows -- is the emulator's own and is not read.
set -u

if [ "${1:-}" = "--hold" ]; then
    run=$(dirname "$2")
    : > "$run/HELD.TXT"
    n=0
    while [ ! -f "$run/GO.TXT" ] && [ "$n" -lt 100 ]; do sleep 0.1; n=$((n + 1)); done
    cp "$3" "$4"
    exit 0
fi

conf="" binary="" output="" log="" report=""
args=("$@")
while [ $# -gt 0 ]; do
    case "$1" in
        --conf) conf=$2; shift ;;
        --binary) binary=$2; shift ;;
        --output) output=$2; shift ;;
        --log) log=$2; shift ;;
        --report) report=$2; shift ;;
        --seconds) shift ;;
        --) break ;;
        *) echo "stub-launcher: unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done
n=$(($(cat "$STUB_STATE/count" 2>/dev/null || echo 0) + 1))
echo "$n" > "$STUB_STATE/count"
run=$(dirname "$conf")
name=$(basename "$output")

if [ -n "${STUB_RECORD:-}" ]; then
    "$STUB_REAL" "${args[@]}"
    rc=$?
    mkdir -p "$STUB_RECORD/$n" || exit 3
    for f in "$name" CWD.TXT RC.TXT FC.TXT SHELL.TXT READY.TXT STOP.TXT; do
        case "$f" in *.img|*.vhd) continue ;; esac     # a disk image is the run's machine, not its answer
        if [ -f "$run/$f" ]; then cp "$run/$f" "$STUB_RECORD/$n/" || exit 3; fi
    done
    # The console as the emulator logs it, and its find calls, are what junktest.sh and dirtest.sh
    # read; the counters' lines are what attrcost.sh and resprb.sh read. The console echoes the
    # mounts, so the run's own directory becomes /RUN.
    LC_ALL=C command grep -a -E 'All slots full|ID out of range|booting a guest OS|^DOS CON: | ah=4[ef], |HOST-DIR-READ read=|DYN-CACHE-RESET reset=' "$log" |
        LC_ALL=C sed "s#$(dirname "$run")#/RUN#g" > "$STUB_RECORD/$n/dosbox.log"
    exit "$rc"
fi

from=${STUB_PLAY:?set STUB_PLAY or STUB_RECORD}/$n
: > "$log"
if [ -d "$from" ]; then
    for f in "$from"/*; do
        case "$(basename "$f")" in
            HOLD|EXIT|INVALID|"$name") ;;
            dosbox.log) cp "$f" "$log" ;;
            *) cp "$f" "$run/" ;;
        esac
    done
    if [ -f "$from/HOLD" ]; then
        "$binary" "$0" --hold "$conf" "$from/$name" "$output"
    elif [ -f "$from/$name" ]; then
        cp "$from/$name" "$output"
    fi
fi
version=${STUB_VERSION-DOSBox-X version 0.0 stub}
if [ -n "$version" ]; then echo "launch.sh: version: $version" > "$report"; else : > "$report"; fi
# An INVALID file holds the reason launch.sh gives when it refuses a run; an EXIT file is the exit
# code for that call alone, as the launcher's report names it.
if [ -f "$from/INVALID" ]; then echo "launch.sh: INVALID: $(cat "$from/INVALID")" >> "$report"; fi
if [ -f "$from/EXIT" ]; then
    echo "launch.sh: exit code: $(cat "$from/EXIT")" >> "$report"
    exit "$(cat "$from/EXIT")"
fi
exit "${STUB_RC:-0}"
