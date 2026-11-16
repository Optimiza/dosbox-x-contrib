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
t_case "neither on nor off" 2 "on or off" run maybe
t_case "two arguments" 2 "usage:" "$here/findlife.sh" "$build_a" "$build_b"
t_end
