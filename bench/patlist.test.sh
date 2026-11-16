#!/usr/bin/env bash
# patlist.sh's verdicts against captured reports, no emulator: bash patlist.test.sh
# fixtures/patlist holds PATLIST's report of two builds that answer alike, long names off.
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
f=$here/fixtures
run() { "$here/patlist.sh" "$build_a" "$build_b" "$@"; }

t_play "$f/patlist"
t_case "two reports alike" 0 "patlist.sh: ALIKE" run off
t_case "each report printed whole" 0 "pat|B*R.TXT|first=0 n=1|,BAR.TXT" run off
t_derive "$f/patlist"; sed -i '' 's/^pat|B\*R\.TXT|first=0 n=1|,BAR\.TXT/pat|B*R.TXT|first=18 n=0|/' "$derived/2/PATLIST.TXT"; t_play "$derived"
t_case "a pattern answered otherwise" 1 "> pat|B*R.TXT|first=18 n=0|" run off
t_case "the lines that differ, counted" 1 "patlist.sh: DIFFERENT, 1 lines differ" run off
t_derive "$f/patlist"; sed -i '' '$d' "$derived/1/PATLIST.TXT"; t_play "$derived"
t_case "a report cut before its trailer" 3 "build A's report has no line or no trailer" run off
t_derive "$f/patlist"; printf 'end|lines=0\r\n' > "$derived/2/PATLIST.TXT"; t_play "$derived"
t_case "a report with no pattern" 3 "build B's report has no line or no trailer" run off
t_play "$f/patlist"
STUB_RC=3 t_case "the launcher refuses the run" 3 "did not run to its end" run off
t_case "neither on nor off" 2 "on or off" run maybe
t_case "two arguments" 2 "usage:" "$here/patlist.sh" "$build_a" "$build_b"
t_end
