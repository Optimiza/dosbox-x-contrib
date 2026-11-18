#!/usr/bin/env bash
# battery.sh's lines against one recorded run of the battery, no emulator: bash battery.test.sh
# fixtures/battery holds what every script printed for base and build in a run on three builds
# with --real-dos and the reporters' files named, as --raw keeps it, one file per call named by
# the call: the calls made for the third build are left out, and the host's paths are replaced by
# /builds, /library/MIDI, /programs, /images and /reporters. The calls of attrprobe (its test,
# then on and off) and the tests of attrsem, attrcost and resprb came later than that run: they
# are what the script printed for the same two builds on its own. The calls of delete (its test,
# then on and off) are a run of battery.sh --only selftest --only delete with the build that
# carries the create and delete patch as build; the calls of aliases (its test, then its cells) a run
# of the same with the build that gives no two entries of a folder one short name; the calls of
# run on the folders of styles dots, mix and wine, and run's test, a run of battery.sh --only
# selftest --only folders with the build that reads a folder in one pass; the tests of p5time,
# p5rep, judge and batch a run of battery.sh --only selftest; the calls of attrsem on and off, and
# sidefx's and its test, a run of battery.sh --only selftest --only attrsem with the build that
# keeps the cache across an attribute change; the calls of overlay a run of battery.sh --only
# overlay with the build that gives the overlay drive the label and root rules, and its test a run
# of battery.sh --only selftest. The calls of the three real DOS are a run of battery.sh --real-dos --only realdos
# --only reporters with the unpatched base as both builds, the images replaced by /images/boot.img,
# boot.vhd and fd.img, but for MS-DOS 6.22's dirtest and the three DOS's dirgone, which are what
# realdos.sh printed for the same call run on its own; the calls of dirgone and lfnren, their tests
# and realdos's test a run of battery.sh --only selftest --only gone with the head of the create
# and delete branch as build; the calls of dosans, on the builds and on the three DOS, its test and
# realdos's a run of battery.sh --real-dos --only selftest --only dosans with the build whose 3Dh,
# 43h and 3Bh read a path as MS-DOS does. The calls of xcomsim (its test, then own and relayed, on
# and off) and its two realdos.sh arms on the three DOS are what each script printed on its own,
# with the build that merges the exact-name, retention and first-read branches as build.
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
f=$here/fixtures
mkdir "$work/scripts" "$work/MIDI" "$work/programs" "$work/junktest" "$work/DIRTEST" "$work/state-home" || exit 3
for s in run memory fc findlife exact drift dirgone lfnren dtadump patlist template findpos dosans overlay attrprobe attrsem sidefx attrcost resprb delete aliases ties enumstat xcopy xcomsim passfail unit realdos junktest dirtest p5time p5rep judge batch; do
    ln -s "$f/stub-script.sh" "$work/scripts/$s.sh" && ln -s "$f/stub-script.sh" "$work/scripts/$s.test.sh" || exit 3
done
: > "$work/MIDI/SONG.MID"; : > "$work/programs/FINDTEST.EXE"; : > "$work/programs/LFNTEST.EXE"; : > "$work/boot.img"; : > "$work/boot.vhd"; : > "$work/fd.img"
export DIRCACHE_SCRIPTS=$work/scripts DIRCACHE_REAL_FOLDER=$work/MIDI DIRCACHE_REAL_FILE=SONG.MID
export DIRCACHE_REGRESSION=$work/programs DIRCACHE_BOOT_MSDOS710=$work/boot.img
export DIRCACHE_BOOT_MSDOS622=$work/boot.vhd DIRCACHE_BOOT_FREEDOS=$work/fd.img
# A host of 16 GB, whatever this one has: half of it for the calls side by side. The lock is the
# test's own, so that a battery running on this host does not hold the test.
export DIRCACHE_MEMORY_KB=16777216 XDG_STATE_HOME=$work/state-home
lock=$work/state-home/dosbox-x-dircache/battery.lock

# battery <recording> <argument>...: one run, kept, so that several of its lines can be checked.
battery() {
    t_play "$1"
    shift
    "$here/battery.sh" "$@" > "$work/out.txt" 2>&1
    echo $? > "$work/rc"
}
printed() { cat "$work/out.txt"; return "$(cat "$work/rc")"; }

# record <file> <script> <argument>...: what a real script prints over the launcher's stand-in,
# as --raw keeps it.
record() {
    local file=$1 out rc
    shift
    rm -f "$STUB_STATE/count"
    out=$("$here/$1" "${@:2}" 2>&1)
    rc=$?
    printf 'exit=%s :: %s\n%s\n' "$rc" "$1" "$out" > "$file"
}

