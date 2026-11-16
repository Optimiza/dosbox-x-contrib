#!/usr/bin/env bash
# Boots one DOSBox-X build headless on a conf, bounded in time, and refuses a run whose guest
# left nothing. The launcher of the scripts in this folder on macOS; windows.ps1 is its
# counterpart. See README.md beside this script.
set -u

usage() {
    cat <<'EOT'
usage: launch.sh --conf <file> --binary <build> --seconds <n> --output <file> --log <file>
                 --report <file> [-- <argument for the emulator>...]

  --conf <file>     the DOSBox-X conf the run boots
  --binary <build>  the DOSBox-X executable
  --seconds <n>     the run is ended after that long; a run that reaches it is not a failure
                    by that alone: what it left decides
  --output <file>   the file the run must leave: the guest's, through a mounted folder
  --log <file>      where the emulator writes its log; its stderr goes to <file>.err
  --report <file>   where the report goes: the build's version line and the exit code

No window opens: the emulator runs on SDL's dummy video driver. It needs GNU timeout, as
timeout or gtimeout on the PATH.

exit: 0 the emulator ran and the run left its output | 1 the emulator failed | 2 usage
      3 INVALID: the output is absent, empty or was not written by this run, or the log is empty
EOT
}

refuse() {
    echo "launch.sh: $1" >&2
    exit 2
}

conf="" binary="" seconds="" output="" log="" report=""
extra=()
if [ $# -eq 1 ] && [ "$1" = "--help" ]; then usage; exit 0; fi
while [ $# -gt 0 ]; do
    case "$1" in
        --conf|--binary|--seconds|--output|--log|--report)
            [ $# -ge 2 ] && [ -n "$2" ] || refuse "$1 needs a value"
            case "$1" in
                --conf) conf=$2 ;;
                --binary) binary=$2 ;;
                --seconds) seconds=$2 ;;
                --output) output=$2 ;;
                --log) log=$2 ;;
                --report) report=$2 ;;
            esac
            shift 2
            ;;
        --) shift; extra=("$@"); break ;;
        *) refuse "unknown option: $1" ;;
    esac
done
for name in conf binary seconds output log report; do
    [ -n "${!name}" ] || refuse "missing --$name"
done
# timeout reads 0 as no limit at all.
case "$seconds" in *[!0-9]*|0) refuse "--seconds is a whole number of seconds, 1 or more: $seconds" ;; esac
[ -r "$conf" ] || refuse "cannot read the conf: $conf"
if [ ! -x "$binary" ] || [ -d "$binary" ]; then refuse "not an executable: $binary"; fi
bound=$(command -v timeout || command -v gtimeout) || refuse "neither timeout nor gtimeout is on the PATH (GNU coreutils): the run would have no bound"

# DOSBox-X prints its banner on stderr and exits non-zero: the first line of either stream.
version=$("$bound" 5 "$binary" -version < /dev/null 2>&1 | awk 'NF && !done { sub(/^[ \t]+/, ""); sub(/[ \t]+$/, ""); print; done = 1 }')

stamp() { stat -f '%z:%m' "$1" 2> /dev/null || stat -c '%s:%Y' "$1" 2> /dev/null; }
before=""
if [ -e "$output" ]; then before=$(stamp "$output"); fi
rm -f "$report" "$log.err"
: > "$log" || refuse "cannot write the log: $log"

# The quit warning waits for an answer when the run is ended with a program still running, and
# the folder prompt is a native dialog at start: neither may wait on a run nobody watches.
rc=0
SDL_VIDEODRIVER=dummy "$bound" --kill-after=2 "$seconds" "$binary" -conf "$conf" \
    -set "dosbox quit warning=false" -nopromptfolder -set "log logfile=$log" \
    ${extra[@]+"${extra[@]}"} > /dev/null 2> "$log.err" || rc=$?
# 124 is the bound reached, 137 the kill that follows when the emulator ignores it.
if [ "$rc" -eq 124 ] || [ "$rc" -eq 137 ]; then rc=0; fi

why=""
if [ ! -s "$log" ]; then
    why="the emulator's log came out empty"
elif [ ! -e "$output" ]; then
    why="the run left no $output"
elif [ ! -s "$output" ]; then
    why="the run left $output empty"
elif [ -n "$before" ] && [ "$(stamp "$output")" = "$before" ]; then
    why="$output was not written by this run"
fi
if [ -n "$why" ]; then rc=3; fi

{
    echo "launch.sh: binary: $binary"
    echo "launch.sh: version: $version"
    if [ -n "$why" ]; then echo "launch.sh: INVALID: $why"; fi
    if [ "$rc" -ne 0 ] && [ -s "$log.err" ]; then
        echo "launch.sh: the emulator's stderr ends:"
        tail -n 8 "$log.err" | sed 's/^/launch.sh: | /'
    fi
    echo "launch.sh: exit code: $rc"
} | tee "$report" >&2
exit "$rc"
