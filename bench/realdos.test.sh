#!/usr/bin/env bash
# realdos.sh's verdicts against captured runs, no emulator: bash realdos.test.sh
# fixtures/realdos holds what the three launches of a findlife run left: the staging's copy list
# (1), the line of the emulator's log that says the image booted (2) and the result file of the
# image's DOS (3). fixtures/realdos-drift, -dtadump, -patlist, -template, -findpos, -memprobe,
# -fc, -xcopy and -dirgone hold the same of a drift, a dtadump, a patlist, a template, a
# findpos-labelled, a memprobe, an fc, an xcopy and a dirgone run, and -junktest and -dirtest of a
# run of each reporter's files: all of them on MS-DOS 7.10. fixtures/realdos-msdos622 and
# realdos-freedos hold a dirgone run on MS-DOS 6.22 and on FreeDOS, realdos-freedos-findpos a
# findpos-labelled run on FreeDOS. fixtures/realdos-dosans holds a dosans run on MS-DOS 7.10,
# realdos-dosans-labelled a dosans-labelled run on MS-DOS 6.22, realdos-xcomsim an xcomsim run on
# MS-DOS 7.10.
# Those files are not in this repository: the folders handed to the script hold empty files under
# their names, as many as the reporters'.
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
f=$here/fixtures
: > "$work/boot.img"
: > "$work/boot.vhd"
run() { "$here/realdos.sh" "$build_a" msdos710 "$work/boot.img" "$@"; }
run_on() { "$here/realdos.sh" "$build_a" "$@"; }

