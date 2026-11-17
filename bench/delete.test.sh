#!/usr/bin/env bash
# delete.sh's verdicts against one captured run, no emulator: bash delete.test.sh
# fixtures/delete holds DELPRB's report of unpatched upstream (1) and of the build where a delete,
# an RD, an MD or a rename removes or adds one entry and a create keeps the cache (2), long names
# on. Upstream's shell DEL over eight long names of one prefix leaves four, and its short names
# move after a delete, a long-name create, an RD, an MD and a rename; the other build deletes all
# eight and its short names stay.
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
f=$here/fixtures
run() { "$here/delete.sh" "$build_a" "$build_b" "$@"; }

t_play "$f/delete"
t_case "a build that leaves half the files against one that leaves none" 1 "delete.sh: DIFFERENT" run on
t_case "each report printed whole" 1 "del|shell|listed_after=4" run on
t_case "the other build's line" 1 "> del|shell|listed_after=0" run on
t_case "upstream's short names move after one delete" 1 "build A: short names moved by one delete: 7 of 8" run on
t_case "the other build's stay" 1 "build B: short names moved by one delete: 0 of 8" run on
t_case "upstream's long-name create moves a short name a search returned" 1 "build A: short names a search returned that open another file after the creates: 1 of 8" run on
t_case "the other build's search keeps its short names" 1 "build B: short names a search returned that open another file after the creates: 0 of 8" run on
t_case "upstream's RD moves the other directories' short names" 1 "build A: short names of directories moved by one RD: 7 of 7" run on
t_case "the other build's directories keep theirs" 1 "build B: short names of directories moved by one RD: 0 of 7" run on
t_case "upstream lists the two new files, one earlier short name now opening another" 1 "build A: C after the creates: listed=10 before=8 created=2 listed twice=0 earlier short names opening another file=1" run on
t_case "the other build lists them with every earlier short name kept" 1 "build B: C after the creates: listed=10 before=8 created=2 listed twice=0 earlier short names opening another file=0" run on
t_case "the other build lists the seven directories left" 1 "build B: R after the RD: listed=7 before=8" run on
t_case "upstream's rename moves the other files' short names" 1 "build A: A after one rename: listed=9 before=9 renamed=1 listed twice=0 earlier short names opening another file=6 RENAMED.TXT opens the renamed file=yes" run on
t_case "the other build's rename keeps them" 1 "build B: A after one rename: listed=9 before=9 renamed=1 listed twice=0 earlier short names opening another file=0 RENAMED.TXT opens the renamed file=yes" run on
t_case "a case-only rename moves no short name" 1 "build B: A after a case-only rename: short names that moved: 0 of 9" run on
t_case "the renamed file's old long name made again takes a free short name" 1 "build B: A after the old long name of the renamed file is made again: earlier short names opening another file=0 its short name=ALPHAT~9.MID the old short name of the renamed file=ALPHAT~2.MID" run on
t_case "upstream's MD moves the other directories' short names" 1 "build A: R after the MD: listed=9 before=7 made=2 listed twice=0 earlier short names reaching another directory=7" run on
t_case "the other build's MD keeps them" 1 "build B: R after the MD: listed=9 before=7 made=2 listed twice=0 earlier short names reaching another directory=0" run on
t_case "removing the new directory again moves none" 1 "build B: R after NEWDIR is removed again: listed=8 before=9 earlier short names reaching another directory=0" run on
t_case "each directory's search lists its own entries" 1 "build B: R directories whose search lists other entries than their own: after the MD=0 after the rename=0" run on
t_case "upstream's directory rename moves the others" 1 "build A: R after one rename: listed=8 before=8 renamed=1 listed twice=0 earlier short names reaching another directory=6 RENAMED reaches the renamed directory=yes" run on
t_case "the other build's directory rename keeps them" 1 "build B: R after one rename: listed=8 before=8 renamed=1 listed twice=0 earlier short names reaching another directory=0 RENAMED reaches the renamed directory=yes" run on
t_case "the renamed directory's old long name made again takes a free short name" 1 "build B: R after the old long name of the renamed directory is made again: earlier short names reaching another directory=0 its short name=ALPHA~10 the old short name of the renamed directory=ALPHAT~2" run on
t_derive "$f/delete"; cp "$derived/1/DELPRB.TXT" "$derived/2/DELPRB.TXT"; t_play "$derived"
t_case "two reports alike" 0 "delete.sh: ALIKE" run on
t_derive "$f/delete"; sed -i '' '$d' "$derived/2/DELPRB.TXT"; t_play "$derived"
t_case "a report cut before its trailer" 3 "build B's report has no line or no trailer" run on
t_derive "$f/delete"; sed -i '' '/^alias|before|PLAIN.TXT=/d' "$derived/1/DELPRB.TXT"; t_play "$derived"
t_case "a line fewer than the trailer says" 3 "build A's report has no line or no trailer" run on
t_derive "$f/delete"; : > "$derived/1/DELPRB.TXT"; t_play "$derived"
t_case "a folder that did not list its files: no line, no trailer" 3 "build A's report has no line or no trailer" run on
t_play "$f/delete"
STUB_RC=3 t_case "the launcher refuses the run" 3 "did not run to its end" run on
# An awk that cannot run the counts' program: the counts are not read, and nothing is judged.
mkdir "$work/awkfail" || exit 3
printf '#!/bin/bash\ncase "$*" in *"short names moved by one delete"*) echo "awk: syntax error" >&2; exit 2 ;; esac\nexec %s "$@"\n' "$(command -v awk)" > "$work/awkfail/awk" && chmod +x "$work/awkfail/awk" || exit 3
PATH="$work/awkfail:$PATH" t_case "the counts' program fails" 3 "build A's counts could not be read" run on
t_case "neither on nor off" 2 "on or off" run maybe
t_case "two arguments" 2 "usage:" "$here/delete.sh" "$build_a" "$build_b"
t_case "its own help" 0 "usage: delete.sh" "$here/delete.sh" --help
t_end
