#!/usr/bin/env bash
# unit.sh's verdicts against one captured result file, no emulator: bash unit.test.sh
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
f=$here/fixtures
run() { "$here/unit.sh" "$@"; }

t_play "$f/unit"
t_case "the counts of a run" 0 "unit.sh: tests=68 failures=0 errors=0 disabled=0 build=" run "$build_a"
t_derive "$f/unit"; sed -i '' '2s/ failures="0"/ failures="2"/' "$derived/1/UNIT.XML"; t_play "$derived"
STUB_RC=1 t_case "a failed test is an answer" 0 "unit.sh: tests=68 failures=2 errors=0" run "$build_a"
t_play "$f/unit"
STUB_RC=1 t_case "an emulator that failed with no test failed" 3 "names no failure" run "$build_a"
t_derive "$f/unit"; sed -i '' '$d' "$derived/1/UNIT.XML"; t_play "$derived"
t_case "a result file cut short" 3 "cut short" run "$build_a"
t_derive "$f/unit"; sed -i '' '2s/ tests="68"/ tests="0"/' "$derived/1/UNIT.XML"; t_play "$derived"
t_case "a result file that counts no test" 3 "counts no test" run "$build_a"
t_derive "$f/unit"; sed -i '' '2d' "$derived/1/UNIT.XML"; t_play "$derived"
t_case "a result file with no line of counts" 3 "no line of counts" run "$build_a"
t_derive "$f/unit"; rm "$derived/1/UNIT.XML"; t_play "$derived"
t_case "an emulator that left no result file" 3 "left no result file" run "$build_a"
t_case "a build that is not there" 2 "not an executable" run "$work/none"
t_case "no argument" 2 "usage:" "$here/unit.sh"
t_end
