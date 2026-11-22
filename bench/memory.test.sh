#!/usr/bin/env bash
# memory.sh's verdicts against captured guest lines: bash memory.test.sh
# On a Mac only: the sampler reads ps and footprint. fixtures/memory is five calls that
# reached their file, memory-missing five that named one that is not there, memory-each 25
# lookups over a folder of 20 files, one file after another, memory-kept 300 children of mode k
# on a build that keeps their searches, memory-label 2,100 searches for a label the drive has.
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
f=$here/fixtures
run() { "$here/memory.sh" "$build_a" "$@"; }

t_play "$f/memory"
t_case "calls that reached the file, read while held" 0 "ok=5 released=1" run synthetic:20:83 on a 5
t_case "the line names the file and both figures" 0 "file=F0000000.TXT entries=20 peak_rss_kb=" run synthetic:20:83 on a 5
t_case "another call count than the guest's line" 3 "not every one of the 6 calls" run synthetic:20:83 on a 6
t_play "$f/memory-missing"
t_case "calls that did not reach the file" 3 "not every one of the 5 calls" run synthetic:20:83 on a 5
t_derive "$f/memory"; rm "$derived/1/HOLD"; t_play "$derived"
t_case "a guest that never held" 3 "was not read while the guest held" run synthetic:20:83 on a 5
t_derive "$f/memory"; sed -i '' 's/released=1/released=0/' "$derived/1/PRB.TXT"; t_play "$derived"
t_case "a guest that gave up waiting" 3 "was not let go" run synthetic:20:83 on a 5
t_play "$f/memory-each"
t_case "a lookup for each file in turn, past the folder's size" 0 'guest="mode=e k=25 ok=25 released=1' run synthetic:20:83 off e 25
t_play "$f/memory-kept"
t_case "children whose searches for one name fill the search table" 0 'slots_full=1 guest="mode=k k=300 ok=300 released=1' run synthetic:100:83 off k 300
t_play "$f/memory-label"
t_case "a search for a label the drive has, its guest line that of mode v" 0 'slots_full=1 guest="mode=v k=2100 ok=2100 released=1' run synthetic:100:83 off w 2100
t_play "$f/memory"
STUB_RC=3 t_case "the launcher refuses the run" 3 "did not run to its end" run synthetic:20:83 on a 5
t_case "no such mode" 2 "no such mode" run synthetic:20:83 on z 5
t_case "a host folder without --file" 2 "needs --file" run "$work" on a 5
t_case "an unknown option" 2 "unknown option" run synthetic:20:83 on a 5 --name x
t_end
