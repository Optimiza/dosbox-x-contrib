#!/usr/bin/env bash
# Runs XCOMSIM.EXE headless on two DOSBox-X builds: X-COM Apocalypse's measured lookups replayed
# as loads, and across them the two-DTA listing upstream issue 4904 describes; compares what the
# guest saw on each. See README.md beside this script.
set -u

usage() {
    cat <<'EOT'
usage: xcomsim.sh <build A> <build B> <on|off> [--listing-at <lookup>] [--between <n>] [--relay]

  <build A>, <build B>   DOSBox-X executables (the same one twice is the control)
  <on|off>               the guest's long file names ([dos] lfn)
  --listing-at <lookup>  lookups made before the listing starts (XCOMSIM's default otherwise)
  --between <n>          lookups between one FindNext and the next (XCOMSIM's default otherwise)
  --relay                the listing goes through the lookups' one DTA, its 43 bytes copied out
                         after each call and back before each FindNext, as the game's DOS
                         extender relays a protected-mode DTA through one real-mode buffer

a model, not the game: XCOMSIM replays the FindFirst lookups X-COM Apocalypse made in a measured
session (xcomsim/calls.txt, its names and attribute words only) in their order, as loads, until
past the emulator's 2,048 search slots, and at the listing point starts the listing the issue's
reporter describes: FindFirst through DTA A, FindFirst through DTA B, then FindNext on each in
turn with lookups between turns. The trace holds no FindNext: the listing is the reporter's
account.

the guest: D:\XCOMA holds every name the game found on C: as a small file, and is the current
directory of D: as C:\XCOMA was the game's; D:\LISTA and D:\LISTB hold 40 files each.

prints, per build, its path and version line, the guest's report whole (a lookup that answers
otherwise than it did in the game, a FindNext that failed before its listing ended, each
listing's count), and one line: the guest's verdict "listing=<found>/<expected>
<found>/<expected> lost=<n>", how many times the emulator logged its search table full
(slots_full) and a slot number out of range (out_of_range). Then the verdict on the two reports.

environment:
  DJDIR                 the DJGPP cross toolchain (default: $HOME/djgpp)
  DIRCACHE_PREBUILT     a folder holding XCOMSIM.EXE built on another host, instead of DJGPP

exit: 0 the two reports are alike | 1 they differ | 2 usage
      3 INVALID: an emulator failed or was cut off, or a report has no verdict or no trailer;
        the run's directory is kept and named
EOT
}

SECONDS_BOUND=600

if [ $# -eq 1 ] && [ "$1" = "--help" ]; then usage; exit 0; fi
if [ $# -lt 3 ]; then usage >&2; exit 2; fi
binary_a=$1 binary_b=$2 lfn=$3
shift 3
options=""
while [ $# -gt 0 ]; do
    case "$1" in
        --listing-at|--between)
            if [ $# -lt 2 ]; then usage >&2; exit 2; fi
            case "$2" in ''|*[!0-9]*) echo "xcomsim.sh: $1 takes a number, not: $2" >&2; exit 2 ;; esac
            options="$options $1 $2"
            shift 2
            ;;
        --relay) options="$options $1"; shift ;;
        *) echo "xcomsim.sh: unknown option: $1" >&2; exit 2 ;;
    esac
done

tool=xcomsim.sh
here=$(cd "$(dirname "$0")" && pwd) || exit 2
if [ ! -f "$here/common.sh" ]; then echo "xcomsim.sh: common.sh is missing beside the script" >&2; exit 3; fi
# shellcheck source=common.sh
. "$here/common.sh"
need_builds "$binary_a" "$binary_b"
lfn_parse "$lfn"
need_tools
calls=$here/xcomsim/calls.txt
if [ ! -f "$calls" ]; then fail_usage "the calls file is missing: $calls"; fi

run_begin xcomsim
guest_build XCOMSIM "$tmp/c" || invalid "XCOMSIM did not build"
cp "$calls" "$tmp/c/CALLS.TXT" || invalid "could not copy the calls file"
xcomsim_tree "$tmp/fx" "$calls" || invalid "could not make the drive"

for label in A B; do
    if [ "$label" = A ]; then binary=$binary_a; else binary=$binary_b; fi
    guest_run "$label" "$binary" "$tmp/fx" "" XCOMSIM.TXT "$SECONDS_BOUND" "c:" \
        "XCOMSIM.EXE C:\\CALLS.TXT D:\\XCOMA D:\\LISTA D:\\LISTB C:\\XCOMSIM.TXT$options"
    LC_ALL=C tr -d '\r' < "$guest_out" > "$tmp/report-$label.txt" || invalid "build $label's report could not be read"
    echo "$tool: build $label: $binary ($emu_version)"
    cat "$tmp/report-$label.txt"
    exact_whole "$tmp/report-$label.txt" || invalid "build $label's report has no line or no trailer"
    verdict=$(command grep -a '^listing=' "$tmp/report-$label.txt")
    case "$verdict" in listing=*/*' '*/*' lost='*) ;; *) invalid "build $label's report has no verdict line" ;; esac
    full=$(log_count 'All slots full') || invalid "the emulator's log could not be read"
    range=$(log_count 'ID out of range') || invalid "the emulator's log could not be read"
    echo "$tool: build $label: lfn=$lfn $verdict slots_full=$full out_of_range=$range build=\"$emu_version\" binary=$binary"
done
reports_verdict
