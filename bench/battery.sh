#!/usr/bin/env bash
# Runs every script of this folder on two or three DOSBox-X builds, in one fixed order, and prints
# one line per cell: the script's own verdict and what it counted. See README.md beside this
# script.
set -u

usage() {
    cat <<'EOT'
usage: battery.sh [--real-dos] [--raw <directory>] <base> <build> [<third build>]

  <base>             the DOSBox-X executable <build> is compared with
  <build>            the one under test
  <third build>      another one <build> is compared with as well
  --real-dos         adds FINDLIFE, EXACT, ENUMSTAT, DRIFT, DTADUMP, PATLIST, TEMPLATE,
                     FINDPOS, MEMPROBE's lookups, FC and XCOPY on the DOS of a disk image,
                     with <build> as the machine
  --raw <directory>  keeps there what every script printed, one file per call: its exit code
                     and arguments, then its output. The directory is empty or absent

runs, in this order: the scripts' own tests, run.sh, memory.sh, fc.sh, findlife.sh, exact.sh,
drift.sh, dtadump.sh, patlist.sh, template.sh, findpos.sh, ties.sh, enumstat.sh, xcopy.sh,
passfail.sh, unit.sh and, when asked, realdos.sh.
A script that compares two builds runs on base against build, then on the third build against
build; one that measures a single build runs on each.

prints the builds with their sha256, then one line per cell:

  cell|<name>|<long names: on, off or ->|<verdict>|<figures>

  <name>     the script, what it ran on, and base:build, third:build or the build measured
  <verdict>  the script's own: IDENTICAL or ALIKE, DIFFERENT, ran (a script that compares
             nothing), INVALID, or "not run" where this host cannot run the cell
  <figures>  what the script counted; for INVALID and "not run", why

and a last line with how many cells it printed, how many INVALID and how many not run. It judges
nothing: a DIFFERENT, a failed test or a figure that grew is for whoever reads the lines.

environment:
  DIRCACHE_REAL_FOLDER  the large host folder of the cells named real: a name with no space
                        that fits 8.3
  DIRCACHE_REAL_FILE    a file of it, as the guest names it
  DIRCACHE_REGRESSION   the folder holding FINDTEST.EXE and LFNTEST.EXE (README.md, passfail.sh)
  DIRCACHE_BOOT_IMAGE   with --real-dos, the disk image realdos.sh boots
  DIRCACHE_SCRIPTS      the folder the scripts are run from (default: this one): the seam of
                        battery.test.sh
  DJDIR, DIRCACHE_PREBUILT  as every script takes them

exit: 0 every cell ran | 2 usage
      3 at least one cell is INVALID: it examined nothing. What the scripts printed is then
        kept and named, unless --raw already keeps it
EOT
}

RUN_SIZES="1000 10000 50000"
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
SELF_TESTS="run memory fc findlife exact drift dtadump patlist template findpos ties enumstat xcopy passfail unit realdos"
REALDOS_PROGRAMS="findlife exact enumstat drift dtadump patlist template findpos findpos-labelled memprobe fc xcopy"
TEMPLATE_VOLUMES="fat host"
FINDPOS_VOLUMES="labelled unlabelled"

if [ $# -eq 1 ] && [ "$1" = "--help" ]; then usage; exit 0; fi

tool=battery.sh
here=$(cd "$(dirname "$0")" && pwd) || exit 2
if [ ! -f "$here/common.sh" ]; then echo "battery.sh: common.sh is missing beside the script" >&2; exit 3; fi
# shellcheck source=common.sh
. "$here/common.sh"

real_dos=0 raw="" builds=()
while [ $# -gt 0 ]; do
    case "$1" in
        --real-dos) real_dos=1 ;;
        --raw)
            if [ $# -lt 2 ]; then fail_usage "--raw takes a directory"; fi
            raw=$2
            shift
            ;;
        --*) fail_usage "unknown option: $1" ;;
        *) builds+=("$1") ;;
    esac
    shift
done
if [ "${#builds[@]}" -ne 2 ] && [ "${#builds[@]}" -ne 3 ]; then usage >&2; exit 2; fi
need_builds "${builds[@]}"
base=${builds[0]} build=${builds[1]} third=${builds[2]:-}
pairs="base:build" singles="base build"
if [ -n "$third" ]; then pairs="base:build third:build" singles="base build third"; fi

scripts=${DIRCACHE_SCRIPTS:-$here}
real_folder=${DIRCACHE_REAL_FOLDER:-} real_file=${DIRCACHE_REAL_FILE:-}
regression=${DIRCACHE_REGRESSION:-} image=${DIRCACHE_BOOT_IMAGE:-}
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

tmp=$(mktemp -d "${TMPDIR:-/tmp}/dircache-battery.XXXXXX") || exit 3
keep=0 child=""
# A signal has to end the script in flight, which ends its own emulator.
finish() {
    if [ -n "$child" ]; then
        kill "$child" 2> /dev/null
        wait "$child" 2> /dev/null
    fi
    [ "$keep" -eq 1 ] || rm -rf "$tmp"
}
trap finish EXIT
trap 'exit 143' TERM INT HUP
raw_named=1
if [ -z "$raw" ]; then
    raw=$tmp/raw raw_named=0
    mkdir "$raw" || exit 3
fi

