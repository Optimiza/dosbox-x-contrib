#!/usr/bin/env bash
# Runs the emulator's own FC.EXE again and again from a batch file, headless on one DOSBox-X
# build, inside a folder of empty files made for the run, and reads the emulator's memory from
# outside. See README.md beside this script.
set -u

usage() {
    cat <<'EOT'
usage: fc.sh <build> <files> <on|off> <runs>

  <build>   a DOSBox-X executable
  <files>   how many empty files the folder holds beside the two that are compared and the
            batch file
  <on|off>  the guest's long file names ([dos] lfn)
  <runs>    how many times the batch file runs FC

the guest: D:\DIR holds <files> empty files with 8.3 names, ONE.TXT and TWO.TXT, which are
equal, and RUNS.BAT, one line "FC ONE.TXT TWO.TXT" per run. The shell runs RUNS.BAT from inside
the folder, FC.EXE being the one on the emulator's Z: drive; then MEMPROBE, on another drive
and with no call to make, holds while the host reads the emulator.

prints one line: the folder and the runs, then the three memory figures memory.sh prints (the
first is the peak while FC ran), how many samples, how many "All slots full" lines the emulator
logged, how many runs of FC said the two files do not differ, the emulator's version line and
its path.

environment:
  DJDIR                 the DJGPP cross toolchain (default: $HOME/djgpp)
  DIRCACHE_PREBUILT     a folder holding MEMPROBE.EXE built on another host, instead of DJGPP

exit: 0 measured | 2 usage
      3 INVALID: a run of FC did not compare the two files, the guest was not read while it
        held, the emulator failed or passed the memory limit; the run's directory is kept and
        named
EOT
}

SECONDS_BOUND=1800

if [ $# -eq 1 ] && [ "$1" = "--help" ]; then usage; exit 0; fi
if [ $# -ne 4 ]; then usage >&2; exit 2; fi
binary=$1 files=$2 lfn=$3 runs=$4

tool=fc.sh
here=$(cd "$(dirname "$0")" && pwd) || exit 2
if [ ! -f "$here/common.sh" ]; then echo "fc.sh: common.sh is missing beside the script" >&2; exit 3; fi
# shellcheck source=common.sh
. "$here/common.sh"
need_builds "$binary"
case "$files" in ''|*[!0-9]*|????????*) fail_usage "bad file count: $files" ;; esac
lfn_parse "$lfn"
case "$runs" in ''|*[!0-9]*|????????*) fail_usage "bad run count: $runs" ;; esac
if [ "$runs" -lt 1 ]; then fail_usage "bad run count: $runs"; fi
need_tools

run_begin fc
run=$tmp/run
guest_build MEMPROBE "$run" || invalid "MEMPROBE did not build"
fc_folder "$tmp/tree/DIR" "$files" "$runs" 'C:\FC.TXT' || invalid "could not make the folder"
host_count=$(find "$tmp/tree/DIR" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')

# MEMPROBE is started from C: so that the hold searches nothing on the folder's drive.
conf_write "$run" "$tmp/tree" "" "d:" "cd \\DIR" "call RUNS.BAT" "c:" \
    "MEMPROBE.EXE a C:\\HELD.TXT 0 C:\\HELD.TXT C:\\GO.TXT > C:\\PRB.TXT"
memory_run "$binary" "$run" PRB.TXT "$SECONDS_BOUND"

compared=$(fc_compared "$run/FC.TXT")
if [ "$compared" != "$runs" ]; then invalid "FC compared the two files ${compared:-0} times of $runs"; fi
case "$(LC_ALL=C tr -d '\r' < "$run/PRB.TXT")" in
    "mode=a k=0 ok=0 released=1 "*) ;;
    *) invalid "the guest did not hold, or was not let go" ;;
esac
memory_figures
slots_full=$(log_count 'All slots full') || invalid "the emulator's log could not be read"

echo "fc.sh: files=$files runs=$runs lfn=$lfn entries=$host_count $memory_figures_out slots_full=$slots_full compared=$compared build=\"$emu_version\" binary=$binary"
