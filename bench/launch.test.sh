#!/usr/bin/env bash
# launch.sh's verdicts against a stand-in for the emulator: bash launch.test.sh
# fixtures/stub-emulator.sh takes the build's place and does what each case tells it.
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
emu=$here/fixtures/stub-emulator.sh
left=$work/OUT.TXT
export STUB_EMU_SAW=$work/saw.txt
: > "$work/run.conf"
launch() { "$here/launch.sh" --conf "$work/run.conf" --binary "$emu" --seconds 20 --output "$left" --log "$work/dosbox.log" --report "$work/report.txt" "$@"; }
# The report and what the emulator saw, after a run: what a script reads from them.
launch_then() { launch "$@" > /dev/null 2>&1; echo "rc=$?"; cat "$work/report.txt" "$STUB_EMU_SAW"; }

STUB_EMU_OUTPUT=$left t_case "a run that leaves its output" 0 "launch.sh: exit code: 0" launch
STUB_EMU_OUTPUT=$left t_case "the report names the build's version line" 0 "launch.sh: version: DOSBox-X version 0.0 stand-in" launch_then
STUB_EMU_OUTPUT=$left t_case "no window: the dummy video driver" 0 "video=dummy" launch_then
STUB_EMU_OUTPUT=$left t_case "the quit warning is off" 0 "dosbox quit warning=false" launch_then
STUB_EMU_OUTPUT=$left t_case "no folder prompt" 0 "-nopromptfolder" launch_then
STUB_EMU_OUTPUT=$left t_case "what follows -- reaches the emulator whole" 0 "sdl waitonerror=false" launch_then -- -tests -set "sdl waitonerror=false"
rm -f "$left"
t_case "no output" 3 "INVALID: the run left no $left" launch
: > "$left"
t_case "an empty output" 3 "INVALID: the run left $left empty" launch
echo old > "$left"
t_case "an output of an earlier run" 3 "was not written by this run" launch
rm -f "$left"
STUB_EMU_OUTPUT=$left STUB_EMU_LOG="" t_case "an empty log" 3 "INVALID: the emulator's log came out empty" launch
rm -f "$left"
STUB_EMU_OUTPUT=$left STUB_EMU_RC=7 t_case "the emulator fails" 7 "launch.sh: | the stand-in's last word" launch
rm -f "$left"
STUB_EMU_OUTPUT=$left STUB_EMU_SLEEP=30 t_case "the bound reached, the output there" 0 "launch.sh: exit code: 0" launch --seconds 1
rm -f "$left"
STUB_EMU_SLEEP=30 t_case "the bound reached, no output" 3 "INVALID: the run left no" launch --seconds 1
t_case "an unknown option" 2 "unknown option: --mode" launch --mode headless
t_case "no bound" 2 "--seconds is a whole number of seconds, 1 or more: 0" launch --seconds 0
t_case "a build that is not there" 2 "not an executable" "$here/launch.sh" --conf "$work/run.conf" --binary "$work/absent" --seconds 5 --output "$left" --log "$work/l" --report "$work/r"
t_case "an option left out" 2 "missing --report" "$here/launch.sh" --conf "$work/run.conf" --binary "$emu" --seconds 5 --output "$left" --log "$work/l"
t_case "--help" 0 "usage: launch.sh" "$here/launch.sh" --help
t_end
