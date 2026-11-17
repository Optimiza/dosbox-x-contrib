#!/usr/bin/env bash
# Runs every script of this folder on two or three DOSBox-X builds and prints one line per cell,
# in one fixed order: the script's own verdict and what it counted. The calls themselves run side
# by side where they can. See README.md beside this script.
set -u

usage() {
    cat <<'EOT'
usage: battery.sh [--real-dos] [--raw <directory>] [--only <group>]... <base> <build> [<third build>]

  <base>             the DOSBox-X executable <build> is compared with
  <build>            the one under test
  <third build>      another one <build> is compared with as well
  --real-dos         adds FINDLIFE, EXACT, ENUMSTAT, DRIFT, DTADUMP, PATLIST, TEMPLATE,
                     FINDPOS, MEMPROBE's lookups, FC and XCOPY on the DOS of a disk image,
                     with <build> as the machine, and the reporters' files where they are named
  --raw <directory>  keeps there what every script printed, one file per call named by the
                     call, and schedule.txt, when each call started and ended. The directory
                     is empty or absent
  --only <group>     runs that group of cells and prints every other cell as "not run"; given
                     again, one more group. The groups:
                       selftest   the scripts' own tests
                       answers    run, findlife, exact, drift, dtadump, patlist, template,
                                  findpos, attrprobe, ties, enumstat, xcopy, passfail, unit
                       folders    run on the folders of styles dots, mix and wine
                       attrsem    attrsem
                       delete     delete
                       aliases    aliases
                       memory     memory, fc
                       realdos    the DOS of the image (needs --real-dos)
                       reporters  junktest, dirtest, and with --real-dos their runs on the image

runs, in this order: the scripts' own tests, run.sh, memory.sh, fc.sh, findlife.sh, exact.sh,
drift.sh, dtadump.sh, patlist.sh, template.sh, findpos.sh, attrprobe.sh, attrsem.sh, delete.sh,
ties.sh, aliases.sh, enumstat.sh, xcopy.sh, passfail.sh, unit.sh, when asked realdos.sh, and last junktest.sh and dirtest.sh
(with their realdos.sh arms when asked), whose cells print "not run" unless the environment
names the reporters' files.
A script that compares two builds runs on base against build, then on the third build against
build; one that measures a single build runs on each.

how they run: the tests and the answers one after another; beside them, the memory cells, the
reporters' runs and the arms of the image's DOS, as many at once as half the host's cores and
half its memory allow. A memory cell counts for the most memory its recording (fixtures/battery)
shows on any build; one that needs over half of that memory runs with no other memory cell, and
one with no recording counts for all of it. An arm of the image's DOS counts for the least any
recorded memory cell holds: the image's DOS keeps no folder in the emulator. A run that holds a
memory or an image group waits while another battery holding one runs on this host.

prints the builds with their sha256, how many calls run at once and in how much memory, then one
line per cell:

  cell|<name>|<long names: on, off or ->|<verdict>|<figures>

  <name>     the script, what it ran on, and base:build, third:build or the build measured
  <verdict>  the script's own: IDENTICAL or ALIKE, DIFFERENT, ran (a script that compares
             nothing), INVALID, or "not run" where this host cannot run the cell or --only
             left it out
  <figures>  what the script counted; for INVALID and "not run", why

and a last line with how many cells it printed, how many INVALID and how many not run. It judges
nothing: a DIFFERENT, a failed test or a figure that grew is for whoever reads the lines.

environment:
  DIRCACHE_REAL_FOLDER  the large host folder of the cells named real: a name with no space
                        that fits 8.3
  DIRCACHE_REAL_FILE    a file of it, as the guest names it
  DIRCACHE_REGRESSION   the folder holding FINDTEST.EXE and LFNTEST.EXE (README.md, passfail.sh)
  DIRCACHE_BOOT_IMAGE   with --real-dos, the disk image realdos.sh boots
  DIRCACHE_JUNKTEST     the files attached to upstream issue 6827, unpacked (junktest.sh)
  DIRCACHE_DIRTEST      the files attached to upstream issue 2485, unpacked (dirtest.sh)
  DIRCACHE_SCRIPTS      the folder the scripts are run from (default: this one): the seam of
                        battery.test.sh, whose stand-in plays the call DIRCACHE_CALL names
  DIRCACHE_MEMORY_KB    the host's memory in kB (default: what the host says): the seam of
                        battery.test.sh
  XDG_STATE_HOME        where the lock is kept: <it, default ~/.local/state>/dosbox-x-dircache
  DJDIR, DIRCACHE_PREBUILT  as every script takes them

exit: 0 every cell ran | 2 usage
      3 at least one cell is INVALID: it examined nothing; or --only left cells out. What the
        scripts printed is then kept and named, unless --raw already keeps it
EOT
}

RUN_SIZES="1000 10000 50000"
# The folders that exercise how aliases are numbered: the list put out of order, prefixes whose
# numbers have other lengths, real files named as Wine-style short names.
STYLE_FOLDERS="synthetic:432:dots synthetic:10240:mix synthetic:120:wine"
MEMORY_FOLDER=synthetic:50000:long
MEMORY_MODES="a d f r"
MEMORY_CALLS="1 20"
# With long names off a search by an exact name stays open: d is one left open, c one still
# open when its process ends.
OPEN_FOLDER=synthetic:50000:83
OPEN_MODES="d c"
# The same search with wildcards: one of the whole folder, left open.
OPEN_WHOLE='*.*'
# Enough calls to walk the emulator's search table many times over.
KEEPALIVE_FOLDER=synthetic:100:long
KEEPALIVE_CALLS=20000
KEEPALIVE_MODES="a v"
# One lookup by name for each file of a folder, none continued, and FC run again and again
# in a folder of empty files: two cases as they were reported upstream.
EACH_FOLDER=synthetic:1835:83
EACH_CALLS="1 1835"
FC_FILES=700
FC_RUNS="1 300"
PASSFAIL_PROGRAMS="FINDTEST LFNTEST"
PASSFAIL_FOLDERS="synthetic:40:long synthetic:10000:long"
SELF_TESTS="run memory fc findlife exact drift dtadump patlist template findpos attrprobe attrsem attrcost resprb delete aliases ties enumstat xcopy passfail unit realdos junktest dirtest p5time p5rep judge batch"
REALDOS_PROGRAMS="findlife exact enumstat drift dtadump patlist template findpos findpos-labelled memprobe fc xcopy"
TEMPLATE_VOLUMES="fat host"
FINDPOS_VOLUMES="labelled unlabelled"
# The reporter's run of upstream issue 6827 and the two steps before its end, so that what each
# batch file adds can be read; long names off, as both reporters' confs leave them.
JUNKTEST_RUNS=("300" "300 JUNK" "300 JUNK 300")
CELL_GROUPS="selftest answers folders attrsem delete aliases memory realdos reporters"
# How often the calls that run side by side are looked at: a call ends between two looks.
POLL_SECONDS=0.1

