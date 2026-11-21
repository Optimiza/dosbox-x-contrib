#!/usr/bin/env bash
# nodrive.sh's verdicts against captured runs, no emulator: bash nodrive.test.sh
# fixtures/nodrive holds the unpatched base against itself on macOS: 48 starts, a line and its
# control in turn, build A's 24 then build B's. The first nine lines die on SIGSEGV (EXIT 139);
# cd, vol 1: and tree 1: and every control answer.
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
: > "$work/prebuilt/NODRIVE.EXE" || exit 3
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
        printf 'end\r\n' >> "$d/$n/OUT.TXT"
    done
}
lines_a=(1 3 5 7 9 11 13 15 17) lines_b=(25 27 29 31 33 35 37 39 41)

t_play "$f"
t_case "a line that ends the emulator is INVALID" 3 "nodrive.sh: INVALID: build A: \"label q: X\" (label-q-x) ended the emulator: SEGV, exit 139" run
t_case "every line that does is named, of both builds" 3 "build B: \"imgmake x.img -t hd -size 4\" (cur-hd) ended the emulator: SEGV, exit 139; the run is kept" run
t_case "with no drive current" 3 "build A: \"vol\" (cur-vol) ended the emulator: SEGV, exit 139" run
t_case "each report printed whole" 3 "cur-tree-control|tree|Directory PATH listing for Volume  / Volume Serial Number is 0000-1234 / C:. / No subdirectories exist" run
t_case "the line that died, in its report" 3 "label-q|label q:|died: SEGV, exit 139" run
t_case "cd with no drive current, which survives" 3 "cur-cd|cd|A:\\
cur-cd-control|cd|C:\\" run
t_case "a drive named by no letter, beside its control" 3 "vol-1|vol 1:|Invalid drive specification
vol-1-control|vol c:| Volume in drive C has no label" run
t_case "the other" 3 "tree-1|tree 1:|Invalid drive specification
tree-1-control|tree c:|Directory PATH listing" run
t_derive "$f"
survive "$derived" "" "${lines_a[@]}" "${lines_b[@]}"; t_play "$derived"
t_case "every line survives, alike" 0 "nodrive.sh: ALIKE" run
t_derive "$f"
survive "$derived" "" "${lines_b[@]}"; t_play "$derived"
t_case "only build B survives: build A's lines are named" 3 "build A: \"imgmake x.img -t hd -size 4\" (cur-hd) ended the emulator: SEGV, exit 139; the run is kept" run
t_derive "$f"
survive "$derived" "" "${lines_a[@]}"; survive "$derived" "Invalid drive specification" "${lines_b[@]}"; t_play "$derived"
t_case "two builds that survive and answer otherwise" 1 "nodrive.sh: DIFFERENT, 9 lines differ" run
t_case "the lines that differ, of the second build" 1 "> cur-vol|vol|Invalid drive specification" run
t_derive "$f"; echo 0 > "$derived/1/EXIT"; t_play "$derived"
t_case "a run that stops short of its last line" 3 "build A: \"label q: X\" (label-q-x) did not reach its last line" run
t_derive "$f"; sed -i '' 's/^A:/C:/' "$derived/7/OUT.TXT"; t_play "$derived"
t_case "NODRIVE.EXE that left C: current" 3 "build A's run of \"label X\" (cur-label-x) had C: current, not A:" run
t_derive "$f"; sed -i '' 's/^C:/A:/' "$derived/2/OUT.TXT"; t_play "$derived"
t_case "a control with no drive current" 3 "build A's run of \"label c: X\" (label-q-x-control) had A: current, not C:" run
t_derive "$f"; sed -i '' '/^start/d' "$derived/4/OUT.TXT"; t_play "$derived"
t_case "a run that left no first line" 3 "build A's run of \"label c:\" left no first line" run
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
t_case "the line runs after NODRIVE.EXE" 0 'NODRIVE.EXE >> C:\OUT.TXT
echo line>> C:\OUT.TXT
vol >> C:\OUT.TXT' conf_of cur-vol
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
t_case "each start runs in a folder of its own" 0 "48 run folders, 48 starts" where
t_case "and writes nothing in the caller's folder" 0 "in the caller's folder: []" where
t_case "one argument" 2 "usage:" "$here/nodrive.sh" "$build_a"
t_case "its own help" 0 "usage: nodrive.sh" "$here/nodrive.sh" --help
t_end