# with_third <recording> <directory>: the recording of a run on three builds, made from the one
# on two. A script that compares is called again for third:build; one that measures is called for
# a third that answers as base; enumstat prints each row for the three.
with_third() {
    local file name
    mkdir "$2" || exit 3
    for file in "$1"/*.txt; do
        name=${file##*/}
        case "$name" in
            enumstat.txt)
                awk '/^enumstat\.sh: lfn=/ { if (first == "") { first = $0; next } print first; print; print first; first = ""; next } { print }' \
                    "$file" > "$2/$name" || exit 3
                continue
                ;;
        esac
        cp "$file" "$2/$name" || exit 3
        case "$name" in
            selftest_*|realdos_*) ;;
            *_base-build_*) cp "$file" "$2/${name/_base-build_/_third-build_}" || exit 3 ;;
            *) cp "$file" "$2/$(printf '%s' "$name" | sed -E 's/_base(_on|_off)?\.txt$/_third\1.txt/')" || exit 3 ;;
        esac
    done
}

# schedule_of <raw directory>: when each call started and ended, as battery.sh logs it.
schedule_of() { cat "$1/schedule.txt"; }

# alone <raw directory> <call>: the call started with no memory cell running, and none started
# before it ended.
alone() {
    awk -F'|' -v key="$2" '
        $1 == "start" && $3 == key { inside = 1; found = 1; if ($4 !~ / measured_beside=0 /) bad = "it started beside " $4; next }
        $1 == "end" && $3 == key { inside = 0; next }
        inside && $1 == "start" && $3 ~ /^(memory|fc|junktest|dirtest)_/ { bad = $3 " started while it ran" }
        END { if (!found) { print "no start of " key; exit 1 } if (bad != "") { print bad; exit 1 } print key " ran alone" }' "$1/schedule.txt"
}

