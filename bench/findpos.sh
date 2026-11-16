#!/usr/bin/env bash
# Runs FINDPOS.EXE headless on two DOSBox-X builds, each over its own copy of exact.sh's folder,
# and compares where each keeps the place of a search and what a search for the volume label
# alone leaves behind. See README.md beside this script.
set -u

usage() {
    cat <<'EOT'
usage: findpos.sh <build A> <build B> <labelled|unlabelled> <on|off>

  <build A>, <build B>    two DOSBox-X executables (the same one twice is the A/A control)
  <labelled|unlabelled>   the drive searched: mounted with the label FPLABEL, or with none
  <on|off>                the guest's long file names ([dos] lfn)

the folder is the one exact.sh makes (its --help lists it), a copy per build.

prints each build's path, version line and report whole, then the verdict and the lines that
differ.

environment:
  DJDIR                 the DJGPP cross toolchain (default: $HOME/djgpp)
  DIRCACHE_PREBUILT     a folder holding FINDPOS.EXE built on another host, instead of DJGPP

exit: 0 alike | 1 different | 2 usage
      3 INVALID: a run collected nothing, or a report has no line or no trailer; the run's
        directory is kept and named
EOT
}

SECONDS_BOUND=600

if [ $# -eq 1 ] && [ "$1" = "--help" ]; then usage; exit 0; fi
if [ $# -ne 4 ]; then usage >&2; exit 2; fi
build_a=$1 build_b=$2 volume=$3 lfn=$4

tool=findpos.sh
here=$(cd "$(dirname "$0")" && pwd) || exit 2
if [ ! -f "$here/common.sh" ]; then echo "findpos.sh: common.sh is missing beside the script" >&2; exit 3; fi
# shellcheck source=common.sh
. "$here/common.sh"
need_builds "$build_a" "$build_b"
case "$volume" in
    labelled) options=" -label $FINDPOS_LABEL" ;;
    unlabelled) options="" ;;
    *) fail_usage "the drive is labelled or unlabelled, not: $volume" ;;
esac
lfn_parse "$lfn"
need_tools

run_begin findpos
guest_build FINDPOS "$tmp/c" || invalid "FINDPOS did not build"

echo "findpos.sh: drive $volume, long names $lfn"
exact_reports FINDPOS "$build_a" "$build_b" "$options"
reports_verdict
