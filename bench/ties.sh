#!/usr/bin/env bash
# Runs TIES.EXE headless, long names on, on two DOSBox-X builds over one folder made for the run
# and compares what an exact-name search returns when two entries share one 8.3 name. See
# README.md beside this script.
set -u

usage() {
    cat <<'EOT'
usage: ties.sh <build A> <build B>

  <build A>, <build B>  two DOSBox-X executables (the same one twice is the A/A control)

the folder holds 30 subdirectories and 12 pairs of files: a long name ("aaa aaa.txt") and a
real file named like the alias the emulator would give it ("AAAAAA~1.TXT"). Whichever of a pair
the host returns first decides whether the two end up sharing one short name, so the number of
ties is the host's.

environment:
  DJDIR                 the DJGPP cross toolchain (default: $HOME/djgpp)
  DIRCACHE_PREBUILT     a folder holding TIES.EXE built on another host, instead of DJGPP

exit: 0 alike | 1 different | 2 usage
      3 INVALID: a run collected nothing, or no two entries share a short name on this host;
        the run's directory is kept and named
EOT
}

SECONDS_BOUND=900
PAIRS="a b c d e f g h j k m n"

if [ $# -eq 1 ] && [ "$1" = "--help" ]; then usage; exit 0; fi
if [ $# -ne 2 ]; then usage >&2; exit 2; fi
build_a=$1 build_b=$2

tool=ties.sh
here=$(cd "$(dirname "$0")" && pwd) || exit 2
if [ ! -f "$here/common.sh" ]; then echo "ties.sh: common.sh is missing beside the script" >&2; exit 3; fi
# shellcheck source=common.sh
. "$here/common.sh"
need_builds "$build_a" "$build_b"
lfn_parse on
need_tools

run_begin ties
guest_build TIES "$tmp/c" || invalid "TIES did not build"
mkdir -p "$tmp/fx/T" || invalid "could not make the folder"
i=1
while [ "$i" -le 30 ]; do printf -v d 'D%02d' "$i"; mkdir "$tmp/fx/T/$d" || invalid "could not make the folder"; i=$((i + 1)); done
# The two files of a pair get different sizes, so the report shows which one a search returned.
k=1
for stem in $PAIRS; do
    upper=$(printf '%s' "$stem$stem$stem$stem$stem$stem" | tr '[:lower:]' '[:upper:]')
    head -c "$k" /dev/zero > "$tmp/fx/T/$stem$stem$stem $stem$stem$stem.txt" || invalid "could not make the folder"
    head -c $((k + 19)) /dev/zero > "$tmp/fx/T/$upper~1.TXT" || invalid "could not make the folder"
    k=$((k + 1))
done

run_one() {
    guest_run "$1" "$2" "$tmp/fx" "" OUT.TXT "$SECONDS_BOUND" "c:" 'TIES.EXE D:\T C:\OUT.TXT'
    echo "ties.sh: build $1: $2 ($emu_version)"
    LC_ALL=C tr -d '\r' < "$guest_out" > "$tmp/ties-$1.txt" || invalid "build $1's report could not be read"
}
run_one A "$build_a"
run_one B "$build_b"

ties=$(sed -n 's/^end|ties=//p' "$tmp/ties-A.txt")
case "$ties" in ''|0|*[!0-9]*) invalid "no two entries share a short name on this host (ties=$ties): nothing to compare" ;; esac
command grep -a '^tie|' "$tmp/ties-A.txt"
cmp -s "$tmp/ties-A.txt" "$tmp/ties-B.txt"
cmp_rc=$?
if [ "$cmp_rc" -eq 0 ]; then echo "ties.sh: ALIKE ($ties ties)"; exit 0; fi
if [ "$cmp_rc" -ne 1 ]; then invalid "cmp failed (exit $cmp_rc)"; fi
echo "ties.sh: DIFFERENT ($ties ties), the lines that differ (A then B):"
diff "$tmp/ties-A.txt" "$tmp/ties-B.txt" | command grep -a -E '^[<>]'
exit 1
