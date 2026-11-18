#!/usr/bin/env bash
# Runs FINDPOS.EXE twice on one DOSBox-X build, over the same folder mounted as a host folder and
# with an overlay drive on top of it, and compares the lines of the searches for the volume label
# (a label alone, then FindNext; the root with every attribute). See README.md beside this script.
set -u

usage() {
    cat <<'EOT'
usage: overlay.sh <build> <labelled|unlabelled> <on|off>

  <build>                 a DOSBox-X executable
  <labelled|unlabelled>   the drive searched: mounted with the label FPLABEL, or with none
  <on|off>                the guest's long file names ([dos] lfn)

run A is findpos.sh's folder on D: as a host folder; run B the same with "mount d <dir> -t
overlay" after it, over an empty directory of the run's own. An overlay drive is a host folder
drive whose FindNext is its own, so it answers a search for the label and a listing of the root
as the host folder does.

prints each "label-" line of the two runs and three checks: the two runs' label lines alike; on
the overlay, a FindNext after a search for the label alone answers 18 and the root lists no "."
or "..", which is what MS-DOS 6.22, MS-DOS 7.10 and FreeDOS 1.4 answer, labelled or not. The
other lines that differ between the two runs are listed after them, not judged.

environment:
  DJDIR                 the DJGPP cross toolchain (default: $HOME/djgpp)
  DIRCACHE_PREBUILT     a folder holding FINDPOS.EXE built on another host, instead of DJGPP

exit: 0 the three checks hold | 1 one does not | 2 usage
      3 INVALID: findpos.sh did not answer, or a run printed no label line
EOT
}

if [ $# -eq 1 ] && [ "$1" = "--help" ]; then usage; exit 0; fi
if [ $# -ne 3 ]; then usage >&2; exit 2; fi
build=$1 volume=$2 lfn=$3
case "$volume" in labelled|unlabelled) ;; *) echo "overlay.sh: the drive is labelled or unlabelled, not: $volume" >&2; usage >&2; exit 2 ;; esac
case "$lfn" in on|off) ;; *) echo "overlay.sh: long names are on or off, not: $lfn" >&2; usage >&2; exit 2 ;; esac

here=$(cd "$(dirname "$0")" && pwd) || exit 2
out=$(mktemp -d "${TMPDIR:-/tmp}/overlay.XXXXXX") || exit 3
trap 'rm -rf "$out"' EXIT

DIRCACHE_OVERLAY=B "$here/findpos.sh" "$build" "$build" "$volume" "$lfn" > "$out/findpos.txt"
rc=$?
case "$rc" in
    0|1) ;;
    2) cat "$out/findpos.txt" >&2; exit 2 ;;
    *) echo "overlay.sh: INVALID: findpos.sh exit $rc:" >&2; cat "$out/findpos.txt" >&2; exit 3 ;;
esac

awk -v dir="$out" '
    /^findpos\.sh: build A: / { f = dir "/A.txt"; next }
    /^findpos\.sh: build B: / { f = dir "/B.txt"; next }
    /^findpos\.sh: / { f = ""; next }
    f != "" { print > f }
' "$out/findpos.txt"
for run in A B; do
    if [ ! -s "$out/$run.txt" ]; then echo "overlay.sh: INVALID: run $run printed no report" >&2; exit 3; fi
    command grep -a '^pos|label-' "$out/$run.txt" > "$out/$run-label.txt"
    if [ ! -s "$out/$run-label.txt" ]; then echo "overlay.sh: INVALID: run $run printed no label line" >&2; exit 3; fi
    command grep -a -v '^pos|label-' "$out/$run.txt" > "$out/$run-other.txt"
done

echo "overlay.sh: drive $volume, long names $lfn, build $build"
echo "overlay.sh: findpos.sh exit $rc"
echo "overlay.sh: run A, the host folder:"
cat "$out/A-label.txt"
echo "overlay.sh: run B, the overlay on it:"
cat "$out/B-label.txt"
verdict=0
if cmp -s "$out/A-label.txt" "$out/B-label.txt"; then echo "overlay.sh: label lines ALIKE"
else verdict=1; echo "overlay.sh: label lines DIFFERENT"; fi
# What MS-DOS 6.22, MS-DOS 7.10 and FreeDOS 1.4 answer, labelled or not: a FindNext
# after a search for the label alone finds nothing, and the root lists neither "." nor "..".
alone=$(command grep -a '^pos|label-alone|' "$out/B.txt")
case "$alone" in
    *' next=18 more=0|') echo "overlay.sh: overlay, FindNext after the label alone: 18, as DOS" ;;
    '') echo "overlay.sh: INVALID: the overlay run printed no label-alone line" >&2; exit 3 ;;
    *) verdict=1; echo "overlay.sh: overlay, FindNext after the label alone: not 18 (DOS: next=18 more=0)" ;;
esac
everything=$(command grep -a '^pos|label-with-everything|' "$out/B.txt")
case "$everything" in
    '') echo "overlay.sh: INVALID: the overlay run printed no label-with-everything line" >&2; exit 3 ;;
    *'entry=.:'*|*'entry=..:'*|*',.:'*|*',..:'*) verdict=1; echo "overlay.sh: overlay, the root lists a dot entry (DOS: none)" ;;
    *) echo "overlay.sh: overlay, the root lists no dot entry, as DOS" ;;
esac
other=$(diff "$out/A-other.txt" "$out/B-other.txt" | command grep -a -c '^<')
echo "overlay.sh: other lines that differ, not judged: $other"
diff "$out/A-other.txt" "$out/B-other.txt" | command grep -a -E '^[<>]'
exit "$verdict"
