#!/usr/bin/env bash
# p5rep.sh's verdicts against one captured round, no emulator: bash p5rep.test.sh
# fixtures/p5rep holds the four runs of one A B B A round of the shell's DIR of one file,
# unpatched upstream against the build that reads a folder in one pass, on synthetic:1000:83
# with long names on: P5REP's ready file, the stop file the shell made and P5REP's line.
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
f=$here/fixtures
run() { "$here/p5rep.sh" "$build_a" "$build_b" synthetic:1000:83 on "$1" 1 "$work/out-$t_cases"; }

t_play "$f/p5rep"
t_case "a round timed, the two builds' guest lines alike" 0 "p5rep|1|B|seconds=" run dir:F0000001.TXT
t_case "each run's guest line: DIR's count" 0 "|guest=p5rep|mode=m files=1 lines=8" run dir:F0000001.TXT
t_derive "$f/p5rep"; LC_ALL=C sed -i '' 's/files=1 /files=0 /' "$derived/1/P5.TXT"; t_play "$derived"
t_case "a DIR that counted no file" 3 "A-1-0: DIR counted no file" run dir:F0000001.TXT
t_derive "$f/p5rep"; printf 'p5rep|mode=o open=0002\r\nend|lines=1\r\n' > "$derived/1/P5.TXT"; t_play "$derived"
t_case "an open that failed" 3 "A-1-0: the step failed: p5rep|mode=o open=0002" run open:F0000001.TXT
t_derive "$f/p5rep"; LC_ALL=C sed -i '' 's/files=1 lines=8/files=1 lines=9/' "$derived/3/P5.TXT"; t_play "$derived"
t_case "a build whose guest answers otherwise" 1 "p5rep: the guest lines differ" run dir:F0000001.TXT
t_derive "$f/p5rep"; rm "$derived/1/STOP.TXT"; t_play "$derived"
t_case "an emulator that ended before the stop file" 3 "A-1-0: the guest's step never ended" run dir:F0000001.TXT
t_derive "$f/p5rep"; rm "$derived/1/P5.TXT"; t_play "$derived"
t_case "a guest that wrote no line" 3 "A-1-0: the guest wrote no line" run dir:F0000001.TXT
t_play "$f/p5rep"
t_case "a case it does not know" 2 "the case is dir, dir:<name>, open:<name> or fopen:<name>" run copy
t_case "a 716Ch open with long names off" 2 "716Ch needs long names on" "$here/p5rep.sh" "$build_a" "$build_b" synthetic:1000:83 off open:F0000001.TXT 1 "$work/out"
t_case "a name with a backslash" 2 "a name with no quote or backslash" run 'dir:A\B'
t_case "six arguments" 2 "usage:" "$here/p5rep.sh" "$build_a" "$build_b" synthetic:1000:83 on dir 1
t_case "its own help" 0 "usage: p5rep.sh" "$here/p5rep.sh" --help
t_end
