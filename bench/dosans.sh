#!/usr/bin/env bash
# Runs DOSANS.EXE headless on two DOSBox-X builds, each over its own copy of exact.sh's folder,
# and compares what each answers where DOS parses a path: 4Eh and the calls that read a path the
# same way. See README.md beside this script.
set -u

usage() {
    cat <<'EOT'
usage: dosans.sh <build A> <build B> <labelled|unlabelled|cd> <on|off>

  <build A>, <build B>    the two DOSBox-X executables compared; one given twice is the control
  <labelled|unlabelled|cd>  D: carries the label FPLABEL, which DOSANS asks for by name, or none;
                          cd: D: is a CD image, fixtures/cdans/game.iso.gz (volume GAMEDISC, FOO.TXT
                          and X\ holding A.B, BAR.TXT, FOO.TXT, NOEXT, ZED.TXT and SUBDIR\INNER.TXT)
  <on|off>                long file names in the guest ([dos] lfn); a real DOS answers off only

DOSANS asks each path shape of 4Eh and of 3Dh, 43h (get and set) and 3Bh, over a copy per
build of exact.sh's folder (exact.sh --help lists it), then lists the root, the label, the
bytes a search leaves in the DTA, the devices and an FCB name with a space.

the output is each build's path and version line, its report whole, the verdict, and the
lines that differ, A's then B's.

environment:
  DJDIR                 where DJGPP's cross compiler is (default: $HOME/djgpp)
  DIRCACHE_PREBUILT     a folder with DOSANS.EXE made on another host, used instead of DJGPP

exit: 0 alike | 1 different | 2 usage
      3 INVALID: a run collected nothing, or a report has no line or no trailer; the run's
        directory is kept and named
EOT
}

SECONDS_BOUND=600

if [ $# -eq 1 ] && [ "$1" = "--help" ]; then usage; exit 0; fi
if [ $# -ne 4 ]; then usage >&2; exit 2; fi
build_a=$1 build_b=$2 volume=$3 lfn=$4

tool=dosans.sh
here=$(cd "$(dirname "$0")" && pwd) || exit 2
if [ ! -f "$here/common.sh" ]; then echo "dosans.sh: common.sh is missing beside the script" >&2; exit 3; fi
# shellcheck source=common.sh
. "$here/common.sh"
need_builds "$build_a" "$build_b"
case "$volume" in
    labelled) options=" -label $FINDPOS_LABEL" ;;
    unlabelled|cd) options="" ;;
    *) fail_usage "the drive is labelled, unlabelled or cd, not: $volume" ;;
esac
lfn_parse "$lfn"
need_tools

run_begin dosans
guest_build DOSANS "$tmp/c" || invalid "DOSANS did not build"
if [ "$volume" = cd ]; then
    gzip -dc "$here/fixtures/cdans/game.iso.gz" > "$tmp/game.iso" || invalid "the CD image could not be unpacked"
    conf_d_image=$tmp/game.iso
fi

echo "dosans.sh: drive $volume, long names $lfn"
exact_reports DOSANS "$build_a" "$build_b" "$options"
reports_verdict
