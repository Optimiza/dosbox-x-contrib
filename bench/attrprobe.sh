#!/usr/bin/env bash
# Runs ATTRPRB.EXE headless on two DOSBox-X builds, each over a drive of its own, and compares
# what a search answers across a delete or an attribute change of another file. See README.md
# beside this script.
set -u

usage() {
    cat <<'EOT'
usage: attrprobe.sh <build A> <build B> <on|off>

  <build A>, <build B>  two DOSBox-X executables (the same one twice is the A/A control)
  <on|off>              the guest's long file names ([dos] lfn)

each build's drive holds two folders: X with F0000.TXT to F0039.TXT and Y with G0000.TXT to
G0019.TXT. ATTRPRB removes, deletes and changes the attribute of files of X while searches of X
and Y are open, and puts back a DTA saved from an ended search after a search of Y has started.

prints each build's path, version line and report whole, then the verdict and the lines that
differ.

environment:
  DJDIR                 the DJGPP cross toolchain (default: $HOME/djgpp)
  DIRCACHE_PREBUILT     a folder holding ATTRPRB.EXE built on another host, instead of DJGPP

exit: 0 alike | 1 different | 2 usage
      3 INVALID: a run collected nothing, a folder listed nothing, or a report has no line or
        no trailer; the run's directory is kept and named
EOT
}

SECONDS_BOUND=300
X_FILES=40
Y_FILES=20

if [ $# -eq 1 ] && [ "$1" = "--help" ]; then usage; exit 0; fi
if [ $# -ne 3 ]; then usage >&2; exit 2; fi
build_a=$1 build_b=$2 lfn=$3

tool=attrprobe.sh
here=$(cd "$(dirname "$0")" && pwd) || exit 2
if [ ! -f "$here/common.sh" ]; then echo "attrprobe.sh: common.sh is missing beside the script" >&2; exit 3; fi
# shellcheck source=common.sh
. "$here/common.sh"
need_builds "$build_a" "$build_b"
lfn_parse "$lfn"
need_tools

run_begin attrprobe
guest_build ATTRPRB "$tmp/c" || invalid "ATTRPRB did not build"

# attr_tree <dir>: X and Y, a copy per build, because ATTRPRB removes and makes files in X.
attr_tree() {
    local i name
    mkdir -p "$1/X" "$1/Y" || return
    i=0
    while [ "$i" -lt "$X_FILES" ]; do printf -v name 'F%04d.TXT' "$i"; : > "$1/X/$name" || return; i=$((i + 1)); done
    i=0
    while [ "$i" -lt "$Y_FILES" ]; do printf -v name 'G%04d.TXT' "$i"; : > "$1/Y/$name" || return; i=$((i + 1)); done
}

echo "attrprobe.sh: long names $lfn"
for label in A B; do
    if [ "$label" = A ]; then binary=$build_a; else binary=$build_b; fi
    attr_tree "$tmp/fx-$label" || invalid "could not make build $label's folders"
    guest_run "$label" "$binary" "$tmp/fx-$label" "" ATTRPRB.TXT "$SECONDS_BOUND" "c:" 'ATTRPRB.EXE D:\X D:\Y C:\ATTRPRB.TXT'
    LC_ALL=C tr -d '\r' < "$guest_out" > "$tmp/report-$label.txt" || invalid "build $label's report could not be read"
    echo "attrprobe.sh: build $label: $binary ($emu_version)"
    cat "$tmp/report-$label.txt"
    exact_whole "$tmp/report-$label.txt" || invalid "build $label's report has no line or no trailer"
done
reports_verdict
