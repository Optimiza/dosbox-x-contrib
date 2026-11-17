#!/usr/bin/env bash
# Runs ATTRSEM.EXE and the shell's ATTRIB and DIR headless on two DOSBox-X builds, each over a
# folder of its own, and compares what a program reads around a change of the hidden, system and
# read-only attributes. See README.md beside this script.
set -u

usage() {
    cat <<'EOT'
usage: attrsem.sh <build A> <build B> <on|off>

  <build A>, <build B>  two DOSBox-X executables (the same one twice is the A/A control)
  <on|off>              the guest's long file names ([dos] lfn)

each build's drive holds X, with F0000.TXT to F0009.TXT and the directory SUB. ATTRSEM makes a
file hidden, system, both, read-only, archive off and back, each followed by 4300h, a 4Eh for its
name with and without the hidden bits in the mask, an open for writing and the folder listed;
hides and shows SUB; hides a file a search in progress has not reached. Then the shell's own
ATTRIB +H, ATTRIB +S, DIR /B, DIR /B /A and ATTRIB, and the same undone.

prints each build's path, version line and report whole (ATTRSEM's lines, then the shell's as
shell|<line>), then the verdict and the lines that differ.

environment:
  DJDIR                 the DJGPP cross toolchain (default: $HOME/djgpp)
  DIRCACHE_PREBUILT     a folder holding ATTRSEM.EXE built on another host, instead of DJGPP

exit: 0 alike | 1 different | 2 usage
      3 INVALID: a run collected nothing, a report has no line or no trailer, or the shell left
        nothing; the run's directory is kept and named
EOT
}

SECONDS_BOUND=300
X_FILES=10

if [ $# -eq 1 ] && [ "$1" = "--help" ]; then usage; exit 0; fi
if [ $# -ne 3 ]; then usage >&2; exit 2; fi
build_a=$1 build_b=$2 lfn=$3

tool=attrsem.sh
here=$(cd "$(dirname "$0")" && pwd) || exit 2
if [ ! -f "$here/common.sh" ]; then echo "attrsem.sh: common.sh is missing beside the script" >&2; exit 3; fi
# shellcheck source=common.sh
. "$here/common.sh"
need_builds "$build_a" "$build_b"
lfn_parse "$lfn"
need_tools

run_begin attrsem
guest_build ATTRSEM "$tmp/c" || invalid "ATTRSEM did not build"

# sem_tree <dir>: X, a copy per build, because ATTRSEM and the shell change its attributes.
sem_tree() {
    local i=0 name
    mkdir -p "$1/X/SUB" || return
    while [ "$i" -lt "$X_FILES" ]; do printf -v name 'F%04d.TXT' "$i"; : > "$1/X/$name" || return; i=$((i + 1)); done
}

echo "attrsem.sh: long names $lfn"
for label in A B; do
    if [ "$label" = A ]; then binary=$build_a; else binary=$build_b; fi
    sem_tree "$tmp/fx-$label" || invalid "could not make build $label's folder"
    guest_run "$label" "$binary" "$tmp/fx-$label" "" SEM.TXT "$SECONDS_BOUND" "c:" 'ATTRSEM.EXE D:\X C:\SEM.TXT' \
        'ATTRIB +H D:\X\F0001.TXT > C:\SHELL.TXT' 'ATTRIB +S D:\X\F0002.TXT >> C:\SHELL.TXT' \
        'DIR D:\X /B >> C:\SHELL.TXT' 'DIR D:\X /B /A >> C:\SHELL.TXT' 'ATTRIB D:\X\*.* >> C:\SHELL.TXT' \
        'ATTRIB -H D:\X\F0001.TXT >> C:\SHELL.TXT' 'ATTRIB -S D:\X\F0002.TXT >> C:\SHELL.TXT' \
        'DIR D:\X /B >> C:\SHELL.TXT' 'ATTRIB D:\X\*.* >> C:\SHELL.TXT'
    LC_ALL=C tr -d '\r' < "$guest_out" > "$tmp/report-$label.txt" || invalid "build $label's report could not be read"
    exact_whole "$tmp/report-$label.txt" || invalid "build $label's report has no line or no trailer"
    [ -s "$tmp/run-$label/SHELL.TXT" ] || invalid "build $label's shell left nothing"
    LC_ALL=C tr -d '\r' < "$tmp/run-$label/SHELL.TXT" | sed 's/^/shell|/' >> "$tmp/report-$label.txt"
    echo "attrsem.sh: build $label: $binary ($emu_version)"
    cat "$tmp/report-$label.txt"
done
reports_verdict
