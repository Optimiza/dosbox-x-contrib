#!/usr/bin/env bash
# realdos.sh's verdicts against captured runs, no emulator: bash realdos.test.sh
# fixtures/realdos holds what the three launches of a findlife run left: the staging's copy list
# (1), the line of the emulator's log that says the image booted (2) and the result file of the
# image's DOS (3). fixtures/realdos-drift, -dtadump, -patlist, -template, -findpos, -memprobe,
# -fc and -xcopy hold the same of a drift, a dtadump, a patlist, a template, a findpos-labelled,
# a memprobe, an fc and an xcopy run.
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
f=$here/fixtures
: > "$work/boot.img"
run() { "$here/realdos.sh" "$build_a" "$work/boot.img" "$@"; }

t_play "$f/realdos"
t_case "the report of the image's DOS" 0 "case|nested-same-dta|outer=42 of 42 inner=32 of 32 foreign=0|ok" run findlife
t_case "which DOS answered" 0 "realdos.sh: ver: Windows 98 [Version 4.10.2222]" run findlife
t_derive "$f/realdos"; sed -i '' 's/^70 file/69 file/' "$derived/1/STAGED.TXT"; t_play "$derived"
t_case "a folder that reached the disk short" 3 "70 files made, 69 copied" run findlife
t_derive "$f/realdos"; : > "$derived/2/dosbox.log"; t_play "$derived"
t_case "a log that does not say the image booted" 3 "shut its own DOS down" run findlife
t_derive "$f/realdos"; sed -i '' '$d' "$derived/3/RESULT.TXT"; t_play "$derived"
t_case "a batch that did not reach its end" 3 "did not reach the end of its batch" run findlife
t_derive "$f/realdos"; sed -i '' 's/drive_z=3/drive_z=0/' "$derived/3/RESULT.TXT"; t_play "$derived"
t_case "a DOS that has the emulator's Z: drive" 3 "the emulator's own DOS answered" run findlife
t_derive "$f/realdos"; sed -i '' 's/int21=030F:/int21=F000:/' "$derived/3/RESULT.TXT"; t_play "$derived"
t_case "a DOS that answers from the emulator's ROM" 3 "the emulator's own DOS answered" run findlife
t_derive "$f/realdos"; sed -i '' '/^end/d' "$derived/3/RESULT.TXT"; t_play "$derived"
t_case "an identification cut short" 3 "DOSID left no report" run findlife
t_derive "$f/realdos"; sed -i '' '/^end|cases/d' "$derived/3/RESULT.TXT"; t_play "$derived"
t_case "a report cut before its trailer" 3 "no case or no trailer" run findlife
t_derive "$f/realdos"; rm "$derived/3/RESULT.TXT"; t_play "$derived"
t_case "a DOS that left no result file" 3 "the result file could not be read" run findlife
t_play "$f/realdos-drift"
t_case "DRIFT's report of the image's DOS" 0 "drift|to-a-later-exact-name|first=0 more=1|,ZED.TXT:20:7" run drift
t_derive "$f/realdos-drift"; sed -i '' '/^end|lines/d' "$derived/3/RESULT.TXT"; t_play "$derived"
t_case "DRIFT's report cut before its trailer" 3 "DRIFT's report has no trailer" run drift
t_play "$f/realdos-dtadump"
t_case "DTADUMP's report of the image's DOS" 0 "list|fcb-rewritten-then-12h|11h 12h, the FCB rewritten, 12h 12h 12h|,BAR     TXT,FOO     TXT,-,-,-" run dtadump
t_case "DTADUMP's figures of it" 0 "realdos.sh: figures: template=8044d2aed1bc untouched=6/6 resumed=6/6 fcb=f9c92156e849" run dtadump
t_derive "$f/realdos-dtadump"; sed -i '' '/^list|fcb-/d' "$derived/3/RESULT.TXT"; t_play "$derived"
t_case "DTADUMP's report with lines missing" 3 "DTADUMP's report has no trailer or its count disagrees" run dtadump
t_play "$f/realdos-patlist"
t_case "PATLIST's report of the image's DOS" 0 "pat|*R.TXT|first=0 n=5|,BAR.TXT,FOO.TXT,MIXCASE.TXT,TWO~1.TXT,ZED.TXT" run patlist
t_derive "$f/realdos-patlist"; sed -i '' '/^end|lines/d' "$derived/3/RESULT.TXT"; t_play "$derived"
t_case "PATLIST's report cut before its trailer" 3 "PATLIST's report has no trailer" run patlist
t_play "$f/realdos-template"
t_case "TEMPLATE's report of the image's DOS" 0 'label|V:\DISK|first=18 |more=0|' run template
t_derive "$f/realdos-template"; sed -i '' 's/^ Volume in drive D is DISK1/ Volume in drive D has no label/' "$derived/1/STAGED.TXT"; t_play "$derived"
t_case "a disk the shell does not call DISK1" 3 "does not say the disk is labelled DISK1" run template
t_derive "$f/realdos-template"; sed -i '' '/^end|lines/d' "$derived/3/RESULT.TXT"; t_play "$derived"
t_case "TEMPLATE's report cut before its trailer" 3 "TEMPLATE's report has no trailer" run template
t_play "$f/realdos-findpos"
t_case "FINDPOS's report of the image's DOS, on the disk that DOS labelled" 0 "pos|label-alone|first=0 entry=FPLABEL:28:0 next=18 more=0|" run findpos-labelled
t_derive "$f/realdos-findpos"; sed -i '' 's/^pos|label-alone|first=0 entry=FPLABEL:28:0/pos|label-alone|first=18 entry=-/' "$derived/3/RESULT.TXT"; t_play "$derived"
t_case "a disk the image's DOS did not label" 3 "did not label the disk FPLABEL" run findpos-labelled
t_derive "$f/realdos-findpos"; sed -i '' '/^end|lines/d' "$derived/3/RESULT.TXT"; t_play "$derived"
t_case "FINDPOS's report cut before its trailer" 3 "FINDPOS's report has no trailer" run findpos-labelled
t_play "$f/realdos-memprobe"
t_case "a lookup for each file on the image's DOS" 0 "realdos.sh: names=83 files=1835 mode=e k=1835 ok=1835" run memprobe
t_derive "$f/realdos-memprobe"; sed -i '' 's/^mode=e k=1835 /mode=e k=1800 /' "$derived/3/RESULT.TXT"; t_play "$derived"
t_case "a MEMPROBE that made another count of calls" 3 "not MEMPROBE's line for 1835 calls in mode e: mode=e k=1800 ok=1835" run memprobe
t_play "$f/realdos-fc"
t_case "FC's runs on the image's DOS" 0 "realdos.sh: files=700 runs=300 compared=300" run fc
t_derive "$f/realdos-fc"; sed -i '' '$d' "$derived/1/STAGED.TXT"; t_play "$derived"
t_case "a folder copied by COPY that reached the disk short" 3 "703 files made, no count copied" run fc
t_derive "$f/realdos-fc"; awk '/^No differences/ && !cut { cut = 1; next } { print }' "$f/realdos-fc/3/RESULT.TXT" > "$derived/3/RESULT.TXT"; t_play "$derived"
t_case "a run of FC that did not compare" 3 "FC compared the two files 299 times of 300" run fc
t_play "$f/realdos-xcopy"
t_case "XCOPY's tree on the image's DOS, listed by that DOS" 0 "realdos.sh: made=2520 copied=2520 dirs_made=18 dirs_copied=18 said=2520" run xcopy
t_derive "$f/realdos-xcopy"; sed -i '' '$d' "$derived/1/STAGED.TXT"; t_play "$derived"
t_case "a tree staged a folder at a time, one folder short" 3 "2520 files made, 2320 copied" run xcopy
t_derive "$f/realdos-xcopy"; awk '/^D:\\COPY\\T5\\S1\\F0000199\.TXT/ && !cut { cut = 1; next } { print }' "$f/realdos-xcopy/3/RESULT.TXT" > "$derived/3/RESULT.TXT"; t_play "$derived"
t_case "a file that DOS does not list under the copy" 0 "copied=2519 dirs_made=18 dirs_copied=18 said=2520" run xcopy
t_derive "$f/realdos-xcopy"; sed -i '' '/^folders/d' "$derived/3/RESULT.TXT"; t_play "$derived"
t_case "a batch that did not list the folders" 3 "did not list what XCOPY left" run xcopy
t_play "$f/realdos"
STUB_RC=3 t_case "the launcher refuses the run" 3 "the disks could not be made" run findlife
t_case "a program it does not have" 2 "findpos, findpos-labelled, memprobe, fc or xcopy, not: shell" run shell
t_case "an image that is not there" 2 "not a disk image" "$here/realdos.sh" "$build_a" "$work/none.img" id
t_case "two arguments" 2 "usage:" "$here/realdos.sh" "$build_a" "$work/boot.img"
t_end
