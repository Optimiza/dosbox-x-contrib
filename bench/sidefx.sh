#!/usr/bin/env bash
# Runs SIDEFX.EXE, or the shell's VOL around an ATTRIB, headless on two DOSBox-X builds and
# compares what an attribute change does besides changing the attribute. See README.md beside
# this script.
set -u

usage() {
    cat <<'EOT'
usage: sidefx.sh <rescan|label> <build A> <build B>

  rescan   D:\X, ten files, a copy per build. SIDEFX lists it and reads D:'s label, waits
           while this script adds NEW.TXT to the folder from the host, lists it again, sets
           one file read-only (4301h) and lists it a third time; then the shell's DIR,
           RESCAN D: and DIR again
  label    Windows only: the host's C:\ mounted as the guest's C:, the one kind of mount whose
           label the guest can change and the host volume's label can overwrite. VOL,
           LABEL C:GUEST, VOL twice, ATTRIB +R on a file of the run's own folder, VOL
  <build A>, <build B>  two DOSBox-X executables (the same one twice is the A/A control)

long names off. Prints each build's path, version line and lines whole, then the verdict and
the lines that differ.

environment:
  DJDIR                 the DJGPP cross toolchain (default: $HOME/djgpp)
  DIRCACHE_PREBUILT     a folder holding SIDEFX.EXE built on another host, instead of DJGPP

exit: 0 alike | 1 different | 2 usage, or label on a host that is not Windows
      3 INVALID: a run did not end, the guest never waited for the host, a report has no end,
        or the shell's lines are missing; the run's directory is kept and named
EOT
}

SECONDS_BOUND=300
X_FILES=10
# How long the host waits for SIDEFX to say it is waiting, in tenths of a second.
HELD_TENTHS=600

if [ $# -eq 1 ] && [ "$1" = "--help" ]; then usage; exit 0; fi
if [ $# -ne 3 ]; then usage >&2; exit 2; fi
mode=$1 build_a=$2 build_b=$3

tool=sidefx.sh
here=$(cd "$(dirname "$0")" && pwd) || exit 2
if [ ! -f "$here/common.sh" ]; then echo "sidefx.sh: common.sh is missing beside the script" >&2; exit 3; fi
# shellcheck source=common.sh
. "$here/common.sh"
case "$mode" in rescan|label) ;; *) fail_usage "the mode is rescan or label, not: $mode" ;; esac
if [ "$mode" = label ] && [ "$HOST_KIND" != windows ]; then
    fail_usage "label runs on Windows only: elsewhere an attribute change never re-reads a label"
fi
need_builds "$build_a" "$build_b"
lfn_parse off
need_tools

run_begin sidefx
guest_build SIDEFX "$tmp/c" || invalid "SIDEFX did not build"

