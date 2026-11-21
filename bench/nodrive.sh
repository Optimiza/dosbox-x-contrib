#!/usr/bin/env bash
# Runs the shell's commands that read a drive headless on two DOSBox-X builds, on a drive that is
# not mounted and with no drive behind the current one, each beside the same command on a mounted
# drive, and says what each build answers and whether it survives. See README.md beside this
# script.
set -u

usage() {
    cat <<'EOT'
usage: nodrive.sh <build A> <build B>

  <build A>, <build B>  two DOSBox-X executables (the same one twice is the A/A control)

each line runs in an emulator start of its own, so that one that ends the emulator hides no
other. Q: is never mounted, C: is the run's folder and holds no label. The lines:

  label-q-x   label q: X     control: label c: X
  label-q     label q:       control: label c:
  label-qx    label q:X      control: label c:X
  cur-label-x label X        after NODRIVE.EXE      control: the same line on C:
  cur-label   label          after NODRIVE.EXE      control: the same line on C:
  cur-vol     vol            after NODRIVE.EXE      control: the same line on C:
  cur-tree    tree           after NODRIVE.EXE      control: the same line on C:
  cur-fd      imgmake x.img -t fd_1440    after NODRIVE.EXE   control: the same line on C:
  cur-hd      imgmake x.img -t hd -size 4 after NODRIVE.EXE   control: the same line on C:
  cur-cd      cd             after NODRIVE.EXE      control: the same line on C:
  vol-1       vol 1:         control: vol c:
  tree-1      tree 1:        control: tree c:
on Windows also, with START.COM made by startcmd=true:
  cur-imgsrc  imgmake x.img -source q   after NODRIVE.EXE   control: the same line on C:
  cur-start   start /hid whoami.exe     after NODRIVE.EXE   control: the same line on C:

NODRIVE.EXE makes A:, which nothing mounts, the current drive, and prints the current drive as
INT 21h 19h answers it; NODRIVE.EXE /S, run before a control, prints it only. It must say A:
before a line and C: before a control, or the run is not trusted.

prints each build's path, version line and report: a line per run, its name (a control's ends
in -control), the command and what the shell answered, its lines joined by " / ". Then the
verdict and the lines that differ, A's then B's.

environment:
  DJDIR                 the DJGPP cross toolchain (default: $HOME/djgpp)
  DIRCACHE_PREBUILT     a folder holding NODRIVE.EXE built on another host, instead of DJGPP

exit: 0 alike | 1 different | 2 usage
      3 INVALID: a line ended the emulator, which names the build, the line and the signal on
        macOS or the exception code on Windows;
        or a run did not reach its last line, or had another drive current than the line
        asks for; the run's directory is kept and named
EOT
}

SECONDS_BOUND=60

