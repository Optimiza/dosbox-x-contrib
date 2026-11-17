#!/usr/bin/env bash
# junktest.sh's verdicts against one captured run, no emulator: bash junktest.test.sh
# On a Mac only: the sampler reads ps and footprint. fixtures/junktest is the reporter's run
# "300 JUNK 300" on an emulator: what FC said of the reporter's two files, the guest's console as
# the emulator logged it, and the line of the hold. The reporter's files are not in this
# repository: the folder handed to the script holds empty files under their names.
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
f=$here/fixtures
folder=$work/junktest
mkdir "$folder" || exit 3
for name in 300.BAT JUNK.BAT DJUNK.BAT e001.exp RESULT.TXT; do : > "$folder/$name"; done
run() { "$here/junktest.sh" "$build_a" "$folder" "$@"; }

t_play "$f/junktest"
t_case "the run's batch files reached their end, read while held" 0 "counted=600 done=3" run off 300 JUNK 300
t_case "the line carries the batch files and the figures" 0 "junktest.sh: batches=300,JUNK,300 lfn=off entries=5 junk=0 counted=600 done=3 peak_rss_kb=" run off 300 JUNK 300
t_case "other batch files than the console shows" 3 "did not reach their end: counted=600 done=3 for 300 JUNK" run off 300 JUNK
t_derive "$f/junktest"; LC_ALL=C awk '/^DOS CON: Count: 300 of 300/ && !cut { cut = 1; next } { print }' "$f/junktest/1/dosbox.log" > "$derived/1/dosbox.log"; t_play "$derived"
t_case "a 300.BAT cut before its last run" 3 "counted=599 done=3" run off 300 JUNK 300
t_derive "$f/junktest"; LC_ALL=C sed -i '' '/^DOS CON: Done! 700/d' "$derived/1/dosbox.log"; t_play "$derived"
t_case "a JUNK.BAT that did not end" 3 "counted=600 done=2" run off 300 JUNK 300
t_derive "$f/junktest"; : > "$derived/1/FC.TXT"; t_play "$derived"
t_case "an FC that did not compare the two files" 3 "FC did not compare the reporter's two files" run off 300 JUNK 300
t_derive "$f/junktest"; rm "$derived/1/HOLD"; t_play "$derived"
t_case "a guest that never held" 3 "was not read while the guest held" run off 300 JUNK 300
t_play "$f/junktest"
STUB_RC=3 t_case "the launcher refuses the run" 3 "did not run to its end" run off 300 JUNK 300
t_case "no folder of the reporter's files" 3 "INVALID: no folder of the reporter's files" "$here/junktest.sh" "$build_a" "$work/none" off 300
rm "$folder/JUNK.BAT"
t_case "a folder that lacks one of them" 3 "the reporter's folder holds no JUNK.BAT" run off 300
t_case "a batch file the reporter did not send" 2 "not: AUTOEXEC" run off AUTOEXEC
t_case "neither on nor off" 2 "on or off" run maybe 300
t_case "no batch file" 2 "usage:" run off
t_end
