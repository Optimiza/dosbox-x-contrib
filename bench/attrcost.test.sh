#!/usr/bin/env bash
# attrcost.sh's figures against captured runs, no emulator: bash attrcost.test.sh
# fixtures/attrcost and attrcost-without are mode s, K=10, in a large real folder on
# Windows, on a build that counts its host reads: with the cache emptied at every attribute
# change, then without; their log holds the counter's lines, the host's paths replaced by
# C:\RUN. fixtures/attrcost-nocounter is a run on macOS on a build with no counter.
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
f=$here/fixtures
mkdir -p "$work/MIDI" "$work/My Folder" "$work/LONGFOLDER" || exit 3
: > "$work/MIDI/A.MID"; : > "$work/MIDI/B.MID"; : > "$work/MIDI/Long name.mid"
run() { "$here/attrcost.sh" "$build_a" "$@"; }

t_play "$f/attrcost"
t_case "every read of a folder counted, and those of the folder itself" 0 "host_reads=26 reads_of_the_folder=11 entries_read=1860253" run "$work/MIDI" s 10
t_case "the probe's own lines" 0 "cost|baseline|names=12 cost|loop|mode=s k=10 done=10 found=10" run "$work/MIDI" s 10
t_case "the host folder's names, made in the run" 0 "folder=$work/MIDI entries=3 entries_after=3" run "$work/MIDI" s 10
t_case "a folder of another name is not this one" 0 "reads_of_the_folder=0" run synthetic:20:83 s 10
t_play "$f/attrcost-without"
t_case "without the emptying, one read of the folder" 0 "host_reads=6 reads_of_the_folder=1 entries_read=169143" run "$work/MIDI" s 10
t_play "$f/attrcost-nocounter"
t_case "a build with no counter" 3 "the build logged no read of a folder: it needs the counter of counters/count-dir.diff" run synthetic:100:83 s 5
t_derive "$f/attrcost"; sed -i '' '$d' "$derived/1/COST.TXT"; t_play "$derived"
t_case "a report cut before its trailer" 3 "ATTRCOST's report has no line or no trailer" run "$work/MIDI" s 10
t_play "$f/attrcost"
STUB_RC=3 t_case "the launcher refuses the run" 3 "did not run to its end" run "$work/MIDI" s 10
t_case "no such mode" 2 "no such mode: z" run "$work/MIDI" z 10
t_case "K of none" 2 "K is 1 to 2000: 0" run "$work/MIDI" s 0
t_case "K past the probe's room" 2 "K is 1 to 2000: 2001" run "$work/MIDI" s 2001
t_case "long names in a synthetic folder" 2 "the synthetic folder is of 8.3 names" run synthetic:20:long s 10
t_case "a folder whose name has a space" 2 "no spaces" run "$work/My Folder" s 10
t_case "a folder whose name is not 8.3" 2 "not 8.3" run "$work/LONGFOLDER" s 10
t_case "three arguments" 2 "usage:" run "$work/MIDI" s
t_case "its own help" 0 "usage: attrcost.sh" "$here/attrcost.sh" --help
t_end
