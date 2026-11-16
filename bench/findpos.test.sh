#!/usr/bin/env bash
# findpos.sh's verdicts against captured reports, no emulator: bash findpos.test.sh
# fixtures/findpos holds FINDPOS's report, the drive labelled and long names off, of a build whose
# FindNext after a search for the label alone returns the root's files (1) and of one where it
# finds no more (2).
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
f=$here/fixtures
run() { "$here/findpos.sh" "$build_a" "$build_b" "$@"; }

t_play "$f/findpos"
t_case "two reports that differ in a label case" 1 "> pos|label-alone|first=0 entry=FPLABEL:08:0 next=18 more=0|" run labelled off
t_case "the lines that differ, counted" 1 "findpos.sh: DIFFERENT, 2 lines differ" run labelled off
t_case "each report printed whole" 1 "pos|rewound-by-restored-dta|first=0 read=3 then=5 more=7|" run labelled off
t_derive "$f/findpos"; cp "$derived/1/FINDPOS.TXT" "$derived/2/FINDPOS.TXT"; t_play "$derived"
t_case "the same report twice" 0 "findpos.sh: ALIKE" run labelled off
t_derive "$f/findpos"; sed -i '' '$d' "$derived/1/FINDPOS.TXT"; t_play "$derived"
t_case "a report cut before its trailer" 3 "build A's report has no line or no trailer" run labelled off
t_derive "$f/findpos"; sed -i '' '/^pos|after-the-end|/d' "$derived/2/FINDPOS.TXT"; t_play "$derived"
t_case "a case fewer than the trailer says" 3 "build B's report has no line or no trailer" run labelled off
t_derive "$f/findpos"; printf 'end|lines=0\r\n' > "$derived/2/FINDPOS.TXT"; t_play "$derived"
t_case "a report with no case" 3 "build B's report has no line or no trailer" run labelled off
t_play "$f/findpos"
STUB_RC=3 t_case "the launcher refuses the run" 3 "did not run to its end" run labelled off
t_case "a drive that is neither" 2 "labelled or unlabelled" run maybe off
t_case "neither on nor off" 2 "on or off" run labelled maybe
t_case "three arguments" 2 "usage:" "$here/findpos.sh" "$build_a" "$build_b" labelled
t_end
