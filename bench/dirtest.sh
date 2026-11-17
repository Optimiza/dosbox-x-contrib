#!/usr/bin/env bash
# Runs the program a reporter attached to upstream issue 2485, as it is, headless on
# one DOSBox-X build, and reads the emulator's memory from outside once it ends. See README.md
# beside this script.
set -u

usage() {
    cat <<'EOT'
usage: dirtest.sh <build> <folder> <on|off>

  <build>   a DOSBox-X executable
  <folder>  the archive of upstream issue 2485, unpacked: DIRTEST.EXE and its folder DATA. The
            run works on a copy; the folder is never written
  <on|off>  the guest's long file names ([dos] lfn); the reporter's conf leaves them off

the guest: D: is the copy and DIRTEST.EXE runs from its root, as the issue says. It is a FoxPro
program with its runtime and DOS extender inside: it lists DATA, asks FILE() of each name, prints
a count, and ends on an error its runtime raises after the loop ("Feature not available", the
program's own SET STEP ON, which the reporter explains in the issue). That dialog waits for a key,
so the emulator types Enter every few seconds from before the program starts (AUTOTYPE), and the
first one after the dialog is up cancels it, which ends the program. The program draws on the
screen, so its lookups are counted from the INT 21h calls the emulator logs ([log] int21) between
the shell starting it and the shell's next prompt. Then MEMPROBE, on another drive and with no
call to make, holds while the host reads the emulator.

prints one line: the files in DATA, the 4Fh calls (its listing of DATA) and the 4Eh calls (the
listing's first, one per FILE(), and the few the runtime makes for itself) the program made, the
three memory figures memory.sh prints (the first is the peak while it ran), how many samples, how
many "All slots full" and "ID out of range" lines the emulator logged, the emulator's version line
and its path.

environment:
  DJDIR                 the DJGPP cross toolchain (default: $HOME/djgpp)
  DIRCACHE_PREBUILT     a folder holding MEMPROBE.EXE built on another host, instead of DJGPP

on Windows a build that exits with AUTOTYPE's keys still pending ends with 0xC0000409, which
upstream's builds do there; that exit is taken as the run's end once the guest's last line,
MEMPROBE's after the hold, has been read, and a line says so.

exit: 0 measured | 2 usage
      3 INVALID: the folder is absent or lacks DIRTEST.EXE or DATA, the program did not start, did
        not return or did not look every file of DATA up, the guest was not read while it held,
        the emulator failed or passed the memory limit; the run's directory is kept and named
EOT
}

SECONDS_BOUND=1800
# Enter for 25 minutes, long past the program's end on a host folder.
DIRTEST_KEYS=150

if [ $# -eq 1 ] && [ "$1" = "--help" ]; then usage; exit 0; fi
if [ $# -ne 3 ]; then usage >&2; exit 2; fi
binary=$1 folder=$2 lfn=$3

tool=dirtest.sh
here=$(cd "$(dirname "$0")" && pwd) || exit 2
if [ ! -f "$here/common.sh" ]; then echo "dirtest.sh: common.sh is missing beside the script" >&2; exit 3; fi
# shellcheck source=common.sh
. "$here/common.sh"
need_builds "$binary"
lfn_parse "$lfn"
need_tools
# shellcheck disable=SC2086  # the names, split on purpose
reporter_folder "$folder" $DIRTEST_FILES

run_begin dirtest
run=$tmp/run tree=$tmp/tree
mkdir -p "$tree" || invalid "could not make the folder"
cp -R "$folder/." "$tree/" || invalid "could not copy the reporter's folder"
files=$(find "$tree/DATA" -type f | wc -l | tr -d ' ')
if [ "$files" -eq 0 ]; then invalid "the reporter's DATA holds no file"; fi
guest_build MEMPROBE "$run" || invalid "MEMPROBE did not build"

# shellcheck disable=SC2034  # read by conf_write and emu_finish
conf_dos='log console=true' accept_exit=-1073740791
conf_write "$run" "$tree" "" "d:" "$(dirtest_autotype "$DIRTEST_KEYS")" "DIRTEST.EXE" "c:" \
    "MEMPROBE.EXE a C:\\HELD.TXT 0 C:\\HELD.TXT C:\\GO.TXT > C:\\PRB.TXT"
printf '\n[log]\nint21=true\ndosmisc=debug\n' >> "$run/run.conf" || invalid "could not write the conf"
memory_run "$binary" "$run" PRB.TXT "$SECONDS_BOUND"

# shellcheck disable=SC2046  # four counts, split on purpose
set -- $(LC_ALL=C tr -d '\r' < "$emu_dir/dosbox.log" | LC_ALL=C awk '
    /^DOS CON: .*>DIRTEST\.EXE$/ { on = 1; started = 1; next }
    on && /^DOS CON: / { on = 0; back = 1 }
    on && / ah=4e, / { e++ }
    on && / ah=4f, / { f++ }
    END { print started + 0, back + 0, e + 0, f + 0 }')
if [ $# -ne 4 ]; then invalid "the emulator's log could not be read"; fi
if [ "$1" -ne 1 ]; then invalid "the shell never started DIRTEST.EXE"; fi
if [ "$2" -ne 1 ]; then invalid "DIRTEST.EXE never returned to the shell"; fi
calls_4e=$3 calls_4f=$4
if [ "$calls_4f" -lt "$files" ] || [ "$calls_4e" -le "$files" ]; then
    invalid "DIRTEST did not look every file of DATA up: $files files, calls_4f=$calls_4f calls_4e=$calls_4e"
fi
case "$(LC_ALL=C tr -d '\r' < "$run/PRB.TXT")" in
    "mode=a k=0 ok=0 released=1 "*) ;;
    *) invalid "the guest did not hold, or was not let go" ;;
esac
memory_figures
slots_full=$(log_count 'All slots full') || invalid "the emulator's log could not be read"
out_of_range=$(log_count 'ID out of range') || invalid "the emulator's log could not be read"

if [ -n "$emu_exit_accepted" ]; then
    echo "dirtest.sh: the emulator exited $emu_exit_accepted (0xC0000409) with AUTOTYPE's keys still pending, after the guest's last line was read"
fi
echo "dirtest.sh: lfn=$lfn files=$files calls_4f=$calls_4f calls_4e=$calls_4e $memory_figures_out slots_full=$slots_full out_of_range=$out_of_range build=\"$emu_version\" binary=$binary"