if [ $# -eq 1 ] && [ "$1" = "--help" ]; then usage; exit 0; fi

tool=battery.sh
here=$(cd "$(dirname "$0")" && pwd) || exit 2
if [ ! -f "$here/common.sh" ]; then echo "battery.sh: common.sh is missing beside the script" >&2; exit 3; fi
# shellcheck source=common.sh
. "$here/common.sh"

real_dos=0 raw="" builds=() only=""
while [ $# -gt 0 ]; do
    case "$1" in
        --real-dos) real_dos=1 ;;
        --raw)
            if [ $# -lt 2 ]; then fail_usage "--raw takes a directory"; fi
            raw=$2
            shift
            ;;
        --only)
            if [ $# -lt 2 ]; then fail_usage "--only takes a group: $CELL_GROUPS"; fi
            case " $CELL_GROUPS " in *" $2 "*) ;; *) fail_usage "no such group: $2 (the groups: $CELL_GROUPS)" ;; esac
            only="$only $2"
            shift
            ;;
        --*) fail_usage "unknown option: $1" ;;
        *) builds+=("$1") ;;
    esac
    shift
done
if [ "${#builds[@]}" -ne 2 ] && [ "${#builds[@]}" -ne 3 ]; then usage >&2; exit 2; fi
case " $only " in *" realdos "*) if [ "$real_dos" -eq 0 ]; then fail_usage "--only realdos needs --real-dos"; fi ;; esac
need_builds "${builds[@]}"
base=${builds[0]} build=${builds[1]} third=${builds[2]:-}
pairs="base:build" singles="base build"
if [ -n "$third" ]; then pairs="base:build third:build" singles="base build third"; fi

scripts=${DIRCACHE_SCRIPTS:-$here}
real_folder=${DIRCACHE_REAL_FOLDER:-} real_file=${DIRCACHE_REAL_FILE:-}
regression=${DIRCACHE_REGRESSION:-} image=${DIRCACHE_BOOT_IMAGE:-}
junktest=${DIRCACHE_JUNKTEST:-} dirtest=${DIRCACHE_DIRTEST:-}
if [ ! -d "$real_folder" ]; then fail_usage "DIRCACHE_REAL_FOLDER is not a directory: $real_folder"; fi
if [ -z "$real_file" ] || [ ! -f "$real_folder/$real_file" ]; then
    fail_usage "DIRCACHE_REAL_FILE is not a file of the real folder: $real_file"
fi
for program in $PASSFAIL_PROGRAMS; do
    if [ ! -f "$regression/$program.EXE" ]; then fail_usage "DIRCACHE_REGRESSION holds no $program.EXE: $regression"; fi
done
if [ "$real_dos" -eq 1 ] && [ "$HOST_KIND" != windows ] && [ ! -f "$image" ]; then
    fail_usage "--real-dos needs DIRCACHE_BOOT_IMAGE, a disk image: $image"
fi
if [ -n "$raw" ]; then
    if ! mkdir -p "$raw"; then fail_usage "the directory for --raw cannot be made: $raw"; fi
    if [ -n "$(ls -A "$raw")" ]; then fail_usage "the directory for --raw already holds files: $raw"; fi
fi

# What the host has: half its cores and half its memory go to the calls that run side by side,
# the rest to the calls that run one after another and to whatever else the host runs.
if [ -n "${DIRCACHE_MEMORY_KB:-}" ]; then
    memory_kb=$DIRCACHE_MEMORY_KB
elif [ "$HOST_KIND" = windows ]; then
    memory_kb=$(awk '/^MemTotal:/ { print $2 }' /proc/meminfo)
else
    memory_kb=$(($(sysctl -n hw.memsize) / 1024))
fi
if [ "$HOST_KIND" = windows ]; then cores=$(nproc); else cores=$(sysctl -n hw.ncpu); fi
case "$memory_kb" in ''|*[!0-9]*) fail_usage "the host's memory is not a number of kB: $memory_kb" ;; esac
case "$cores" in ''|*[!0-9]*) echo "battery.sh: the host's cores could not be read: $cores" >&2; exit 3 ;; esac
budget_kb=$((memory_kb / 2)) pool_jobs=$((cores / 2))
if [ "$pool_jobs" -lt 1 ]; then pool_jobs=1; fi
footprints=$here/fixtures/battery

tmp=$(mktemp -d "${TMPDIR:-/tmp}/dircache-battery.XXXXXX") || exit 3
keep=0 serial_pid="" lock="" phase=plan
mkdir "$tmp/plan" "$tmp/out" || exit 3
# A signal has to end every script in flight, each of which ends its own emulator.
finish() {
    local i
    if [ -n "$serial_pid" ]; then kill "$serial_pid" 2> /dev/null; wait "$serial_pid" 2> /dev/null; fi
    for i in ${pool_running:-}; do kill "${call_pid[$i]}" 2> /dev/null; wait "${call_pid[$i]}" 2> /dev/null; done
    if [ -n "$lock" ]; then rm -rf "$lock"; fi
    [ "$keep" -eq 1 ] || rm -rf "$tmp"
}
trap finish EXIT
trap 'exit 143' TERM INT HUP
raw_named=1
if [ -z "$raw" ]; then
    raw=$tmp/raw raw_named=0
    mkdir "$raw" || exit 3
fi

selected() {
    if [ -z "$only" ]; then return 0; fi
    case " $only " in *" $1 "*) return 0 ;; esac
    return 1
}

build_of() {
    case "$1" in base) echo "$base" ;; build) echo "$build" ;; third) echo "$third" ;; esac
}

digest() { shasum -a 256 "$1" | cut -c1-"${2:-12}"; }

# call_key <name> <long names>: the name of a call's file, from its cell's name.
call_key() {
    local k=$1
    if [ "$2" != - ]; then k="$k $2"; fi
    k=${k// /_} k=${k//:/-} k=${k//\*/@}
    printf '%s' "$k"
}

# The most memory a recording shows for the cell on any build, in kB: every *_kb figure of its
# line. Empty when nothing of it is recorded.
recorded_kb() {
    local stem=$1 lfn=$2 who file files=()
    for who in base build third; do
        file=$footprints/$(call_key "$stem $who" "$lfn").txt
        if [ -f "$file" ]; then files+=("$file"); fi
    done
    if [ "${#files[@]}" -eq 0 ]; then return 0; fi
    awk 'FNR > 1 {
            while (match($0, /_kb=[0-9]+/)) { n = substr($0, RSTART + 4, RLENGTH - 4) + 0; if (n > m) m = n; $0 = substr($0, RSTART + RLENGTH) }
        }
        END { if (m) print m }' "${files[@]}"
}

