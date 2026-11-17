#!/usr/bin/env bash
# Runs the batch files a reporter attached to upstream issue 6827, as they are,
# headless on one DOSBox-X build, and reads the emulator's memory from outside once they end. See
# README.md beside this script.
set -u

usage() {
    cat <<'EOT'
usage: junktest.sh <build> <folder> <on|off> <batch>...

  <build>   a DOSBox-X executable
  <folder>  the archive of upstream issue 6827, unpacked: 300.BAT, JUNK.BAT, DJUNK.BAT,
            e001.exp and RESULT.TXT. The run works on a copy; the folder is never written
  <on|off>  the guest's long file names ([dos] lfn); the reporter's conf leaves them off
  <batch>   300, JUNK or DJUNK, the reporter's batch files, called in the order given:
            "300 JUNK 300" is the run the issue describes

the guest: D: is the copy, the reporter's folder at its root, as the issue mounts it. FC.EXE is
the one on the emulator's Z: drive, as in the report: the archive carries none. FC first
compares the reporter's two files once, its answer kept, which shows it runs in that folder;
then the shell calls each batch file. 300.BAT sends FC's answers to NUL, so the runs are counted
from what the batch files print, which the emulator logs ([dos] log console). Then MEMPROBE, on
another drive and with no call to make, holds while the host reads the emulator.

prints one line: the batch files, how many entries the folder holds at the end and how many of
them are .TMP files (JUNK.BAT makes them), how many lines 300.BAT counted its runs with and how
many batch files said Done, the three memory figures memory.sh prints (the first is the peak while
the batch files ran), how many samples, how many "All slots full" and "ID out of range" lines the
emulator logged, the emulator's version line and its path.

environment:
  DJDIR                 the DJGPP cross toolchain (default: $HOME/djgpp)
  DIRCACHE_PREBUILT     a folder holding MEMPROBE.EXE built on another host, instead of DJGPP

exit: 0 measured | 2 usage
      3 INVALID: the folder is absent or lacks one of the reporter's files, FC did not compare
        them, a batch file did not reach its end, the guest was not read while it held, the
        emulator failed or passed the memory limit; the run's directory is kept and named
EOT
}

SECONDS_BOUND=1800

if [ $# -eq 1 ] && [ "$1" = "--help" ]; then usage; exit 0; fi
if [ $# -lt 4 ]; then usage >&2; exit 2; fi
binary=$1 folder=$2 lfn=$3
shift 3

tool=junktest.sh
here=$(cd "$(dirname "$0")" && pwd) || exit 2
if [ ! -f "$here/common.sh" ]; then echo "junktest.sh: common.sh is missing beside the script" >&2; exit 3; fi
# shellcheck source=common.sh
. "$here/common.sh"
need_builds "$binary"
lfn_parse "$lfn"
junktest_batches "$@"
need_tools
# shellcheck disable=SC2086  # the names, split on purpose
reporter_folder "$folder" $JUNKTEST_FILES

run_begin junktest
run=$tmp/run tree=$tmp/tree
mkdir -p "$tree" || invalid "could not make the folder"
cp -R "$folder/." "$tree/" || invalid "could not copy the reporter's folder"
guest_build MEMPROBE "$run" || invalid "MEMPROBE did not build"

lines=("d:" "FC /B E001.EXP RESULT.TXT > C:\\FC.TXT")
for b in "$@"; do lines+=("CALL $b.BAT"); done
# MEMPROBE is started from C: so that the hold searches nothing on the folder's drive.
# shellcheck disable=SC2034  # read by conf_write
conf_dos='log console=true'
conf_write "$run" "$tree" "" "${lines[@]}" "c:" "MEMPROBE.EXE a C:\\HELD.TXT 0 C:\\HELD.TXT C:\\GO.TXT > C:\\PRB.TXT"
memory_run "$binary" "$run" PRB.TXT "$SECONDS_BOUND"

fc_answered "$run/FC.TXT" || invalid "FC did not compare the reporter's two files"
sed -n 's/^DOS CON: //p' "$emu_dir/dosbox.log" > "$tmp/console.txt" || invalid "the emulator's log could not be read"
said=$(junktest_said "$tmp/console.txt")
if [ "$said" != "counted=$((junktest_runs * 300)) done=$#" ]; then
    invalid "the batch files did not reach their end: $said for $*"
fi
case "$(LC_ALL=C tr -d '\r' < "$run/PRB.TXT")" in
    "mode=a k=0 ok=0 released=1 "*) ;;
    *) invalid "the guest did not hold, or was not let go" ;;
esac
memory_figures
slots_full=$(log_count 'All slots full') || invalid "the emulator's log could not be read"
out_of_range=$(log_count 'ID out of range') || invalid "the emulator's log could not be read"
entries=$(find "$tree" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')
junk=$(find "$tree" -mindepth 1 -maxdepth 1 -iname '*.TMP' | wc -l | tr -d ' ')

batches=$*
echo "junktest.sh: batches=${batches// /,} lfn=$lfn entries=$entries junk=$junk $said $memory_figures_out slots_full=$slots_full out_of_range=$out_of_range build=\"$emu_version\" binary=$binary"