battery "$f/battery" --real-dos "$build_a" "$build_b"
t_case "every cell of a run, the three DOS among them" 0 "battery.sh: 247 cells, 0 INVALID, 3 not run" printed
t_case "each build named with its digest" 0 "battery.sh: build: $build_b sha256=" printed
t_case "how many calls run side by side, and in how much memory" 0 "kB of 16777216; groups: selftest answers folders gone dosans overlay attrsem delete aliases memory realdos reporters" printed
t_case "a script's own tests" 0 "cell|selftest run.test.sh|-|ran|cases=26 failed=0" printed
t_case "the tests of a timer" 0 "cell|selftest p5rep.test.sh|-|ran|cases=12 failed=0" printed
t_case "the tests of a reporters' runner" 0 "cell|selftest junktest.test.sh|-|ran|cases=13 failed=0" printed
t_case "the reporters' files, not named" 0 "cell|junktest|off|not run|DIRCACHE_JUNKTEST names no folder" printed
t_case "and the other's" 0 "cell|dirtest|off|not run|DIRCACHE_DIRTEST names no folder" printed
t_case "a listing" 0 "cell|run synthetic:50000:long base:build|off|IDENTICAL|entries=50000 A(4e=50002 lfn=0 look=5) B(4e=50002 lfn=0 look=5)" printed
t_case "a folder that puts the list of aliases out of order" 0 "cell|run synthetic:432:dots base:build|off|IDENTICAL|entries=432 A(4e=434 lfn=0 look=5) B(4e=434 lfn=0 look=5)" printed
t_case "and one of real files named as Wine-style short names" 0 "cell|run synthetic:120:wine base:build|on|IDENTICAL|entries=120 A(4e=122 lfn=122 look=10)" printed
t_case "a memory line, with the figure this host reads" 0 "cell|memory synthetic:100:long a 20000 build|on|ran|entries=100 ok=20000 slots_full=0 held_footprint_kb=" printed
t_case "a search left open, long names off" 0 "cell|memory synthetic:50000:83 c 20 base|off|ran|entries=50000 ok=20 slots_full=0 held_footprint_kb=" printed
t_case "a search of the whole folder left open, the pattern in the cell's name" 0 "cell|memory synthetic:50000:83 *.* d 20 build|off|ran|entries=50000 ok=20 slots_full=0 held_footprint_kb=" printed
t_case "a lookup for each file of a folder, the calls in the cell's name" 0 "cell|memory synthetic:1835:83 e 1835 base|off|ran|entries=1835 ok=1835 slots_full=0 held_footprint_kb=" printed
t_case "FC's runs, the peak while it ran and the figure held after" 0 "cell|fc 700 300 build|off|ran|entries=703 compared=300 slots_full=0 peak_rss_kb=220752 held_footprint_kb=181216" printed
t_case "a report's cases by how each reads" 0 "cell|findlife base:build|on|DIFFERENT|A(cases=24 ok=17 differs=7 not_judged=0) B(cases=24 ok=21 differs=3 not_judged=0) differ=lfn-next-after-its-end,lfn-first-with-no-handle-left,left-open-past-the-slots,turn-about-past-the-slots" printed
t_case "exact's sections, drift among them" 0 "cell|exact base:build|off|ALIKE|basic=ALIKE:362 life=ALIKE:9 shell=ALIKE:69 tree=ALIKE:20 drift=ALIKE:7" printed
t_case "two reports that differ, the cases named" 0 "cell|drift base:build|off|DIFFERENT|cases=25 sha256=70fc2e99d792/2a76d274855d differ=folder-gained-files,label-search-then-edited" printed
t_case "a dump's figures for each build, its differing lines counted" 0 "cell|dtadump base:build|off|DIFFERENT|A(template=1c5027e13814 untouched=3/6 resumed=3/6 fcb=ce9cdd5c399c) B(template=1c5027e13814 untouched=3/6 resumed=3/6 fcb=ce9cdd5c399c) differing_lines=1" printed
t_case "two lists of patterns alike, by their digests" 0 "cell|patlist base:build|on|ALIKE|patterns=15 sha256=a8e695a8baca/a8e695a8baca" printed
t_case "the template's answers on the image, alike by their digests" 0 "cell|template fat base:build|off|ALIKE|lines=38 sha256=511332f08802/511332f08802" printed
t_case "and on the host folder, the lines that differ counted" 0 "cell|template host base:build|on|DIFFERENT|lines=37 sha256=912a42f66374/56fc67120257 differing_lines=4" printed
t_case "where a search keeps its place and the label alone, the cases named" 0 "cell|findpos labelled base:build|off|DIFFERENT|cases=12 sha256=6e77d287ea95/0fef681213a5 differ=label-alone,label-alone-through-a-live-search" printed
t_case "how a path is read, the lines that differ counted" 0 "cell|dosans unlabelled base:build|off|DIFFERENT|lines=730 sha256=bfe1f25843f6/ad27936e059f differing_lines=246" printed
t_case "and alike with long names on" 0 "cell|dosans labelled base:build|on|ALIKE|lines=730 sha256=52883a50def3/52883a50def3" printed
t_case "the same program on a real DOS, by its digest" 0 "cell|realdos msdos622 dosans-labelled|off|ran|dos=6.22 lines=741 sha256=7422fa4c45cc" printed
t_case "an overlay that answers as DOS" 0 "cell|overlay labelled build|on|ALIKE|label=ALIKE next=18 dots=none other_lines=4" printed
t_case "and one that does not, beside its host folder" 0 "cell|overlay unlabelled base|off|DIFFERENT|label=ALIKE next=other dots=listed other_lines=4" printed
t_case "an attribute change across searches, alike by their digests" 0 "cell|attrprobe base:build|off|ALIKE|cases=8 sha256=" printed
t_case "an attribute change, the program's and the shell's lines by their digests" 0 "cell|attrsem base:build|off|ALIKE|lines=32 shell=55 sha256=5bbc318c4907/5bbc318c4907" printed
t_case "a host's file across an attribute change, by the digests" 0 "cell|sidefx rescan base:build|off|ALIKE|lines=27 sha256=e4d5b0b6a291/e4d5b0b6a291" printed
t_case "the label overwritten by the host's, Windows only" 0 "cell|sidefx label base:build|off|not run|only a Windows build lets the host's volume label overwrite the guest's" printed
t_case "a delete's steps by their digests, what each build left on the host" 0 "cell|delete base:build|on|DIFFERENT|lines=166 sha256=7be8d4e9a45f/1b7b2776c757 A(S=4 L=4 W=4 A=10 P=6 C=10 R=9) B(S=0 L=0 W=0 A=10 P=6 C=10 R=9) differ=del:shell," printed
t_case "one build's short names, judged against the host" 0 "cell|aliases cases base|on|ran|entries=87 host=87 names_shared=17 exact_search_not_one=19 real_name_not_its_own=11 files_no_short_name_opens=19 listed_with_another_size=20 name_opens_another_file=19 long_name_opens_another_file=8" printed
t_case "the same with long names off, the long-name figures left out" 0 "cell|aliases cases build|off|ran|entries=87 host=87 names_shared=0 exact_search_not_one=0 real_name_not_its_own=0 files_no_short_name_opens=0" printed
t_case "the large real folder's shared names" 0 "cell|aliases real base|on|ran|entries=169111 host=169457 names_shared=1048 entries_sharing=7684 matched=169106 listed_with_another_size=6633" printed
t_case "the ties of this host" 0 "cell|ties base:build|on|ALIKE|ties=11" printed
t_case "one call, a row for each build" 0 "cell|enumstat s 83 build|off|ran|listed=3002 looked_up_ok=3000 last=F0002999.TXT slots_full=0 out_of_range=0" printed
t_case "a name with spaces in a row" 0 "cell|enumstat l long base|on|ran|listed=139 looked_up_ok=137 last=Alpha track 000336.mid slots_full=1 out_of_range=0" printed
t_case "a tree that XCOPY left short" 0 "cell|xcopy base|off|ran|made=2520 copied=2065 dirs_made=18 dirs_copied=15 said=2065 slots_full=1 out_of_range=3" printed
t_case "and one it copied whole" 0 "cell|xcopy build|on|ran|made=2520 copied=2520 dirs_made=18 dirs_copied=18 said=2520 slots_full=0 out_of_range=0" printed
t_case "a program's checks" 0 "cell|passfail LFNTEST synthetic:10000:long build|on|ran|sha256=10da11a297d0 entries=10000 pass=10 fail=0 exit=0" printed
t_case "the emulator's unit tests" 0 "cell|unit build|-|ran|tests=68 failures=0 errors=0 disabled=0" printed
t_case "the report of the image's DOS, by its digest" 0 "cell|realdos msdos710 drift|off|ran|dos=7.10 cases=25 sha256=921bcc301dce" printed
t_case "the image's DOS, the dump's figures" 0 "cell|realdos msdos710 dtadump|off|ran|dos=7.10 template=8044d2aed1bc untouched=6/6 resumed=6/6 fcb=f9c92156e849 sha256=d6dec7521dad" printed
t_case "the image's DOS, the patterns" 0 "cell|realdos msdos710 patlist|off|ran|dos=7.10 patterns=15 sha256=dfc20fe25661" printed
t_case "the image's DOS, the template's answers" 0 "cell|realdos msdos710 template|off|ran|dos=7.10 lines=37 sha256=6f970af81275" printed
t_case "the image's DOS, FINDLIFE's cases" 0 "cell|realdos msdos710 findlife|off|ran|dos=7.10 cases=24 ok=15 differs=2 not_judged=7 sha256=f53718142aec" printed
t_case "the image's DOS, a row" 0 "cell|realdos msdos710 enumstat x 83|off|ran|dos=7.10 listed=3002 looked_up_ok=3000 last=F0002999.TXT" printed
t_case "the image's DOS, where a search keeps its place" 0 "cell|realdos msdos710 findpos|off|ran|dos=7.10 cases=12 sha256=fdb2307c7b1f" printed
t_case "the image's DOS, the same on the disk it labelled" 0 "cell|realdos msdos710 findpos-labelled|off|ran|dos=7.10 cases=12 sha256=fb2deb9f2f3a" printed
t_case "the image's DOS, a lookup for each file" 0 "cell|realdos msdos710 memprobe|off|ran|dos=7.10 mode=e k=1835 ok=1835" printed
t_case "the image's DOS, FC's runs" 0 "cell|realdos msdos710 fc|off|ran|dos=7.10 files=700 runs=300 compared=300" printed
t_case "X-COM's lookups and the listing: the base loses part of it" 0 "cell|xcomsim own base:build|off|DIFFERENT|A(listing=28/40 27/40 lost=25 slots_full=1 out_of_range=2) B(listing=40/40 40/40 lost=0 slots_full=0 out_of_range=0)" printed
t_case "the listing relayed through the lookups' one DTA" 0 "cell|xcomsim relayed base:build|on|DIFFERENT|A(listing=28/40 27/40 lost=25 slots_full=1 out_of_range=2) B(listing=40/40 40/40 lost=0" printed
t_case "the image's DOS, X-COM's lookups and the listing relayed" 0 "cell|realdos msdos622 xcomsim-relay|off|ran|dos=6.22 listing=40/40 40/40 lost=0" printed
t_case "the image's DOS, XCOPY's tree" 0 "cell|realdos msdos710 xcopy|off|ran|dos=7.10 made=2520 copied=2520 dirs_made=18 dirs_copied=18 said=2520" printed
t_case "MS-DOS 6.22's report, the same digest as MS-DOS 7.10's" 0 "cell|realdos msdos622 drift|off|ran|dos=6.22 cases=25 sha256=921bcc301dce" printed
t_case "FreeDOS's report, a digest of its own" 0 "cell|realdos freedos template|off|ran|dos=7.10 lines=37 sha256=c951723cb44b" printed
t_case "a search open in a directory removed or renamed, on a real DOS" 0 "cell|realdos freedos dirgone|off|ran|dos=7.10 cases=11 sha256=a258698d6548" printed
t_case "the same on two builds, each by its digest, the cases that differ named" 0 "cell|dirgone base:build|off|DIFFERENT|cases=11 sha256=cae23a196291/a258698d6548 differ=rd,ren,ren-remade,rd-late-remade," printed
t_case "MS-DOS 7.10 answers as the build" 0 "cell|realdos msdos710 dirgone|off|ran|dos=7.10 cases=11 sha256=a258698d6548" printed
t_case "the short names a directory gave before its rename" 0 "cell|lfnren base:build|on|DIFFERENT|lines=7/9 sha256=ec87dc187175/bb6fb3dfc5bb differ=listed,search,end" printed
t_case "no lock is left once it ended" 1 "" test -e "$lock"

