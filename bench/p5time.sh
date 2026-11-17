#!/usr/bin/env bash
# Times the first read of a folder from the host: P5PROBE's one 4Eh for <folder>\*.* on a folder
# the emulator has not read, on two DOSBox-X builds interleaved. See README.md beside this script.
set -u

usage() {
    cat <<'EOT'
usage: p5time.sh <build A> <build B> <folder> <on|off> <pairs> <out dir>

  <build A>, <build B>  two DOSBox-X executables (the same one twice is the A/A pair)
  <folder>              synthetic:<count>:<style>, made once under $P5_FOLDERS, or a host
                        directory, mounted read-only through its parent
  <on|off>              the guest's long file names ([dos] lfn)
  <pairs>               how many A B B A rounds
  <out dir>             where each run's guest line, the launcher's report and the emulator's
                        pid are kept

the guest makes its ready file and waits; the clock starts when the host makes the go file and
stops when the host sees the guest's last line, its 4Eh done. Each run is a fresh emulator, its
guest at a fixed clock.

prints a line naming the two builds, one line per run,
  p5time|<round>|<A|B>|seconds=<s>|t0=<epoch>|t1=<epoch>|pid=<emulator>|guest=<line>
and one per build with its fastest, median and slowest time.

environment:
  P5_FOLDERS            where a synthetic folder is made and kept between runs (default: the
                        run's own directory)
  DJDIR                 the DJGPP cross toolchain (default: $HOME/djgpp)
  DIRCACHE_PREBUILT     a folder holding P5PROBE.EXE built on another host, instead of DJGPP

exit: 0 timed, the two builds' guest lines alike | 1 the guest lines differ | 2 usage
      3 INVALID: a run did not reach its last line, or the emulator failed; the run's directory
        is kept and named
EOT
}

if [ $# -eq 1 ] && [ "$1" = "--help" ]; then usage; exit 0; fi
if [ $# -ne 6 ]; then usage >&2; exit 2; fi
build_a=$1 build_b=$2 folder=$3 lfn=$4 pairs=$5 out=$6
case "$pairs" in ''|*[!0-9]*|0) echo "p5time.sh: pairs is a number from 1: $pairs" >&2; exit 2 ;; esac

tool=p5time.sh
here=$(cd "$(dirname "$0")" && pwd) || exit 2
if [ ! -f "$here/common.sh" ]; then echo "p5time.sh: common.sh is missing beside the script" >&2; exit 3; fi
# shellcheck source=common.sh
. "$here/common.sh"
need_builds "$build_a" "$build_b"
lfn_parse "$lfn"
folder_parse "$folder"
need_tools
command -v python3 > /dev/null || fail_usage "python3 is not on the PATH"
mkdir -p "$out" || exit 3
run_begin p5time
guest_build P5PROBE "$tmp/c" || invalid "P5PROBE did not build"
timer_folder "$folder"
# shellcheck disable=SC2034  # read by conf_write
conf_cycles=$TIMER_CYCLES

# time_one <label> <build>: one run; sets seconds, t0, t1 and pid, keeps its guest line in $out.
time_one() {
    local label=$1 binary=$2 run=$tmp/$1
    if ! mkdir -p "$run" || ! cp "$tmp/c/P5PROBE.EXE" "$run/"; then invalid "could not make $run"; fi
    conf_write "$run" "$parent" " -ro" "c:" "P5PROBE.EXE f D:\\$base \"*.*\" 0 C:\\P5.TXT C:\\READY.TXT C:\\GO.TXT C:\\END.TXT"
    timer_start "$label" "$binary" "$run" P5.TXT
    timer_clock "$label" "$run" P5.TXT "end|"
    : > "$run/END.TXT"
    emu_finish "$label" || invalid "$label: the emulator did not run to its end"
    LC_ALL=C tr -d '\r' < "$run/P5.TXT" | awk '/^p5\|/' > "$out/$label.guest"
    cp "$run/report.txt" "$out/$label.report"
    echo "$pid" > "$out/$label.pid"
}

echo "p5time: A=$build_a B=$build_b folder=$folder lfn=$lfn"
timer_rounds p5time "$pairs" "$out" "$build_a" "$build_b"
