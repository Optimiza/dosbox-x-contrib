#!/usr/bin/env bash
# overlay.sh's verdicts against captured runs, no emulator: bash overlay.test.sh
# fixtures/overlay holds FINDPOS's two reports, a host folder labelled FPLABEL and an overlay on
# it, long names on, of the build that gives the overlay drive the label and root rules: the three
# checks hold. fixtures/overlay-red holds the same of the build before it, whose overlay continues
# a search for the label alone and lists the root's dot entries.
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
f=$here/fixtures
run() { "$here/overlay.sh" "$build_a" "$@"; }

t_play "$f/overlay"
t_case "the overlay answers as the host folder" 0 "overlay.sh: label lines ALIKE" run labelled on
t_case "a FindNext after the label alone, as DOS" 0 "overlay.sh: overlay, FindNext after the label alone: 18, as DOS" run labelled on
t_case "no dot entry in the root, as DOS" 0 "overlay.sh: overlay, the root lists no dot entry, as DOS" run labelled on
t_case "the lines left to upstream's overlay, listed" 0 "overlay.sh: other lines that differ, not judged: 4" run labelled on
t_play "$f/overlay-red"
t_case "an overlay that answers otherwise" 1 "overlay.sh: label lines DIFFERENT" run labelled on
t_case "a FindNext after the label alone that goes on" 1 "overlay.sh: overlay, FindNext after the label alone: not 18" run labelled on
t_case "the root's dot entries" 1 "overlay.sh: overlay, the root lists a dot entry (DOS: none)" run labelled on
t_derive "$f/overlay"; sed -i '' -e '/^pos|label-alone|/d' -e 's/^end|lines=12/end|lines=11/' "$derived/2/FINDPOS.TXT"; t_play "$derived"
t_case "an overlay run with no label-alone line" 3 "the overlay run printed no label-alone line" run labelled on
t_derive "$f/overlay"; sed -i '' -e '/^pos|label-with-everything|/d' -e 's/^end|lines=12/end|lines=11/' "$derived/2/FINDPOS.TXT"; t_play "$derived"
t_case "an overlay run with no listing of the root" 3 "the overlay run printed no label-with-everything line" run labelled on
t_derive "$f/overlay"; sed -i '' -e '/^pos|label-/d' -e 's/^end|lines=12/end|lines=7/' "$derived/1/FINDPOS.TXT"; t_play "$derived"
t_case "a host-folder run with no label line" 3 "run A printed no label line" run labelled on
t_play "$f/overlay"
STUB_RC=3 t_case "the launcher refuses the run" 3 "overlay.sh: INVALID: findpos.sh exit 3" run labelled on
t_case "a build that is not there" 2 "not an executable" "$here/overlay.sh" "$work/none" labelled on
t_case "neither labelled nor unlabelled" 2 "labelled or unlabelled, not: both" run both on
t_case "neither on nor off" 2 "on or off, not: maybe" run labelled maybe
t_case "two arguments" 2 "usage:" run labelled
t_case "its own help" 0 "usage: overlay.sh" "$here/overlay.sh" --help
t_end