build_of() {
    case "$1" in base) echo "$base" ;; build) echo "$build" ;; third) echo "$third" ;; esac
}

digest() { shasum -a 256 "$1" | cut -c1-"${2:-12}"; }

calls=0 cells=0 invalid_cells=0 not_run_cells=0 rc=0

# call <script> <argument>...: runs it and sets rc. What it printed is $tmp/text, and a file of
# the raw directory.
call() {
    local script=$1 file
    shift
    calls=$((calls + 1))
    "$BASH" "$scripts/$script" "$@" > "$tmp/out" 2>&1 &
    child=$!
    wait "$child"
    rc=$?
    child=""
    LC_ALL=C tr -d '\r' < "$tmp/out" > "$tmp/text"
    printf -v file '%s/%03d-%s.txt' "$raw" "$calls" "${script%.sh}"
    { echo "exit=$rc :: $script $*"; cat "$tmp/text"; } > "$file"
}

cell() {
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
            name = (part[1] == "case" || part[1] == "drift" || part[1] == "life" || part[1] == "tie" || part[1] == "pat" || part[1] == "pos") ? part[2] : part[1]
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
        call "$t.test.sh"
        # 1 is a case that failed: the count says so.
        case "$rc" in
            0|1) emit "selftest $t.test.sh" - ran "$(first 's/^\([0-9]*\) cases, \([0-9]*\) failed$/cases=\1 failed=\2/p')" ;;
            *) emit "selftest $t.test.sh" - INVALID "" ;;
        esac
    done
}

# cells_run <the folder's name in the cell> <folder> <on|off>
cells_run() {
    local pair
    for pair in $pairs; do
        call run.sh "$(build_of "${pair%%:*}")" "$(build_of "${pair##*:}")" "$2" "$3"
        emit "run $1 $pair" "$3" "$(pair_word IDENTICAL)" "$(figures_run)"
    done
}

# cells_memory <what the cell is named for> <folder> <on|off> <mode> <calls> [--file <name>]
cells_memory() {
    local label=$1 who
    shift
    for who in $singles; do
        call memory.sh "$(build_of "$who")" "$@"
        emit "memory $label $3 $4 $who" "$2" "$(ran_word)" "$(figures_memory)"
    done
}

# cells_fc <files> <on|off> <runs>
cells_fc() {
    local who
    for who in $singles; do
        call fc.sh "$(build_of "$who")" "$1" "$2" "$3"
        emit "fc $1 $3 $who" "$2" "$(ran_word)" "$(figures_fc)"
    done
}

# cells_xcopy <on|off>
cells_xcopy() {
    local who
    for who in $singles; do
        call xcopy.sh "$(build_of "$who")" "$1"
        emit "xcopy $who" "$1" "$(ran_word)" "$(figures_xcopy)"
    done
}

# cells_pair <script, without .sh> <word for alike> <on|off|-> [<argument>...]
cells_pair() {
    local script=$1 word=$2 lfn=$3 pair figures=""
    shift 3
    for pair in $pairs; do
        call "$script.sh" "$(build_of "${pair%%:*}")" "$(build_of "${pair##*:}")" "$@"
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
        call findpos.sh "$(build_of "${pair%%:*}")" "$(build_of "${pair##*:}")" "$1" "$2"
        emit "findpos $1 $pair" "$2" "$(pair_word ALIKE)" "$(figures_findpos)"
    done
}

# cells_template <fat|host> <on|off>
cells_template() {
    local pair
    for pair in $pairs; do
        call template.sh "$(build_of "${pair%%:*}")" "$(build_of "${pair##*:}")" "$1" "$2"
        emit "template $1 $pair" "$2" "$(pair_word ALIKE)" "$(figures_template)"
    done
}

# One call lists every build: its lines come a row at a time, the builds in the order given.
cells_enumstat() {
    local n=0 count=0 who lfn names mode figures
    for who in $singles; do count=$((count + 1)); done
    call enumstat.sh "$base" "$build" ${third:+"$third"}
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
                call passfail.sh "$(build_of "$who")" "$folder" on "$regression/$program.EXE"
                emit "passfail $program $folder $who" on "$(ran_word)" "$(figures_passfail)"
            done
        done
    done
}

cells_unit() {
    local who
    for who in $singles; do
        call unit.sh "$(build_of "$who")"
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
        call realdos.sh "$build" "$image" "$what"
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

echo "battery.sh: host: $HOST_KIND"
for who in $singles; do
    echo "battery.sh: $who: $(build_of "$who") sha256=$(digest "$(build_of "$who")" 64)"
done

cells_self_tests
for size in $RUN_SIZES; do
    for style in 83 long; do
        for lfn in on off; do cells_run "synthetic:$size:$style" "synthetic:$size:$style" "$lfn"; done
    done
done
for lfn in on off; do cells_run real "$real_folder" "$lfn"; done
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
cells_pair ties ALIKE on
cells_enumstat
for lfn in on off; do cells_xcopy "$lfn"; done
cells_passfail
cells_unit
if [ "$real_dos" -eq 1 ]; then cells_realdos; fi

echo "battery.sh: $cells cells, $invalid_cells INVALID, $not_run_cells not run"
if [ "$invalid_cells" -ne 0 ]; then
    if [ "$raw_named" -eq 0 ]; then
        keep=1
        echo "battery.sh: what every script printed is kept in $raw" >&2
    fi
    exit 3
fi