# The least any recorded memory cell holds: the emulator with no folder in its cache.
idle_kb() {
    local min
    min=$(cat "$footprints"/memory_*.txt 2> /dev/null | awk '{
            while (match($0, /held_[a-z]+_kb=[0-9]+/)) { n = substr($0, RSTART, RLENGTH); sub(/.*=/, "", n); n += 0; if (m == "" || n < m) m = n; $0 = substr($0, RSTART + RLENGTH) }
        }
        END { print m }')
    echo "${min:-$budget_kb}"
}

calls=0 serial_list="" pool_list=""
call_file=() call_script=() call_line=() call_foot=() call_measured=() call_pid=()

# plan_add <name> <long names> <group> <script> <argument>...: one call, its lane and the memory
# it counts for.
plan_add() {
    local name=$1 lfn=$2 group=$3 script=$4 key foot measured=0 i=$calls
    shift 4
    key=$(call_key "$name" "$lfn")
    if [ -f "$tmp/plan/keys" ] && command grep -qxF "$key" "$tmp/plan/keys"; then
        echo "battery.sh: two calls are named $key" >&2
        exit 3
    fi
    echo "$key" >> "$tmp/plan/keys"
    printf '%s\n' "$@" > "$tmp/plan/$i.args"
    call_file[i]=$key call_script[i]=$script call_line[i]="$script $*"
    case "$group" in
        memory|realdos|reporters)
            case "$script" in
                memory.sh|fc.sh|junktest.sh|dirtest.sh)
                    measured=1
                    foot=$(recorded_kb "${name% *}" "$lfn")
                    foot=${foot:-$budget_kb}
                    ;;
                *) foot=$idle ;;
            esac
            pool_list="$pool_list $i"
            ;;
        *) serial_list="$serial_list $i" foot=0 ;;
    esac
    call_foot[i]=$foot call_measured[i]=$measured
    calls=$((calls + 1))
}

cells=0 invalid_cells=0 not_run_cells=0 rc=0

# call <name> <long names> <group> <script> <argument>...: while the battery is planned, records
# the call and fails; once the calls have run, sets rc and $tmp/text from what it printed, or
# prints the cell as not run when --only left its group out, and fails.
call() {
    local name=$1 lfn=$2 group=$3 key
    if [ "$phase" = plan ]; then
        if selected "$group"; then plan_add "$@"; fi
        return 1
    fi
    if ! selected "$group"; then
        cell "$name" "$lfn" "not run" "--only left out its group, $group"
        return 1
    fi
    key=$(call_key "$name" "$lfn")
    rc=$(sed -n '1s/^exit=\([0-9]*\) :: .*/\1/p' "$raw/$key.txt" 2> /dev/null)
    if [ -z "$rc" ]; then
        rc=3
        echo "battery.sh: INVALID: the call left no record: $raw/$key.txt" > "$tmp/text"
    else
        sed 1d "$raw/$key.txt" > "$tmp/text"
    fi
    return 0
}

# schedule <what> <key> <field>...: one line of schedule.txt.
schedule() {
    local what=$1 key=$2
    shift 2
    printf '%s|%s|%s|%s\n' "$what" "$(date +%s)" "$key" "$*" >> "$raw/schedule.txt"
}

# job_start <call>: starts it in the background and sets job_pid.
job_start() {
    local i=$1 a=() line
    while IFS= read -r line; do a+=("$line"); done < "$tmp/plan/$i.args"
    DIRCACHE_CALL=${call_file[$i]} "$BASH" "$scripts/${call_script[$i]}" ${a[@]+"${a[@]}"} > "$tmp/out/$i" 2>&1 < /dev/null &
    job_pid=$!
}

# job_end <call> <exit code>: what it printed, into the raw directory.
job_end() {
    local i=$1
    {
        echo "exit=$2 :: ${call_line[$i]}"
        LC_ALL=C tr -d '\r' < "$tmp/out/$i"
    } > "$raw/${call_file[$i]}.txt"
    schedule end "${call_file[$i]}" "exit=$2"
}

# The tests and the answers, one after another, in a lane of their own.
serial_lane() {
    local i c=""
    trap 'if [ -n "$c" ]; then kill "$c" 2> /dev/null; wait "$c" 2> /dev/null; fi; exit 143' TERM INT HUP
    for i in $serial_list; do
        job_start "$i"
        c=$job_pid
        schedule start "${call_file[$i]}" "lane=serial"
        wait "$c"
        job_end "$i" "$?"
        c=""
    done
}

# Whether call <i> may start now, beside what runs: a free slot, room in the memory, and a
# memory cell over half of it alone among the memory cells. Nothing running admits anything.
admits() {
    local i=$1
    if [ "$pool_count" -eq 0 ]; then return 0; fi
    if [ "$pool_count" -ge "$pool_jobs" ]; then return 1; fi
    if [ $((pool_held + call_foot[i])) -gt "$budget_kb" ]; then return 1; fi
    if [ "${call_measured[$i]}" -eq 1 ]; then
        if [ "$big_running" -eq 1 ]; then return 1; fi
        if [ $((call_foot[i] * 2)) -gt "$budget_kb" ] && [ "$measured_count" -gt 0 ]; then return 1; fi
    fi
    return 0
}

# The memory cells, the reporters' runs and the image's arms, side by side. The image's arms
# start first: they hold the longest runs of the battery and little memory. A memory cell that
# cannot start yet holds back the memory cells behind it, so the largest is not passed for ever.
pool() {
    local i pending="" rest="" next blocked
    pool_running="" pool_count=0 pool_held=0 measured_count=0 big_running=0
    for i in $pool_list; do
        if [ "${call_script[$i]}" = realdos.sh ]; then pending="$pending $i"; else rest="$rest $i"; fi
    done
    pending="$pending $rest"
    while [ -n "${pending// /}" ] || [ -n "$pool_running" ]; do
        next=""
        for i in $pool_running; do
            if kill -0 "${call_pid[$i]}" 2> /dev/null; then next="$next $i"; continue; fi
            wait "${call_pid[$i]}"
            job_end "$i" "$?"
            pool_count=$((pool_count - 1)) pool_held=$((pool_held - call_foot[i]))
            if [ "${call_measured[$i]}" -eq 1 ]; then
                measured_count=$((measured_count - 1))
                if [ $((call_foot[i] * 2)) -gt "$budget_kb" ]; then big_running=0; fi
            fi
        done
        pool_running=$next
        next="" blocked=0
        for i in $pending; do
            if [ "${call_measured[$i]}" -eq 1 ] && [ "$blocked" -eq 1 ]; then next="$next $i"; continue; fi
            if ! admits "$i"; then
                if [ "${call_measured[$i]}" -eq 1 ]; then blocked=1; fi
                next="$next $i"
                continue
            fi
            job_start "$i"
            call_pid[i]=$job_pid
            schedule start "${call_file[$i]}" "lane=pool footprint_kb=${call_foot[$i]} beside=$pool_count measured_beside=$measured_count held_kb=$((pool_held + call_foot[i]))"
            pool_running="$pool_running $i"
            pool_count=$((pool_count + 1)) pool_held=$((pool_held + call_foot[i]))
            if [ "${call_measured[$i]}" -eq 1 ]; then
                measured_count=$((measured_count + 1))
                if [ $((call_foot[i] * 2)) -gt "$budget_kb" ]; then big_running=1; fi
            fi
        done
        pending=$next
        if [ -n "$pool_running" ]; then sleep "$POLL_SECONDS"; fi
    done
}

