#!/usr/bin/env bash
# xcopy.sh's verdicts against one captured run, no emulator: bash xcopy.test.sh
# fixtures/xcopy is what XCOPY printed and what the emulator logged in a run that lost part of
# the tree. The launcher's stand-in copies nothing, so every line here reads copied=0: the count
# of what arrived is proved by runs on an emulator.
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
f=$here/fixtures
run() { "$here/xcopy.sh" "$build_a" "$@"; }

t_play "$f/xcopy"
t_case "what XCOPY said, and the log's counts" 0 "said=2065 slots_full=1 out_of_range=3" run off
t_case "the tree it made" 0 "xcopy.sh: lfn=off made=2520 copied=0 dirs_made=18 dirs_copied=0" run off
t_derive "$f/xcopy"; sed -i '' '/ile(s) copied/d' "$derived/1/XCOPY.TXT"; t_play "$derived"
t_case "an XCOPY that printed no count" 0 "said=- slots_full=1" run off
t_derive "$f/xcopy"; : > "$derived/1/XCOPY.TXT"; t_play "$derived"
t_case "an XCOPY that printed nothing" 3 "XCOPY printed nothing" run off
t_play "$f/xcopy"
STUB_RC=3 t_case "the launcher refuses the run" 3 "did not run to its end" run off
t_case "neither on nor off" 2 "on or off" run maybe
t_case "one argument" 2 "usage:" run
t_end
