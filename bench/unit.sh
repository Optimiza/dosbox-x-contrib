#!/usr/bin/env bash
# Runs a DOSBox-X build's own unit tests headless and prints their counts. See README.md beside
# this script.
set -u

usage() {
    cat <<'EOT'
usage: unit.sh <build>

  <build>   a DOSBox-X executable built with its debugger: no other build carries the tests

prints one line: how many tests ran, how many failed, erred or are disabled, then the
emulator's version line and path. Exit 0 is not a pass: read failures= and errors=.

exit: 0 the tests ran, the counts are reported | 2 usage
      3 INVALID: the emulator left no result file, the file is cut short or counts no test, or
        the emulator failed and the file names no failure; the run's directory is kept and named
EOT
}

SECONDS_BOUND=600

if [ $# -eq 1 ] && [ "$1" = "--help" ]; then usage; exit 0; fi
if [ $# -ne 1 ]; then usage >&2; exit 2; fi
build=$1

tool=unit.sh
here=$(cd "$(dirname "$0")" && pwd) || exit 2
if [ ! -f "$here/common.sh" ]; then echo "unit.sh: common.sh is missing beside the script" >&2; exit 3; fi
# shellcheck source=common.sh
. "$here/common.sh"
need_builds "$build"
# No guest program runs, so the host needs the launcher and no compiler.
DIRCACHE_PREBUILT=$here need_tools

run_begin unit
run=$tmp/run
mkdir -p "$run" || invalid "could not make the run directory"
printf '[dosbox]\nmemsize=64\n' > "$run/run.conf" || invalid "could not write the conf"

# The tests end before the shell starts: the result file is the emulator's, not a guest's.
# waitonerror: without it a Windows build ends its tests waiting for Enter on a console.
launcher_rc=0
if [ "$HOST_KIND" = windows ]; then
    emu_run "the unit tests" "$build" "$run" UNIT.XML "$SECONDS_BOUND" -UnitTests || launcher_rc=$?
else
    emu_run "the unit tests" "$build" "$run" UNIT.XML "$SECONDS_BOUND" \
        -tests -set "sdl waitonerror=false" "--gtest_output=xml:$run/UNIT.XML" || launcher_rc=$?
fi

if [ ! -s "$run/UNIT.XML" ]; then invalid "the emulator left no result file"; fi
LC_ALL=C tr -d '\r' < "$run/UNIT.XML" > "$tmp/unit.xml" || invalid "the result file could not be read"
if [ "$(tail -n 1 "$tmp/unit.xml")" != "</testsuites>" ]; then invalid "the result file is cut short"; fi
# shellcheck disable=SC2046  # four numbers, split on purpose
set -- $(sed -n 's/^<testsuites tests="\([0-9]*\)" failures="\([0-9]*\)" disabled="\([0-9]*\)" errors="\([0-9]*\)" .*/\1 \2 \3 \4/p' "$tmp/unit.xml")
if [ $# -ne 4 ]; then invalid "the result file has no line of counts"; fi
tests=$1 failures=$2 disabled=$3 errors=$4
if [ "$tests" -eq 0 ]; then invalid "the result file counts no test"; fi
# The emulator exits non-zero when a test fails: that run is an answer. Any other failure is not.
if [ "$launcher_rc" -ne 0 ] && [ $((failures + errors)) -eq 0 ]; then
    invalid "the emulator did not run to its end, and its result file names no failure"
fi

echo "unit.sh: tests=$tests failures=$failures errors=$errors disabled=$disabled build=\"$emu_version\" binary=$build"