t_play "$f/realdos"
t_case "the report of the image's DOS, each line named by it" 0 "msdos710|case|nested-same-dta|outer=42 of 42 inner=32 of 32 foreign=0|ok" run findlife
t_case "which DOS answered" 0 "realdos.sh: msdos710: ver: Windows 98 [Version 4.10.2222]" run findlife
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
t_case "DTADUMP's figures of it" 0 "realdos.sh: msdos710: figures: template=8044d2aed1bc untouched=6/6 resumed=6/6 fcb=f9c92156e849" run dtadump
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
t_case "a lookup for each file on the image's DOS" 0 "realdos.sh: msdos710: names=83 files=1835 mode=e k=1835 ok=1835" run memprobe
t_derive "$f/realdos-memprobe"; sed -i '' 's/^mode=e k=1835 /mode=e k=1800 /' "$derived/3/RESULT.TXT"; t_play "$derived"
t_case "a MEMPROBE that made another count of calls" 3 "not MEMPROBE's line for 1835 calls in mode e: mode=e k=1800 ok=1835" run memprobe
t_play "$f/realdos-fc"
t_case "FC's runs on the image's DOS" 0 "realdos.sh: msdos710: files=700 runs=300 compared=300" run fc
t_derive "$f/realdos-fc"; sed -i '' '$d' "$derived/1/STAGED.TXT"; t_play "$derived"
t_case "a folder copied by COPY that reached the disk short" 3 "703 files made, no count copied" run fc
t_derive "$f/realdos-fc"; awk '/^No differences/ && !cut { cut = 1; next } { print }' "$f/realdos-fc/3/RESULT.TXT" > "$derived/3/RESULT.TXT"; t_play "$derived"
t_case "a run of FC that did not compare" 3 "FC compared the two files 299 times of 300" run fc
t_play "$f/realdos-xcopy"
t_case "XCOPY's tree on the image's DOS, listed by that DOS" 0 "realdos.sh: msdos710: made=2520 copied=2520 dirs_made=18 dirs_copied=18 said=2520" run xcopy
t_derive "$f/realdos-xcopy"; sed -i '' '$d' "$derived/1/STAGED.TXT"; t_play "$derived"
t_case "a tree staged a folder at a time, one folder short" 3 "2520 files made, 2320 copied" run xcopy
t_derive "$f/realdos-xcopy"; awk '/^D:\\COPY\\T5\\S1\\F0000199\.TXT/ && !cut { cut = 1; next } { print }' "$f/realdos-xcopy/3/RESULT.TXT" > "$derived/3/RESULT.TXT"; t_play "$derived"
t_case "a file that DOS does not list under the copy" 0 "copied=2519 dirs_made=18 dirs_copied=18 said=2520" run xcopy
t_derive "$f/realdos-xcopy"; sed -i '' '/^folders/d' "$derived/3/RESULT.TXT"; t_play "$derived"
t_case "a batch that did not list the folders" 3 "did not list what XCOPY left" run xcopy
t_play "$f/realdos-dirgone"
t_case "DIRGONE's report of MS-DOS 7.10" 0 "msdos710|gone|ren|first=0000 entry=. op=0000 made=- next=0012 rest=..,ID.TXT,TWO.TXT" run dirgone
t_case "MS-DOS 7.10 reads on in a directory whose parent was renamed" 0 "msdos710|gone|ren-parent|first=0000 entry=. op=0000 made=- next=0012 rest=..,ID.TXT" run dirgone
t_derive "$f/realdos-dirgone"; sed -i '' '/^gone|rd|/d' "$derived/3/RESULT.TXT"; t_play "$derived"
t_case "DIRGONE's report with a case missing" 3 "DIRGONE's report has no trailer or its count disagrees" run dirgone
t_play "$f/realdos-dosans"
t_case "DOSANS's report of MS-DOS 7.10" 0 "msdos710|call|3D|D:\\NOSUCH\\CON|err=3" run dosans
t_derive "$f/realdos-dosans"; sed -i '' '/^call|3B|D:\\X\\|/d' "$derived/3/RESULT.TXT"; t_play "$derived"
t_case "DOSANS's report with a line missing" 3 "DOSANS's report has no trailer or its count disagrees" run dosans
t_play "$f/realdos-xcomsim"
t_case "XCOMSIM's report of the image's DOS" 0 "msdos710|lookups|made=2118 as_the_game=2118 differ=0 loads=18.41" run xcomsim
t_case "XCOMSIM's verdict on the image's DOS" 0 "realdos.sh: msdos710: listing=40/40 40/40 lost=0" run xcomsim
t_derive "$f/realdos-xcomsim"; sed -i '' -e '/^listing=/d' -e 's/^end|lines=6/end|lines=5/' "$derived/3/RESULT.TXT"; t_play "$derived"
t_case "XCOMSIM's report with no verdict line" 3 "XCOMSIM's report has no verdict line" run xcomsim
t_derive "$f/realdos-xcomsim"; sed -i '' '/^listing|A|/d' "$derived/3/RESULT.TXT"; t_play "$derived"
t_case "XCOMSIM's report with a line missing" 3 "XCOMSIM's report has no trailer or its count disagrees" run xcomsim
t_play "$f/realdos-dosans-labelled"
t_case "DOSANS on the disk MS-DOS 6.22 labelled" 0 "msdos622|ans|root|3F|D:\\*|D:\\|err=0|n=2|,X:10:0,FPLABEL:28:0" run_on msdos622 "$work/boot.vhd" dosans-labelled
t_play "$f/realdos-msdos622"
t_case "the same program on MS-DOS 6.22, named by it" 0 "msdos622|gone|rd|first=0000 entry=. op=0000 made=- next=0012 rest=.." run_on msdos622 "$work/boot.vhd" dirgone
t_case "MS-DOS 6.22's own VER line" 0 "realdos.sh: msdos622: ver: MS-DOS Version 6.22" run_on msdos622 "$work/boot.vhd" dirgone
t_case "MS-DOS 6.22 in a removed directory whose parent was removed" 0 "msdos622|gone|rd-parent-rd|first=0000 entry=. op=0000 made=0000 next=0012 rest=.." run_on msdos622 "$work/boot.vhd" dirgone
t_play "$f/realdos-freedos"
t_case "the same program on FreeDOS, named by it" 0 "freedos|gone|ren-remade|first=0000 entry=. op=0000 made=0000 next=0012 rest=..,ID.TXT,TWO.TXT" run_on freedos "$work/boot.img" dirgone
t_case "FreeDOS's identification" 0 "realdos.sh: freedos: dos|version=7.10 oem=FD" run_on freedos "$work/boot.img" dirgone
t_play "$f/realdos-freedos-findpos"
t_case "FINDPOS on the disk FreeDOS's own LABEL named" 0 "freedos|pos|label-alone|first=0 entry=FPLABEL:28:0 next=18 more=0|" run_on freedos "$work/boot.img" findpos-labelled
t_derive "$f/realdos-freedos-findpos"; sed -i '' 's/^pos|label-alone|first=0 entry=FPLABEL:28:0/pos|label-alone|first=18 entry=-/' "$derived/3/RESULT.TXT"; t_play "$derived"
t_case "a FreeDOS that did not label the disk" 3 "realdos.sh: freedos: INVALID: the image's DOS did not label the disk FPLABEL" run_on freedos "$work/boot.img" findpos-labelled
junk=$work/junktest
mkdir "$junk" || exit 3
for name in 300.BAT JUNK.BAT DJUNK.BAT e001.exp RESULT.TXT; do : > "$junk/$name"; done
t_play "$f/realdos-junktest"
t_case "the reporter's run on the image's DOS" 0 "realdos.sh: msdos710: batches=300,JUNK,300 entries=705 junk=700 counted=600 done=3" run junktest "$junk"
t_derive "$f/realdos-junktest"; LC_ALL=C awk '/^Count: 300 of 300/ && !cut { cut = 1; next } { print }' "$f/realdos-junktest/3/RESULT.TXT" > "$derived/3/RESULT.TXT"; t_play "$derived"
t_case "a 300.BAT that did not reach its end there" 3 "did not reach their end: counted=599 done=3" run junktest "$junk"
t_derive "$f/realdos-junktest"; LC_ALL=C sed -i '' '/^Comparing /d' "$derived/3/RESULT.TXT"; t_play "$derived"
t_case "an FC that did not compare the reporter's files there" 3 "FC did not compare the reporter's two files" run junktest "$junk"
t_case "no folder of the reporter's files" 3 "INVALID: no folder of the reporter's files" run junktest "$work/none"
t_case "a reporter's program with no folder" 2 "junktest takes the folder of the reporter's files" run junktest
t_case "a folder beside a program of this folder" 2 "findlife takes no folder" run findlife "$junk"
dirtest=$work/DIRTEST
mkdir -p "$dirtest/DATA" || exit 3
for name in DIRTEST.EXE DIRTEST.FXP DIRTEST.PJT DIRTEST.PJX DIRTEST.PRG; do : > "$dirtest/$name"; done
i=0
while [ "$i" -lt 1835 ]; do printf -v name 'F%04d.FRX' "$i"; : > "$dirtest/DATA/$name"; i=$((i + 1)); done
t_play "$f/realdos-dirtest"
t_case "the reporter's program on the image's DOS, and that DOS's listing of its folder" 0 "realdos.sh: msdos710: files=1835 returned=1" run dirtest "$dirtest"
t_derive "$f/realdos-dirtest"; LC_ALL=C awk '/^F0000\.FRX/ && !cut { cut = 1; next } { print }' "$f/realdos-dirtest/3/RESULT.TXT" > "$derived/3/RESULT.TXT"; t_play "$derived"
t_case "a folder that DOS lists a file short" 3 "that DOS lists 1834 files in D:\\DATA, of 1835 staged" run dirtest "$dirtest"
t_derive "$f/realdos-dirtest"; echo 139 > "$derived/2/EXIT"; t_play "$derived"
t_case "the emulator's AUTOTYPE crash after the batch's end" 0 "realdos.sh: msdos710: the emulator exited 139 with AUTOTYPE's keys still pending, after the DOS's batch reached its end" run dirtest "$dirtest"
t_derive "$f/realdos-dirtest"; echo 139 > "$derived/2/EXIT"; sed -i '' '$d' "$derived/3/RESULT.TXT"; t_play "$derived"
t_case "that crash before the batch's end" 3 "did not reach the end of its batch" run dirtest "$dirtest"
t_derive "$f/realdos-dirtest"; echo 134 > "$derived/2/EXIT"; t_play "$derived"
t_case "another exit of the emulator" 3 "the image did not boot, or its DOS wrote nothing" run dirtest "$dirtest"
t_derive "$f/realdos"; echo 139 > "$derived/2/EXIT"; t_play "$derived"
t_case "that exit in a run with no keys to type" 3 "the image did not boot, or its DOS wrote nothing" run findlife
t_play "$f/realdos"
STUB_RC=3 t_case "the launcher refuses the run" 3 "the disks could not be made" run findlife
t_case "a program it does not have" 2 "memprobe, fc, xcopy, dirgone, xcomsim, xcomsim-relay, junktest or dirtest, not: shell" run shell
t_case "an image that is not there" 2 "not a disk image" run_on msdos710 "$work/none.img" id
t_case "a DOS it does not know" 2 "the DOS is msdos710, msdos622 or freedos, not: pcdos7" run_on pcdos7 "$work/boot.img" id
t_case "the image and the program with no DOS" 2 "usage:" run_on "$work/boot.img" id
t_end
