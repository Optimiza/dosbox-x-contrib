#!/usr/bin/env bash
# dirgone.sh's verdicts against captured reports, no emulator: bash dirgone.test.sh
# fixtures/dirgone holds DIRGONE's report of the unpatched base (1) and of the create-delete
# branch before its search followed a removed or renamed directory (2), long names off: the two
# answer alike. fixtures/dirgone-red holds that branch (1) beside the commit that follows them (2),
# which reads on as the three DOS do.
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
f=$here/fixtures
run() { "$here/dirgone.sh" "$build_a" "$build_b" "$@"; }

t_play "$f/dirgone"
t_case "two builds that answer alike" 0 "dirgone.sh: ALIKE" run off
t_case "each report printed whole" 0 "gone|ren|first=0000 entry=. op=0000 made=- next=0012 rest=-" run off
t_case "a directory removed, emptied after the search, and made again" 0 "gone|rd-late-remade|first=0000 entry=. op=0000 made=0000 next=0012 rest=..,ID.TXT" run off
t_play "$f/dirgone-red"
t_case "a build that reads on in the renamed directory" 1 "> gone|ren|first=0000 entry=. op=0000 made=- next=0012 rest=..,ID.TXT,TWO.TXT" run off
t_case "and in one whose parent was renamed" 1 "> gone|ren-parent|first=0000 entry=. op=0000 made=- next=0012 rest=..,ID.TXT" run off
t_case "and not in the directory made again under the old name" 1 "> gone|rd-late-remade|first=0000 entry=. op=0000 made=0000 next=0012 rest=.." run off
t_derive "$f/dirgone"; sed -i '' '$d' "$derived/1/DIRGONE.TXT"; t_play "$derived"
t_case "a report cut before its trailer" 3 "build A's report has no case or no trailer" run off
t_derive "$f/dirgone"; sed -i '' '/^gone|rd-remade|/d' "$derived/2/DIRGONE.TXT"; t_play "$derived"
t_case "a case fewer than the trailer says" 3 "build B's report has no case or no trailer" run off
t_derive "$f/dirgone"; printf 'end|lines=0\r\n' > "$derived/2/DIRGONE.TXT"; t_play "$derived"
t_case "a report with no case" 3 "build B's report has no case or no trailer" run off
t_play "$f/dirgone"
STUB_RC=3 t_case "the launcher refuses the run" 3 "did not run to its end" run off
t_case "neither on nor off" 2 "on or off" run maybe
t_case "two arguments" 2 "usage:" "$here/dirgone.sh" "$build_a" "$build_b"
t_end
