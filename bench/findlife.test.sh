#!/usr/bin/env bash
# findlife.sh's verdicts against captured reports, no emulator: bash findlife.test.sh
# fixtures/findlife holds the report of one build (1) and of a build that answers several cases
# otherwise (2).
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
f=$here/fixtures
run() { "$here/findlife.sh" "$build_a" "$build_b" "$@"; }

t_play "$f/findlife"
t_case "two reports that differ" 1 "> case|nested-same-dta|outer=3 of 42" run on
t_case "each report printed whole" 1 "case|listed-again-after-a-new-file|created=1 first_listing=42 of 42 second_listing=43 of 43 new_file_in_second=1 foreign=0|ok" run on
t_case "two searches read turn about, cut short on one build" 1 "< case|turn-about-past-the-slots|lookups=1960 found=1960 first=28 of 42 second=28 of 32 foreign=0|DIFFERS" run on
t_case "and whole on the other" 1 "> case|turn-about-past-the-slots|lookups=2940 found=2940 first=42 of 42 second=32 of 32 foreign=0|ok" run on
t_derive "$f/findlife"; cp "$derived/1/LIFE.TXT" "$derived/2/LIFE.TXT"; t_play "$derived"
t_case "the same report twice" 0 "findlife.sh: ALIKE" run on
t_derive "$f/findlife"; sed -i '' '$d' "$derived/1/LIFE.TXT"; t_play "$derived"
t_case "a report cut before its trailer" 3 "no case or no trailer" run on
t_derive "$f/findlife"; printf 'folders|a=2 b=2 foreign=0\r\nend|cases=0\r\n' > "$derived/2/LIFE.TXT"; t_play "$derived"
t_case "a report with no case" 3 "build B's report has no case" run on
t_play "$f/findlife"
STUB_RC=3 t_case "the launcher refuses the run" 3 "did not run to its end" run on
# A temporary folder longer than a DOS command line, wherever the test runs. FINDLIFE hands the
# remount's folder to MOUNT after " d ", in the 126 characters of the command line.
long_tmp=$work/tmp/$(printf '%0130d' 0)
mkdir -p "$long_tmp" || exit 3
root_of() {
    local out
    out=$(TMPDIR=$long_tmp STUB_RC=3 run on 2>&1)
    awk '{ print (length($0) <= 123 ? "fits" : "too long: " length($0)) }' "$(printf '%s\n' "$out" | sed -n 's/.*the run is kept in //p')/run-A/ROOT.TXT"
}
t_case "under a long TMPDIR the remount's folder fits MOUNT's command line" 0 "fits" root_of
tree_of() {
    local out kept
    out=$(STUB_RC=3 run on 2>&1)
    kept=$(printf '%s\n' "$out" | sed -n 's/.*the run is kept in //p')
    if [ "$(cd "$kept/run-A" && cd "$(cat ROOT.TXT)" && pwd -P)" = "$kept/tree-A" ]; then echo "the build's tree"; else echo "another folder"; fi
}
t_case "the remount's folder, from the run's folder, is the build's tree" 0 "the build's tree" tree_of
# On Windows: a uname that says MINGW, and a cygpath that names a relative path from the folder it
# is called in, as Git Bash's does. A launcher with no run to play refuses, so the run is kept.
mkdir -p "$work/winbin" || exit 3
printf '#!/bin/sh\necho MINGW64_NT-10.0-26300\n' > "$work/winbin/uname"
# shellcheck disable=SC2016  # the script written here expands its own argument
printf '#!/bin/sh\ncase "$2" in /*) echo "$2" ;; *) echo "$PWD/$2" ;; esac\n' > "$work/winbin/cygpath"
chmod +x "$work/winbin/uname" "$work/winbin/cygpath" && ln -s "$here/fixtures/stub-powershell.sh" "$work/winbin/powershell" || exit 3
win_root() {
    local out
    out=$(PATH="$work/winbin:$PATH" STUB_PLAY=$work/none run on 2>&1)
    cat "$(printf '%s\n' "$out" | sed -n 's/.*the run is kept in //p')/run-A/ROOT.TXT"
}
t_case "on Windows too, the remount's folder is named from the run's folder" 0 '..\tree-A' win_root
spy=$work/spy.sh
# shellcheck disable=SC2016  # the script written here expands its own variables
printf '%s\n' '#!/bin/bash' 'pwd -P >> "$SPY_OUT"' "exec \"$here/fixtures/stub-launcher.sh\" \"\$@\"" > "$spy" && chmod +x "$spy" || exit 3
where() { SPY_OUT=$work/where.txt DIRCACHE_LAUNCHER=$spy run on > /dev/null; head -n 1 "$work/where.txt"; }
t_case "the emulator starts in the run's folder, which the remount's folder is named from" 0 "/run-A" where
t_case "neither on nor off" 2 "on or off" run maybe
t_case "two arguments" 2 "usage:" "$here/findlife.sh" "$build_a" "$build_b"
t_end