# Two batteries that hold memory cells at once can exhaust the host's memory: the second waits.
# The lock is a directory holding its battery's pid; one whose pid is gone was left by a battery
# that did not end cleanly.
lock_take() {
    local dir=${XDG_STATE_HOME:-$HOME/.local/state}/dosbox-x-dircache owner said=0 unnamed=0
    if ! mkdir -p "$dir"; then echo "battery.sh: the state folder cannot be made: $dir" >&2; exit 3; fi
    while ! mkdir "$dir/battery.lock" 2> /dev/null; do
        owner=$(cat "$dir/battery.lock/pid" 2> /dev/null)
        # A lock with no pid yet is being taken; still none a second later, it never will be.
        if [ -z "$owner" ]; then unnamed=$((unnamed + 1)); else unnamed=0; fi
        if { [ -n "$owner" ] && ! kill -0 "$owner" 2> /dev/null; } || [ "$unnamed" -gt 1 ]; then
            echo "battery.sh: the lock of a battery that is gone (pid ${owner:-none}) is taken: $dir/battery.lock" >&2
            rm -rf "$dir/battery.lock"
            continue
        fi
        if [ "$said" -eq 0 ]; then
            echo "battery.sh: another battery runs on this host (pid ${owner:-not yet written}): waiting for it to end" >&2
            said=1
        fi
        sleep 1
    done
    lock=$dir/battery.lock
    echo "$$" > "$lock/pid"
}

calls_run() {
    if [ "$calls" -eq 0 ]; then return 0; fi
    if [ -n "$serial_list" ]; then
        serial_lane &
        serial_pid=$!
    fi
    pool
    if [ -n "$serial_pid" ]; then wait "$serial_pid"; serial_pid=""; fi
}

cell() {
    if [ "$phase" = plan ]; then return 0; fi
    cells=$((cells + 1))
    case "$3" in
        INVALID) invalid_cells=$((invalid_cells + 1)) ;;
        "not run") not_run_cells=$((not_run_cells + 1)) ;;
    esac
    printf 'cell|%s|%s|%s|%s\n' "$1" "$2" "$3" "${4//|/ }"
}

# What the script said when it judged nothing.
why() {
    local said
    said=$(command grep -a -m 1 'INVALID' "$tmp/text") || said=$(tail -n 1 "$tmp/text")
    echo "exit=$rc $said"
}

# The word of the call just made: a script that compares answers 0 alike and 1 different, one
# that measures answers 0; any other exit code judged nothing.
pair_word() {
    case "$rc" in 0) echo "$1" ;; 1) echo DIFFERENT ;; *) echo INVALID ;; esac
}
ran_word() {
    if [ "$rc" -eq 0 ]; then echo ran; else echo INVALID; fi
}

# emit <name> <long names> <verdict> <figures>: the cell of the call just made. A call whose
# figures could not be read examined nothing either.
emit() {
    local verdict=$3 figures=$4
    if [ -z "$figures" ]; then verdict=INVALID; fi
    if [ "$verdict" = INVALID ]; then figures=$(why); fi
    cell "$1" "$2" "$verdict" "$figures"
}

# first <sed program>: its first line out of what the script printed.
first() { sed -n "$1" "$tmp/text" | head -n 1; }

# The reports a script prints whole after its "build A:" and "build B:" lines, into
# $tmp/A.txt and $tmp/B.txt.
reports() {
    : > "$tmp/A.txt"
    : > "$tmp/B.txt"
    awk -v s="$1: " -v dir="$tmp" '
        index($0, s "build A: ") == 1 { file = dir "/A.txt"; next }
        index($0, s "build B: ") == 1 { file = dir "/B.txt"; next }
        index($0, s) == 1 { file = ""; next }
        file != "" { print > file }' "$tmp/text"
}

# The cases whose lines differ, each once: a script prints them as "< case|<name>|...".
differing() {
    awk '
        /^[<>] / {
            n = split(substr($0, 3), part, "|")
            if (n < 2) next
            name = (part[1] == "case" || part[1] == "drift" || part[1] == "life" || part[1] == "tie" || part[1] == "pat" || part[1] == "pos" || part[1] == "attr" || part[1] == "sem") ? part[2] : part[1]
            if (part[1] ~ /^(del|alias|search|rmdir|mkdir|rename|host)$/) name = part[1] ":" part[2]
            if (!(name in seen)) { seen[name] = 1; list = list sep name; sep = "," }
        }
        END { print list }' "$tmp/text"
}

# FINDLIFE's cases by how each one reads.
tally() {
    awk -F'|' '
        $1 == "case" { n++; k[$NF]++ }
        END { if (n) printf "cases=%d ok=%d differs=%d not_judged=%d", n, k["ok"], k["DIFFERS"], k["not judged"] }' "$1"
}

figures_run() {
    local entries a b lines
    entries=$(first 's/^run\.sh: folder .* (\([0-9]*\) entries on the host), long names .*/\1/p')
    a=$(first 's/^run\.sh: build A: \(4e=[0-9]* lfn=[0-9]* look=[0-9]*\)$/\1/p')
    b=$(first 's/^run\.sh: build B: \(4e=[0-9]* lfn=[0-9]* look=[0-9]*\)$/\1/p')
    lines=$(first 's/^run\.sh: \([0-9]*\) differing lines in all$/\1/p')
    if [ -z "$entries" ] || [ -z "$a" ] || [ -z "$b" ]; then return 0; fi
    echo "entries=$entries A($a) B($b)${lines:+ differing_lines=$lines}"
}

# The figure a host reads is the third one memory.sh prints: the footprint, or the private bytes.
figures_memory() {
    first 's/^memory\.sh: mode=.* entries=\([0-9]*\) .* \(held_[a-z]*_kb=[0-9]*\) samples=[0-9]* slots_full=\([0-9]*\) guest="mode=[a-z] k=[0-9]* ok=\([0-9]*\) .*/entries=\1 ok=\4 slots_full=\3 \2/p'
}

