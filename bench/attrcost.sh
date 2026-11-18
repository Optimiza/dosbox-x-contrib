#!/usr/bin/env bash
# Runs ATTRCOST.EXE headless on one DOSBox-X build that counts its reads of the host's folders,
# and prints how many reads a loop of attribute changes, deletes or creates cost it. See README.md
# beside this script.
set -u

usage() {
    cat <<'EOT'
usage: attrcost.sh <build> <folder> <mode> <K>

  <build>   a DOSBox-X executable that logs each read of a folder from the host: a build of
            the source with counters/count-dir.diff applied (it applies to unpatched upstream
            and to the branches cut from it). Any other build is INVALID here
  <folder>  synthetic:<count>:83, a folder of <count> empty files made for this run, or a host
            directory, whose names are made as empty files in a folder of this run: ATTRCOST
            deletes and makes files, and the folder handed is never written. Its name goes on
            a DOS command line: no spaces, and an 8.3 name
  <mode>    what ATTRCOST repeats after searching the folder twice (b, the baseline, repeats
            nothing):
              s  4301h on a file, then a 4Eh for another file's name
              m  libc remove() of a file made for it (4301h, then 41h), then the 4Eh
              u  41h alone on a file made for it, then the 4Eh
              c  a file created and closed (3Ch, 3Eh), then the 4Eh
  <K>       how many times, 1 to 2000; the folder holds at least K+2 plain files

long names off. prints one line: the mode, K, the folder, its entries before and after,
host_reads (every read of a folder the build logged), reads_of_the_folder (those of the
folder itself), entries_read (the entries those reads brought), ATTRCOST's own lines (the
baseline's names, then done= the calls that answered, found= the 4Eh that did, guest_us= the
loop's time on the guest's clock), the emulator's version line and its path. The count of reads
does not depend on the host's load; the guest's time does.

environment:
  DJDIR                 the DJGPP cross toolchain (default: $HOME/djgpp)
  DIRCACHE_PREBUILT     a folder holding ATTRCOST.EXE built on another host, instead of DJGPP

exit: 0 measured | 2 usage
      3 INVALID: the build logged no read of a folder (it carries no counter), ATTRCOST did not
        reach its trailer, or the emulator failed; the run's directory is kept and named
EOT
}

SECONDS_BOUND=3000

if [ $# -eq 1 ] && [ "$1" = "--help" ]; then usage; exit 0; fi
if [ $# -ne 4 ]; then usage >&2; exit 2; fi
binary=$1 folder=$2 mode=$3 k=$4

tool=attrcost.sh
here=$(cd "$(dirname "$0")" && pwd) || exit 2
if [ ! -f "$here/common.sh" ]; then echo "attrcost.sh: common.sh is missing beside the script" >&2; exit 3; fi
# shellcheck source=common.sh
. "$here/common.sh"
need_builds "$binary"
lfn_parse off
case "$mode" in b|s|m|u|c) ;; *) fail_usage "no such mode: $mode" ;; esac
case "$k" in ''|*[!0-9]*|?????*) fail_usage "K is 1 to 2000: $k" ;; esac
if [ "$k" -lt 1 ] || [ "$k" -gt 2000 ]; then fail_usage "K is 1 to 2000: $k"; fi
folder_parse "$folder"
if [ -n "$synth_count" ] && [ "$synth_style" != 83 ]; then fail_usage "long names are off: the synthetic folder is of 8.3 names: $folder"; fi
if [ -z "$synth_count" ]; then
    case "$(basename "$folder")" in *' '*) fail_usage "the folder's name goes on a DOS command line: no spaces: $folder" ;; esac
    is_83 "$(basename "$folder")" || fail_usage "with long names off the guest cannot reach a folder whose name is not 8.3: $folder"
fi
need_tools

run_begin cost
run=$tmp/run
guest_build ATTRCOST "$run" || invalid "ATTRCOST did not build"
if [ -n "$synth_count" ]; then
    folder_resolve "$folder" off
else
    # The host folder's names, as empty files of this run's own.
    parent=$tmp/tree base=$(basename "$folder")
    mkdir -p "$parent/$base" || invalid "could not make the folder"
    (cd "$folder" && find . -mindepth 1 -maxdepth 1 -type f) | while IFS= read -r name; do
        : > "$parent/$base/${name#./}" || exit 1
    done || invalid "could not make the folder's names"
    host_count=$(find "$parent/$base" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')
fi
conf_write "$run" "$parent" "" "c:" "ATTRCOST.EXE $mode D:\\$base $k C:\\COST.TXT"
emu_run "the run" "$binary" "$run" COST.TXT "$SECONDS_BOUND" || invalid "the emulator did not run to its end"

LC_ALL=C tr -d '\r' < "$run/COST.TXT" > "$tmp/cost.txt" || invalid "the report could not be read"
exact_whole "$tmp/cost.txt" || invalid "ATTRCOST's report has no line or no trailer"
LC_ALL=C tr -d '\r' < "$emu_dir/dosbox.log" | command grep -a 'HOST-DIR-READ read=' > "$tmp/reads.txt"
reads=$(wc -l < "$tmp/reads.txt" | tr -d ' ')
# The baseline searches the folder, so a build that counts reads has read it at least once.
if [ "$reads" -eq 0 ]; then invalid "the build logged no read of a folder: it needs the counter of counters/count-dir.diff"; fi
entries=$(sed -n 's/.*HOST-DIR-READ read=.* total_entries=\([0-9]*\) .*/\1/p' "$tmp/reads.txt" | tail -n 1)
of_folder=$(command grep -a -c "dir=.*[\\/]${base}[\\/]\$" "$tmp/reads.txt")
after=$(find "$parent/$base" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')
echo "attrcost.sh: mode=$mode k=$k folder=$folder entries=$host_count entries_after=$after host_reads=$reads reads_of_the_folder=$of_folder entries_read=${entries:-0} $(tr '\n' ' ' < "$tmp/cost.txt")build=\"$emu_version\" binary=$binary"
