#!/usr/bin/env bash
# xcomsim.sh's verdicts against one captured run, no emulator: bash xcomsim.test.sh
# fixtures/xcomsim is what XCOMSIM reported and what the emulator logged on the unpatched base
# (1), which lost part of both listings, and on a build that kept them whole (2), long names off.
# fixtures/xcomsim-trace.txt is ten lines of the game's INT 21h trace that xcomsim/calls.txt was
# written from: a SetDTA and four FindFirst calls with their returns.
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
f=$here/fixtures
run() { "$here/xcomsim.sh" "$build_a" "$build_b" "$@"; }

extract() { "$here/xcomsim/extract.sh" "$@"; }
t_case "a FindFirst that failed, with its error" 0 "336|13BF:10B7|0001|c|err=0003|smk/intro1.smk" extract "$f/xcomsim-trace.txt"
t_case "a name on the CD" 0 "339|13BF:10B7|0001|cd|found|D:/xcom3/smk/intro1.smk" extract "$f/xcomsim-trace.txt"
t_case "a name with its trailing spaces" 0 "|found|RAWSOUND/STRATEGC/INTRFACE/BUTTNDRP.RAW       
5578|" extract "$f/xcomsim-trace.txt"
t_case "the attribute word as the game passed it" 0 "5578|13BA:10B7|0000|c|found|OPTIONS.DAT" extract "$f/xcomsim-trace.txt"
command grep -v '^R N=5578 ' "$f/xcomsim-trace.txt" > "$work/no-return.txt"
t_case "a FindFirst with no return" 3 "FindFirst 5578 has no return" extract "$work/no-return.txt"
command grep '^. N=334 ' "$f/xcomsim-trace.txt" > "$work/no-find.txt"
t_case "a trace with no FindFirst" 3 "the trace holds no FindFirst" extract "$work/no-find.txt"
t_case "no trace" 2 "usage:" extract "$work/none.txt"

t_play "$f/xcomsim"
t_case "the base's listings cut short, beside one kept whole" 1 "DIFFERENT" run off
t_case "the base's verdict and the log's counts" 1 "build A: lfn=off listing=28/40 27/40 lost=25 slots_full=1 out_of_range=2" run off
t_case "the other build's verdict and counts" 1 "build B: lfn=off listing=40/40 40/40 lost=0 slots_full=0 out_of_range=0" run off
t_case "a FindNext that failed before its listing ended" 1 "findnext-failed|B|after=27 of 40|error=0012|lookups=2066" run off
t_derive "$f/xcomsim"; cp "$derived/1/XCOMSIM.TXT" "$derived/2/XCOMSIM.TXT"; t_play "$derived"
t_case "the same report twice" 0 "xcomsim.sh: ALIKE" run off
t_derive "$f/xcomsim"; sed -i '' -e '/^listing=/d' -e 's/^end|lines=8/end|lines=7/' "$derived/1/XCOMSIM.TXT"; t_play "$derived"
t_case "a report with no verdict line" 3 "build A's report has no verdict line" run off
t_derive "$f/xcomsim"; sed -i '' '/^end|lines/d' "$derived/2/XCOMSIM.TXT"; t_play "$derived"
t_case "a report cut before its trailer" 3 "build B's report has no line or no trailer" run off
t_play "$f/xcomsim"
STUB_RC=3 t_case "the launcher refuses the run" 3 "did not run to its end" run off
t_case "neither on nor off" 2 "on or off" run maybe
t_case "an option it does not know" 2 "unknown option: --loads" run off --loads 3
t_case "a listing point that is not a number" 2 "--listing-at takes a number, not: soon" run off --listing-at soon
t_case "an option with no value" 2 "usage:" run off --between
t_case "one argument" 2 "usage:" "$here/xcomsim.sh" "$build_a"
t_end
