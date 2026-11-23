#!/usr/bin/env bash
# drift.sh's verdicts against captured reports, no emulator: bash drift.test.sh
# fixtures/drift holds DRIFT's report of one build (1) and of a build that returns one entry
# more in folder-gained-files (2). fixtures/drift-star holds one build twice, with the cases of a
# template that holds a '*'. fixtures/drift-moved holds a build that reads on in a renamed folder
# (1) and one that returns nothing there (2). fixtures/drift-reused holds, with long names on, a
# build that reads a search given the number of an abandoned one to its end (1) and one that
# stops after its first entry (2); each emulator logged one "All slots full".
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
f=$here/fixtures
run() { "$here/drift.sh" "$build_a" "$build_b" "$@"; }

t_play "$f/drift"
t_case "two reports that differ in one case" 1 "> drift|folder-gained-files|first=0 more=7" run off
t_case "each report printed whole" 1 "drift|label-search-then-edited|first=18 more=4" run off
t_play "$f/drift-star"
t_case "a '*' in the template taken as the rest of the field" 0 "drift|to-a-later-name-with-a-star|first=0 more=1|,ZED.TXT:20:7" run off
t_case "a '*' for the whole name" 0 "drift|to-a-star-for-the-name|first=0 more=4|" run off
t_play "$f/drift-moved"
t_case "a search for one name in a renamed folder, read on in it" 1 "> drift|in-a-folder-renamed|first=0 op=0 more=0|" run off
t_case "the same in a removed folder, alike" 1 "drift|in-a-folder-removed|first=0 op=0 more=0|" run off
t_case "a search in a folder whose rename failed, read on with the rest" 1 "> drift|in-a-folder-renamed-and-failed|first=0 op=5 create=0 more=0|" run off
t_play "$f/drift-reused"
t_case "a search given the number of an abandoned one, cut after its first entry" 1 "> drift|after-the-search-table-emptied|first=0 more=0|" run on
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
