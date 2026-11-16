#!/usr/bin/env bash
# Runs a DOS program that tests the folder it is started in, headless on one DOSBox-X build, and
# counts the PASS and FAIL lines it prints. See README.md beside this script.
set -u

usage() {
    cat <<'EOT'
usage: passfail.sh <build> <folder> <on|off> <program>

  <build>     a DOSBox-X executable
  <folder>    a host directory, mounted read-only and reached through its parent, or
              synthetic:<count>:<83|long>, a folder of <count> empty files made for this run
  <on|off>    the guest's long file names ([dos] lfn)
  <program>   a DOS executable that takes no arguments, searches its current directory and
              prints one line ending in PASS or FAIL per check

the guest changes into the folder, then starts the program from another drive.

prints what the program printed, then one line: the program and the start of its sha256, how
many of its lines end in PASS and in FAIL, its exit code, and the emulator's version line and
path.

exit: 0 ran, the counts are reported | 2 usage
      3 INVALID: the guest did not reach the folder, the program printed no PASS or FAIL
        line, or the run collected nothing; the run's directory is kept and named
EOT
}

SECONDS_BOUND=600

if [ $# -eq 1 ] && [ "$1" = "--help" ]; then usage; exit 0; fi
if [ $# -ne 4 ]; then usage >&2; exit 2; fi
binary=$1 folder=$2 lfn=$3 program=$4

tool=passfail.sh
here=$(cd "$(dirname "$0")" && pwd) || exit 2
if [ ! -f "$here/common.sh" ]; then echo "passfail.sh: common.sh is missing beside the script" >&2; exit 3; fi
# shellcheck source=common.sh
. "$here/common.sh"
need_builds "$binary"
lfn_parse "$lfn"
if [ ! -f "$program" ]; then fail_usage "no such program: $program"; fi
name=$(basename "$program" | tr '[:lower:]' '[:upper:]')
case "$name" in
    *[!A-Z0-9_.-]*|*.*.*) fail_usage "the program needs an 8.3 name: $name" ;;
    ????????.EXE|???????.EXE|??????.EXE|?????.EXE|????.EXE|???.EXE|??.EXE|?.EXE) ;;
    *) fail_usage "the program needs an 8.3 name ending in .EXE: $name" ;;
esac
folder_parse "$folder"
# The program is handed over built, so the host needs the launcher and no compiler.
DIRCACHE_PREBUILT=$(dirname "$program") need_tools

run_begin passfail
folder_resolve "$folder" "$lfn"
if ! mkdir -p "$tmp/c" || ! cp "$program" "$tmp/c/$name"; then invalid "could not copy the program"; fi
digest=$(shasum -a 256 "$tmp/c/$name" | cut -c1-12)

# CD with no argument prints where the guest stands: the proof that it reached the folder. The
# shell has no variable for a program's exit code, only IF ERRORLEVEL n, true from n up: one
# line per value, and the last one RC.TXT holds is the code.
{
    printf '@echo off\r\nd:\r\ncd \\%s\r\ncd > C:\\CWD.TXT\r\nC:\\%s > C:\\OUT.TXT\r\n' "$base" "$name"
    n=0
    while [ "$n" -le 255 ]; do
        printf 'if errorlevel %d echo %d >> C:\\RC.TXT\r\n' "$n" "$n"
        n=$((n + 1))
    done
} > "$tmp/c/INSIDE.BAT" || invalid "could not write the guest's batch file"
guest_run program "$binary" "$parent" " -ro" OUT.TXT "$SECONDS_BOUND" 'call C:\INSIDE.BAT'
run=$tmp/run-program

cwd=$(LC_ALL=C tr -d '\r' < "$run/CWD.TXT" 2>/dev/null | tr '[:lower:]' '[:upper:]')
want=$(printf 'D:\\%s' "$base" | tr '[:lower:]' '[:upper:]')
if [ "$cwd" != "$want" ]; then invalid "the guest stood in \"$cwd\" and not in $want when the program ran"; fi
LC_ALL=C tr -d '\r' < "$guest_out" > "$tmp/out.txt" || invalid "the program's output could not be read"
cat "$tmp/out.txt"
pass=$(awk '/ PASS$/ { n++ } END { print n + 0 }' "$tmp/out.txt")
fail=$(awk '/ FAIL$/ { n++ } END { print n + 0 }' "$tmp/out.txt")
if [ ! -s "$run/RC.TXT" ]; then invalid "the shell recorded no exit code for the program"; fi
code=$(LC_ALL=C tr -d '\r ' < "$run/RC.TXT" | awk 'NF { last = $0 } END { print last }')
case "$code" in ''|*[!0-9]*) invalid "the recorded exit code is not a number: $code" ;; esac

line="passfail.sh: program=$name sha256=$digest lfn=$lfn folder=$folder entries=$host_count pass=$pass fail=$fail exit=$code build=\"$emu_version\" binary=$binary"
if [ $((pass + fail)) -eq 0 ]; then
    echo "$line" >&2
    invalid "the program printed no PASS or FAIL line"
fi
echo "$line"