battery "$f/battery" --raw "$work/raw" "$build_a" "$build_b"
t_case "no DOS image unless asked" 0 "battery.sh: 190 cells, 0 INVALID, 3 not run" printed
t_case "what a script printed is kept, named by its call, with its exit code" 0 "exit=1 :: drift.sh $build_a $build_b off" cat "$work/raw/drift_base-build_off.txt"
t_case "when each call started, in which lane, beside how many" 0 "|memory_real_f_20_base_on|lane=pool footprint_kb=" schedule_of "$work/raw"
t_case "and when it ended" 0 "|memory_real_f_20_base_on|exit=0" schedule_of "$work/raw"
t_case "the tests and the answers in their own lane" 0 "|run_real_base-build_off|lane=serial" schedule_of "$work/raw"

with_third "$f/battery" "$work/third"
battery "$work/third" "$build_a" "$build_b" "$build_a"
t_case "a third build: more cells" 0 "battery.sh: 296 cells, 0 INVALID, 4 not run" printed
t_case "a third build is compared with the build" 0 "cell|run synthetic:1000:83 third:build|on|IDENTICAL|" printed
t_case "a third build is measured" 0 "cell|unit third|-|ran|tests=68" printed
t_case "a third build has its rows" 0 "cell|enumstat n 83 third|off|ran|listed=3002 looked_up_ok=0" printed
t_case "a third build's short names are judged" 0 "cell|aliases real third|on|ran|entries=169111" printed

