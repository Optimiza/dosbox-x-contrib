#!/usr/bin/env bash
# nodrive.sh's verdicts against captured runs, no emulator: bash nodrive.test.sh
# fixtures/nodrive holds a base build against itself on macOS: 52 starts, a line and its control
# in turn, build A's 26 then build B's. lines_a and lines_b are the starts that do not answer: the
# nine that die on SIGSEGV (EXIT 139), recorded before the unmounted-drive fix merged upstream, and
# the XCOPY line, recorded from upstream main-ai at 0948c6a9b, where it is cut at its bound before
# its last line.
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
f=$here/fixtures/nodrive
run() { "$here/nodrive.sh" "$build_a" "$build_b"; }

# survive <dir> <answer> <call>...: those calls, which died, reach their last line instead, the
# answer printed before it.
survive() {
    local d=$1 answer=$2 n
    shift 2
    for n in "$@"; do
        echo 0 > "$d/$n/EXIT"
        if [ -n "$answer" ]; then printf '%s\r\n' "$answer" >> "$d/$n/OUT.TXT"; fi
        printf 'nodrive-end\r\n' >> "$d/$n/OUT.TXT"
    done
}
lines_a=(1 3 5 7 9 11 13 15 17 25) lines_b=(27 29 31 33 35 37 39 41 43 51)