# The peak is the resident size or the working set while FC ran; the other is the figure a host
# reads once the runs are over.
figures_fc() {
    first 's/^fc\.sh: files=[0-9]* runs=[0-9]* lfn=[a-z]* entries=\([0-9]*\) \(peak_[a-z]*_kb=[0-9]*\) held_[a-z]*_kb=[0-9]* \(held_[a-z]*_kb=[0-9]*\) samples=[0-9]* slots_full=\([0-9]*\) compared=\([0-9]*\) build=.*/entries=\1 compared=\5 slots_full=\4 \2 \3/p'
}

figures_xcopy() {
    first 's/^xcopy\.sh: lfn=[a-z]* \(made=[0-9]* copied=[0-9]* dirs_made=[0-9]* dirs_copied=[0-9]* said=[-0-9]* slots_full=[0-9]* out_of_range=[0-9]*\) build=.*/\1/p'
}

figures_junktest() {
    first 's/^junktest\.sh: batches=[^ ]* lfn=[a-z]* \(entries=[0-9]* junk=[0-9]* counted=[0-9]* done=[0-9]*\) \(peak_[a-z]*_kb=[0-9]*\) held_[a-z]*_kb=[0-9]* \(held_[a-z]*_kb=[0-9]*\) samples=[0-9]* \(slots_full=[0-9]* out_of_range=[0-9]*\) build=.*/\1 \4 \2 \3/p'
}

figures_dirtest() {
    first 's/^dirtest\.sh: lfn=[a-z]* \(files=[0-9]* calls_4f=[0-9]* calls_4e=[0-9]*\) \(peak_[a-z]*_kb=[0-9]*\) held_[a-z]*_kb=[0-9]* \(held_[a-z]*_kb=[0-9]*\) samples=[0-9]* \(slots_full=[0-9]* out_of_range=[0-9]*\) build=.*/\1 \4 \2 \3/p'
}

figures_findlife() {
    local a b differ
    reports findlife.sh
    a=$(tally "$tmp/A.txt") b=$(tally "$tmp/B.txt") differ=$(differing)
    if [ -z "$a" ] || [ -z "$b" ]; then return 0; fi
    echo "A($a) B($b)${differ:+ differ=$differ}"
}