# The memory cells take a moment each, so that the ones that may run together are seen to.
rm -rf "$work/raw"
STUB_SLOW='memory_*' battery "$f/battery" --raw "$work/raw" "$build_a" "$build_b"
t_case "memory cells side by side: every cell ran" 0 "battery.sh: 190 cells, 0 INVALID, 3 not run" printed
t_case "a memory cell started beside other memory cells" 0 "measured_beside=3 " schedule_of "$work/raw"
t_case "the largest memory cell ran alone among them" 0 "memory_real_f_20_base_on ran alone" alone "$work/raw" memory_real_f_20_base_on
# The second of a pair is followed by small cells, which the memory left would let in beside it.
t_case "and its twin, before the small cells behind it" 0 "memory_real_f_20_build_on ran alone" alone "$work/raw" memory_real_f_20_build_on
t_case "and another over half the memory" 0 "memory_real_a_20_build_on ran alone" alone "$work/raw" memory_real_a_20_build_on
t_derive "$f/battery"; printf 'exit=3 :: memory.sh\nmemory.sh: INVALID: the emulator did not run to its end; the run is kept in /tmp/x\n' > "$derived/memory_synthetic-50000-long_a_20_build_on.txt"
rm -rf "$work/raw"
STUB_SLOW='memory_*' battery "$derived" --raw "$work/raw" "$build_a" "$build_b"
t_case "a memory cell that fails beside others is INVALID" 3 "cell|memory synthetic:50000:long a 20 build|on|INVALID|exit=3 memory.sh: INVALID: the emulator did not run to its end" printed
t_case "the cells beside it keep their own figures" 3 "cell|memory synthetic:50000:long a 20 base|on|ran|entries=50000 ok=20 slots_full=0 held_footprint_kb=" printed
t_case "and the one after it" 3 "cell|memory synthetic:50000:long d 1 base|on|ran|entries=50000 ok=1 slots_full=0 held_footprint_kb=" printed
t_case "it did run beside them" 0 "|memory_synthetic-50000-long_a_20_build_on|lane=pool footprint_kb=1499681 beside=3 measured_beside=3 " schedule_of "$work/raw"
t_case "one INVALID among them" 3 "battery.sh: 190 cells, 1 INVALID, 3 not run" printed

