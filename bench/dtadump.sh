#!/usr/bin/env bash
# Runs DTADUMP.EXE headless on two DOSBox-X builds, each over its own copy of exact.sh's folder,
# and compares the bytes they leave in a DTA and in an FCB around the find calls. See README.md
# beside this script.
set -u

usage() {
    cat <<'EOT'
usage: dtadump.sh <build A> <build B> <on|off>

  <build A>, <build B>  two DOSBox-X executables (the same one twice is the A/A control)
  <on|off>              the guest's long file names ([dos] lfn)

the folder is the one exact.sh makes (its --help lists it), a copy per build: one case removes
a file from it.

prints each build's path, version line and report whole, then a line of figures per build:

  template=<digest>   the template and attribute bytes of every FindFirst dumped
  untouched=<n>/<m>   of the calls that must leave a DTA alone, how many left it unchanged
  resumed=<n>/<m>     of the searches such a call interrupted, how many returned the rest
  fcb=<digest>        what the FCB searches returned

then the verdict and the lines that differ.

environment:
  DJDIR                 the DJGPP cross toolchain (default: $HOME/djgpp)
  DIRCACHE_PREBUILT     a folder holding DTADUMP.EXE built on another host, instead of DJGPP

exit: 0 alike | 1 different | 2 usage
      3 INVALID: a run collected nothing, or a report has no trailer or lacks the lines the
        figures are read from; the run's directory is kept and named
EOT
}

SECONDS_BOUND=600

if [ $# -eq 1 ] && [ "$1" = "--help" ]; then usage; exit 0; fi
if [ $# -ne 3 ]; then usage >&2; exit 2; fi
build_a=$1 build_b=$2 lfn=$3

tool=dtadump.sh
here=$(cd "$(dirname "$0")" && pwd) || exit 2
if [ ! -f "$here/common.sh" ]; then echo "dtadump.sh: common.sh is missing beside the script" >&2; exit 3; fi
# shellcheck source=common.sh
. "$here/common.sh"
need_builds "$build_a" "$build_b"
lfn_parse "$lfn"
need_tools

run_begin dtadump
guest_build DTADUMP "$tmp/c" || invalid "DTADUMP did not build"

echo "dtadump.sh: long names $lfn"
exact_reports DTADUMP "$build_a" "$build_b"
for label in A B; do
    figures=$(dtadump_figures "$tmp/report-$label.txt") || invalid "build $label's report lacks the lines its figures are read from"
    echo "dtadump.sh: figures $label: $figures"
done
reports_verdict
