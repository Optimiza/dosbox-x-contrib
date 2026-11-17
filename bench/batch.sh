#!/usr/bin/env bash
# The timers' detached batch: every cell of a jobs file as three calls of its timer (A against B,
# A against A, B against B), with the host sampled throughout; a cell that ran on a busy host is
# run again, whole. See README.md beside this script, "The timers".
set -u

usage() {
    cat <<'EOT'
usage: batch.sh <jobs file> <out dir>

  <jobs file>  one cell a line, '#' a comment:
                 <label>|<p5time|p5rep>|<key A>|<key B>|<folder>|<on|off>|<case or ->|<pairs>
               a key names a build through the environment: BASE is $P5_BUILD_BASE
  <out dir>    gets batch.log, load.txt (loadwatch.sh's samples), pids.txt, jobs.txt (the jobs
               file, which analyze.py reads), and <label>/try<n>/ for each cell and try: each
               call's output, its runs' files and judge.txt

the synthetic folders are made once, before anything is timed. After its three calls judge.py
says whether the cell ran on a quiet host; a BUSY cell is run again, until the host has been
busy for an hour; a cell with no timed line is not judged, and the batch goes on to the next.

environment:
  P5_BUILD_<KEY>  the DOSBox-X executable a key of the jobs file names
  P5_SCRIPTS      the folder the timers, loadwatch.sh and judge.py are run from (default: this
                  one): the seam of batch.test.sh, whose stand-ins play them

exit: 0 every cell ran quiet | 2 usage, or a key no build is named for
      3 a timer call was INVALID, a cell held no timed line, or a folder could not be made
      4 BUSY: the host was not quiet for over an hour
EOT
}

if [ $# -eq 1 ] && [ "$1" = "--help" ]; then usage; exit 0; fi
if [ $# -ne 2 ]; then usage >&2; exit 2; fi
jobs=$1 out=$2
here=$(cd "$(dirname "$0")" && pwd) || exit 2
scripts=${P5_SCRIPTS:-$here}
if [ ! -f "$jobs" ]; then echo "batch.sh: no jobs file: $jobs" >&2; exit 2; fi
mkdir -p "$out" || exit 3
cp "$jobs" "$out/jobs.txt" || exit 3
log=$out/batch.log
say() { echo "$(date +%s) $(date '+%H:%M:%S') $*" >> "$log"; }

build_of() {
    local var=P5_BUILD_$1
    case "$1" in ''|*[!A-Z0-9_]*) return 1 ;; esac
    [ -n "${!var:-}" ] || return 1
    echo "${!var}"
}

run=$(mktemp -d "${TMPDIR:-/tmp}/dircache-batch.XXXXXX") || exit 3
watch_pid=""
# shellcheck disable=SC2329  # called by the EXIT trap
finish() {
    [ -n "$watch_pid" ] && kill "$watch_pid" 2> /dev/null
    rm -rf "$run"
    say "end, run directory $run removed"
}
trap finish EXIT
trap 'exit 143' TERM INT HUP

export P5_FOLDERS=$run/folders TMPDIR=$run
echo "batch $$ run=$run" > "$out/pids.txt"
say "start, batch pid $$, run directory $run, jobs $jobs"

"$scripts/loadwatch.sh" "$out/load.txt" 10 &
watch_pid=$!
echo "loadwatch $watch_pid" >> "$out/pids.txt"

# The synthetic folders, made before anything is timed, with common.sh's own names.
while IFS='|' read -r _ _ _ _ folder _ _ _ || [ -n "${folder:-}" ]; do
    case "$folder" in
        synthetic:*)
            spec=${folder#synthetic:} n=${spec%%:*} style=${spec#*:}
            d=$P5_FOLDERS/$n-$style/DIR
            [ -d "$d" ] && continue
            say "making $d"
            tool=batch.sh here=$here bash -c '. "$here/common.sh"; folder_make "$1" "$2" "$3"' _ "$d" "$n" "$style" < /dev/null || { say "could not make $d"; exit 3; }
            say "made $d: $(find "$d" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ') entries"
            ;;
    esac
done < <(command grep -v '^#' "$jobs")

busy_since=""
status=0
while IFS='|' read -r label timer ka kb folder lfn kase pairs || [ -n "${label:-}" ]; do
    case "$label" in ''|'#'*) continue ;; esac
    if ! a=$(build_of "$ka") || ! b=$(build_of "$kb"); then say "$label: no build named for $ka or $kb"; echo "batch.sh: $label: no build named for $ka or $kb (P5_BUILD_<key>)" >&2; exit 2; fi
    host=$folder
    case "$folder" in synthetic:*) spec=${folder#synthetic:}; host=$P5_FOLDERS/${spec%%:*}-${spec#*:}/DIR ;; esac
    try=1
    while :; do
        cell=$out/$label/try$try
        mkdir -p "$cell"
        ls -f "$host" > /dev/null
        say "$label try $try: start ($ka $kb $folder $lfn $kase pairs=$pairs)"
        for call in "AB:$a:$b" "AA-$ka:$a:$a" "AA-$kb:$b:$b"; do
            name=${call%%:*} rest=${call#*:}
            ba=${rest%%:*} bb=${rest#*:}
            if [ "$timer" = p5time ]; then
                "$scripts/p5time.sh" "$ba" "$bb" "$folder" "$lfn" "$pairs" "$cell/$name" < /dev/null > "$cell/$name.out" 2> "$cell/$name.err"
            else
                "$scripts/p5rep.sh" "$ba" "$bb" "$folder" "$lfn" "$kase" "$pairs" "$cell/$name" < /dev/null > "$cell/$name.out" 2> "$cell/$name.err"
            fi
            rc=$?
            echo "rc=$rc" >> "$cell/$name.out"
            say "$label try $try: $name exit $rc"
            if [ "$rc" -ge 2 ]; then status=3; fi
        done
        verdict=$(python3 -I "$scripts/judge.py" "$out/load.txt" "$cell" < /dev/null 2>&1)
        echo "$verdict" > "$cell/judge.txt"
        say "$label try $try: $verdict"
        case "$verdict" in
            QUIET*) busy_since=""; break ;;
            INVALID*) status=3; break ;;
        esac
        [ -n "$busy_since" ] || busy_since=$(date +%s)
        if [ $(( $(date +%s) - busy_since )) -gt 3600 ]; then
            say "BUSY: the host was not quiet for more than an hour; stopping"
            exit 4
        fi
        try=$((try + 1))
    done
done < "$jobs"
say "all cells done, status $status"
exit "$status"
