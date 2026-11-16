#!/usr/bin/env bash
# exact.sh's verdicts against captured reports, no emulator: bash exact.test.sh
# fixtures/exact holds EXACT's report and the shell test's of one build (1, 2) and of a build
# that differs from it in the drift section only (3, 4).
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
f=$here/fixtures
run() { "$here/exact.sh" "$build_a" "$build_b" "$@"; }

t_play "$f/exact"
t_case "a difference in drift alone does not decide" 0 "exact.sh: drift: DIFFERENT" run on
t_case "the judged sections alike" 0 "exact.sh: basic: ALIKE (362 lines)" run on
t_derive "$f/exact"; sed -i '' '1,/^basic|4e|/s/^\(basic|4e|.*\)n=\([0-9]*\)/\1n=9\2/' "$derived/3/EXACT.TXT"; t_play "$derived"
t_case "a basic line that differs" 1 "exact.sh: basic: DIFFERENT" run on
t_derive "$f/exact"; sed -i '' '/foo yes/d' "$derived/4/SH.TXT"; t_play "$derived"
t_case "a shell line that differs" 1 "exact.sh: shell: DIFFERENT" run on
t_derive "$f/exact"; sed -i '' '$d' "$derived/1/EXACT.TXT"; t_play "$derived"
t_case "a report cut before its trailer" 3 "no trailer" run on
t_derive "$f/exact"; sed -i '' '/^END/d' "$derived/2/SH.TXT"; t_play "$derived"
t_case "a shell test that did not reach its end" 3 "did not reach its end" run on
t_play "$f/exact"
STUB_RC=3 t_case "the launcher refuses the run" 3 "did not run to its end" run on
t_case "two arguments" 2 "usage:" "$here/exact.sh" "$build_a" "$build_b"

# The folder itself: exact_tree refuses one that did not come out with its entries.
# shellcheck source=common.sh
tree() { (tool=exact.test.sh; . "$here/common.sh"; exact_tree "$1"); }
t_case "the folder, whole" 0 "" tree "$work/whole"
mkdir -p "$work/more/X" && : > "$work/more/X/EXTRA.TXT"
t_case "a folder with another count of entries" 1 "the folder came out with 19 entries, not 18" tree "$work/more"
t_end
