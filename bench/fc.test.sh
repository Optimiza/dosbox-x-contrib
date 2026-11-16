#!/usr/bin/env bash
# fc.sh's verdicts against one captured run, no emulator: bash fc.test.sh
# On a Mac only: the sampler reads ps and footprint. fixtures/fc is three runs of FC in a folder
# of five files: what FC printed, and the line of the hold.
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
f=$here/fixtures
run() { "$here/fc.sh" "$build_a" "$@"; }

t_play "$f/fc"
t_case "runs of FC that compared, read while held" 0 "slots_full=0 compared=3" run 5 off 3
t_case "the line carries the folder and the figures" 0 "fc.sh: files=5 runs=3 lfn=off entries=8 peak_rss_kb=" run 5 off 3
t_case "another run count than FC's output" 3 "FC compared the two files 3 times of 4" run 5 off 4
t_derive "$f/fc"; awk '/^No differences/ && !cut { cut = 1; next } { print }' "$f/fc/1/FC.TXT" > "$derived/1/FC.TXT"; t_play "$derived"
t_case "a run of FC that did not compare" 3 "FC compared the two files 2 times of 3" run 5 off 3
t_derive "$f/fc"; rm "$derived/1/FC.TXT"; t_play "$derived"
t_case "no run of FC at all" 3 "FC compared the two files 0 times of 3" run 5 off 3
t_derive "$f/fc"; rm "$derived/1/HOLD"; t_play "$derived"
t_case "a guest that never held" 3 "was not read while the guest held" run 5 off 3
t_derive "$f/fc"; sed -i '' 's/released=1/released=0/' "$derived/1/PRB.TXT"; t_play "$derived"
t_case "a hold that gave up waiting" 3 "was not let go" run 5 off 3
t_play "$f/fc"
STUB_RC=3 t_case "the launcher refuses the run" 3 "did not run to its end" run 5 off 3
t_case "no run" 2 "bad run count: 0" run 5 off 0
t_case "a file count that is no number" 2 "bad file count: many" run many off 3
t_case "neither on nor off" 2 "on or off" run 5 maybe 3
t_case "three arguments" 2 "usage:" run 5 off
t_end
