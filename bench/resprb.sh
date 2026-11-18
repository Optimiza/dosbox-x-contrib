#!/usr/bin/env bash
# Runs RESPRB.EXE headless on one DOSBox-X build and reads the emulator's memory from outside
# while the guest holds after repeating one thing: a child process of one kind, a change of the
# FPU's control word, or a search. See README.md beside this script.
set -u

usage() {
    cat <<'EOT'
usage: resprb.sh <build> <mode> <calls> [--core <dynamic|normal>]

  <build>   a DOSBox-X executable
  <mode>    what RESPRB repeats, over a folder of 100 empty 8.3 files, long names off:
              c  a protected-mode child that starts a search and ends (memory.sh's mode c)
              n  a protected-mode child that returns at once: no search at all
              w  a protected-mode child that runs a search of the folder to its end
              r  a real-mode child that starts a search and ends: no DPMI, no FPU
              q  a real-mode child that ends at once
              p  no child and no search: FNINIT, then FLDCW with three exceptions unmasked,
                 the two control words a protected-mode child's start-up goes through
              d  no child: a search started and never continued
  <calls>   how many times
  --core    the emulator's CPU core (default dynamic, as every script of this folder runs)

prints one line: the mode, the calls, the core, then as memory.sh prints them the peak, the
resident size or working set and the footprint or private bytes while the guest holds, in kB;
resets= how many times the dynamic core reset its code cache, on a build of the source with
counters/count-dyn.diff applied, or none when the log holds no reset: a build without that
counter, or the normal core (the figures of memory need no counter); the guest's own line, the
emulator's version line and its path.

environment:
  DJDIR                 the DJGPP cross toolchain (default: $HOME/djgpp)
  DIRCACHE_PREBUILT     a folder holding RESPRB.EXE built on another host, instead of DJGPP

exit: 0 measured | 2 usage
      3 INVALID: a repetition did not answer, the guest was not read while it held, the
        emulator failed or passed the memory limit; the run's directory is kept and named
EOT
}

SECONDS_BOUND=1800
FILES=100

if [ $# -eq 1 ] && [ "$1" = "--help" ]; then usage; exit 0; fi
if [ $# -ne 3 ] && [ $# -ne 5 ]; then usage >&2; exit 2; fi
binary=$1 mode=$2 calls=$3 core=dynamic

tool=resprb.sh
here=$(cd "$(dirname "$0")" && pwd) || exit 2
if [ ! -f "$here/common.sh" ]; then echo "resprb.sh: common.sh is missing beside the script" >&2; exit 3; fi
# shellcheck source=common.sh
. "$here/common.sh"
if [ $# -eq 5 ]; then
    if [ "$4" != --core ]; then fail_usage "unknown option: $4"; fi
    core=$5
fi
need_builds "$binary"
lfn_parse off
case "$mode" in c|n|w|r|q|p|d) ;; *) fail_usage "no such mode: $mode" ;; esac
case "$core" in dynamic|normal) ;; *) fail_usage "the core is dynamic or normal, not: $core" ;; esac
case "$calls" in ''|*[!0-9]*|????????*) fail_usage "bad call count: $calls" ;; esac
need_tools

run_begin res
run=$tmp/run
guest_build RESPRB "$run" || invalid "RESPRB did not build"
# The two real-mode children, written byte by byte:
#   FF.COM   mov ah,4Eh / mov cx,37h / mov dx,10Fh / int 21h / mov ax,4C00h / int 21h, then
#            "D:\DIR\*.*": a search never continued
#   NOP.COM  mov ax,4C00h / int 21h
printf '\xB4\x4E\xB9\x37\x00\xBA\x0F\x01\xCD\x21\xB8\x00\x4C\xCD\x21D:\\DIR\\*.*\x00' > "$run/FF.COM" || invalid "could not write FF.COM"
printf '\xB8\x00\x4C\xCD\x21' > "$run/NOP.COM" || invalid "could not write NOP.COM"
folder_parse "synthetic:$FILES:83"
folder_resolve "synthetic:$FILES:83" off
synth_name 83 0
case "$mode" in w) guest_path="D:\\$base\\*.*" ;; *) guest_path="D:\\$base\\$synth_name_out" ;; esac
conf_write "$run" "$parent" " -ro" "c:" "RESPRB.EXE $mode \"$guest_path\" $calls C:\\HELD.TXT C:\\GO.TXT > C:\\PRB.TXT"
if [ "$core" = normal ]; then
    lines=$(command grep -c '^core=dynamic$' "$run/run.conf")
    if [ "$lines" != 1 ]; then invalid "the conf has $lines core lines"; fi
    if ! sed 's/^core=dynamic$/core=normal/' "$run/run.conf" > "$run/run.conf.new" || ! mv "$run/run.conf.new" "$run/run.conf" \
        || [ "$(command grep -c '^core=normal$' "$run/run.conf")" != 1 ]; then
        invalid "could not set the core"
    fi
fi

memory_run "$binary" "$run" PRB.TXT "$SECONDS_BOUND"
guest_line=$(LC_ALL=C tr -d '\r' < "$run/PRB.TXT" | awk '/^mode=/ { line = $0 } END { print line }')
case "$guest_line" in
    "mode=$mode k=$calls ok=$calls released=1 "*) ;;
    *) invalid "not every one of the $calls repetitions answered, or the guest was not let go: $guest_line" ;;
esac
memory_figures
resets=$(log_count 'DYN-CACHE-RESET reset=') || invalid "the emulator's log could not be read"
if [ "$resets" -eq 0 ]; then resets=none; fi

echo "resprb.sh: mode=$mode calls=$calls core=$core files=$FILES $memory_figures_out resets=$resets guest=\"$guest_line\" build=\"$emu_version\" binary=$binary"
