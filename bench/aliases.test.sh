#!/usr/bin/env bash
# aliases.sh's verdicts against captured runs, no emulator: bash aliases.test.sh
# fixtures/aliases/cases holds ALIASES's report of unpatched upstream (1) and of a build where no
# two entries of a folder share a short name (2), long names on; cases-off the same, long names
# off; fixtures/aliases/folder their listings of the folder ties_folder makes. Upstream lists one short name for two entries and
# leaves files that no short name opens; the other build none.
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
f=$here/fixtures/aliases
run() { "$here/aliases.sh" "$@"; }

# The folder the folder fixture listed: twelve long names, each beside a real file named like
# the alias the emulator gives it, every file a size of its own.
ties_folder() {
    local size=0 stem upper
    mkdir -p "$1" || exit 3
    for stem in a b c d e f g h j k m n; do
        upper=$(printf '%s' "$stem$stem$stem$stem$stem$stem" | tr '[:lower:]' '[:upper:]')
        size=$((size + 1)); head -c "$size" /dev/zero > "$1/$upper~1.TXT" || exit 3
        size=$((size + 1)); head -c "$size" /dev/zero > "$1/$stem$stem$stem $stem$stem$stem.txt" || exit 3
    done
}
ties_folder "$work/F/TIES"

zero="names_shared=0 exact_search_not_one=0 real_name_not_its_own=0 files_no_short_name_opens=0 listed_with_another_size=0 name_opens_another_file=0 long_name_opens_another_file=0"
t_play "$f/cases"
t_case "a build that shares short names against one that does not" 1 "aliases.sh: DIFFERENT" run cases on "$build_a" "$build_b"
t_case "upstream's figures" 1 "entries=87 host=87 names_shared=17 exact_search_not_one=19 real_name_not_its_own=11 files_no_short_name_opens=19 listed_with_another_size=20 name_opens_another_file=19 long_name_opens_another_file=8" run cases on "$build_a" "$build_b"
t_case "a shared name, named" 1 "  shared|AAAAAA~1.TXT" run cases on "$build_a" "$build_b"
t_case "a real file whose own name opens another" 1 "  real_name_not_its_own|SIBLIN~2.DAT|opens 28" run cases on "$build_a" "$build_b"
t_case "a directory listed as a file" 1 "  listed_with_another_size|dirlong name|a directory listed as a file" run cases on "$build_a" "$build_b"
t_case "the other build's figures, every one zero" 1 "entries=87 host=87 $zero build=" run cases on "$build_a" "$build_b"
t_case "one build: its figures, no verdict" 0 "names_shared=17" run cases on "$build_a"
t_derive "$f/cases"; cp "$derived/2/ALIASES.TXT" "$derived/1/ALIASES.TXT"; t_play "$derived"
t_case "two builds alike" 0 "aliases.sh: ALIKE" run cases on "$build_a" "$build_b"
t_derive "$f/cases"; sed -i '' '$d' "$derived/2/ALIASES.TXT"; t_play "$derived"
t_case "a report cut before its trailer" 3 "build 2's report has no line or no trailer" run cases on "$build_a" "$build_b"
t_derive "$f/cases"; sed -i '' '/^open|PLAIN.TXT|/d' "$derived/1/ALIASES.TXT"; t_play "$derived"
t_case "a line fewer than the trailer says" 3 "build 1's report has no line or no trailer" run cases on "$build_a" "$build_b"
t_derive "$f/cases"; printf 'lfn|none|err=1\nend|lines=1\n' > "$derived/1/ALIASES.TXT"; t_play "$derived"
t_case "no entry listed" 3 "build 1 listed nothing" run cases on "$build_a" "$build_b"
t_derive "$f/cases"; awk -F'|' '$1 != "lfn" { print } END { }' "$f/cases/1/ALIASES.TXT" | awk -F'|' '$1 == "end" { print "end|lines=" n; next } { n++; print }' > "$derived/1/ALIASES.TXT"; t_play "$derived"
t_case "long names on and no long-name listing" 3 "build 1 listed nothing" run cases on "$build_a" "$build_b"

t_play "$f/cases-off"
t_case "upstream's figures with long names off, from 4Eh alone" 1 "entries=87 host=87 names_shared=17 exact_search_not_one=17 real_name_not_its_own=11 files_no_short_name_opens=19 build=" run cases off "$build_a" "$build_b"
t_case "the other build's, long names off" 1 "entries=87 host=87 names_shared=0 exact_search_not_one=0 real_name_not_its_own=0 files_no_short_name_opens=0 build=" run cases off "$build_a" "$build_b"

t_play "$f/folder"
t_case "a folder listed by two builds" 1 "aliases.sh: DIFFERENT" run folder on "$work/F/TIES" "$build_a" "$build_b"
t_case "upstream's figures on the folder" 1 "entries=24 host=24 names_shared=9 entries_sharing=18 matched=24 listed_with_another_size=9" run folder on "$work/F/TIES" "$build_a" "$build_b"
t_case "the other build's" 1 "entries=24 host=24 names_shared=0 entries_sharing=0 matched=24 listed_with_another_size=0" run folder on "$work/F/TIES" "$build_a" "$build_b"
t_derive "$f/folder"; printf 'lfn|none|err=29184\nsfn|AAAAAA~1.TXT|20|1\nsfn|AAAAAA~1.TXT|20|1\nend|lines=3\n' > "$derived/1/ALIASES.TXT"; t_play "$derived"
t_case "long names on and the long-name listing refused" 3 "build 1 listed nothing" run folder on "$work/F/TIES" "$build_a" "$build_b"

t_play "$f/cases"
STUB_RC=3 t_case "the launcher refuses the run" 3 "did not run to its end" run cases on "$build_a"
t_case "neither on nor off" 2 "on or off" run cases maybe "$build_a"
t_case "neither cases nor folder" 2 "cases or folder, not: listing" run listing on "$build_a"
t_case "an option it does not know" 2 "unknown option: --raw" run cases on --raw "$build_a"
t_case "a parent that is not a directory" 2 "not a directory: $work/none" run cases on --parent "$work/none" "$build_a"
t_case "a folder that is not a directory" 2 "not a directory: $work/none" run folder on "$work/none" "$build_a"
t_case "no build" 2 "usage:" run cases on
t_case "its own help" 0 "usage: aliases.sh cases" run --help
t_end