t_play "$f"
t_case "a line that ends the emulator is INVALID" 3 "nodrive.sh: INVALID: build A: \"label q: X\" (label-q-x) ended the emulator: SEGV, exit 139" run
t_case "every line that does is named, of both builds" 3 "build B: \"imgmake x.img -t hd -size 4\" (cur-hd) ended the emulator: SEGV, exit 139; build B: \"xcopy c:\\A.TXT q:\\\" (xcopy-q) did not reach its last line; the run is kept" run
t_case "with no drive current" 3 "build A: \"vol\" (cur-vol) ended the emulator: SEGV, exit 139" run
t_case "each report printed whole" 3 "cur-tree-control|tree|Directory PATH listing for Volume  / Volume Serial Number is 0000-1234 / C:. / No subdirectories exist" run
t_case "the line that died, in its report" 3 "label-q|label q:|died: SEGV, exit 139" run
t_case "cd with no drive current, which survives" 3 "cur-cd|cd|A:\\
cur-cd-control|cd|C:\\" run
t_case "a drive named by no letter, beside its control" 3 "vol-1|vol 1:|Invalid drive specification
vol-1-control|vol c:| Volume in drive C has no label" run
t_case "the other" 3 "tree-1|tree 1:|Invalid drive specification
tree-1-control|tree c:|Directory PATH listing" run
t_case "the XCOPY line cut at its bound, never reaching its last line" 3 "xcopy-q|xcopy c:\\A.TXT q:\\|did not reach its last line" run
t_case "and named with the lines that do not answer" 3 "build A: \"xcopy c:\\A.TXT q:\\\" (xcopy-q) did not reach its last line" run
t_derive "$f"
survive "$derived" "" "${lines_a[@]}" "${lines_b[@]}"; t_play "$derived"
t_case "every line survives, alike" 0 "nodrive.sh: ALIKE" run
t_derive "$f"
survive "$derived" "" "${lines_b[@]}"; t_play "$derived"
t_case "only build B survives: build A's lines are named" 3 "build A: \"imgmake x.img -t hd -size 4\" (cur-hd) ended the emulator: SEGV, exit 139; build A: \"xcopy c:\\A.TXT q:\\\" (xcopy-q) did not reach its last line; the run is kept" run
t_derive "$f"
survive "$derived" "" "${lines_a[@]}"; survive "$derived" "Invalid drive specification" "${lines_b[@]}"; t_play "$derived"
t_case "two builds that survive and answer otherwise" 1 "nodrive.sh: DIFFERENT, 10 lines differ" run
t_case "the lines that differ, of the second build" 1 "> cur-vol|vol|Invalid drive specification" run
t_derive "$f"; echo 0 > "$derived/1/EXIT"; t_play "$derived"
t_case "a run that stops short of its last line, whenever it stopped" 3 "build A: \"label q: X\" (label-q-x) did not reach its last line; " run
t_derive "$f"; survive "$derived" "" "${lines_a[@]}" "${lines_b[@]}"; printf 'start\r\nC:\r\nline\r\nUnable to extend\r\n' > "$derived/2/OUT.TXT"; t_play "$derived"
t_case "a run cut on an answer that ends in the letters of the old last line" 3 "build A: \"label c: X\" (label-q-x-control) did not reach its last line" run
t_derive "$f"; printf 'start\r\n' > "$derived/7/OUT.TXT"; t_play "$derived"
t_case "a line that ends the emulator before its drive line is a death" 3 "build A: \"label q:X\" (label-qx) ended the emulator: SEGV, exit 139; build A: \"label X\" (cur-label-x) ended the emulator: SEGV, exit 139" run
t_derive "$f"; echo 1 > "$derived/1/EXIT"; t_play "$derived"
t_case "a code that is no signal, by its number" 3 "(label-q-x) ended the emulator: exit 1;" run
t_derive "$f"; survive "$derived" "" "${lines_a[@]}" "${lines_b[@]}"; sed -i '' '/^line/d' "$derived/12/OUT.TXT"; t_play "$derived"
t_case "a run that left no line marker" 3 "build A's run of \"vol\" (cur-vol-control) left no \"line\" marker" run
t_derive "$f"; rm "$derived/2/OUT.TXT"; t_play "$derived"
t_case "a run that left no output" 3 "build A's run of \"label c: X\" (label-q-x-control) left no output" run
t_derive "$f"; rm "$derived/2/OUT.TXT"; echo 3 > "$derived/2/EXIT"; echo 'the run left no OUT.TXT' > "$derived/2/INVALID"; t_play "$derived"
t_case "on macOS a run the launcher refused, whose code is the launcher's" 3 "the launcher refused build A's run of \"label c: X\" (label-q-x-control): the run left no OUT.TXT; before it, build A: \"label q: X\"" run
t_derive "$f"; sed -i '' 's/^A:/C:/' "$derived/19/OUT.TXT"; t_play "$derived"
t_case "NODRIVE.EXE that left C: current" 3 "build A's run of \"cd\" (cur-cd) had C: current, not A:" run
t_derive "$f"; sed -i '' 's/^C:/A:/' "$derived/2/OUT.TXT"; t_play "$derived"
t_case "a control with no drive current" 3 "build A's run of \"label c: X\" (label-q-x-control) had A: current, not C:" run
t_derive "$f"; sed -i '' 's/^C:/A:/' "$derived/8/OUT.TXT"; t_play "$derived"
t_case "a run not trusted names the deaths before it" 3 "build A's run of \"label X\" (cur-label-x-control) had A: current, not C:; before it, build A: \"label q: X\" (label-q-x) ended the emulator: SEGV, exit 139; build A: \"label q:\" (label-q) ended the emulator" run
t_derive "$f"; sed -i '' '/^start/d' "$derived/4/OUT.TXT"; t_play "$derived"
t_case "a run that left no first line" 3 "build A's run of \"label c:\" (label-q-control) left no first line" run
t_derive "$f"; printf 'start\r\nC:\r\nline\r\nUnable to read floppy.nodrive-end\r\n' > "$derived/2/OUT.TXT"; t_play "$derived"
t_case "an answer with no newline of its own, which the last line closes" 3 "label-q-x-control|label c: X|Unable to read floppy.
label-q|" run
t_derive "$f"; rm "$derived/1/EXIT"; t_play "$derived"
t_case "a launcher's report that names no exit code" 3 "names no exit code" run
t_play "$f"
STUB_VERSION="" t_case "a build that does not start" 3 "build A did not start" run
# A run that judged nothing keeps its directory: the confs it booted are read there.
conf_of() {
    local out
    out=$(run 2>&1)
    cat "$(printf '%s\n' "$out" | sed -n 's/.*the run is kept in //p')/run-A-$1/run.conf"
}
conf_of_win() {
    local out
    out=$(win 2>&1)
    cat "$(printf '%s\n' "$out" | sed -n 's/.*the run is kept in //p')/run-A-$1/run.conf"
}
t_case "the line runs after NODRIVE.EXE, and a line no command prints closes it" 0 'NODRIVE.EXE >> C:\OUT.TXT
echo line>> C:\OUT.TXT
vol >> C:\OUT.TXT
echo nodrive-end>> C:\OUT.TXT' conf_of cur-vol
t_case "and its control with C: current, after NODRIVE.EXE /S" 0 'c:
echo start> C:\OUT.TXT
NODRIVE.EXE /S >> C:\OUT.TXT
echo line>> C:\OUT.TXT
vol >> C:\OUT.TXT' conf_of cur-vol-control
t_case "a control of a line on Q: runs it on C:" 0 'label c:X >> C:\OUT.TXT' conf_of label-qx-control
t_case "and of a line on 1:" 0 'tree c: >> C:\OUT.TXT' conf_of tree-1-control
t_case "no line needs START.COM on macOS" 0 '[dos]
lfn=false' conf_of cur-vol
# The spy writes an image in its working folder, as IMGMAKE does with no drive current.
spy=$work/spy.sh
# shellcheck disable=SC2016  # the script written here expands its own variables
printf '%s\n' '#!/bin/bash' 'pwd -P >> "$SPY_OUT"' ': > x.img' "exec \"$here/fixtures/stub-launcher.sh\" \"\$@\"" > "$spy" && chmod +x "$spy" || exit 3
where() {
    rm -rf "$work/caller" "$work/where.txt" && mkdir "$work/caller" || exit 3
    (cd "$work/caller" && SPY_OUT=$work/where.txt DIRCACHE_LAUNCHER=$spy run > /dev/null 2>&1)
    awk '$0 ~ /\/run-[AB]-[a-z0-9-]+$/ { n[$0]++ } END { print length(n) " run folders, " NR " starts" }' "$work/where.txt"
    printf 'in the caller'\''s folder: [%s]\n' "$(ls -A "$work/caller")"
}
t_case "each start runs in a folder of its own" 0 "52 run folders, 52 starts" where
t_case "and writes nothing in the caller's folder" 0 "in the caller's folder: []" where
# args.sh records what the launcher is given: the XCOPY line is bounded shorter than the rest.
args=$work/args.sh
# shellcheck disable=SC2016  # the script written here expands its own variables
printf '%s\n' '#!/bin/bash' 'printf "%s\n" "$*" >> "$SPY_OUT"' "exec \"$here/fixtures/stub-launcher.sh\" \"\$@\"" > "$args" && chmod +x "$args" || exit 3
bounds() {
    rm -rf "$work/caller" "$work/args.txt" && mkdir "$work/caller" || exit 3
    (cd "$work/caller" && SPY_OUT=$work/args.txt DIRCACHE_LAUNCHER=$args run > /dev/null 2>&1)
    awk '{ s = ""; c = ""; for (i = 1; i < NF; i++) { if ($i == "--seconds") s = $(i + 1); if ($i == "--conf") c = $(i + 1) }
        sub(/^.*\/run-/, "", c); sub(/\/run\.conf$/, "", c)
        if (c == "A-xcopy-q" || c == "A-xcopy-q-control" || c == "A-cur-vol") print c " " s }' "$work/args.txt"
}
t_case "the XCOPY line and its control are bounded at 10 seconds, every other line at 60" 0 "A-cur-vol 60
A-xcopy-q 10
A-xcopy-q-control 10" bounds
# whole is common.sh's: nodrive.sh and findlife.sh name the builds by it before they change folder.
# shellcheck disable=SC2016  # the child shell expands its own variables
whole_of() { bash -c 'tool=t here=$1; . "$here/common.sh" && cd "$2" && printf "[%s] [%s] [%s]\n" "$(whole C:/dosbox/d.exe)" "$(whole /c/w/d.exe)" "$(whole d.exe)"' _ "$here" "$work"; }
t_case "a path from a drive letter or from the root is kept, another is named from here" 0 "[C:/dosbox/d.exe] [/c/w/d.exe] [$work/d.exe]" whole_of
# fixtures/nodrive-windows holds the unpatched base against itself on Windows, as windows.ps1
# wrote its starts and as stub-powershell.sh plays them, the build's path replaced. win_dead are
# the starts that die on 0xC0000005.
w=$here/fixtures/nodrive-windows
mkdir -p "$work/winbin" || exit 3
printf '#!/bin/sh\necho MINGW64_NT-10.0-26300\n' > "$work/winbin/uname"
# shellcheck disable=SC2016  # the script written here expands its own argument
printf '#!/bin/sh\necho "$2"\n' > "$work/winbin/cygpath"
chmod +x "$work/winbin/uname" "$work/winbin/cygpath" && ln -s "$here/fixtures/stub-powershell.sh" "$work/winbin/powershell" || exit 3
win() { PATH="$work/winbin:$PATH" "$here/nodrive.sh" "$build_a" "$build_b"; }
# win_survive <dir> <call>...: those calls, which died, exit 0 and reach their last line.
win_survive() {
    local d=$1 n
    shift
    for n in "$@"; do
        sed -i '' 's/^windows\.ps1: exit code: .*/windows.ps1: exit code: 0\r/' "$d/$n/report.txt"
        echo 0 > "$d/$n/launcher.rc" && rm "$d/$n/launcher.err" && printf 'nodrive-end\r\n' >> "$d/$n/OUT.TXT" || exit 3
    done
}
win_dead=(1 3 5 7 9 11 13 15 17 25 27 31 33 35 37 39 41 43 45 47 55 57)
# win_killed: the starts the bound cut, the XCOPY line on a drive that is not mounted, on each
# build. They are not deaths and a run that survives them ends them too.
win_killed=(29 59)
t_play "$w"
t_case "Windows: a line that ends the emulator is named by its exception" 3 "nodrive.sh: INVALID: build A: \"label q: X\" (label-q-x) ended the emulator: 0xC0000005, exit -1073741819" win
t_case "Windows: every line that does is named, of both builds" 3 "build B: \"start /hid whoami.exe\" (cur-start) ended the emulator: 0xC0000005, exit -1073741819; build B: \"xcopy c:\\A.TXT q:\\\" (xcopy-q) passed the bound of 10 s and was killed; the run is kept" win
t_case "Windows: the line that died, in its report" 3 "cur-imgsrc|imgmake x.img -source q|died: 0xC0000005, exit -1073741819" win
t_case "Windows: IMGMAKE -source with C: current" 3 "cur-imgsrc-control|imgmake x.img -source q|Unable to read floppy." win
t_case "Windows: START with C: current" 3 "cur-start-control|start /hid whoami.exe|Starting whoami.exe... / (Press Ctrl+C to exit immediately)" win
t_case "Windows: the XCOPY line is cut at its bound and named so" 3 "xcopy-q|xcopy c:\\A.TXT q:\\|killed: passed the bound of 10 s" win
t_case "Windows: and the line\'s control on C: answers" 3 "xcopy-q-control|xcopy c:\\A.TXT c:\\|File cannot be copied onto itself - c:\\A.TXT / 0 file(s) copied" win
t_derive "$w"; sed -i '' 's/^windows\.ps1: exit code: .*/windows.ps1: exit code: -1073740791\r/' "$derived/1/report.txt"; t_play "$derived"
t_case "Windows: another exception, by its own code" 3 "(label-q-x) ended the emulator: 0xC0000409, exit -1073740791" win
t_derive "$w"; sed -i '' 's/^windows\.ps1: exit code: .*/windows.ps1: exit code: 3\r/' "$derived/1/report.txt"; t_play "$derived"
t_case "Windows: a code that is no exception, by its number" 3 "(label-q-x) ended the emulator: exit 3;" win
# fixtures/nodrive-windows-bound is a run windows.ps1 killed at a bound of 5 s, its guest held on
# PAUSE: the emulator's exit code is then the -1 of the kill.
t_derive "$w"; cp "$here/fixtures/nodrive-windows-bound/"* "$derived/2/" || exit 3; t_play "$derived"
t_case "Windows: a run killed at its bound is named so, never as a crash" 3 "build A: \"label c: X\" (label-q-x-control) passed the bound of 5 s and was killed;" win
t_case "and its report says so" 3 "label-q-x-control|label c: X|killed: passed the bound of 5 s" win
t_derive "$w"; win_survive "$derived" "${win_dead[@]}" "${win_killed[@]}"; t_play "$derived"
t_case "Windows: every line survives, alike" 0 "nodrive.sh: ALIKE" win
t_play "$w"
t_case "Windows: every run has START.COM" 0 '[dos]
startcmd=true
lfn=false' conf_of_win cur-vol
t_case "one argument" 2 "usage:" "$here/nodrive.sh" "$build_a"
t_case "its own help" 0 "usage: nodrive.sh" "$here/nodrive.sh" --help
t_end
