#!/usr/bin/env bash
# drift.sh's verdicts against captured reports, no emulator: bash drift.test.sh
# fixtures/drift holds DRIFT's report of one build (1) and of a build that returns one entry
# more in folder-gained-files (2).
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
f=$here/fixtures
run() { "$here/drift.sh" "$build_a" "$build_b" "$@"; }

t_play "$f/drift"
t_case "two reports that differ in one case" 1 "> drift|folder-gained-files|first=0 more=7" run off
t_case "each report printed whole" 1 "drift|label-search-then-edited|first=18 more=4" run off
t_derive "$f/drift"; cp "$derived/1/DRIFT.TXT" "$derived/2/DRIFT.TXT"; t_play "$derived"
t_case "the same report twice" 0 "drift.sh: ALIKE" run off
t_derive "$f/drift"; sed -i '' '$d' "$derived/1/DRIFT.TXT"; t_play "$derived"
t_case "a report cut before its trailer" 3 "build A's report has no case or no trailer" run off
t_derive "$f/drift"; sed -i '' '/^drift|edited-twice|/d' "$derived/2/DRIFT.TXT"; t_play "$derived"
t_case "a case fewer than the trailer says" 3 "build B's report has no case or no trailer" run off
t_derive "$f/drift"; printf 'end|lines=0\r\n' > "$derived/2/DRIFT.TXT"; t_play "$derived"
t_case "a report with no case" 3 "build B's report has no case or no trailer" run off
t_play "$f/drift"
STUB_RC=3 t_case "the launcher refuses the run" 3 "did not run to its end" run off
t_case "neither on nor off" 2 "on or off" run maybe
t_case "two arguments" 2 "usage:" "$here/drift.sh" "$build_a" "$build_b"
t_end
