#!/usr/bin/env bash
# Times the reporters' cases from the host: the shell's DIR of a folder or of one file in it, or
# one 716Ch or C library open of a file in it, on a folder the emulator has not read, on two
# DOSBox-X builds interleaved. See README.md beside this script.
set -u

usage() {
    cat <<'EOT'
usage: p5rep.sh <build A> <build B> <folder> <on|off> <case> <pairs> <out dir>

  <build A>, <build B>  two DOSBox-X executables (the same one twice is the A/A pair)
  <folder>              synthetic:<count>:<style>, made once under $P5_FOLDERS, or a host
                        directory, mounted read-only through its parent
  <on|off>              the guest's long file names ([dos] lfn)
  <case>                dir             the shell's DIR of the folder
                        dir:<name>      the shell's DIR of one file of the folder
                        open:<name>     one 716Ch open of one file of the folder (long names on)
                        fopen:<name>    the C library's fopen of one file of the folder
  <pairs>               how many A B B A rounds
  <out dir>             where each run's guest line, the launcher's report and the emulator's
                        pid are kept

the guest makes its ready file and waits; the clock starts when the host makes the go file and
stops when the host sees the stop file, which the shell makes right after its DIR, or P5REP as
soon as its open returns. DIR's count is read after the clock stopped. Each run is a fresh
emulator, its guest at a fixed clock.

prints a line naming the two builds and the case, one line per run,
  p5rep|<round>|<A|B>|seconds=<s>|t0=<epoch>|t1=<epoch>|pid=<emulator>|guest=<line>
and one per build with its fastest, median and slowest time.

environment:
  DJDIR                 the DJGPP cross toolchain (default: $HOME/djgpp)
  DIRCACHE_PREBUILT     a folder holding P5REP.EXE built on another host, instead of DJGPP
  P5_FOLDERS            where a synthetic folder is made and kept between runs (default: the
                        run's own directory)

exit: 0 timed, the two builds' guest lines alike | 1 the guest lines differ | 2 usage
      3 INVALID: the step did not run (no ready or stop file, no guest line, DIR counted no
        file, the open failed) or the emulator failed; the run's directory is kept and named
EOT
}

if [ $# -eq 1 ] && [ "$1" = "--help" ]; then usage; exit 0; fi
if [ $# -ne 7 ]; then usage >&2; exit 2; fi
build_a=$1 build_b=$2 folder=$3 lfn=$4 case_spec=$5 pairs=$6 out=$7
case "$pairs" in ''|*[!0-9]*|0) echo "p5rep.sh: pairs is a number from 1: $pairs" >&2; exit 2 ;; esac
case "$case_spec" in
    dir) step=dir name="" ;;
    dir:?*) step=dir name=${case_spec#dir:} ;;
    open:?*) step=open name=${case_spec#open:} ;;
    fopen:?*) step=fopen name=${case_spec#fopen:} ;;
    *) echo "p5rep.sh: the case is dir, dir:<name>, open:<name> or fopen:<name>: $case_spec" >&2; exit 2 ;;
esac
if [ "$step" = open ] && [ "$lfn" != on ]; then echo "p5rep.sh: 716Ch needs long names on" >&2; exit 2; fi
backslash=$'\\'
case "$name" in *'"'*|*"$backslash"*) echo "p5rep.sh: a name with no quote or backslash: $name" >&2; exit 2 ;; esac

tool=p5rep.sh
here=$(cd "$(dirname "$0")" && pwd) || exit 2
if [ ! -f "$here/common.sh" ]; then echo "p5rep.sh: common.sh is missing beside the script" >&2; exit 3; fi
# shellcheck source=common.sh
. "$here/common.sh"
need_builds "$build_a" "$build_b"
lfn_parse "$lfn"
folder_parse "$folder"
need_tools
command -v python3 > /dev/null || fail_usage "python3 is not on the PATH"
mkdir -p "$out" || exit 3
run_begin p5rep
guest_build P5REP "$tmp/c" || invalid "P5REP did not build"
timer_folder "$folder"
if [ -n "$name" ] && [ ! -e "$parent/$base/$name" ]; then
    echo "p5rep.sh: note: $name is not in the host folder; the run will say what the guest found" >&2
fi
# shellcheck disable=SC2034  # read by conf_write
conf_cycles=$TIMER_CYCLES

# The autoexec lines of one run, for the case.
case_lines() {
    if [ "$step" = open ] || [ "$step" = fopen ]; then
        printf '%s\n' "P5REP.EXE ${step:0:1} \"D:\\$base\\$name\" C:\\STOP.TXT C:\\READY.TXT C:\\GO.TXT C:\\P5.TXT"
        return
    fi
    printf '%s\n' "P5REP.EXE w C:\\READY.TXT C:\\GO.TXT"
    if [ -n "$name" ]; then
        printf '%s\n' "DIR \"D:\\$base\\$name\" > C:\\DIR.OUT"
    else
        printf '%s\n' "DIR D:\\$base > C:\\DIR.OUT"
    fi
    printf '%s\n' "ECHO stop> C:\\STOP.TXT" "P5REP.EXE m C:\\DIR.OUT C:\\P5.TXT"
}

# time_one <label> <build>: one run; sets seconds, t0, t1 and pid, keeps its guest line in $out.
time_one() {
    local label=$1 binary=$2 run=$tmp/$1 lines=() line
    if ! mkdir -p "$run" || ! cp "$tmp/c/P5REP.EXE" "$run/"; then invalid "could not make $run"; fi
    while IFS= read -r line || [ -n "$line" ]; do lines+=("$line"); done < <(case_lines)
    conf_write "$run" "$parent" " -ro" "c:" "${lines[@]}"
    timer_start "$label" "$binary" "$run" P5.TXT
    timer_clock "$label" "$run" STOP.TXT
    emu_finish "$label" || invalid "$label: the emulator did not run to its end"
    [ -f "$run/P5.TXT" ] || invalid "$label: the guest wrote no line"
    LC_ALL=C tr -d '\r' < "$run/P5.TXT" | awk '/^p5rep\|/' > "$out/$label.guest"
    [ -s "$out/$label.guest" ] || invalid "$label: the guest's capture is empty"
    case "$(cat "$out/$label.guest")" in
        *files=none*|*"files=0 "*) invalid "$label: DIR counted no file: $(cat "$out/$label.guest")" ;;
        *open=0000*|*files=*) ;;
        *) invalid "$label: the step failed: $(cat "$out/$label.guest")" ;;
    esac
    cp "$run/report.txt" "$out/$label.report"
    if [ -f "$run/DIR.OUT" ]; then LC_ALL=C tr -d '\r' < "$run/DIR.OUT" | tail -n 3 > "$out/$label.dirtail"; fi
    echo "$pid" > "$out/$label.pid"
}

echo "p5rep: A=$build_a B=$build_b folder=$folder lfn=$lfn case=$case_spec"
timer_rounds p5rep "$pairs" "$out" "$build_a" "$build_b"