# --only: one group runs, the others print not run, and the battery is not whole.
rm -rf "$work/raw"
battery "$f/battery" --raw "$work/raw" --only memory "$build_a" "$build_b"
t_case "one group asked: the battery is incomplete" 3 "battery.sh: incomplete: only memory ran" printed
t_case "its cells ran" 3 "cell|fc 700 300 build|off|ran|entries=703 compared=300" printed
t_case "another group's cell is not run" 3 "cell|run synthetic:1000:83 base:build|on|not run|--only left out its group, answers" printed
t_case "and a test's" 3 "cell|selftest run.test.sh|-|not run|--only left out its group, selftest" printed
# ENUMSTAT's one call prints one line for its twelve rows when it does not run.
t_case "every cell is still printed, none INVALID" 3 "battery.sh: 179 cells, 0 INVALID, 123 not run" printed
t_case "no call of another group was made" 1 "" command grep -q '|run_' "$work/raw/schedule.txt"
battery "$f/battery" --only selftest --only answers "$build_a" "$build_b"
t_case "two groups asked" 3 "battery.sh: incomplete: only selftest answers ran" printed
t_case "both ran" 3 "cell|ties base:build|on|ALIKE|ties=11" printed
t_case "the others did not" 3 "cell|memory synthetic:50000:long a 1 base|on|not run|--only left out its group, memory" printed
battery "$f/battery" --real-dos --only dosans "$build_a" "$build_b"
t_case "the dosans group, its runs on the image among them" 3 "cell|realdos freedos dosans|off|ran|dos=7.10 lines=741 sha256=858a803179f8" printed
t_case "the image's other arms are another group's" 3 "cell|realdos freedos dirgone|off|not run|--only left out its group, realdos" printed
battery "$f/battery" --only gone "$build_a" "$build_b"
t_case "the gone group alone" 3 "cell|lfnren base:build|on|DIFFERENT|lines=7/9" printed
t_case "with DIRGONE in it" 3 "cell|dirgone base:build|on|DIFFERENT|cases=11" printed
battery "$f/battery" --only overlay "$build_a" "$build_b"
t_case "the overlay group alone" 3 "cell|overlay labelled base|off|DIFFERENT|label=ALIKE next=other" printed
t_case "beside the findpos cells it reads" 3 "cell|findpos labelled base:build|off|not run|--only left out its group, answers" printed
battery "$f/battery" --only attrsem "$build_a" "$build_b"
t_case "the attrsem group alone" 3 "cell|attrsem base:build|on|ALIKE|lines=32" printed
t_case "the side effects among it" 3 "cell|sidefx rescan base:build|off|ALIKE|lines=27" printed
battery "$f/battery" --only delete "$build_a" "$build_b"
t_case "the delete group alone" 3 "cell|delete base:build|off|DIFFERENT|lines=157 " printed
t_case "beside the answers it is not part of" 3 "cell|exact base:build|on|not run|--only left out its group, answers" printed
battery "$f/battery" --only folders "$build_a" "$build_b"
t_case "the folders group alone" 3 "cell|run synthetic:10240:mix base:build|on|IDENTICAL|entries=10240" printed
t_case "the other listings are another group" 3 "cell|run synthetic:1000:83 base:build|on|not run|--only left out its group, answers" printed
battery "$f/battery" --only aliases "$build_a" "$build_b"
t_case "the aliases group alone" 3 "cell|aliases real build|on|ran|entries=169111 host=169457 names_shared=0 entries_sharing=0" printed
battery "$f/battery" --real-dos --only realdos "$build_a" "$build_b"
t_case "the image's group" 3 "cell|realdos msdos710 xcopy|off|ran|dos=7.10 made=2520" printed
DIRCACHE_JUNKTEST=$work/junktest DIRCACHE_DIRTEST=$work/DIRTEST battery "$f/battery" --real-dos --only reporters "$build_a" "$build_b"
t_case "the reporters' group, their runs on the image among them" 3 "cell|realdos msdos710 dirtest|off|ran|dos=7.10 files=1835 returned=1" printed
t_case "and on the builds" 3 "cell|dirtest build|off|ran|files=1835" printed
t_case "the image's other arms are another group" 3 "cell|realdos msdos710 findlife|off|not run|--only left out its group, realdos" printed

# The lock: a second battery waits for the first; one left by a battery that is gone is taken.
mkdir -p "$lock" || exit 3
sleep 2 &
echo $! > "$lock/pid"
battery "$f/battery" --only memory "$build_a" "$build_b"
t_case "a battery that holds the lock: the second waits for it" 3 "another battery runs on this host (pid " printed
t_case "and runs once it ended" 3 "battery.sh: incomplete: only memory ran" printed
t_case "the lock it took is gone with it" 1 "" test -e "$lock"
mkdir -p "$lock" || exit 3
(exit 0) &
gone=$!
wait "$gone"
echo "$gone" > "$lock/pid"
battery "$f/battery" --only memory "$build_a" "$build_b"
t_case "a lock whose battery is gone is taken" 3 "the lock of a battery that is gone (pid $gone) is taken" printed
mkdir -p "$lock" || exit 3
battery "$f/battery" --only memory "$build_a" "$build_b"
t_case "a lock that never got its pid is taken" 3 "the lock of a battery that is gone (pid none) is taken" printed
mkdir -p "$lock" || exit 3
sleep 30 &
holder=$!
echo "$holder" > "$lock/pid"
battery "$f/battery" --only selftest --only answers "$build_a" "$build_b"
t_case "the answers alone do not wait for it" 3 "battery.sh: incomplete: only selftest answers ran" printed
t_case "nor say they do" 1 "" command grep -q 'another battery runs' "$work/out.txt"
kill "$holder"
wait "$holder" 2> /dev/null
rm -rf "$lock"

