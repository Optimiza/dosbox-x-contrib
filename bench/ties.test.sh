#!/usr/bin/env bash
# ties.sh's verdicts against a captured report: bash ties.test.sh
# fixtures/ties holds one build's report twice: eleven pairs sharing a name.
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
f=$here/fixtures
run() { "$here/ties.sh" "$build_a" "$build_b"; }

t_play "$f/ties"
t_case "the same report twice" 0 "ties.sh: ALIKE (11 ties)" run
t_derive "$f/ties"; awk -F'|' 'BEGIN { OFS = "|" } $1 == "tie" && $3 == "lfn" && !done { n = split($4, e, ","); $4 = e[2] "," e[1]; done = 1 } { print }' "$f/ties/2/OUT.TXT" > "$derived/2/OUT.TXT"; t_play "$derived"
t_case "one pair returned in the other order" 1 "ties.sh: DIFFERENT (11 ties)" run
t_derive "$f/ties"; sed -i '' 's/^end|ties=.*/end|ties=0/' "$derived/1/OUT.TXT"; t_play "$derived"
t_case "no two entries share a name" 3 "nothing to compare" run
t_play "$f/ties"
STUB_RC=3 t_case "the launcher refuses the run" 3 "did not run to its end" run
t_case "one argument" 2 "usage:" "$here/ties.sh" "$build_a"
t_end
