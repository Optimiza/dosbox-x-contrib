#!/usr/bin/env bash
# Runs MEMPROBE headless on one DOSBox-X build and reads the emulator's memory from outside
# while the guest holds after repeating one call. See README.md beside this script.
set -u

usage() {
    cat <<'EOT'
usage: memory.sh <build> <folder> <on|off> <mode> <calls> [--file <name>]

  <build>     a DOSBox-X executable
  <folder>    a host directory, mounted read-only and reached through its parent, or
              synthetic:<count>:<83|long>, a folder of <count> empty files made for this run
  <on|off>    the guest's long file names ([dos] lfn)
  <mode>      the call the guest repeats on one file of the folder:
                a access   s stat   d findfirst, never continued   o open+read+close
                f fopen+fread+fclose   r raw 716Ch open, read, close
                v 4Eh for the volume label   c child processes that each make one findfirst
                e 4Eh for each file of the folder in turn, by its name, never continued:
                  the folder is listed first, and <calls> past its size start over
  <calls>     how many times
  --file <name>   the file inside <folder> the guest names, as the guest can reach it (a host
                  directory needs it; a synthetic folder defaults to its first file)

prints one line: the call, the folder, then on macOS the peak resident size, the resident size
and the footprint while the guest holds after its calls (peak_rss_kb, held_rss_kb,
held_footprint_kb), on Windows the peak working set, the working set and the private bytes
(peak_ws_kb, held_ws_kb, held_private_kb), all in kB of 1,024 bytes; then how many samples, how
many "All slots full" lines the emulator logged, the guest's own line, the emulator's version
line and its path.

environment:
  DJDIR                 the DJGPP cross toolchain (default: $HOME/djgpp)
  DIRCACHE_PREBUILT     a folder holding MEMPROBE.EXE built on another host, instead of DJGPP

exit: 0 measured | 2 usage
      3 INVALID: a call did not reach the file, the guest was not read while it held, the
        emulator failed or passed the memory limit; the run's directory is kept and named
EOT
}

SECONDS_BOUND=1800

if [ $# -eq 1 ] && [ "$1" = "--help" ]; then usage; exit 0; fi
if [ $# -ne 5 ] && [ $# -ne 7 ]; then usage >&2; exit 2; fi
binary=$1 folder=$2 lfn=$3 mode=$4 calls=$5 file=""

tool=memory.sh
here=$(cd "$(dirname "$0")" && pwd) || exit 2
if [ ! -f "$here/common.sh" ]; then echo "memory.sh: common.sh is missing beside the script" >&2; exit 3; fi
# shellcheck source=common.sh
. "$here/common.sh"
if [ $# -eq 7 ]; then
    if [ "$6" != "--file" ]; then fail_usage "unknown option: $6"; fi
    file=$7
fi
need_builds "$binary"
lfn_parse "$lfn"
case "$mode" in a|s|d|o|f|r|v|c|e) ;; *) fail_usage "no such mode: $mode" ;; esac
case "$calls" in ''|*[!0-9]*|????????*) fail_usage "bad call count: $calls" ;; esac
folder_parse "$folder"
if [ -z "$synth_count" ]; then
    if [ -z "$file" ]; then fail_usage "a host directory needs --file <name>"; fi
    if [ ! -f "$folder/$file" ]; then fail_usage "no such file in the folder: $file"; fi
fi
need_tools

run_begin mem
run=$tmp/run
guest_build MEMPROBE "$run" || invalid "MEMPROBE did not build"
folder_resolve "$folder" "$lfn"
if [ -z "$file" ]; then synth_name "$synth_style" 0; file=$synth_name_out; fi

# The volume label belongs to the drive, so mode v names the drive's root and not the file.
if [ "$mode" = v ]; then guest_path='D:\*.*'; else guest_path="D:\\$base\\$file"; fi
conf_write "$run" "$parent" " -ro" "c:" "MEMPROBE.EXE $mode \"$guest_path\" $calls C:\\HELD.TXT C:\\GO.TXT > C:\\PRB.TXT"

memory_run "$binary" "$run" PRB.TXT "$SECONDS_BOUND"

# The guest's own line is the last one: in mode c each child prints one before it.
guest_line=$(LC_ALL=C tr -d '\r' < "$run/PRB.TXT" | awk '/^mode=/ { line = $0 } END { print line }')
case "$guest_line" in
    "mode=$mode k=$calls ok=$calls released=1 "*) ;;
    *) invalid "not every one of the $calls calls reached the file, or the guest was not let go: $guest_line" ;;
esac
memory_figures
slots_full=$(log_count 'All slots full') || invalid "the emulator's log could not be read"

echo "memory.sh: mode=$mode calls=$calls lfn=$lfn folder=$folder file=$file entries=$host_count $memory_figures_out slots_full=$slots_full guest=\"$guest_line\" build=\"$emu_version\" binary=$binary"
