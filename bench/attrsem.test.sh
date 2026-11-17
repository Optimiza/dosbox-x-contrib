#!/usr/bin/env bash
# attrsem.sh's verdicts against one captured run, no emulator: bash attrsem.test.sh
# fixtures/attrsem holds ATTRSEM's report and the shell's lines of two builds on macOS, long
# names off, which read alike. Every build has read alike on both hosts, with the attribute
# change emptying the directory cache and without: the lines that differ here are written by the
# test, the ones a build would print if it returned a hidden file or lost an attribute.
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
f=$here/fixtures
run() { "$here/attrsem.sh" "$build_a" "$build_b" "$@"; }
cr=$'\r'

t_play "$f/attrsem"
t_case "two reports alike" 0 "attrsem.sh: ALIKE" run off
t_case "a file hidden mid-search is not returned" 0 "sem|hidden-mid-search|set=0 n=9 returned=0" run off
t_case "the shell's lines follow the program's" 0 "shell|  A   H " run off
t_derive "$f/attrsem"; sed -i '' "s/^sem|hidden-mid-search|.*/sem|hidden-mid-search|set=0 n=10 returned=1$cr/" "$derived/1/SEM.TXT"; t_play "$derived"
t_case "a build that returns a file hidden mid-search" 1 "< sem|hidden-mid-search|set=0 n=10 returned=1" run off
t_case "the lines that differ, counted" 1 "attrsem.sh: DIFFERENT, 1 lines differ" run off
t_derive "$f/attrsem"; sed -i '' "s/^  A   H \(.*F0001\.TXT\)/  A     \1/" "$derived/2/SHELL.TXT"; t_play "$derived"
t_case "a shell whose ATTRIB lost the hidden bit" 1 "> shell|  A     " run off
t_derive "$f/attrsem"; sed -i '' '$d' "$derived/2/SEM.TXT"; t_play "$derived"
t_case "a report cut before its trailer" 3 "build B's report has no line or no trailer" run off
t_derive "$f/attrsem"; sed -i '' '/^sem|read-only|/d' "$derived/1/SEM.TXT"; t_play "$derived"
t_case "a line fewer than the trailer says" 3 "build A's report has no line or no trailer" run off
t_derive "$f/attrsem"; rm "$derived/2/SHELL.TXT"; t_play "$derived"
t_case "a shell that left nothing" 3 "build B's shell left nothing" run off
t_play "$f/attrsem"
STUB_RC=3 t_case "the launcher refuses the run" 3 "did not run to its end" run off
t_case "neither on nor off" 2 "on or off" run maybe
t_case "two arguments" 2 "usage:" "$here/attrsem.sh" "$build_a" "$build_b"
t_case "its own help" 0 "usage: attrsem.sh" "$here/attrsem.sh" --help
t_end
