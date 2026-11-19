#!/usr/bin/env bash
# longpath.sh's verdicts against captured runs, no emulator: bash longpath.test.sh
# fixtures/longpath-red holds the six runs of a build that overruns its arrays (a control and a
# case for each of mount, nested and zip: the cases end the emulator, exit 139, 134 and 134);
# fixtures/longpath holds the same six on a build that answers "path not found" or refuses the mount.
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
f=$here/fixtures
run() { "$here/longpath.sh" "$@"; }

t_play "$f/longpath"
t_case "a build that survives the three cases" 0 "longpath.sh: SURVIVED" run on "$build_a"
t_case "its line" 0 "mount=survived nested=survived zip=survived overlay=survived controls=ok" run on "$build_a"
t_case "long names off" 0 "lfn=off mount=survived" run off "$build_a"
t_play "$f/longpath-red"
t_case "a build whose stack is overrun" 1 "longpath.sh: CRASHED" run on "$build_a"
t_case "the exit codes of the three cases" 1 "mount=crashed:139 nested=crashed:134 zip=crashed:134 overlay=crashed:134 controls=ok" run on "$build_a"
t_derive "$f/longpath-red"; printf 0 > "$derived/4/EXIT"; printf 'start\r\nend\r\n' > "$derived/4/OUT.TXT"; t_play "$derived"
t_case "one case ended and the others did not" 1 "mount=crashed:139 nested=survived zip=crashed:134" run on "$build_a"
t_derive "$f/longpath"; printf 3 > "$derived/6/EXIT"; t_play "$derived"
t_case "a run that reached its last line and exited non-zero" 1 "zip=crashed:3" run on "$build_a"
t_derive "$f/longpath"; printf 'start\r\n' > "$derived/3/OUT.TXT"; t_play "$derived"
t_case "a control that listed nothing" 3 "the nested control did not list its file" run on "$build_a"
t_derive "$f/longpath"; printf 'start\r\n' > "$derived/1/OUT.TXT"; t_play "$derived"
t_case "the mount control too" 3 "the mount control did not list its file" run on "$build_a"
t_derive "$f/longpath"; printf 'start\r\n' > "$derived/5/OUT.TXT"; t_play "$derived"
t_case "the zip control too" 3 "the zip control did not list its file" run on "$build_a"
t_derive "$f/longpath"; printf 'start\r\n' > "$derived/7/OUT.TXT"; t_play "$derived"
t_case "the overlay control too" 3 "the overlay control did not list its file" run on "$build_a"
t_derive "$f/longpath"; printf 'start\r\nend\r\n' > "$derived/8/OUT.TXT"; t_play "$derived"
t_case "an overlay that lists nothing" 1 "overlay=wrong:unlisted" run on "$build_a"
t_derive "$f/longpath"; printf 'start\r\nend\r\n' > "$derived/9/OUT.TXT"; t_play "$derived"
t_case "an overlay whose RD does not fail" 1 "overlay=wrong:rd-succeeded" run on "$build_a"
t_derive "$f/longpath"; printf 'no first line\r\n' > "$derived/2/OUT.TXT"; t_play "$derived"
t_case "a run that left no first line" 3 "1-mount left no first line" run on "$build_a"
t_play "$f/longpath"
STUB_VERSION="" t_case "a launcher that names no build" 3 "did not start" run on "$build_a"
t_derive "$f/longpath"; for i in 1 2 3 4 5 6 7 8 9; do cp -R "$derived/$i" "$derived/$((i + 9))"; done; t_play "$derived"
t_case "two builds, each judged" 0 "longpath.sh: SURVIVED" run on "$build_a" "$build_b"
t_case "neither on nor off" 2 "on or off" run maybe "$build_a"
t_case "an option it does not know" 2 "unknown option: --raw" run on --raw "$build_a"
t_case "no build" 2 "usage:" run on
t_case "a path too short to overrun" 2 "at least 250" env DIRCACHE_LONGPATH_BYTES=100 "$here/longpath.sh" on "$build_a"
t_case "a path that is not a number" 2 "a number of bytes" env DIRCACHE_LONGPATH_BYTES=long "$here/longpath.sh" on "$build_a"
t_case "a zips folder with no zips" 2 "holds no long.zip and short.zip" env DIRCACHE_LONGPATH_ZIPS="$work" "$here/longpath.sh" on "$build_a"
mkdir "$work/zips" && : > "$work/zips/long.zip" && : > "$work/zips/short.zip" || exit 3
t_play "$f/longpath"
t_case "zips made elsewhere" 0 "longpath.sh: SURVIVED" env DIRCACHE_LONGPATH_ZIPS="$work/zips" "$here/longpath.sh" on "$build_a"
t_case "its own help" 0 "usage: longpath.sh" run --help
t_end
