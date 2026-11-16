#!/usr/bin/env bash
# enumstat.sh's verdicts against one build's six captured rows: bash enumstat.test.sh
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
f=$here/fixtures
run() { "$here/enumstat.sh" "$@"; }

t_play "$f/enumstat"
t_case "a row with its listing and the log's counts" 0 "lfn=on names=long files=3000 enumstat|mode=s|listed=139|looked_up_ok=137|last=ALPH~137.MID slots_full=1 out_of_range=0" run "$build_a"
t_case "six rows" 0 "lfn=off names=83 files=3000 enumstat|mode=n|listed=3002" run "$build_a"
t_derive "$f/enumstat"; cp "$derived/1/OUT.TXT" "$derived/3/OUT.TXT"; t_play "$derived"
t_case "a row that is another mode's" 3 "not ENUMSTAT's line for mode x" run "$build_a"
t_derive "$f/enumstat"; rm "$derived/4/OUT.TXT"; t_play "$derived"
t_case "a run that left no output" 3 "not ENUMSTAT's line for mode s" run "$build_a"
t_play "$f/enumstat"
STUB_RC=3 t_case "the launcher refuses the run" 3 "did not run to its end" run "$build_a"
t_case "no argument" 2 "usage:" "$here/enumstat.sh"
t_end
