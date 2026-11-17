#!/usr/bin/env bash
# Stands in for powershell running windows.ps1 in the *.test.sh here, with a uname that says
# MINGW and a cygpath that hands paths back unchanged: the n-th call copies <STUB_PLAY>/<n>/ into
# its -Run directory, the guest's output under -Output's name, prints launcher.err as the
# launcher's words and exits with launcher.rc (0 when there is none).
#   STUB_PLAY=<dir>   the runs; STUB_STATE=<dir> the call counter
set -u
run="" output=""
while [ $# -gt 0 ]; do
    case "$1" in
        -Run) run=$2; shift ;;
        -Output) output=$2; shift ;;
        -File|-Build|-Seconds|-Held|-Go|-LimitKb|-ExecutionPolicy) shift ;;
        -NoProfile|-NonInteractive) ;;
        *) echo "stub-powershell: unknown argument: $1" >&2; exit 2 ;;
    esac
    shift
done
n=$(($(cat "$STUB_STATE/count" 2>/dev/null || echo 0) + 1))
echo "$n" > "$STUB_STATE/count"
from=${STUB_PLAY:?set STUB_PLAY}/$n
[ -d "$from" ] || { echo "stub-powershell: no run $n in $STUB_PLAY" >&2; exit 3; }
for f in "$from"/*; do
    case "$(basename "$f")" in
        launcher.err|launcher.rc) ;;
        GUEST.TXT) cp "$f" "$run/$output" ;;
        *) cp "$f" "$run/" ;;
    esac
done
if [ -f "$from/launcher.err" ]; then cat "$from/launcher.err" >&2; fi
exit "$(cat "$from/launcher.rc" 2>/dev/null || echo 0)"