figures_exact() {
    local sections differ
    sections=$(awk '
        /^exact\.sh: (basic|life|shell|tree|drift): / {
            name = $2; sub(/:$/, "", name)
            word = $3; sub(/,$/, "", word)
            count = $4; sub(/^\(/, "", count)
            if (word == "DIFFERENT") count = count "/" $6
            list = list sep name "=" word ":" count; sep = " "; n++
        }
        END { if (n == 5) print list }' "$tmp/text")
    differ=$(differing)
    if [ -z "$sections" ]; then return 0; fi
    echo "$sections${differ:+ differ=$differ}"
}

figures_drift() {
    local cases other differ
    reports drift.sh
    cases=$(command grep -a -c '^drift|' "$tmp/A.txt") other=$(command grep -a -c '^drift|' "$tmp/B.txt")
    differ=$(differing)
    if [ "${cases:-0}" -eq 0 ] || [ "${other:-0}" -eq 0 ]; then return 0; fi
    echo "cases=$cases sha256=$(digest "$tmp/A.txt")/$(digest "$tmp/B.txt")${differ:+ differ=$differ}"
}

# DTADUMP's lines differ by the dozen between two builds: counted, not named.
figures_dtadump() {
    local a b lines
    a=$(first 's/^dtadump\.sh: figures A: //p') b=$(first 's/^dtadump\.sh: figures B: //p')
    lines=$(first 's/^dtadump\.sh: DIFFERENT, \([0-9]*\) lines differ.*/\1/p')
    if [ -z "$a" ] || [ -z "$b" ]; then return 0; fi
    echo "A($a) B($b)${lines:+ differing_lines=$lines}"
}

figures_patlist() {
    local patterns other differ
    reports patlist.sh
    patterns=$(command grep -a -c '^pat|' "$tmp/A.txt") other=$(command grep -a -c '^pat|' "$tmp/B.txt")
    differ=$(differing)
    if [ "${patterns:-0}" -eq 0 ] || [ "${other:-0}" -eq 0 ]; then return 0; fi
    echo "patterns=$patterns sha256=$(digest "$tmp/A.txt")/$(digest "$tmp/B.txt")${differ:+ differ=$differ}"
}

# TEMPLATE's lines hold paths and quotes: counted, not named.
figures_template() {
    local lines other differ
    reports template.sh
    lines=$(command grep -a -c -v '^end|' "$tmp/A.txt") other=$(command grep -a -c -v '^end|' "$tmp/B.txt")
    differ=$(first 's/^template\.sh: DIFFERENT, \([0-9]*\) lines differ.*/\1/p')
    if [ "${lines:-0}" -eq 0 ] || [ "${other:-0}" -eq 0 ]; then return 0; fi
    echo "lines=$lines sha256=$(digest "$tmp/A.txt")/$(digest "$tmp/B.txt")${differ:+ differing_lines=$differ}"
}

figures_findpos() {
    local cases other differ
    reports findpos.sh
    cases=$(command grep -a -c '^pos|' "$tmp/A.txt") other=$(command grep -a -c '^pos|' "$tmp/B.txt")
    differ=$(differing)
    if [ "${cases:-0}" -eq 0 ] || [ "${other:-0}" -eq 0 ]; then return 0; fi
    echo "cases=$cases sha256=$(digest "$tmp/A.txt")/$(digest "$tmp/B.txt")${differ:+ differ=$differ}"
}

figures_attrprobe() {
    local cases other differ
    reports attrprobe.sh
    cases=$(command grep -a -c '^attr|' "$tmp/A.txt") other=$(command grep -a -c '^attr|' "$tmp/B.txt")
    differ=$(differing)
    if [ "${cases:-0}" -eq 0 ] || [ "${other:-0}" -eq 0 ]; then return 0; fi
    echo "cases=$cases sha256=$(digest "$tmp/A.txt")/$(digest "$tmp/B.txt")${differ:+ differ=$differ}"
}

# One build's figures, as aliases.sh prints them between its long-name field and the build.
figures_aliases() {
    first 's/^aliases\.sh: [a-z]* lfn=[a-z]* \(entries=[0-9]* host=[0-9]* names_shared=[0-9]* .*[0-9]\) build=.*/\1/p'
}

# ATTRSEM's lines and the shell's after them, by their digests.
figures_attrsem() {
    local lines other shell differ
    reports attrsem.sh
    lines=$(command grep -a -c '^sem|' "$tmp/A.txt") other=$(command grep -a -c '^sem|' "$tmp/B.txt")
    shell=$(command grep -a -c '^shell|' "$tmp/A.txt")
    differ=$(differing)
    if [ "${lines:-0}" -eq 0 ] || [ "${other:-0}" -eq 0 ] || [ "${shell:-0}" -eq 0 ]; then return 0; fi
    echo "lines=$lines shell=$shell sha256=$(digest "$tmp/A.txt")/$(digest "$tmp/B.txt")${differ:+ differ=$differ}"
}

# DELPRB's steps by their digests, and what each build left on the host.
figures_delete() {
    local lines other left_a left_b differ
    reports delete.sh
    lines=$(command grep -a -c -v '^end|' "$tmp/A.txt") other=$(command grep -a -c -v '^end|' "$tmp/B.txt")
    left_a=$(first 's/^delete\.sh: build A: files the host holds at the end: \(.*\) directories$/\1/p')
    left_b=$(first 's/^delete\.sh: build B: files the host holds at the end: \(.*\) directories$/\1/p')
    differ=$(differing)
    if [ "${lines:-0}" -eq 0 ] || [ "${other:-0}" -eq 0 ] || [ -z "$left_a" ] || [ -z "$left_b" ]; then return 0; fi
    echo "lines=$lines sha256=$(digest "$tmp/A.txt")/$(digest "$tmp/B.txt") A($left_a) B($left_b)${differ:+ differ=$differ}"
}

figures_ties() {
    local ties differ
    ties=$(first 's/^ties\.sh: [A-Z]* (\([0-9]*\) ties).*/\1/p') differ=$(differing)
    if [ -z "$ties" ]; then return 0; fi
    echo "ties=$ties${differ:+ differ=$differ}"
}

figures_passfail() {
    first 's/^passfail\.sh: program=[^ ]* sha256=\([0-9a-f]*\) .* entries=\([0-9]*\) \(pass=[0-9]* fail=[0-9]* exit=[0-9]*\) build=.*/sha256=\1 entries=\2 \3/p'
}

# ENUMSTAT's lines, as enumstat.sh and realdos.sh print them, one per row:
# <long names>|<names>|<mode>|<figures>
enumstat_rows() {
    awk -v prefix="$1" '
        index($0, prefix) == 1 && index($0, " enumstat|mode=") {
            line = substr($0, length(prefix) + 1)
            sub(/ build=".*$/, "", line)
            n = split(line, part, "|")
            if (n != 5) next
            lfn = "off"; names = ""
            m = split(part[1], head, " ")
            for (i = 1; i <= m; i++) {
                if (head[i] ~ /^lfn=/) lfn = substr(head[i], 5)
                if (head[i] ~ /^names=/) names = substr(head[i], 7)
            }
            printf "%s|%s|%s|%s %s %s\n", lfn, names, substr(part[2], 6), part[3], part[4], part[5]
        }' "$tmp/text"
}

cells_self_tests() {
    local t
    for t in $SELF_TESTS; do
        if [ "$HOST_KIND" = windows ]; then
            cell "selftest $t.test.sh" - "not run" "it plays captured runs through a stand-in for launch.sh, the launcher of the other hosts"
            continue
        fi
        call "selftest $t.test.sh" - selftest "$t.test.sh" || continue
        # 1 is a case that failed: the count says so.
        case "$rc" in
            0|1) emit "selftest $t.test.sh" - ran "$(first 's/^\([0-9]*\) cases, \([0-9]*\) failed$/cases=\1 failed=\2/p')" ;;
            *) emit "selftest $t.test.sh" - INVALID "" ;;
        esac
    done
}

# cells_run <the folder's name in the cell> <folder> <on|off> <group>
cells_run() {
    local pair
    for pair in $pairs; do
        call "run $1 $pair" "$3" "$4" run.sh "$(build_of "${pair%%:*}")" "$(build_of "${pair##*:}")" "$2" "$3" || continue
        emit "run $1 $pair" "$3" "$(pair_word IDENTICAL)" "$(figures_run)"
    done
}

# cells_memory <what the cell is named for> <folder> <on|off> <mode> <calls> [--file <name>]
cells_memory() {
    local label=$1 who
    shift
    for who in $singles; do
        call "memory $label $3 $4 $who" "$2" memory memory.sh "$(build_of "$who")" "$@" || continue
        emit "memory $label $3 $4 $who" "$2" "$(ran_word)" "$(figures_memory)"
    done
}

# cells_fc <files> <on|off> <runs>
cells_fc() {
    local who
    for who in $singles; do
        call "fc $1 $3 $who" "$2" memory fc.sh "$(build_of "$who")" "$1" "$2" "$3" || continue
        emit "fc $1 $3 $who" "$2" "$(ran_word)" "$(figures_fc)"
    done
}

# cells_xcopy <on|off>
cells_xcopy() {
    local who
    for who in $singles; do
        call "xcopy $who" "$1" answers xcopy.sh "$(build_of "$who")" "$1" || continue
        emit "xcopy $who" "$1" "$(ran_word)" "$(figures_xcopy)"
    done
}

# cells_pair <script, without .sh> <word for alike> <on|off|-> [<argument>...]
cells_pair() {
    local script=$1 word=$2 lfn=$3 pair figures=""
    shift 3
    for pair in $pairs; do
        call "$script $pair" "$lfn" answers "$script.sh" "$(build_of "${pair%%:*}")" "$(build_of "${pair##*:}")" "$@" || continue
        case "$script" in
            findlife) figures=$(figures_findlife) ;;
            exact) figures=$(figures_exact) ;;
            drift) figures=$(figures_drift) ;;
            dtadump) figures=$(figures_dtadump) ;;
            patlist) figures=$(figures_patlist) ;;
            ties) figures=$(figures_ties) ;;
        esac
        emit "$script $pair" "$lfn" "$(pair_word "$word")" "$figures"
    done
}

