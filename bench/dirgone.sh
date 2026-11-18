#!/usr/bin/env bash
# Runs DIRGONE.EXE headless on two DOSBox-X builds, each over its own copy of the folder, and
# compares what a search left open inside a directory answers once that directory is removed or
# renamed. See README.md beside this script.
set -u

usage() {
    cat <<'EOT'
usage: dirgone.sh <build A> <build B> <on|off>

  <build A>, <build B>  two DOSBox-X executables (the same one twice is the A/A control)
  <on|off>              the guest's long file names ([dos] lfn)

the folder is D:\G, a copy per build: KEEP, RD0, RD1, REN0 and REN1, each holding ID.TXT and
TWO.TXT, every name 8.3; DIRGONE makes six more directories there itself. Each case opens a
search of one directory, reads its first entry, removes or renames that directory or its parent
(or leaves it), and reads on until the search fails.

prints each build's path, version line and report whole, then the lines that differ.

environment:
  DJDIR                 the DJGPP cross toolchain (default: $HOME/djgpp)
  DIRCACHE_PREBUILT     a folder holding DIRGONE.EXE built on another host, instead of DJGPP

exit: 0 alike | 1 different | 2 usage
      3 INVALID: a run collected nothing, or a report has no case or no trailer; the run's
        directory is kept and named
EOT
}

SECONDS_BOUND=600

if [ $# -eq 1 ] && [ "$1" = "--help" ]; then usage; exit 0; fi
if [ $# -ne 3 ]; then usage >&2; exit 2; fi
build_a=$1 build_b=$2 lfn=$3

tool=dirgone.sh
here=$(cd "$(dirname "$0")" && pwd) || exit 2
if [ ! -f "$here/common.sh" ]; then echo "dirgone.sh: common.sh is missing beside the script" >&2; exit 3; fi
# shellcheck source=common.sh
. "$here/common.sh"
need_builds "$build_a" "$build_b"
lfn_parse "$lfn"
need_tools

run_begin dirgone
guest_build DIRGONE "$tmp/c" || invalid "DIRGONE did not build"

echo "dirgone.sh: long names $lfn"
for label in A B; do
    if [ "$label" = A ]; then binary=$build_a; else binary=$build_b; fi
    dirgone_tree "$tmp/fx-$label" || invalid "could not make build $label's folder"
    guest_run "$label" "$binary" "$tmp/fx-$label" "" DIRGONE.TXT "$SECONDS_BOUND" "c:" 'DIRGONE.EXE D:\G C:\DIRGONE.TXT'
    LC_ALL=C tr -d '\r' < "$guest_out" > "$tmp/report-$label.txt" || invalid "build $label's report could not be read"
    echo "dirgone.sh: build $label: $binary ($emu_version)"
    cat "$tmp/report-$label.txt"
    exact_whole "$tmp/report-$label.txt" || invalid "build $label's report has no case or no trailer"
done
reports_verdict
