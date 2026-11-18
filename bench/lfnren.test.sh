#!/usr/bin/env bash
# lfnren.sh's verdicts against captured reports, no emulator: bash lfnren.test.sh
# fixtures/lfnren holds LFNREN's report of the create-delete branch's head twice, long names on:
# alike. fixtures/lfnren-red holds the branch before it kept a renamed directory's entries (1)
# beside its head (2): a name listed before the rename opens another file, or none.
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
f=$here/fixtures
run() { "$here/lfnren.sh" "$build_a" "$build_b"; }

t_play "$f/lfnren"
t_case "two builds that answer alike" 0 "lfnren.sh: ALIKE" run
t_case "a name listed before the rename opens its own file" 0 "lfnren|listed|LONGNA~3.TXT=0000:six" run
t_case "a search open across the rename returns names that open" 0 "lfnren|search|returned=3" run
t_play "$f/lfnren-red"
t_case "a name that opens another file after the rename" 1 "< lfnren|listed|LONGNA~2.TXT=0000:six" run
t_case "and one that opens none" 1 "< lfnren|listed|LONGNA~3.TXT=0002:-" run
t_derive "$f/lfnren"; sed -i '' '$d' "$derived/2/LFNREN.TXT"; t_play "$derived"
t_case "a report cut before its trailer" 3 "build B's report has no line or no trailer" run
t_derive "$f/lfnren"; sed -i '' '/^lfnren|search|returned/d' "$derived/1/LFNREN.TXT"; t_play "$derived"
t_case "a line fewer than the trailer says" 3 "build A's report has no line or no trailer" run
t_play "$f/lfnren"
STUB_RC=3 t_case "the launcher refuses the run" 3 "did not run to its end" run
t_case "one argument" 2 "usage:" "$here/lfnren.sh" "$build_a"
t_case "its own help" 0 "usage: lfnren.sh" "$here/lfnren.sh" --help
t_end