# The run of $f/battery with the reporters' files named: their calls come last.
reporters_battery() { DIRCACHE_JUNKTEST=$work/junktest DIRCACHE_DIRTEST=$work/DIRTEST battery "$derived" --real-dos "$build_a" "$build_b"; }
t_derive "$f/battery"; reporters_battery
t_case "the reporters' files, named: every cell ran" 0 "battery.sh: 259 cells, 0 INVALID, 1 not run" printed
t_case "the reporter's run on base, read after its last batch file" 0 "cell|junktest 300 JUNK 300 base|off|ran|entries=705 junk=700 counted=600 done=3 slots_full=0 out_of_range=0 peak_rss_kb=355808 held_footprint_kb=462545" printed
t_case "a step of it on the build" 0 "cell|junktest 300 JUNK build|off|ran|entries=705 junk=700 counted=300 done=2 slots_full=0 out_of_range=0 peak_rss_kb=" printed
t_case "the other reporter's program on base" 0 "cell|dirtest base|off|ran|files=1835 calls_4f=1835 calls_4e=1865 slots_full=0 out_of_range=0 peak_rss_kb=2248688 held_footprint_kb=2371746" printed
t_case "the image's DOS, the reporter's run" 0 "cell|realdos msdos710 junktest|off|ran|dos=7.10 batches=300,JUNK,300 entries=705 junk=700 counted=600 done=3" printed
t_case "the image's DOS, the other reporter's program" 0 "cell|realdos msdos710 dirtest|off|ran|dos=7.10 files=1835 returned=1" printed
t_derive "$f/battery"; LC_ALL=C sed -i '' '/^junktest\.sh: /d' "$derived/junktest_300_JUNK_300_base_off.txt"; reporters_battery
t_case "a run that printed no line" 3 "cell|junktest 300 JUNK 300 base|off|INVALID|exit=0" printed
t_derive "$f/battery"; LC_ALL=C sed -i '' 's/ returned=1$//' "$derived/realdos_msdos710_dirtest_off.txt"; reporters_battery
t_case "the image's DOS with no line of the program" 3 "cell|realdos msdos710 dirtest|off|INVALID|exit=0" printed

