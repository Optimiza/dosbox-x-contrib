#!/usr/bin/env bash
# Runs PATLIST.EXE headless on two DOSBox-X builds, each over its own copy of exact.sh's folder,
# and compares the entries a 4Eh search returns for a list of patterns. See README.md beside
# this script.
set -u

usage() {
    cat <<'EOT'
usage: patlist.sh <build A> <build B> <on|off>

  <build A>, <build B>  two DOSBox-X executables (the same one twice is the A/A control)
  <on|off>              the guest's long file names ([dos] lfn)

the folder is the one exact.sh makes (its --help lists it), a copy per build.

prints each build's path, version line and report whole, then the verdict and the lines that
differ.

environment:
  DJDIR                 the DJGPP cross toolchain (default: $HOME/djgpp)
  DIRCACHE_PREBUILT     a folder holding PATLIST.EXE built on another host, instead of DJGPP

exit: 0 alike | 1 different | 2 usage
      3 INVALID: a run collected nothing, or a report has no pattern or no trailer; the run's
        directory is kept and named
EOT
}

SECONDS_BOUND=600

if [ $# -eq 1 ] && [ "$1" = "--help" ]; then usage; exit 0; fi
if [ $# -ne 3 ]; then usage >&2; exit 2; fi
build_a=$1 build_b=$2 lfn=$3

tool=patlist.sh
here=$(cd "$(dirname "$0")" && pwd) || exit 2
if [ ! -f "$here/common.sh" ]; then echo "patlist.sh: common.sh is missing beside the script" >&2; exit 3; fi
# shellcheck source=common.sh
. "$here/common.sh"
need_builds "$build_a" "$build_b"
lfn_parse "$lfn"
need_tools

run_begin patlist
guest_build PATLIST "$tmp/c" || invalid "PATLIST did not build"

echo "patlist.sh: long names $lfn"
exact_reports PATLIST "$build_a" "$build_b"
reports_verdict
