#!/usr/bin/env bash
# Runs FINDLIFE headless on two DOSBox-X builds and compares what each answers, case by case.
# See README.md beside this script.
set -u

usage() {
    cat <<'EOT'
usage: findlife.sh <build A> <build B> <on|off>

  <build A>, <build B>  two DOSBox-X executables (the same one twice is the A/A control)
  <on|off>              the guest's long file names ([dos] lfn)

prints each build's path, version line and report whole, then the lines that differ.

environment:
  DJDIR                 the DJGPP cross toolchain (default: $HOME/djgpp)
  DIRCACHE_PREBUILT     a folder holding FINDLIFE.EXE built on another host, instead of DJGPP

exit: 0 alike | 1 different | 2 usage
      3 INVALID: a run collected nothing, or a report has no case or no trailer; the run's
        directory is kept and named
EOT
}

SECONDS_BOUND=600

if [ $# -eq 1 ] && [ "$1" = "--help" ]; then usage; exit 0; fi
if [ $# -ne 3 ]; then usage >&2; exit 2; fi
build_a=$1 build_b=$2 lfn=$3

tool=findlife.sh
here=$(cd "$(dirname "$0")" && pwd) || exit 2
if [ ! -f "$here/common.sh" ]; then echo "findlife.sh: common.sh is missing beside the script" >&2; exit 3; fi
# shellcheck source=common.sh
. "$here/common.sh"
need_builds "$build_a" "$build_b"
lfn_parse "$lfn"
need_tools

run_begin life
guest_build FINDLIFE "$tmp/c" || invalid "FINDLIFE did not build"

# The emulator runs in the run's own folder, as windows.ps1 starts it there too: the builds and
# the launcher are named whole before the script moves into it.
whole() { case "$1" in /*) printf '%s\n' "$1" ;; *) printf '%s/%s\n' "$PWD" "$1" ;; esac; }
build_a=$(whole "$build_a") build_b=$(whole "$build_b") launcher=$(whole "$launcher")

# Each build gets its own D: tree: one case creates and removes a file in it. ROOT.TXT carries
# the host path the remount mounts it from, relative to the emulator's working folder: FINDLIFE
# hands it to MOUNT on a DOS command line, which holds 126 characters, and a path under TMPDIR
# grows past them.
run_one() {
    local label=$1 binary=$2 tree=$tmp/tree-$1
    findlife_tree "$tree" || invalid "could not make build $label's folders"
    host_path "../tree-$label" > "$tmp/c/ROOT.TXT" || invalid "could not write ROOT.TXT"
    if ! mkdir -p "$tmp/run-$label" || ! cd "$tmp/run-$label"; then invalid "could not enter build $label's run directory"; fi
    guest_run "$label" "$binary" "$tree" "" LIFE.TXT "$SECONDS_BOUND" "c:" 'FINDLIFE.EXE D:\A D:\B C:\LIFE.TXT C:\ROOT.TXT'
    LC_ALL=C tr -d '\r' < "$guest_out" > "$tmp/life-$label.txt" || invalid "build $label's report could not be read"
    echo "findlife.sh: build $label: $binary ($emu_version)"
    cat "$tmp/life-$label.txt"
    findlife_whole "$tmp/life-$label.txt" \
        || invalid "build $label's report has no case or no trailer"
}

echo "findlife.sh: long names $lfn"
run_one A "$build_a"
run_one B "$build_b"

cmp -s "$tmp/life-A.txt" "$tmp/life-B.txt"
cmp_rc=$?
if [ "$cmp_rc" -eq 0 ]; then echo "findlife.sh: ALIKE"; exit 0; fi
if [ "$cmp_rc" -ne 1 ]; then invalid "cmp failed (exit $cmp_rc)"; fi
echo "findlife.sh: DIFFERENT, the lines that differ (A then B):"
diff "$tmp/life-A.txt" "$tmp/life-B.txt" | command grep -a -E '^[<>]'
exit 1