t_derive "$f/battery"; STUB_PLAY=$f/listing record "$derived/run_synthetic-1000-83_base-build_on.txt" run.sh "$build_a" "$build_b" synthetic:10:long on
battery "$derived" "$build_a" "$build_b"
t_case "a listing that differs is a cell, not a failure" 0 "cell|run synthetic:1000:83 base:build|on|DIFFERENT|entries=10 A(4e=12 lfn=12 look=10) B(4e=13 lfn=13 look=10) differing_lines=24" printed
t_derive "$f/battery"; STUB_PLAY=$f/listing-empty record "$derived/run_synthetic-1000-83_base-build_on.txt" run.sh "$build_a" "$build_b" synthetic:10:long on
battery "$derived" "$build_a" "$build_b"
t_case "a script that judged nothing" 3 "cell|run synthetic:1000:83 base:build|on|INVALID|exit=3 run.sh: INVALID: build A's dump" printed
t_case "is counted" 3 "battery.sh: 190 cells, 1 INVALID, 3 not run" printed
t_case "and what the scripts printed is kept" 3 "battery.sh: what every script printed is kept in $work/tmp/dircache-battery." printed
t_derive "$f/battery"; printf 'exit=0 :: memory.sh\n' > "$derived/memory_synthetic-50000-long_a_1_base_on.txt"
battery "$derived" "$build_a" "$build_b"
t_case "a script that exits 0 and prints no figure" 3 "cell|memory synthetic:50000:long a 1 base|on|INVALID|exit=0" printed
t_derive "$f/battery"; printf 'exit=0 :: fc.sh\n' > "$derived/fc_700_1_base_off.txt"
battery "$derived" "$build_a" "$build_b"
t_case "an FC run that printed no line" 3 "cell|fc 700 1 base|off|INVALID|exit=0" printed
t_derive "$f/battery"; sed -i '' '/^xcopy\.sh: /s/ said=2065 / said=many /' "$derived/xcopy_base_off.txt"
battery "$derived" "$build_a" "$build_b"
t_case "an XCOPY line that is not the script's" 3 "cell|xcopy base|off|INVALID|exit=0" printed
t_derive "$f/battery"; sed -i '' '/^xcomsim\.sh: build A: lfn=/s/ lost=25 / lost=many /' "$derived/xcomsim_own_base-build_off.txt"
battery "$derived" "$build_a" "$build_b"
t_case "an XCOMSIM verdict that is not the script's" 3 "cell|xcomsim own base:build|off|INVALID|exit=1" printed
t_derive "$f/battery"; sed -i '' '/^realdos\.sh: msdos710: names=83 /d' "$derived/realdos_msdos710_memprobe_off.txt"
battery "$derived" --real-dos "$build_a" "$build_b"
t_case "the image's DOS with no line of the lookups" 3 "cell|realdos msdos710 memprobe|off|INVALID|exit=0" printed
t_derive "$f/battery"; sed -i '' -e '1s/^exit=0/exit=3/' -e '$d' "$derived/enumstat.txt"
battery "$derived" "$build_a" "$build_b"
t_case "rows that were not printed" 3 "cell|enumstat, the rows it did not print|-|INVALID|exit=3" printed
t_case "beside the rows that were" 3 "cell|enumstat n 83 base|off|ran|listed=3002" printed
t_derive "$f/battery"; sed -i '' -e '1s/^exit=0/exit=1/' -e '$s/, 0 failed$/, 2 failed/' "$derived/selftest_run.test.sh.txt"
battery "$derived" "$build_a" "$build_b"
t_case "a script's test that failed is a figure" 0 "cell|selftest run.test.sh|-|ran|cases=26 failed=2" printed
t_derive "$f/battery"; sed -i '' '/^label|/d' "$derived/template_fat_base-build_on.txt"
battery "$derived" "$build_a" "$build_b"
t_case "a template report that lost lines shows in its count and digests" 0 "cell|template fat base:build|on|ALIKE|lines=23 sha256=499b87b17af1/" printed
t_derive "$f/battery"; sed -i '' -e '/^template\.sh: build /,$d' "$derived/template_host_base-build_on.txt"
battery "$derived" "$build_a" "$build_b"
t_case "a template run that printed no report" 3 "cell|template host base:build|on|INVALID|exit=1" printed
t_derive "$f/battery"; sed -i '' -e '1s/^exit=0/exit=1/' -e '$a\
attrsem.sh: DIFFERENT, 1 lines differ (A then B):\
< sem|hidden|4300=0002 find20=none find37=F0001.TXT open=0000\
> sem|hidden|4300=0002 find20=F0001.TXT find37=F0001.TXT open=0000
' "$derived/attrsem_base-build_on.txt"
battery "$derived" "$build_a" "$build_b"
t_case "an attribute case that differs, named" 0 "cell|attrsem base:build|on|DIFFERENT|lines=32 shell=55 sha256=5bbc318c4907/5bbc318c4907 differ=hidden" printed
t_derive "$f/battery"; rm "$derived/ties_base-build_on.txt"
battery "$derived" "$build_a" "$build_b"
t_case "a recording with no file for a call" 3 "cell|ties base:build|on|INVALID|exit=3 stub-script: the recording has no call ties_base-build_on" printed
t_derive "$f/battery"; cp "$derived/unit_base.txt" "$derived/ties_base-build_on.txt"
battery "$derived" "$build_a" "$build_b"
t_case "a call played from another script's file" 3 "cell|ties base:build|on|INVALID|exit=3 stub-script: ties_base-build_on is recorded for unit.sh, not ties.sh" printed

t_play "$f/battery"
t_case "one build" 2 "usage:" "$here/battery.sh" "$build_a"
t_case "an unknown option" 2 "unknown option: --fast" "$here/battery.sh" --fast "$build_a" "$build_b"
t_case "a group that is not one" 2 "no such group: fast" "$here/battery.sh" --only fast "$build_a" "$build_b"
t_case "--only with no group" 2 "--only takes a group" "$here/battery.sh" "$build_a" "$build_b" --only
t_case "the image's group without the image" 2 "--only realdos needs --real-dos" "$here/battery.sh" --only realdos "$build_a" "$build_b"
t_case "a build that is not there" 2 "not an executable" "$here/battery.sh" "$build_a" "$work/none"
DIRCACHE_REAL_FOLDER=$work/none t_case "no real folder" 2 "DIRCACHE_REAL_FOLDER is not a directory" "$here/battery.sh" "$build_a" "$build_b"
DIRCACHE_REAL_FILE=NONE.MID t_case "no file of the real folder" 2 "DIRCACHE_REAL_FILE is not a file" "$here/battery.sh" "$build_a" "$build_b"
DIRCACHE_REGRESSION=$work/MIDI t_case "no regression programs" 2 "DIRCACHE_REGRESSION holds no FINDTEST.EXE" "$here/battery.sh" "$build_a" "$build_b"
DIRCACHE_BOOT_MSDOS622=$work/none t_case "one of the three DOS with no image" 2 "--real-dos needs DIRCACHE_BOOT_MSDOS622, a disk image: $work/none" "$here/battery.sh" --real-dos "$build_a" "$build_b"
DIRCACHE_MEMORY_KB=many t_case "a host memory that is not a number" 2 "the host's memory is not a number of kB: many" "$here/battery.sh" "$build_a" "$build_b"
t_case "a directory for --raw that holds files" 2 "already holds files" "$here/battery.sh" --raw "$work/programs" "$build_a" "$build_b"
t_end
