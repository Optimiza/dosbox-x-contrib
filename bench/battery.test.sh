#!/usr/bin/env bash
# battery.sh's lines against one recorded run of the battery, no emulator: bash battery.test.sh
# fixtures/battery holds what every script printed for base and build in a run on three builds
# with --real-dos, as --raw keeps it: the calls made for the third build are left out, and the
# host's paths are replaced by /builds, /library/MIDI, /programs and /images.
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
f=$here/fixtures
mkdir "$work/scripts" "$work/MIDI" "$work/programs" || exit 3
for s in run memory fc findlife exact drift dtadump patlist template findpos ties enumstat xcopy passfail unit realdos; do
    ln -s "$f/stub-script.sh" "$work/scripts/$s.sh" && ln -s "$f/stub-script.sh" "$work/scripts/$s.test.sh" || exit 3
done
: > "$work/MIDI/SONG.MID"; : > "$work/programs/FINDTEST.EXE"; : > "$work/programs/LFNTEST.EXE"; : > "$work/boot.img"
export DIRCACHE_SCRIPTS=$work/scripts DIRCACHE_REAL_FOLDER=$work/MIDI DIRCACHE_REAL_FILE=SONG.MID
export DIRCACHE_REGRESSION=$work/programs DIRCACHE_BOOT_IMAGE=$work/boot.img

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
# on two. A script that compares is called twice; one that measures is called for base and
# build, then for a third that answers as base; enumstat prints each row for the three.
with_third() {
    local file name held="" n=0
    mkdir "$2" || exit 3
    put() { n=$((n + 1)); cp "$1" "$(printf '%s/%03d-%s.txt' "$2" "$n" "$name")" || exit 3; }
    for file in "$1"/*.txt; do
        name=${file##*/}; name=${name#*-}; name=${name%.txt}
        case "$name" in
            *.test|realdos) put "$file" "$2" ;;
            run|findlife|exact|drift|dtadump|patlist|template|findpos|ties) put "$file" "$2"; put "$file" "$2" ;;
            enumstat)
                n=$((n + 1))
                awk '/^enumstat\.sh: lfn=/ { if (first == "") { first = $0; next } print first; print; print first; first = ""; next } { print }' \
                    "$file" > "$(printf '%s/%03d-enumstat.txt' "$2" "$n")" || exit 3
                ;;
            *)
                put "$file" "$2"
                if [ -z "$held" ]; then held=$file; else put "$held" "$2"; held=""; fi
                ;;
        esac
    done
}

