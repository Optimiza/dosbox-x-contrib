#!/usr/bin/env bash
# Runs LISTDUMP headless on two DOSBox-X builds over one folder and compares the two dumps with
# cmp. See README.md beside this script.
set -u

usage() {
    cat <<'EOT'
usage: run.sh <build A> <build B> <folder> <on|off>

  <build A>, <build B>  two DOSBox-X executables (the same one twice is the A/A control)
  <folder>              a host directory, mounted read-only and listed through its parent, or
                        synthetic:<count>:<83|long>, a folder of <count> empty files made for
                        this run (8.3 names, or long names that need aliases)
  <on|off>              the guest's long file names ([dos] lfn)

prints each build's path, version line and counts, then IDENTICAL or DIFFERENT with the first
differing lines.

environment:
  DJDIR                 the DJGPP cross toolchain (default: $HOME/djgpp)
  DIRCACHE_PREBUILT     a folder holding LISTDUMP.EXE built on another host, instead of DJGPP

exit: 0 identical | 1 different | 2 usage
      3 INVALID: a run collected nothing, a dump is truncated or disagrees with its own
        counts, or the folder is empty; the run's directory is kept and named
EOT
}

SECONDS_BOUND=1800

if [ $# -eq 1 ] && [ "$1" = "--help" ]; then usage; exit 0; fi
if [ $# -ne 4 ]; then usage >&2; exit 2; fi
build_a=$1 build_b=$2 folder=$3 lfn=$4

tool=run.sh
here=$(cd "$(dirname "$0")" && pwd) || exit 2
if [ ! -f "$here/common.sh" ]; then echo "run.sh: common.sh is missing beside the script" >&2; exit 3; fi
# shellcheck source=common.sh
. "$here/common.sh"
need_builds "$build_a" "$build_b"
lfn_parse "$lfn"
folder_parse "$folder"
need_tools

run_begin run
guest_build LISTDUMP "$tmp/c" || invalid "LISTDUMP did not build"
folder_resolve "$folder" "$lfn"

# The folder is D:, read-only, the same one for both builds.
run_one() {
    guest_run "$1" "$2" "$parent" " -ro" LIST.TXT "$SECONDS_BOUND" "c:" "LISTDUMP.EXE D:\\$base C:\\LIST.TXT"
    echo "run.sh: build $1: $2 ($emu_version)"
}

# Prints the dump's counts; non-zero when the dump is truncated, its counts disagree with its
# own trailers, or it listed nothing but the folder's own two entries. Read as bytes: a name
# holds whatever the guest's code page gave it.
check_dump() {
    local label=$1 dump=$2 summary rc
    summary=$(LC_ALL=C awk -F'|' -v want_lfn="$lfn" '
        $1 == "4e" { n4e++; if ($NF == "name=." || $NF == "name=..") dots++ }
        $1 == "lfn" { nlfn++ }
        $1 == "look" { nlook++ }
        $1 == "end" { endline = $0; split($2, a, "="); t4e = a[2]; split($3, b, "="); tlfn = b[2]; split($4, c, "="); tlook = c[2] }
        END {
            if (endline == "") { print "no trailer: the dump is truncated"; exit 3 }
            if (n4e + 0 != t4e + 0 || nlfn + 0 != tlfn + 0 || nlook + 0 != tlook + 0) {
                printf "counted 4e=%d lfn=%d look=%d, the trailer says 4e=%s lfn=%s look=%s\n", n4e, nlfn, nlook, t4e, tlfn, tlook
                exit 3
            }
            if (n4e - dots == 0) { print "no entry through 4Eh: the folder is empty or was not reached"; exit 3 }
            if (want_lfn == "on" && nlfn + 0 == 0) { print "zero entries through 714Eh with long names on"; exit 3 }
            if (want_lfn == "off" && nlfn + 0 != 0) { print "714Eh listed entries with long names off"; exit 3 }
            printf "4e=%d lfn=%d look=%d\n", n4e, nlfn, nlook
        }' "$dump")
    rc=$?
    echo "run.sh: build $label: $summary"
    return "$rc"
}

echo "run.sh: folder $folder ($host_count entries on the host), long names $lfn"
run_one A "$build_a"
check_dump A "$tmp/run-A/LIST.TXT" || invalid "build A's dump"
run_one B "$build_b"
check_dump B "$tmp/run-B/LIST.TXT" || invalid "build B's dump"

cmp -s "$tmp/run-A/LIST.TXT" "$tmp/run-B/LIST.TXT"
cmp_rc=$?
if [ "$cmp_rc" -eq 0 ]; then echo "run.sh: IDENTICAL"; exit 0; fi
if [ "$cmp_rc" -ne 1 ]; then invalid "cmp failed (exit $cmp_rc)"; fi
echo "run.sh: DIFFERENT, the first differing lines (A then B):"
diff "$tmp/run-A/LIST.TXT" "$tmp/run-B/LIST.TXT" > "$tmp/diff.txt"
command grep -a -m 20 -E '^[<>]' "$tmp/diff.txt"
echo "run.sh: $(command grep -a -c -E '^[<>]' "$tmp/diff.txt") differing lines in all"
exit 1
