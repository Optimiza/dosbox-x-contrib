#!/usr/bin/env bash
# Runs ENUMSTAT.EXE headless on each DOSBox-X build given, over two folders of 3,000 files made
# for the run, and prints how many entries a whole-folder listing returns while every entry is
# looked up by its exact name. See README.md beside this script.
set -u

usage() {
    cat <<'EOT'
usage: enumstat.sh <build>...

  <build>...  one or more DOSBox-X executables

prints one line per build and row: long names on or off, the folder's names (8.3 or long), the
guest's own line (listing mode, entries listed, lookups that found their entry, the last name
listed), how many times the emulator logged its search table full and a slot number out of
range, and the emulator's version line and path. The rows:

  on  l long   714Eh listing, libc stat() on every entry
  on  s long   4Eh listing, libc stat() on every entry
  on  x 83     4Eh listing, a raw 4Eh exact-name search on every entry, never continued
  off s 83     4Eh listing, libc stat() on every entry
  off x 83     4Eh listing, a raw 4Eh exact-name search on every entry
  off n 83     4Eh listing alone: the count the others are read against

environment:
  DJDIR                 the DJGPP cross toolchain (default: $HOME/djgpp)
  DIRCACHE_PREBUILT     a folder holding ENUMSTAT.EXE built on another host, instead of DJGPP

exit: 0 every run printed its line | 2 usage
      3 INVALID: a run collected nothing or its line is not ENUMSTAT's; the run's directory is
        kept and named
EOT
}

SECONDS_BOUND=900
FILES=3000
ROWS="on:l:long on:s:long on:x:83 off:s:83 off:x:83 off:n:83"

if [ $# -eq 1 ] && [ "$1" = "--help" ]; then usage; exit 0; fi
if [ $# -lt 1 ]; then usage >&2; exit 2; fi

tool=enumstat.sh
here=$(cd "$(dirname "$0")" && pwd) || exit 2
if [ ! -f "$here/common.sh" ]; then echo "enumstat.sh: common.sh is missing beside the script" >&2; exit 3; fi
# shellcheck source=common.sh
. "$here/common.sh"
need_builds "$@"
need_tools

run_begin enumstat
guest_build ENUMSTAT "$tmp/c" || invalid "ENUMSTAT did not build"
folder_make "$tmp/fx-83/DIR" "$FILES" 83 || invalid "could not make the 8.3 folder"
folder_make "$tmp/fx-long/DIR" "$FILES" long || invalid "could not make the long-name folder"

n=0
for row in $ROWS; do
    lfn=${row%%:*} style=${row##*:} mode=${row#*:}
    mode=${mode%%:*}
    lfn_parse "$lfn"
    for build in "$@"; do
        n=$((n + 1))
        guest_run "$n" "$build" "$tmp/fx-$style" "" OUT.TXT "$SECONDS_BOUND" "c:" "ENUMSTAT.EXE $mode D:\\DIR C:\\OUT.TXT"
        line=$(LC_ALL=C tr -d '\r' < "$guest_out" | command grep -a '^enumstat|')
        case "$line" in "enumstat|mode=$mode|listed="*) ;; *) invalid "run $n: not ENUMSTAT's line for mode $mode: $line" ;; esac
        full=$(log_count 'All slots full') || invalid "the emulator's log could not be read"
        range=$(log_count 'ID out of range') || invalid "the emulator's log could not be read"
        echo "enumstat.sh: lfn=$lfn names=$style files=$FILES $line slots_full=$full out_of_range=$range build=\"$emu_version\" binary=$build"
    done
done
