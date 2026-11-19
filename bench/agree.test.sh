#!/usr/bin/env bash
# agree.py's counts against captured reports, no emulator: bash agree.test.sh
# fixtures/agree holds what realdos.sh printed for dosans-cd on MS-DOS 7.10 (MSCDEX 2.25) and on
# MS-DOS 6.22 (MSCDEX 2.23), each line named by its DOS; fixtures/dosans-cd holds DOSANS's report over
# the same CD image of an unpatched build (1) and of one that answers a CD as MSCDEX does (2).
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
f=$here/fixtures
agree() { python3 -I "$here/agree.py" "$@"; }
a=$f/agree/msdos710.txt b=$f/agree/msdos622.txt base=$f/dosans-cd/1/DOSANS.TXT patched=$f/dosans-cd/2/DOSANS.TXT

t_case "the lines both DOS answer alike" 0 "lines both DOS answer alike: 703 of 709" agree "$a" "$b" "$base" "$patched"
t_case "what the unpatched build equals" 0 "DOSANS.TXT: equal to both DOS on 404 of 703" agree "$a" "$b" "$base" "$patched"
t_case "what the patched build equals" 0 "DOSANS.TXT: equal to both DOS on 494 of 703" agree "$a" "$b" "$base" "$patched"
t_case "the lines it changes all become DOS's" 0 "changes against the first: 90, now equal to both DOS: 90, were right and are now wrong: 0" agree "$a" "$b" "$base" "$patched"
t_case "the builds in the other order spoil them" 0 "changes against the first: 90, now equal to both DOS: 0, were right and are now wrong: 90" agree "$a" "$b" "$patched" "$base"
t_case "one build alone has no last line" 0 "equal to both DOS on 494 of 703" agree "$a" "$b" "$patched"
: > "$work/empty.txt"
t_case "two DOS that answer nothing alike" 3 "the two DOS answered no line alike" agree "$a" "$work/empty.txt" "$patched"
t_case "no build report" 2 "usage:" agree "$a" "$b"
d=$f/agree/dosans-cd-differ.txt
t_case "the lines a comparing script printed, A's" 0 "lines of build A that differ: 90, equal to both DOS: 0" agree --differ "$a" "$b" "$d"
t_case "the lines a comparing script printed, B's" 0 "lines of build B that differ: 90, equal to both DOS: 90" agree --differ "$a" "$b" "$d"
t_derive "$f/agree"; sed 's/^</-/; s/^>/</; s/^-/>/' "$d" > "$derived/swapped.txt"
t_case "the same lines with the builds the other way" 0 "lines of build A that differ: 90, equal to both DOS: 90" agree --differ "$a" "$b" "$derived/swapped.txt"
t_case "an output with no line that differs" 3 "the output holds no line that differs" agree --differ "$a" "$b" "$work/empty.txt"
r1=$f/agree/run-base-folder.txt r2=$f/agree/run-folder-cd.txt
t_case "main-ai in the output of dosans.sh cd, the part of build A" 0 "run-base-folder.txt#A: equal to both DOS on 404 of 703" agree "$a" "$b" "$r1#A" "$r1#B" "$r2#B"
t_case "the folder half, the part of build B" 0 "run-base-folder.txt#B: equal to both DOS on 428 of 703" agree "$a" "$b" "$r1#A" "$r1#B" "$r2#B"
t_case "the CD half, the part of build B of the next run" 0 "run-folder-cd.txt#B: equal to both DOS on 494 of 703" agree "$a" "$b" "$r1#A" "$r1#B" "$r2#B"
t_case "what the CD half changes over the folder half" 0 "changes against the first: 66, now equal to both DOS: 66, were right and are now wrong: 0" agree "$a" "$b" "$r1#B" "$r2#B"
t_end
