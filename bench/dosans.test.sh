#!/usr/bin/env bash
# dosans.sh's verdicts against captured reports, no emulator: bash dosans.test.sh
# fixtures/dosans holds DOSANS's report of the unpatched base (1) and of the build whose 3Dh, 43h
# and 3Bh read a path as MS-DOS does (2), unlabelled, long names off: they differ in the calls'
# lines and in no 4Eh line. fixtures/dosans-alike holds that build twice.
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
f=$here/fixtures
run() { "$here/dosans.sh" "$build_a" "$build_b" "$@"; }

t_play "$f/dosans-alike"
t_case "two builds that answer alike" 0 "dosans.sh: ALIKE" run unlabelled off
t_case "each report printed whole" 0 "call|3D|D:\\NOSUCH\\CON|err=0" run unlabelled off
t_play "$f/dosans"
t_case "a build that reads a path otherwise" 1 "dosans.sh: DIFFERENT, 246 lines differ" run unlabelled off
t_case "the lines that differ, A then B" 1 "> call|3B|D:\\X\\...|err=3" run unlabelled off
t_derive "$f/dosans-alike"; sed -i '' '$d' "$derived/2/DOSANS.TXT"; t_play "$derived"
t_case "a report cut before its trailer" 3 "build B's report has no line or no trailer" run unlabelled off
t_derive "$f/dosans-alike"; sed -i '' '/^ans|shape|37|D:\\X\\|/d' "$derived/1/DOSANS.TXT"; t_play "$derived"
t_case "a line fewer than the trailer says" 3 "build A's report has no line or no trailer" run unlabelled off
t_play "$f/dosans-alike"
STUB_RC=3 t_case "the launcher refuses the run" 3 "did not run to its end" run unlabelled off
t_case "neither labelled nor unlabelled" 2 "labelled or unlabelled, not: both" run both off
t_case "neither on nor off" 2 "on or off" run unlabelled maybe
t_case "three arguments" 2 "usage:" run unlabelled
t_case "its own help" 0 "usage: dosans.sh" "$here/dosans.sh" --help
t_end