# cells_findpos <labelled|unlabelled> <on|off>
cells_findpos() {
    local pair
    for pair in $pairs; do
        call "findpos $1 $pair" "$2" answers findpos.sh "$(build_of "${pair%%:*}")" "$(build_of "${pair##*:}")" "$1" "$2" || continue
        emit "findpos $1 $pair" "$2" "$(pair_word ALIKE)" "$(figures_findpos)"
    done
}

# cells_attrprobe <on|off>
cells_attrprobe() {
    local pair
    for pair in $pairs; do
        call "attrprobe $pair" "$1" answers attrprobe.sh "$(build_of "${pair%%:*}")" "$(build_of "${pair##*:}")" "$1" || continue
        emit "attrprobe $pair" "$1" "$(pair_word ALIKE)" "$(figures_attrprobe)"
    done
}

# cells_attrsem <on|off>
cells_attrsem() {
    local pair
    for pair in $pairs; do
        call "attrsem $pair" "$1" attrsem attrsem.sh "$(build_of "${pair%%:*}")" "$(build_of "${pair##*:}")" "$1" || continue
        emit "attrsem $pair" "$1" "$(pair_word ALIKE)" "$(figures_attrsem)"
    done
}

# cells_delete <on|off>
cells_delete() {
    local pair
    for pair in $pairs; do
        call "delete $pair" "$1" delete delete.sh "$(build_of "${pair%%:*}")" "$(build_of "${pair##*:}")" "$1" || continue
        emit "delete $pair" "$1" "$(pair_word ALIKE)" "$(figures_delete)"
    done
}

# cells_aliases: the folder of cases on and off, then the large real folder, each on one build.
cells_aliases() {
    local who lfn
    for lfn in on off; do
        for who in $singles; do
            call "aliases cases $who" "$lfn" aliases aliases.sh cases "$lfn" "$(build_of "$who")" || continue
            emit "aliases cases $who" "$lfn" "$(ran_word)" "$(figures_aliases)"
        done
    done
    for who in $singles; do
        call "aliases real $who" on aliases aliases.sh folder on "$real_folder" "$(build_of "$who")" || continue
        emit "aliases real $who" on "$(ran_word)" "$(figures_aliases)"
    done
}

# cells_template <fat|host> <on|off>
cells_template() {
    local pair
    for pair in $pairs; do
        call "template $1 $pair" "$2" answers template.sh "$(build_of "${pair%%:*}")" "$(build_of "${pair##*:}")" "$1" "$2" || continue
        emit "template $1 $pair" "$2" "$(pair_word ALIKE)" "$(figures_template)"
    done
}

# One call lists every build: its lines come a row at a time, the builds in the order given.
cells_enumstat() {
    local n=0 count=0 who lfn names mode figures
    for who in $singles; do count=$((count + 1)); done
    call enumstat - answers enumstat.sh "$base" "$build" ${third:+"$third"} || return 0
    enumstat_rows "enumstat.sh: " > "$tmp/rows.txt"
    while IFS='|' read -r lfn names mode figures; do
        # shellcheck disable=SC2086  # the names of the builds, split on purpose
        set -- $singles
        shift $((n % count))
        cell "enumstat $mode $names $1" "$lfn" ran "$figures"
        n=$((n + 1))
    done < "$tmp/rows.txt"
    if [ "$rc" -ne 0 ] || [ "$n" -eq 0 ] || [ $((n % count)) -ne 0 ]; then
        cell "enumstat, the rows it did not print" - INVALID "$(why)"
    fi
}

cells_passfail() {
    local program folder who
    for program in $PASSFAIL_PROGRAMS; do
        for folder in $PASSFAIL_FOLDERS; do
            for who in $singles; do
                call "passfail $program $folder $who" on answers passfail.sh "$(build_of "$who")" "$folder" on "$regression/$program.EXE" || continue
                emit "passfail $program $folder $who" on "$(ran_word)" "$(figures_passfail)"
            done
        done
    done
}

cells_unit() {
    local who
    for who in $singles; do
        call "unit $who" - answers unit.sh "$(build_of "$who")" || continue
        emit "unit $who" - "$(ran_word)" "$(first 's/^unit\.sh: \(tests=[0-9]* failures=[0-9]* errors=[0-9]* disabled=[0-9]*\) build=.*/\1/p')"
    done
}

# The DOS of the image answers, <build> being only the machine: its report is condensed to its
# counts and a digest, so two runs, or a build's own report, can be told equal from the line.
cells_realdos() {
    local what dos counts n lfn names mode figures
    for what in $REALDOS_PROGRAMS; do
        if [ "$HOST_KIND" = windows ]; then
            cell "realdos $what" off "not run" "the disk image is booted on another host: read the lines of a run there"
            continue
        fi
        call "realdos $what" off realdos realdos.sh "$build" "$image" "$what" || continue
        dos=$(first 's/^realdos\.sh: dos|version=\([0-9.]*\) .*/\1/p')
        command grep -a -v '^realdos\.sh: ' "$tmp/text" > "$tmp/A.txt"
        counts="" line=""
        case "$what" in
            memprobe) line=$(first 's/^realdos\.sh: names=83 files=[0-9]* \(mode=e k=[0-9]* ok=[0-9]*\)$/\1/p') ;;
            fc) line=$(first 's/^realdos\.sh: \(files=[0-9]* runs=[0-9]* compared=[0-9]*\)$/\1/p') ;;
            xcopy) line=$(first 's/^realdos\.sh: \(made=[0-9]* copied=[0-9]* dirs_made=[0-9]* dirs_copied=[0-9]* said=[-0-9]*\)$/\1/p') ;;
        esac
        # These three print one line of counts and no report: nothing to digest.
        case "$what" in
            memprobe|fc|xcopy)
                if [ -z "$dos" ] || [ -z "$line" ]; then figures=""; else figures="dos=$dos $line"; fi
                emit "realdos $what" off "$(ran_word)" "$figures"
                continue
                ;;
        esac
        case "$what" in
            findlife) counts=$(tally "$tmp/A.txt") ;;
            exact) counts=$(awk -F'|' '{ k[$1]++ } END { if (k["basic"]) printf "basic=%d life=%d drift=%d", k["basic"], k["life"], k["drift"] }' "$tmp/A.txt") ;;
            drift) counts=$(awk -F'|' '$1 == "drift" { n++ } END { if (n) printf "cases=%d", n }' "$tmp/A.txt") ;;
            findpos|findpos-labelled) counts=$(awk -F'|' '$1 == "pos" { n++ } END { if (n) printf "cases=%d", n }' "$tmp/A.txt") ;;
            dtadump) counts=$(first 's/^realdos\.sh: figures: //p') ;;
            patlist) counts=$(awk -F'|' '$1 == "pat" { n++ } END { if (n) printf "patterns=%d", n }' "$tmp/A.txt") ;;
            template) counts=$(awk -F'|' '$1 != "end" { n++ } END { if (n) printf "lines=%d", n }' "$tmp/A.txt") ;;
            enumstat)
                n=0
                enumstat_rows "realdos.sh: " > "$tmp/rows.txt"
                while IFS='|' read -r lfn names mode figures; do
                    cell "realdos enumstat $mode $names" "$lfn" ran "dos=$dos $figures"
                    n=$((n + 1))
                done < "$tmp/rows.txt"
                if [ "$rc" -ne 0 ] || [ "$n" -eq 0 ] || [ -z "$dos" ]; then
                    cell "realdos enumstat, the rows it did not print" off INVALID "$(why)"
                fi
                continue
                ;;
        esac
        if [ -z "$dos" ] || [ -z "$counts" ]; then figures=""; else figures="dos=$dos $counts sha256=$(digest "$tmp/A.txt")"; fi
        emit "realdos $what" off "$(ran_word)" "$figures"
    done
}

