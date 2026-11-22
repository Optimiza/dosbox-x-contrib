#!/usr/bin/env bash
# Runs DRIFT.EXE headless on two DOSBox-X builds, each over its own copy of exact.sh's folder, and
# compares what they answer when a FindNext brings another pattern than its FindFirst had. See
# README.md beside this script.
set -u

usage() {
    cat <<'EOT'
usage: drift.sh <build A> <build B> <on|off>

  <build A>, <build B>  two DOSBox-X executables (the same one twice is the A/A control)
  <on|off>              the guest's long file names ([dos] lfn)

the folder is the one exact.sh makes (its --help lists it), a copy per build: some cases
create and remove files and folders in it.

prints each build's path, version line and report whole, then the lines that differ.

environment:
  DJDIR                 the DJGPP cross toolchain (default: $HOME/djgpp)
  DIRCACHE_PREBUILT     a folder holding DRIFT.EXE built on another host, instead of DJGPP

exit: 0 alike | 1 different | 2 usage
      3 INVALID: a run collected nothing, or a report has no case or no trailer; the run's
        directory is kept and named
EOT
}

SECONDS_BOUND=600

if [ $# -eq 1 ] && [ "$1" = "--help" ]; then usage; exit 0; fi
if [ $# -ne 3 ]; then usage >&2; exit 2; fi
build_a=$1 build_b=$2 lfn=$3

tool=drift.sh
here=$(cd "$(dirname "$0")" && pwd) || exit 2
if [ ! -f "$here/common.sh" ]; then echo "drift.sh: common.sh is missing beside the script" >&2; exit 3; fi
# shellcheck source=common.sh
. "$here/common.sh"
need_builds "$build_a" "$build_b"
lfn_parse "$lfn"
need_tools

run_begin drift
guest_build DRIFT "$tmp/c" || invalid "DRIFT did not build"

run_one() {
    local label=$1 binary=$2
    exact_tree "$tmp/fx-$label" || invalid "could not make build $label's folder"
    guest_run "$label" "$binary" "$tmp/fx-$label" "" DRIFT.TXT "$SECONDS_BOUND" "c:" 'DRIFT.EXE D:\X C:\DRIFT.TXT'
    LC_ALL=C tr -d '\r' < "$guest_out" > "$tmp/drift-$label.txt" || invalid "build $label's report could not be read"
    echo "drift.sh: build $label: $binary ($emu_version)"
    cat "$tmp/drift-$label.txt"
    exact_whole "$tmp/drift-$label.txt" || invalid "build $label's report has no case or no trailer"
}

echo "drift.sh: long names $lfn"
run_one A "$build_a"
run_one B "$build_b"

cmp -s "$tmp/drift-A.txt" "$tmp/drift-B.txt"
cmp_rc=$?
if [ "$cmp_rc" -eq 0 ]; then echo "drift.sh: ALIKE"; exit 0; fi
if [ "$cmp_rc" -ne 1 ]; then invalid "cmp failed (exit $cmp_rc)"; fi
echo "drift.sh: DIFFERENT, the lines that differ (A then B):"
diff "$tmp/drift-A.txt" "$tmp/drift-B.txt" | command grep -a -E '^[<>]'
exit 1
