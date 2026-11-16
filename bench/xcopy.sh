#!/usr/bin/env bash
# Runs the emulator's own XCOPY.EXE headless on one DOSBox-X build, over a tree of folders made
# for the run, and counts on the host how much of the tree arrived. See README.md beside this
# script.
set -u

usage() {
    cat <<'EOT'
usage: xcopy.sh <build> <on|off>

  <build>   a DOSBox-X executable
  <on|off>  the guest's long file names ([dos] lfn)

the guest: D:\TREE holds folders three levels deep, with files at the two lower levels, every
name 8.3. The shell makes D:\COPY and runs "XCOPY D:\TREE\*.* D:\COPY /S /E /Y", XCOPY.EXE
being the one on the emulator's Z: drive.

prints one line: how many files and folders the tree holds (made, dirs_made), how many of each
are under D:\COPY afterwards, counted on the host (copied, dirs_copied), the count XCOPY itself
printed (said, or - when it printed none), how many times the emulator logged its search table
full and a slot number out of range, and the emulator's version line and path. It compares
nothing: read copied against made.

exit: 0 the run printed its line | 2 usage
      3 INVALID: the emulator failed or was cut off, or XCOPY printed nothing; the run's
        directory is kept and named
EOT
}

SECONDS_BOUND=900

if [ $# -eq 1 ] && [ "$1" = "--help" ]; then usage; exit 0; fi
if [ $# -ne 2 ]; then usage >&2; exit 2; fi
binary=$1 lfn=$2

tool=xcopy.sh
here=$(cd "$(dirname "$0")" && pwd) || exit 2
if [ ! -f "$here/common.sh" ]; then echo "xcopy.sh: common.sh is missing beside the script" >&2; exit 3; fi
# shellcheck source=common.sh
. "$here/common.sh"
need_builds "$binary"
lfn_parse "$lfn"
need_tools

run_begin xcopy
mkdir "$tmp/c" || invalid "could not make the run directory"
xcopy_tree "$tmp/fx/TREE" || invalid "could not make the tree"
made=$(find "$tmp/fx/TREE" -type f | wc -l | tr -d ' ')
dirs_made=$(find "$tmp/fx/TREE" -mindepth 1 -type d | wc -l | tr -d ' ')

guest_run 1 "$binary" "$tmp/fx" "" XCOPY.TXT "$SECONDS_BOUND" "md D:\\COPY" "XCOPY D:\\TREE\\*.* D:\\COPY /S /E /Y > C:\\XCOPY.TXT"
if [ ! -s "$guest_out" ]; then invalid "XCOPY printed nothing"; fi
# Counted on the host: the emulator's own listing of the copy is what is under test.
copied=0 dirs_copied=0
if [ -d "$tmp/fx/COPY" ]; then
    copied=$(find "$tmp/fx/COPY" -type f | wc -l | tr -d ' ')
    dirs_copied=$(find "$tmp/fx/COPY" -mindepth 1 -type d | wc -l | tr -d ' ')
fi
said=$(xcopy_said "$guest_out")
full=$(log_count 'All slots full') || invalid "the emulator's log could not be read"
range=$(log_count 'ID out of range') || invalid "the emulator's log could not be read"

echo "xcopy.sh: lfn=$lfn made=$made copied=$copied dirs_made=$dirs_made dirs_copied=$dirs_copied said=${said:--} slots_full=$full out_of_range=$range build=\"$emu_version\" binary=$binary"