# The files reporters attached to their upstream issues are theirs and are not in this repository:
# a folder the environment does not name is a cell that says so.
cells_reporters() {
    local steps who what folder dos line
    if [ -z "$junktest" ]; then
        cell junktest off "not run" "DIRCACHE_JUNKTEST names no folder: the files of upstream issue 6827 are not in this repository"
    else
        for steps in "${JUNKTEST_RUNS[@]}"; do
            for who in $singles; do
                # shellcheck disable=SC2086  # the batch files, split on purpose
                call "junktest $steps $who" off reporters junktest.sh "$(build_of "$who")" "$junktest" off $steps || continue
                emit "junktest $steps $who" off "$(ran_word)" "$(figures_junktest)"
            done
        done
    fi
    if [ -z "$dirtest" ]; then
        cell dirtest off "not run" "DIRCACHE_DIRTEST names no folder: the files of upstream issue 2485 are not in this repository"
    else
        for who in $singles; do
            call "dirtest $who" off reporters dirtest.sh "$(build_of "$who")" "$dirtest" off || continue
            emit "dirtest $who" off "$(ran_word)" "$(figures_dirtest)"
        done
    fi
    if [ "$real_dos" -eq 0 ]; then return 0; fi
    for what in junktest dirtest; do
        if [ "$what" = junktest ]; then folder=$junktest; else folder=$dirtest; fi
        if [ -z "$folder" ]; then continue; fi
        if [ "$HOST_KIND" = windows ]; then
            cell "realdos $what" off "not run" "the disk image is booted on another host: read the lines of a run there"
            continue
        fi
        call "realdos $what" off reporters realdos.sh "$build" "$image" "$what" "$folder" || continue
        dos=$(first 's/^realdos\.sh: dos|version=\([0-9.]*\) .*/\1/p')
        case "$what" in
            junktest) line=$(first 's/^realdos\.sh: \(batches=[^ ]* entries=[0-9]* junk=[0-9]* counted=[0-9]* done=[0-9]*\)$/\1/p') ;;
            dirtest) line=$(first 's/^realdos\.sh: \(files=[0-9]* returned=1\)$/\1/p') ;;
        esac
        if [ -z "$dos" ] || [ -z "$line" ]; then line=""; else line="dos=$dos $line"; fi
        emit "realdos $what" off "$(ran_word)" "$line"
    done
}

# Every cell in the battery's order: planned once, then printed once the calls have run.
cells_all() {
    local size style lfn mode count volume folder pair
    cells_self_tests
    for size in $RUN_SIZES; do
        for style in 83 long; do
            for lfn in on off; do cells_run "synthetic:$size:$style" "synthetic:$size:$style" "$lfn" answers; done
        done
    done
    for lfn in on off; do cells_run real "$real_folder" "$lfn" answers; done
    for folder in $STYLE_FOLDERS; do
        for lfn in on off; do
            # Windows strips the " ." that ends a third of the dots folder's names.
            if [ "$HOST_KIND" = windows ] && [ "${folder##*:}" = dots ]; then
                for pair in $pairs; do cell "run $folder $pair" "$lfn" "not run" "its names end in \" .\", which Windows' file system takes off"; done
                continue
            fi
            cells_run "$folder" "$folder" "$lfn" folders
        done
    done
    for mode in $MEMORY_MODES; do
        for count in $MEMORY_CALLS; do cells_memory "$MEMORY_FOLDER" "$MEMORY_FOLDER" on "$mode" "$count"; done
    done
    for mode in $MEMORY_MODES; do
        for count in $MEMORY_CALLS; do cells_memory real "$real_folder" on "$mode" "$count" --file "$real_file"; done
    done
    for mode in $OPEN_MODES; do
        for count in $MEMORY_CALLS; do cells_memory "$OPEN_FOLDER" "$OPEN_FOLDER" off "$mode" "$count"; done
    done
    for count in $MEMORY_CALLS; do cells_memory "$OPEN_FOLDER $OPEN_WHOLE" "$OPEN_FOLDER" off d "$count" --file "$OPEN_WHOLE"; done
    for mode in $KEEPALIVE_MODES; do cells_memory "$KEEPALIVE_FOLDER" "$KEEPALIVE_FOLDER" on "$mode" "$KEEPALIVE_CALLS"; done
    for count in $EACH_CALLS; do cells_memory "$EACH_FOLDER" "$EACH_FOLDER" off e "$count"; done
    for count in $FC_RUNS; do cells_fc "$FC_FILES" off "$count"; done
    for lfn in on off; do cells_pair findlife ALIKE "$lfn" "$lfn"; done
    for lfn in on off; do cells_pair exact ALIKE "$lfn" "$lfn"; done
    for lfn in on off; do cells_pair drift ALIKE "$lfn" "$lfn"; done
    for lfn in on off; do cells_pair dtadump ALIKE "$lfn" "$lfn"; done
    for lfn in on off; do cells_pair patlist ALIKE "$lfn" "$lfn"; done
    for volume in $TEMPLATE_VOLUMES; do
        for lfn in on off; do cells_template "$volume" "$lfn"; done
    done
    for volume in $FINDPOS_VOLUMES; do
        for lfn in on off; do cells_findpos "$volume" "$lfn"; done
    done
    for lfn in on off; do cells_attrprobe "$lfn"; done
    for lfn in on off; do cells_attrsem "$lfn"; done
    for lfn in on off; do cells_delete "$lfn"; done
    cells_pair ties ALIKE on
    cells_aliases
    cells_enumstat
    for lfn in on off; do cells_xcopy "$lfn"; done
    cells_passfail
    cells_unit
    if [ "$real_dos" -eq 1 ]; then cells_realdos; fi
    cells_reporters
}

idle=$(idle_kb)
cells_all
if [ -n "$pool_list" ]; then lock_take; fi

echo "battery.sh: host: $HOST_KIND"
for who in $singles; do
    echo "battery.sh: $who: $(build_of "$who") sha256=$(digest "$(build_of "$who")" 64)"
done
echo "battery.sh: side by side: up to $pool_jobs calls in $budget_kb kB of $memory_kb; groups:${only:- $CELL_GROUPS}"

calls_run
phase=render
cells_all

echo "battery.sh: $cells cells, $invalid_cells INVALID, $not_run_cells not run"
if [ "$invalid_cells" -ne 0 ] || [ -n "$only" ]; then
    if [ "$invalid_cells" -ne 0 ] && [ "$raw_named" -eq 0 ]; then
        keep=1
        echo "battery.sh: what every script printed is kept in $raw" >&2
    fi
    if [ -n "$only" ]; then echo "battery.sh: incomplete: only$only ran"; fi
    exit 3
fi