battery "$f/battery" --real-dos "$build_a" "$build_b"
t_case "every cell of a run, the DOS of the image among them" 0 "battery.sh: 145 cells, 0 INVALID, 0 not run" printed
t_case "each build named with its digest" 0 "battery.sh: build: $build_b sha256=" printed
t_case "a script's own tests" 0 "cell|selftest run.test.sh|-|ran|cases=19 failed=0" printed
t_case "a listing" 0 "cell|run synthetic:50000:long base:build|off|IDENTICAL|entries=50000 A(4e=50002 lfn=0 look=5) B(4e=50002 lfn=0 look=5)" printed
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
t_case "the ties of this host" 0 "cell|ties base:build|on|ALIKE|ties=11" printed
t_case "one call, a row for each build" 0 "cell|enumstat s 83 build|off|ran|listed=3002 looked_up_ok=3000 last=F0002999.TXT slots_full=0 out_of_range=0" printed
t_case "a name with spaces in a row" 0 "cell|enumstat l long base|on|ran|listed=139 looked_up_ok=137 last=Alpha track 000336.mid slots_full=1 out_of_range=0" printed
t_case "a tree that XCOPY left short" 0 "cell|xcopy base|off|ran|made=2520 copied=2065 dirs_made=18 dirs_copied=15 said=2065 slots_full=1 out_of_range=3" printed
t_case "and one it copied whole" 0 "cell|xcopy build|on|ran|made=2520 copied=2520 dirs_made=18 dirs_copied=18 said=2520 slots_full=0 out_of_range=0" printed
t_case "a program's checks" 0 "cell|passfail LFNTEST synthetic:10000:long build|on|ran|sha256=10da11a297d0 entries=10000 pass=10 fail=0 exit=0" printed
t_case "the emulator's unit tests" 0 "cell|unit build|-|ran|tests=68 failures=0 errors=0 disabled=0" printed
t_case "the report of the image's DOS, by its digest" 0 "cell|realdos drift|off|ran|dos=7.10 cases=25 sha256=921bcc301dce" printed
t_case "the image's DOS, the dump's figures" 0 "cell|realdos dtadump|off|ran|dos=7.10 template=8044d2aed1bc untouched=6/6 resumed=6/6 fcb=f9c92156e849 sha256=d6dec7521dad" printed
t_case "the image's DOS, the patterns" 0 "cell|realdos patlist|off|ran|dos=7.10 patterns=15 sha256=dfc20fe25661" printed
t_case "the image's DOS, the template's answers" 0 "cell|realdos template|off|ran|dos=7.10 lines=37 sha256=6f970af81275" printed
t_case "the image's DOS, FINDLIFE's cases" 0 "cell|realdos findlife|off|ran|dos=7.10 cases=24 ok=15 differs=2 not_judged=7 sha256=f53718142aec" printed
t_case "the image's DOS, a row" 0 "cell|realdos enumstat x 83|off|ran|dos=7.10 listed=3002 looked_up_ok=3000 last=F0002999.TXT" printed
t_case "the image's DOS, where a search keeps its place" 0 "cell|realdos findpos|off|ran|dos=7.10 cases=12 sha256=fdb2307c7b1f" printed
t_case "the image's DOS, the same on the disk it labelled" 0 "cell|realdos findpos-labelled|off|ran|dos=7.10 cases=12 sha256=fb2deb9f2f3a" printed
t_case "the image's DOS, a lookup for each file" 0 "cell|realdos memprobe|off|ran|dos=7.10 mode=e k=1835 ok=1835" printed
t_case "the image's DOS, FC's runs" 0 "cell|realdos fc|off|ran|dos=7.10 files=700 runs=300 compared=300" printed
t_case "the image's DOS, XCOPY's tree" 0 "cell|realdos xcopy|off|ran|dos=7.10 made=2520 copied=2520 dirs_made=18 dirs_copied=18 said=2520" printed

battery "$f/battery" --raw "$work/raw" "$build_a" "$build_b"
t_case "no DOS image unless asked" 0 "battery.sh: 131 cells, 0 INVALID, 0 not run" printed
t_case "what a script printed is kept with its exit code" 0 "exit=1 :: drift.sh $build_a $build_b off" cat "$work/raw/092-drift.txt"

with_third "$f/battery" "$work/third"
battery "$work/third" "$build_a" "$build_b" "$build_a"
t_case "a third build: more cells" 0 "battery.sh: 205 cells, 0 INVALID, 0 not run" printed
t_case "a third build is compared with the build" 0 "cell|run synthetic:1000:83 third:build|on|IDENTICAL|" printed
t_case "a third build is measured" 0 "cell|unit third|-|ran|tests=68" printed
t_case "a third build has its rows" 0 "cell|enumstat n 83 third|off|ran|listed=3002 looked_up_ok=0" printed

