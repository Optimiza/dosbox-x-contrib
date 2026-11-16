#!/usr/bin/env bash
# passfail.sh's verdicts against captured runs: bash passfail.test.sh
# fixtures: passfail, ten checks that pass; -control, one PASS, two FAIL, two lower-case lines,
# exit 7; -no-line, stopped before its first check; -wrong-folder, the folder not reached.
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
f=$here/fixtures
: > "$work/PROGRAM.EXE"
run() { "$here/passfail.sh" "$build_a" "$@" "$work/PROGRAM.EXE"; }

t_play "$f/passfail"
t_case "ten checks that pass" 0 "pass=10 fail=0 exit=0" run synthetic:40:long on
t_play "$f/passfail-control"
t_case "counts and exit code, upper case only" 0 "pass=1 fail=2 exit=7" run synthetic:40:long on
t_play "$f/passfail-no-line"
t_case "no PASS or FAIL line" 3 "printed no PASS or FAIL line" run synthetic:40:long off
t_play "$f/passfail-wrong-folder"
t_case "the guest did not reach the folder" 3 "and not in D:\\DIR" run synthetic:40:long on
t_derive "$f/passfail"; : > "$derived/1/RC.TXT"; t_play "$derived"
t_case "no exit code recorded" 3 "recorded no exit code" run synthetic:40:long on
t_derive "$f/passfail"; printf 'x\r\n' > "$derived/1/RC.TXT"; t_play "$derived"
t_case "an exit code that is not a number" 3 "not a number" run synthetic:40:long on
t_play "$f/passfail"
STUB_RC=3 t_case "the launcher refuses the run" 3 "did not run to its end" run synthetic:40:long on
t_case "a program that is not an .EXE" 2 "8.3 name ending in .EXE" "$here/passfail.sh" "$build_a" synthetic:40:long on "$here/passfail.sh"
: > "$work/A.B.EXE"
t_case "a program name with two dots" 2 "needs an 8.3 name: A.B.EXE" "$here/passfail.sh" "$build_a" synthetic:40:long on "$work/A.B.EXE"
t_case "three arguments" 2 "usage:" "$here/passfail.sh" "$build_a" synthetic:40:long on
t_end
