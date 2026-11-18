#!/usr/bin/env bash
# sidefx.sh's verdicts against one captured run, no emulator: bash sidefx.test.sh
# fixtures/sidefx holds the rescan mode's report and the shell's lines of unpatched upstream and
# of a build that keeps the cache across an attribute change, on macOS, which read alike. The
# line that differs is written by the test: the one unpatched upstream prints on Windows, where
# the attribute change empties the cache and the host's new file shows.
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
f=$here/fixtures
run() { "$here/sidefx.sh" "$1" "$build_a" "$build_b"; }
cr=$'\r'

t_play "$f/sidefx"
t_case "two reports alike" 0 "sidefx.sh: ALIKE" run rescan
t_case "the host's file listed once the folder is rescanned" 0 "dir-after-rescan|NEW.TXT" run rescan
t_case "the shell's lines before the rescan" 0 "dir-before-rescan|F0009.TXT" run rescan
t_derive "$f/sidefx"; sed -i '' "s/^sidefx|after-setattr|listed=10 new=0 /sidefx|after-setattr|listed=11 new=1 /" "$derived/1/FX.TXT"; t_play "$derived"
t_case "a build whose attribute change shows the host's file" 1 "< sidefx|after-setattr|listed=11 new=1 label_rc=18 label=" run rescan
t_derive "$f/sidefx"; sed -i '' "s/^sidefx|released=1/sidefx|released=0/" "$derived/2/FX.TXT"; t_play "$derived"
t_case "a guest that went on without the host's file" 3 "build B: SIDEFX went on without the host's file" run rescan
t_derive "$f/sidefx"; sed -i '' '/^sidefx|end/d' "$derived/1/FX.TXT"; t_play "$derived"
t_case "a report with no end" 3 "build A's report has no end" run rescan
t_derive "$f/sidefx"; sed -i '' "/^RESCAN$cr\$/d" "$derived/2/SHELL.TXT"; t_play "$derived"
t_case "a shell that never reached the rescan" 3 "build B's shell left no line" run rescan
t_derive "$f/sidefx"; rm "$derived/1/HOLD"; t_play "$derived"
t_case "a guest that never waits for the host" 3 "build A: SIDEFX never waited for the host" run rescan
t_play "$f/sidefx"
STUB_RC=3 t_case "the launcher refuses the run" 3 "did not run to its end" run rescan
t_case "label off Windows" 2 "label runs on Windows only" run label
t_case "no such mode" 2 "the mode is rescan or label, not: both" run both
t_case "two arguments" 2 "usage:" "$here/sidefx.sh" rescan "$build_a"
t_case "its own help" 0 "usage: sidefx.sh" "$here/sidefx.sh" --help
t_end