# run_rescan <label> <build>: the report into $tmp/report-<label>.txt.
run_rescan() {
    local label=$1 binary=$2 d=$tmp/fx-$1 run=$tmp/run-$1 i=0 name waited=0
    mkdir -p "$d/X" "$run" || invalid "could not make build $label's folder"
    cp -R "$tmp/c/." "$run/" || invalid "could not make the run directory of $label"
    while [ "$i" -lt "$X_FILES" ]; do printf -v name 'F%04d.TXT' "$i"; : > "$d/X/$name" || invalid "could not make build $label's folder"; i=$((i + 1)); done
    conf_write "$run" "$d" "" 'c:' \
        'SIDEFX.EXE D:\X D:\X\F0001.TXT C:\HELD.TXT C:\GO.TXT C:\FX.TXT' \
        'DIR D:\X /B > C:\SHELL.TXT' 'ECHO RESCAN>>C:\SHELL.TXT' 'RESCAN D:' 'DIR D:\X /B >> C:\SHELL.TXT'
    emu_start "$binary" "$run" FX.TXT "$SECONDS_BOUND"
    while [ ! -f "$run/HELD.TXT" ]; do
        # An emulator that ended before SIDEFX waited will never wait.
        kill -0 "$emu_job" 2> /dev/null || break
        [ "$waited" -lt "$HELD_TENTHS" ] || break
        sleep 0.1
        waited=$((waited + 1))
    done
    if [ ! -f "$run/HELD.TXT" ]; then emu_finish "$label"; invalid "build $label: SIDEFX never waited for the host"; fi
    : > "$d/X/NEW.TXT" || invalid "could not add NEW.TXT to build $label's folder"
    : > "$run/GO.TXT" || invalid "could not let build $label's guest go"
    emu_finish "$label" || invalid "$label did not run to its end"
    LC_ALL=C tr -d '\r' < "$run/FX.TXT" > "$tmp/report-$label.txt" || invalid "build $label's report could not be read"
    command grep -q -x 'sidefx|released=1' "$tmp/report-$label.txt" || invalid "build $label: SIDEFX went on without the host's file"
    command grep -q -x 'sidefx|end' "$tmp/report-$label.txt" || invalid "build $label's report has no end"
    if [ ! -f "$run/SHELL.TXT" ] || ! command grep -a -q '^RESCAN' "$run/SHELL.TXT"; then invalid "build $label's shell left no line"; fi
    LC_ALL=C tr -d '\r' < "$run/SHELL.TXT" |
        awk '/^RESCAN$/ { after = 1; next } { print (after ? "dir-after-rescan|" : "dir-before-rescan|") $0 }' >> "$tmp/report-$label.txt"
}

# run_label <label> <build>: the same, the VOL lines and ATTRIB's.
run_label() {
    local label=$1 binary=$2 run=$tmp/run-$1 target=$tmp/sfx guest_dir
    if ! mkdir -p "$run" "$target" || ! : > "$target/F0001.TXT"; then invalid "could not make build $label's file"; fi
    # The guest reaches the file through C:, so by its 8.3 path on the host's own C:.
    guest_dir=$(cygpath -d "$target") || invalid "the run's folder has no 8.3 path"
    case "$guest_dir" in [Cc]:\\*) ;; *) invalid "the run's folder is not on C: ($guest_dir)" ;; esac
    {
        printf '[dosbox]\nmemsize=64\n\n[cpu]\ncore=dynamic\ncycles=max\n\n[dos]\nlfn=false\n\n[autoexec]\n'
        printf 'mount c c:\\\nmount e "%s" -label ""\ne:\n' "$(host_path "$run")"
        printf '%s\n' 'VOL C: > E:\VOL.TXT' 'LABEL C:GUEST' 'VOL C: >> E:\VOL.TXT' 'VOL C: >> E:\VOL.TXT' \
            "ATTRIB +R $guest_dir\\F0001.TXT > E:\\ATTRIB.TXT" 'VOL C: >> E:\VOL.TXT' \
            "ATTRIB $guest_dir\\F0001.TXT >> E:\\ATTRIB.TXT" "ATTRIB -R $guest_dir\\F0001.TXT" 'ECHO done> E:\END.TXT' exit
    } > "$run/run.conf"
    emu_run "$label" "$binary" "$run" END.TXT "$SECONDS_BOUND" || invalid "$label did not run to its end"
    {
        LC_ALL=C tr -d '\r' < "$run/VOL.TXT" | command grep -a -i 'volume in drive' | sed 's/^ */vol|/'
        LC_ALL=C tr -d '\r' < "$run/ATTRIB.TXT" | sed 's/^/attrib|/'
    } > "$tmp/report-$label.txt"
    [ "$(command grep -c '^vol|' "$tmp/report-$label.txt")" = 4 ] || invalid "build $label: not four VOL lines"
    command grep -q '^attrib|' "$tmp/report-$label.txt" || invalid "build $label: ATTRIB printed nothing"
    rm -rf "$target"
}

echo "sidefx.sh: $mode, long names off"
for label in A B; do
    if [ "$label" = A ]; then binary=$build_a; else binary=$build_b; fi
    case "$mode" in rescan) run_rescan "$label" "$binary" ;; label) run_label "$label" "$binary" ;; esac
    echo "sidefx.sh: build $label: $binary ($emu_version)"
    cat "$tmp/report-$label.txt"
done
reports_verdict
