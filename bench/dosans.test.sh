#!/usr/bin/env bash
# dosans.sh's verdicts against captured reports, no emulator: bash dosans.test.sh
# fixtures/dosans holds DOSANS's report of the unpatched base (1) and of the build whose 3Dh, 43h
# and 3Bh read a path as MS-DOS does (2), unlabelled, long names off: they differ in the calls'
# lines and in no 4Eh line. fixtures/dosans-alike holds that build twice.
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
f=$here/fixtures
run() { "$here/dosans.sh" "$build_a" "$build_b" "$@"; }

t_play "$f/dosans-alike"
t_case "two builds that answer alike" 0 "dosans.sh: ALIKE" run unlabelled off
t_case "each report printed whole" 0 "call|3D|D:\\NOSUCH\\CON|err=0" run unlabelled off
t_play "$f/dosans"
t_case "a build that reads a path otherwise" 1 "dosans.sh: DIFFERENT, 246 lines differ" run unlabelled off
t_case "the lines that differ, A then B" 1 "> call|3B|D:\\X\\...|err=3" run unlabelled off
t_derive "$f/dosans-alike"; sed -i '' '$d' "$derived/2/DOSANS.TXT"; t_play "$derived"
t_case "a report cut before its trailer" 3 "build B's report has no line or no trailer" run unlabelled off
t_derive "$f/dosans-alike"; sed -i '' '/^ans|shape|37|D:\\X\\|/d' "$derived/1/DOSANS.TXT"; t_play "$derived"
t_case "a line fewer than the trailer says" 3 "build A's report has no line or no trailer" run unlabelled off
t_play "$f/dosans-alike"
STUB_RC=3 t_case "the launcher refuses the run" 3 "did not run to its end" run unlabelled off
conf() { bash -c 'here=$1; tool=t; . "$here/common.sh"; lfn_conf=false; mkdir -p "$2"; conf_d_image=$3 conf_write "$2" "$2" ""; cat "$2/run.conf"' _ "$here" "$work/conf-$t_cases" "$1"; }
f_iso=$here/fixtures/cdans/game.iso.gz
t_case "a CD image is mounted as D:" 0 "imgmount d \"/x/game.iso\" -t iso" conf /x/game.iso
t_case "a folder still is without it" 0 "mount d \"" conf ""
# shellcheck disable=SC2016  # the quoted text is the child shell's, which expands it
t_case "the CD image of the fixture is a real archive" 0 "GAMEDISC" bash -c 'gzip -dc "$1" | strings | head -3' _ "$f_iso"
t_play "$f/dosans-cd"
t_case "two builds that answer a CD otherwise" 1 "dosans.sh: DIFFERENT, 105 lines differ" run cd off
t_case "the label asked of the root, A then B" 1 "> ans|trail|08|D:\\|D:\\|err=0|n=1|,GAMEDISC.:09:0" run cd off
spy=$work/spy.sh
# shellcheck disable=SC2016  # the script written here expands its own variables
printf '%s\n' '#!/bin/bash' 'while [ $# -gt 0 ]; do if [ "$1" = --conf ]; then cp "$2" "$SPY_OUT"; break; fi; shift; done' > "$spy"
printf 'exec "%s" "$@"\n' "$here/fixtures/stub-launcher.sh" >> "$spy"; chmod +x "$spy"
seen() { SPY_OUT=$work/seen.conf DIRCACHE_LAUNCHER="$spy" run "$@" > /dev/null; command grep -a 'imgmount d' "$work/seen.conf"; }
t_case "the run on a CD mounts the image" 0 "-t iso" seen cd off
t_play "$f/dosans-alike"
t_case "the run on a folder mounts none" 1 "" seen unlabelled off
t_play "$f/dosans-cd"
t_derive "$f/dosans-cd"; sed -i '' '$d' "$derived/2/DOSANS.TXT"; t_play "$derived"
t_case "a CD report cut before its trailer" 3 "build B's report has no line or no trailer" run cd off
t_play "$f/dosans-alike"
t_case "neither labelled, unlabelled nor cd" 2 "labelled, unlabelled or cd, not: both" run both off
t_case "neither on nor off" 2 "on or off" run unlabelled maybe
t_case "three arguments" 2 "usage:" run unlabelled
t_case "its own help" 0 "usage: dosans.sh" "$here/dosans.sh" --help
t_end
