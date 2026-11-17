#!/usr/bin/env bash
# run.sh's verdicts against captured dumps, no emulator: bash run.test.sh
# fixtures/listing holds one folder dumped by a build (1) and by a stand-in that put one more
# file in it (2); listing-off the same folder with long names off; listing-empty an empty one;
# listing-dots the folder of style dots dumped by unpatched upstream, which the build that reads
# a folder in one pass dumped byte for byte the same.
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
f=$here/fixtures
run() { "$here/run.sh" "$build_a" "$build_b" "$@"; }

t_play "$f/listing"
t_case "two different dumps" 1 "run.sh: DIFFERENT" run synthetic:10:long on
t_case "each build named" 1 "run.sh: build B: $build_b (DOSBox-X version 0.0 stub)" run synthetic:10:long on
t_derive "$f/listing"; cp "$derived/1/LIST.TXT" "$derived/2/LIST.TXT"; t_play "$derived"
t_case "the same dump twice" 0 "run.sh: IDENTICAL" run synthetic:10:long on
t_derive "$f/listing"; LC_ALL=C sed -i '' "s/Bravo track/Brav$(printf '\351') track/" "$derived/1/LIST.TXT"; cp "$derived/1/LIST.TXT" "$derived/2/LIST.TXT"; t_play "$derived"
t_case "names with bytes above 7Fh" 0 "run.sh: IDENTICAL" run synthetic:10:long on
t_derive "$f/listing"; sed -i '' '$d' "$derived/1/LIST.TXT"; t_play "$derived"
t_case "a dump cut before its trailer" 3 "no trailer" run synthetic:10:long on
t_derive "$f/listing"; sed -i '' '/^4e|3|/d' "$derived/1/LIST.TXT"; t_play "$derived"
t_case "an entry fewer than the trailer says" 3 "the trailer says" run synthetic:10:long on
t_derive "$f/listing"; sed -i '' '/^look|lfn|case|/d' "$derived/1/LIST.TXT"; t_play "$derived"
t_case "a lookup fewer than the trailer says" 3 "the trailer says" run synthetic:10:long on
t_play "$f/listing-off"
t_case "no long-name entry with long names on" 3 "zero entries through 714Eh" run synthetic:10:long on
t_case "the same dump with long names off" 0 "run.sh: IDENTICAL" run synthetic:10:long off
t_play "$f/listing"
t_case "long-name entries with long names off" 3 "714Eh listed entries" run synthetic:10:long off
t_play "$f/listing-empty"
t_case "an empty folder" 3 "the folder is empty" run synthetic:10:long on
t_play "$f/listing"
STUB_RC=3 t_case "the launcher refuses the run" 3 "did not run to its end" run synthetic:10:long on
STUB_VERSION="" t_case "a report that names no build" 3 "did not run to its end" run synthetic:10:long on
t_derive "$f/listing-dots"; mkdir "$derived/2" && cp "$derived/1/"* "$derived/2/" || exit 3; t_play "$derived"
t_case "a folder that puts the list of aliases out of order, every name made" 0 "run.sh: folder synthetic:432:dots (432 entries on the host)" run synthetic:432:dots on
t_case "and listed alike" 0 "run.sh: IDENTICAL" run synthetic:432:dots on
t_case "a count past the shell's arithmetic" 2 "bad count" run synthetic:99999999999999999999:83 on
t_case "a style it does not know" 2 "style is 83, long, dots, mix or wine" run synthetic:10:wide on
t_case "a dots folder that is not twelve names a character" 2 "twelve names a character" run synthetic:430:dots on
t_case "a dots folder past its characters" 2 "twelve names a character, 432 at most" run synthetic:444:dots on
t_case "a mix folder no larger than its short stems" 2 "more than 240" run synthetic:240:mix on
t_case "a wine folder of an odd count" 2 "pairs of names" run synthetic:121:wine on
mkdir "$work/LongFolderName"
t_case "a folder the guest cannot name with long names off" 2 "not 8.3" run "$work/LongFolderName" off
t_case "neither on nor off" 2 "on or off" run synthetic:10:long maybe
t_case "three arguments" 2 "usage:" "$here/run.sh" "$build_a" "$build_b" synthetic:10:long
t_case "a build that is not there" 2 "not an executable" "$here/run.sh" "$work/none" "$build_b" synthetic:10:long on
DIRCACHE_LAUNCHER=$work/absent t_case "no launcher" 2 "the launcher is not an executable" run synthetic:10:long on
t_end