t_derive "$f/battery"; STUB_PLAY=$f/listing record "$derived/017-run.txt" run.sh "$build_a" "$build_b" synthetic:10:long on
battery "$derived" "$build_a" "$build_b"
t_case "a listing that differs is a cell, not a failure" 0 "cell|run synthetic:1000:83 base:build|on|DIFFERENT|entries=10 A(4e=12 lfn=12 look=10) B(4e=13 lfn=13 look=10) differing_lines=24" printed
t_derive "$f/battery"; STUB_PLAY=$f/listing-empty record "$derived/017-run.txt" run.sh "$build_a" "$build_b" synthetic:10:long on
battery "$derived" "$build_a" "$build_b"
t_case "a script that judged nothing" 3 "cell|run synthetic:1000:83 base:build|on|INVALID|exit=3 run.sh: INVALID: build A's dump" printed
t_case "is counted" 3 "battery.sh: 131 cells, 1 INVALID, 0 not run" printed
t_case "and what the scripts printed is kept" 3 "battery.sh: what every script printed is kept in $work/tmp/dircache-battery." printed
t_derive "$f/battery"; printf 'exit=0 :: memory.sh\n' > "$derived/031-memory.txt"
battery "$derived" "$build_a" "$build_b"
t_case "a script that exits 0 and prints no figure" 3 "cell|memory synthetic:50000:long a 1 base|on|INVALID|exit=0" printed
t_derive "$f/battery"; printf 'exit=0 :: fc.sh\n' > "$derived/083-fc.txt"
battery "$derived" "$build_a" "$build_b"
t_case "an FC run that printed no line" 3 "cell|fc 700 1 base|off|INVALID|exit=0" printed
t_derive "$f/battery"; sed -i '' '/^xcopy\.sh: /s/ said=2065 / said=many /' "$derived/109-xcopy.txt"
battery "$derived" "$build_a" "$build_b"
t_case "an XCOPY line that is not the script's" 3 "cell|xcopy base|off|INVALID|exit=0" printed
t_derive "$f/battery"; sed -i '' '/^realdos\.sh: names=83 /d' "$derived/130-realdos.txt"
battery "$derived" --real-dos "$build_a" "$build_b"
t_case "the image's DOS with no line of the lookups" 3 "cell|realdos memprobe|off|INVALID|exit=0" printed
t_derive "$f/battery"; sed -i '' -e '1s/^exit=0/exit=3/' -e '$d' "$derived/106-enumstat.txt"
battery "$derived" "$build_a" "$build_b"
t_case "rows that were not printed" 3 "cell|enumstat, the rows it did not print|-|INVALID|exit=3" printed
t_case "beside the rows that were" 3 "cell|enumstat n 83 base|off|ran|listed=3002" printed
t_derive "$f/battery"; sed -i '' -e '1s/^exit=0/exit=1/' -e '$s/, 0 failed$/, 2 failed/' "$derived/001-run.test.txt"
battery "$derived" "$build_a" "$build_b"
t_case "a script's test that failed is a figure" 0 "cell|selftest run.test.sh|-|ran|cases=19 failed=2" printed
t_derive "$f/battery"; sed -i '' '/^label|/d' "$derived/097-template.txt"
battery "$derived" "$build_a" "$build_b"
t_case "a template report that lost lines shows in its count and digests" 0 "cell|template fat base:build|on|ALIKE|lines=23 sha256=499b87b17af1/" printed
t_derive "$f/battery"; sed -i '' -e '/^template\.sh: build /,$d' "$derived/099-template.txt"
battery "$derived" "$build_a" "$build_b"
t_case "a template run that printed no report" 3 "cell|template host base:build|on|INVALID|exit=1" printed
t_derive "$f/battery"; rm "$derived/105-ties.txt"
battery "$derived" "$build_a" "$build_b"
t_case "a recording out of step with the battery's order" 3 "cell|ties base:build|on|INVALID|exit=3 stub-script: call 105 is ties.sh" printed

t_play "$f/battery"
t_case "one build" 2 "usage:" "$here/battery.sh" "$build_a"
t_case "an unknown option" 2 "unknown option: --fast" "$here/battery.sh" --fast "$build_a" "$build_b"
t_case "a build that is not there" 2 "not an executable" "$here/battery.sh" "$build_a" "$work/none"
DIRCACHE_REAL_FOLDER=$work/none t_case "no real folder" 2 "DIRCACHE_REAL_FOLDER is not a directory" "$here/battery.sh" "$build_a" "$build_b"
DIRCACHE_REAL_FILE=NONE.MID t_case "no file of the real folder" 2 "DIRCACHE_REAL_FILE is not a file" "$here/battery.sh" "$build_a" "$build_b"
DIRCACHE_REGRESSION=$work/MIDI t_case "no regression programs" 2 "DIRCACHE_REGRESSION holds no FINDTEST.EXE" "$here/battery.sh" "$build_a" "$build_b"
DIRCACHE_BOOT_IMAGE=$work/none t_case "the DOS of an image that is not there" 2 "--real-dos needs DIRCACHE_BOOT_IMAGE" "$here/battery.sh" --real-dos "$build_a" "$build_b"
t_case "a directory for --raw that holds files" 2 "already holds files" "$here/battery.sh" --raw "$work/programs" "$build_a" "$build_b"
t_end
