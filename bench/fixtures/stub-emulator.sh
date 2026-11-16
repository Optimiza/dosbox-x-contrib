#!/usr/bin/env bash
# Stands in for a DOSBox-X build in launch.test.sh. It answers -version; started on a conf it
# writes its arguments and its video driver to STUB_EMU_SAW, and then:
#   STUB_EMU_LOG=<text>     what it writes to the log file its arguments name (default: a line)
#   STUB_EMU_OUTPUT=<file>  a file it writes, as a guest would through a mounted folder
#   STUB_EMU_SLEEP=<n>      how long it stays up after that
#   STUB_EMU_RC=<n>         its exit code
set -u
if [ "${1:-}" = "-version" ]; then echo "DOSBox-X version 0.0 stand-in" >&2; exit 1; fi
log=""
for arg in "$@"; do
    case "$arg" in "log logfile="*) log=${arg#log logfile=} ;; esac
done
{ printf '%s\n' "$@"; echo "video=${SDL_VIDEODRIVER:-}"; } > "$STUB_EMU_SAW"
printf '%s' "${STUB_EMU_LOG-started$'\n'}" > "$log"
if [ -n "${STUB_EMU_OUTPUT:-}" ]; then echo answer > "$STUB_EMU_OUTPUT"; fi
sleep "${STUB_EMU_SLEEP:-0}"
echo "the stand-in's last word" >&2
exit "${STUB_EMU_RC:-0}"
