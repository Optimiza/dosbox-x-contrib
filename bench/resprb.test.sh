#!/usr/bin/env bash
# resprb.sh's figures against captured runs, no emulator: bash resprb.test.sh
# On a Mac only: the sampler reads ps and footprint. fixtures/resprb is mode c, 2 children, on
# macOS, whose build compiles no x86 dynamic core and so logs no reset. fixtures/resprb-counted
# is mode c, 20 children, on Windows, on a build with the counter of counters/count-dyn.diff:
# its log holds that counter's lines.
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
f=$here/fixtures
run() { "$here/resprb.sh" "$build_a" "$@"; }

t_play "$f/resprb"
t_case "children that each started a search, read while held" 0 'guest="mode=c k=2 ok=2 released=1' run c 2
t_case "the line names the mode, the core and the figures" 0 "mode=c calls=2 core=dynamic files=100 peak_rss_kb=" run c 2
t_case "a build that logs no reset" 0 "resets=none" run c 2
t_case "the normal core" 0 "core=normal" run c 2 --core normal
t_case "another count than the guest's line" 3 "not every one of the 3 repetitions answered" run c 3
t_play "$f/resprb-counted"
t_case "the dynamic core's resets, counted" 0 "resets=42 " run c 20
t_derive "$f/resprb"; rm "$derived/1/HOLD"; t_play "$derived"
t_case "a guest that never held" 3 "was not read while the guest held" run c 2
t_derive "$f/resprb"; sed -i '' 's/released=1/released=0/' "$derived/1/PRB.TXT"; t_play "$derived"
t_case "a guest that gave up waiting" 3 "or the guest was not let go" run c 2
t_play "$f/resprb"
STUB_RC=3 t_case "the launcher refuses the run" 3 "did not run to its end" run c 2
t_case "no such mode" 2 "no such mode: x" run x 2
t_case "no such core" 2 "the core is dynamic or normal, not: auto" run c 2 --core auto
t_case "an unknown option" 2 "unknown option: --cpu" run c 2 --cpu normal
t_case "two arguments" 2 "usage:" run c
t_case "its own help" 0 "usage: resprb.sh" "$here/resprb.sh" --help
t_end
