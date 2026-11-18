#!/usr/bin/env bash
# Runs LFNREN.EXE headless on two DOSBox-X builds, long names on, each over an empty folder of its
# own, and compares whether the short names a directory gave before a rename still open the same
# files under its new name. See README.md beside this script.
set -u

usage() {
    cat <<'EOH'
usage: lfnren.sh <build A> <build B>

  <build A>, <build B>  two DOSBox-X executables (the same one twice is the A/A control)

long names on: the files have long names, made by 716Ch in D:\L, an empty folder per build.
In A, a listing before a rename to AR and each name it gave opened under AR; in C, a search open
across a rename to CR and each name it returned opened under CR.

prints each build's path, version line and report whole, then the lines that differ.

environment:
  DJDIR                 the DJGPP cross toolchain (default: $HOME/djgpp)
  DIRCACHE_PREBUILT     a folder holding LFNREN.EXE built on another host, instead of DJGPP

exit: 0 alike | 1 different | 2 usage
      3 INVALID: a run collected nothing, or a report has no line or no trailer; the run's
        directory is kept and named
EOH
}

SECONDS_BOUND=300

if [ $# -eq 1 ] && [ "$1" = "--help" ]; then usage; exit 0; fi
if [ $# -ne 2 ]; then usage >&2; exit 2; fi
build_a=$1 build_b=$2

tool=lfnren.sh
here=$(cd "$(dirname "$0")" && pwd) || exit 2
if [ ! -f "$here/common.sh" ]; then echo "lfnren.sh: common.sh is missing beside the script" >&2; exit 3; fi
# shellcheck source=common.sh
. "$here/common.sh"
need_builds "$build_a" "$build_b"
lfn_parse on
need_tools

run_begin lfnren
guest_build LFNREN "$tmp/c" || invalid "LFNREN did not build"

echo "lfnren.sh: long names on"
for label in A B; do
    if [ "$label" = A ]; then binary=$build_a; else binary=$build_b; fi
    mkdir -p "$tmp/fx-$label/L" || invalid "could not make build $label's folder"
    guest_run "$label" "$binary" "$tmp/fx-$label" "" LFNREN.TXT "$SECONDS_BOUND" "c:" 'LFNREN.EXE D:\L C:\LFNREN.TXT'
    LC_ALL=C tr -d '\r' < "$guest_out" > "$tmp/report-$label.txt" || invalid "build $label's report could not be read"
    echo "lfnren.sh: build $label: $binary ($emu_version)"
    cat "$tmp/report-$label.txt"
    exact_whole "$tmp/report-$label.txt" || invalid "build $label's report has no line or no trailer"
done
reports_verdict
