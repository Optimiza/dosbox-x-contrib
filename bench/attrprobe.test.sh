#!/usr/bin/env bash
# attrprobe.sh's verdicts against one captured run, no emulator: bash attrprobe.test.sh
# fixtures/attrprobe holds ATTRPRB's report of two builds that answer alike on macOS, long names
# off. The line a build answers differently with is the one the unpatched base printed on Windows,
# where an attribute change empties the directory cache and a DTA saved from an ended search
# reads the search of the other folder.
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
f=$here/fixtures
run() { "$here/attrprobe.sh" "$build_a" "$build_b" "$@"; }
cr=$'\r'

t_play "$f/attrprobe"
t_case "two reports alike" 0 "attrprobe.sh: ALIKE" run off
t_case "each report printed whole" 0 "attr|saved-dta-after-setattr|more=0 of 39 foreign=0 y=22 of 22" run off
t_derive "$f/attrprobe"; sed -i '' "s/^attr|saved-dta-after-setattr|.*/attr|saved-dta-after-setattr|more=19 of 39 foreign=19 y=3 of 22$cr/" "$derived/1/ATTRPRB.TXT"; t_play "$derived"
t_case "a saved DTA that reads the other folder" 1 "< attr|saved-dta-after-setattr|more=19 of 39 foreign=19 y=3 of 22" run off
t_case "the lines that differ, counted" 1 "attrprobe.sh: DIFFERENT, 1 lines differ" run off
t_derive "$f/attrprobe"; sed -i '' '$d' "$derived/2/ATTRPRB.TXT"; t_play "$derived"
t_case "a report cut before its trailer" 3 "build B's report has no line or no trailer" run off
t_derive "$f/attrprobe"; sed -i '' '/^attr|remove-a-later-file|/d' "$derived/1/ATTRPRB.TXT"; t_play "$derived"
t_case "a case fewer than the trailer says" 3 "build A's report has no line or no trailer" run off
t_derive "$f/attrprobe"; : > "$derived/1/ATTRPRB.TXT"; t_play "$derived"
t_case "a folder that listed nothing: no line, no trailer" 3 "build A's report has no line or no trailer" run off
t_play "$f/attrprobe"
STUB_RC=3 t_case "the launcher refuses the run" 3 "did not run to its end" run off
t_case "neither on nor off" 2 "on or off" run maybe
t_case "two arguments" 2 "usage:" "$here/attrprobe.sh" "$build_a" "$build_b"
t_case "its own help" 0 "usage: attrprobe.sh" "$here/attrprobe.sh" --help
t_end