if [ $# -eq 1 ] && [ "$1" = "--help" ]; then usage; exit 0; fi
if [ $# -ne 2 ]; then usage >&2; exit 2; fi
build_a=$1 build_b=$2

tool=nodrive.sh
here=$(cd "$(dirname "$0")" && pwd) || exit 2
if [ ! -f "$here/common.sh" ]; then echo "nodrive.sh: common.sh is missing beside the script" >&2; exit 3; fi
# shellcheck source=common.sh
. "$here/common.sh"
need_builds "$build_a" "$build_b"
# shellcheck disable=SC2034  # read by conf_write
lfn_conf=false
need_tools

run_begin nodrive
guest_build NODRIVE "$tmp/c" || invalid "NODRIVE did not build"
mkdir -p "$tmp/d" || invalid "could not make D:'s folder"

# Each start runs in its own run's folder, as windows.ps1 starts it there too: IMGMAKE with no
# drive current writes its image in the emulator's working folder, so a folder shared between
# lines would answer the first line's image to the next. The builds and the launcher are named
# whole before the script moves.
whole() { case "$1" in /*) printf '%s\n' "$1" ;; *) printf '%s/%s\n' "$PWD" "$1" ;; esac; }
build_a=$(whole "$build_a") build_b=$(whole "$build_b") launcher=$(whole "$launcher")

# name|state|line: state q is a line on a drive nothing is mounted on, Q: or 1:, whose control
# runs it on C:; state none runs the line after NODRIVE.EXE, and its control the same line with C:
# current.
CASES='label-q-x|q|label q: X
label-q|q|label q:
label-qx|q|label q:X
cur-label-x|none|label X
cur-label|none|label
cur-vol|none|vol
cur-tree|none|tree
cur-fd|none|imgmake x.img -t fd_1440
cur-hd|none|imgmake x.img -t hd -size 4
cur-cd|none|cd
vol-1|q|vol 1:
tree-1|q|tree 1:'
# IMGMAKE -source and START are built on Windows only. START.COM exists only with startcmd=true,
# which no other line reads.
if [ "$HOST_KIND" = windows ]; then
    CASES+=$'\ncur-imgsrc|none|imgmake x.img -source q\ncur-start|none|start /hid whoami.exe'
    # shellcheck disable=SC2034  # read by conf_write
    conf_dos=startcmd=true
fi

# signal_of <exit code>: the signal a code past 128 carries on a Mac, the exception a negative
# code is on Windows (an NTSTATUS read as signed), or the code itself.
signal_of() {
    if [ "$HOST_KIND" = windows ] && [ "$1" -lt 0 ]; then
        printf '0x%08X, exit %s\n' $(($1 + 4294967296)) "$1"
    elif [ "$HOST_KIND" != windows ] && [ "$1" -gt 128 ] && [ "$1" -lt 160 ]; then
        printf '%s, exit %s\n' "$(kill -l $(($1 - 128)))" "$1"
    else
        printf 'exit %s\n' "$1"
    fi
}

# run_one <label> <build> <name> <state> <line>: one emulator start. The guest writes "start",
# the drive NODRIVE.EXE names, "line" and the line's answer into OUT.TXT, then "end". Appends the
# report line, and to $tmp/dead what ended the emulator or kept it from its last line.
run_one() {
    local label=$1 binary=$2 name=$3 state=$4 line=$5 run=$tmp/run-$1-$3 code before='NODRIVE.EXE /S' answer current
    if ! mkdir -p "$run" || ! cp -R "$tmp/c/." "$run/" || ! cd "$run"; then invalid "could not make the run directory of $label $name"; fi
    if [ "$state" = none ]; then before='NODRIVE.EXE'; fi
    conf_write "$run" "$tmp/d" "" 'c:' 'echo start> C:\OUT.TXT' "$before >> C:\\OUT.TXT" \
        'echo line>> C:\OUT.TXT' "$line >> C:\\OUT.TXT" 'echo end>> C:\OUT.TXT'
    emu_start "$binary" "$run" OUT.TXT "$SECONDS_BOUND"
    wait "$emu_job"
    emu_job=""
    emu_version=$(sed -n 's/^[^ ]*: version: //p' "$run/report.txt" 2> /dev/null)
    if [ -z "$emu_version" ]; then
        echo "$tool: $label $name: no version line; the launcher said:" >&2
        cat "$run/launcher.txt" >&2
        invalid "build $label did not start"
    fi
    if [ "$HOST_KIND" = windows ]; then
        code=$(sed -n 's/^windows\.ps1: exit code: //p' "$run/report.txt" | tr -d '\r')
    else
        code=$(sed -n 's/^launch\.sh: exit code: //p' "$run/report.txt")
    fi
    if [ ! -f "$run/OUT.TXT" ]; then invalid "build $label's run of \"$line\" left no output"; fi
    # IMGMAKE -source ends its answer with no newline, so "end" lands on the answer's last line,
    # and the shell writes no empty line to a file (echo. prints none there): split it off here.
    LC_ALL=C tr -d '\r' < "$run/OUT.TXT" | LC_ALL=C awk 'NR > 1 { print prev } { prev = $0 }
        END { if (NR) { if (prev ~ /.end$/) { print substr(prev, 1, length(prev) - 3); prev = "end" } print prev } }' \
        > "$run/said.txt" || invalid "build $label's output could not be read"
    if [ "$(head -n 1 "$run/said.txt")" != start ]; then invalid "build $label's run of \"$line\" left no first line"; fi
    case "${code#-}" in ''|*[!0-9]*) invalid "the launcher's report of build $label's run of \"$line\" names no exit code" ;; esac
    current=C:
    if [ "$state" = none ]; then current=A:; fi
    if [ "$(sed -n 2p "$run/said.txt")" != "$current" ]; then
        invalid "build $label's run of \"$line\" ($name) had $(sed -n 2p "$run/said.txt") current, not $current"
    fi
    if [ "$code" -ne 0 ]; then
        answer="died: $(signal_of "$code")"
        echo "build $label: \"$line\" ($name) ended the emulator: $(signal_of "$code")" >> "$tmp/dead"
    elif [ "$(tail -n 1 "$run/said.txt")" != end ]; then
        answer="did not reach its last line"
        echo "build $label: \"$line\" ($name) did not reach its last line" >> "$tmp/dead"
    else
        answer=$(awk 'f && $0 != "end" && NF { printf "%s%s", sep, $0; sep = " / " } $0 == "line" { f = 1 } END { print "" }' "$run/said.txt")
    fi
    echo "$name|$line|$answer" >> "$tmp/report-$label.txt"
}

: > "$tmp/dead"
for label in A B; do
    if [ "$label" = A ]; then binary=$build_a; else binary=$build_b; fi
    : > "$tmp/report-$label.txt"
    while IFS='|' read -r name state line; do
        run_one "$label" "$binary" "$name" "$state" "$line"
        if [ "$state" = q ]; then
            run_one "$label" "$binary" "$name-control" q "$(printf '%s\n' "$line" | sed 's/ [q1]:/ c:/')"
        else
            run_one "$label" "$binary" "$name-control" c "$line"
        fi
    done <<< "$CASES"
    echo "$tool: build $label: $binary ($emu_version)"
    cat "$tmp/report-$label.txt"
done
if [ -s "$tmp/dead" ]; then invalid "$(awk '{ printf "%s%s", sep, $0; sep = "; " }' "$tmp/dead")"; fi
reports_verdict
