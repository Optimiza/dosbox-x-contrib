# shellcheck shell=bash
# Sourced by every script in this folder, which sets `tool` (its name) and `here` (this folder)
# first: the arguments they share, the folder, the guest program, the conf and the launcher.

: "${tool:?the script sets tool before sourcing common.sh}" "${here:?and here}"

LONG_WORDS=(Alpha Bravo Charlie Delta Echo Foxtrot Golf Hotel)

case "$(uname -s)" in MINGW*|MSYS*) HOST_KIND=windows ;; *) HOST_KIND=unix ;; esac

# DIRCACHE_LAUNCHER is the seam of the tests: a stand-in that plays what real runs left.
launcher=${DIRCACHE_LAUNCHER:-$here/launch.sh}

fail_usage() {
    echo "$tool: $1" >&2
    exit 2
}

# Nothing was judged. The run's directory stays, named, for whoever needs to see why.
invalid() {
    keep=1
    echo "$tool: INVALID: $1; the run is kept in $tmp" >&2
    exit 3
}

need_builds() {
    local b
    for b in "$@"; do
        if [ ! -x "$b" ] || [ -d "$b" ]; then fail_usage "not an executable: $b"; fi
    done
}

lfn_parse() {
    case "$1" in
        on) lfn_conf=true ;;
        off) lfn_conf=false ;;
        *) fail_usage "long names are on or off, not: $1" ;;
    esac
}

# What a run needs from the host, asked before anything is made.
need_tools() {
    if [ "$HOST_KIND" = windows ]; then
        [ -f "$here/windows.ps1" ] || fail_usage "windows.ps1 is missing beside the script"
    else
        [ -x "$launcher" ] || fail_usage "the launcher is not an executable: $launcher"
    fi
    if [ -n "${DIRCACHE_PREBUILT:-}" ]; then
        [ -d "$DIRCACHE_PREBUILT" ] || fail_usage "DIRCACHE_PREBUILT is not a directory: $DIRCACHE_PREBUILT"
    elif [ ! -x "${DJDIR:-$HOME/djgpp}/bin/i586-pc-msdosdjgpp-gcc" ]; then
        fail_usage "no DJGPP compiler under ${DJDIR:-$HOME/djgpp} (set DJDIR, or DIRCACHE_PREBUILT)"
    fi
}

# run_begin <name>: the run's directory and the one trap that ends it. A signal has to end the
# emulator too: left alone it runs to the launcher's bound.
run_begin() {
    tmp=$(mktemp -d "${TMPDIR:-/tmp}/dircache-$1.XXXXXX") || exit 3
    tmp=$(cd "$tmp" && pwd -P) || exit 3
    keep=0 emu_job="" emu_dir=""
    trap run_end EXIT
    trap 'exit 143' TERM INT HUP
}

run_end() {
    emu_kill
    [ "$keep" -eq 1 ] || rm -rf "$tmp"
}

# Ends a run still in flight: on a Mac the processes that name its conf (the emulator, the
# launcher, its timeout), on Windows the pid the launcher wrote.
emu_kill() {
    local pids
    [ -n "$emu_job" ] || return 0
    if [ "$HOST_KIND" = windows ]; then
        [ -f "$emu_dir/emulator.pid" ] || return 0
        MSYS_NO_PATHCONV=1 taskkill /F /PID "$(cat "$emu_dir/emulator.pid")" > /dev/null 2>&1
        return 0
    fi
    pids=$(ps -ww -Ao pid=,args= | awk -v c="$emu_dir/run.conf" 'index($0, c) { print $1 }')
    [ -n "$pids" ] || return 0
    # shellcheck disable=SC2086  # a list of pids, split on purpose
    kill $pids 2> /dev/null
    sleep 1
    # shellcheck disable=SC2086
    kill -KILL $pids 2> /dev/null
    return 0
}

host_path() {
    if [ "$HOST_KIND" = windows ]; then cygpath -w "$1"; else printf '%s\n' "$1"; fi
}

# guest_build <NAME> <dir>: <dir>/<NAME>.EXE from the source beside the scripts, so a run tests
# the source it sits with; or from DIRCACHE_PREBUILT, on a host with no DJGPP.
guest_build() {
    local name=$1 dir=$2 source
    source=$here/$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]').c
    mkdir -p "$dir" || return
    if [ -n "${DIRCACHE_PREBUILT:-}" ]; then
        cp "$DIRCACHE_PREBUILT/$name.EXE" "$dir/"
        return
    fi
    "${DJDIR:-$HOME/djgpp}/bin/i586-pc-msdosdjgpp-gcc" -O2 -Wall -Wextra -Wshadow -Werror \
        -o "$dir/$name.EXE" "$source"
}

# folder_parse <folder>: a host directory, or synthetic:<count>:<83|long>. Sets synth_count and
# synth_style, both empty for a host directory.
folder_parse() {
    local spec
    synth_count="" synth_style=""
    case "$1" in
        synthetic:*)
            spec=${1#synthetic:}
            synth_count=${spec%%:*}
            synth_style=${spec#*:}
            # Seven digits at most: a longer count is past what the shell's arithmetic holds.
            case "$synth_count" in ''|*[!0-9]*|????????*) fail_usage "bad count in $1" ;; esac
            if [ "$synth_count" -lt 1 ]; then fail_usage "bad count in $1"; fi
            case "$synth_style" in 83|long) ;; *) fail_usage "style is 83 or long: $1" ;; esac
            ;;
        *)
            if [ ! -d "$1" ]; then fail_usage "not a directory: $1"; fi
            ;;
    esac
}

# synth_name <83|long> <i>: sets synth_name_out to the i-th name of a synthetic folder.
synth_name() {
    if [ "$1" = 83 ]; then
        printf -v synth_name_out 'F%07d.TXT' "$2"
    else
        printf -v synth_name_out '%s track %06d.mid' "${LONG_WORDS[$(($2 % ${#LONG_WORDS[@]}))]}" "$2"
    fi
}

folder_make() {
    local dir=$1 n=$2 style=$3 i=0
    mkdir -p "$dir" || return
    while [ "$i" -lt "$n" ]; do
        synth_name "$style" "$i"
        : > "$dir/$synth_name_out" || return
        i=$((i + 1))
    done
}

# findlife_tree <dir>: the two folders FINDLIFE searches. A's files start with A and B's with B,
# so an entry handed back from the wrong folder shows in its name.
FINDLIFE_FILES_A=40
FINDLIFE_FILES_B=30
findlife_tree() {
    local tree=$1 i name
    mkdir -p "$tree/A" "$tree/B" || return
    i=0
    while [ "$i" -lt "$FINDLIFE_FILES_A" ]; do printf -v name 'A%04d.TXT' "$i"; : > "$tree/A/$name" || return; i=$((i + 1)); done
    i=0
    while [ "$i" -lt "$FINDLIFE_FILES_B" ]; do printf -v name 'B%04d.DAT' "$i"; : > "$tree/B/$name" || return; i=$((i + 1)); done
}

# findlife_whole <report>: a report with no trailer was cut short, and one with no case judged
# nothing.
findlife_whole() {
    awk -F'|' '$1 == "case" { n++ } $1 == "end" { split($2, a, "="); t = a[2] } END { exit !(n > 0 && n == t + 0) }' "$1"
}

# exact_tree <dir>: the folder EXACT searches; exact.sh's --help lists it. The real file named
# like an alias is made before the long names: where the file system names the aliases, a long
# name made first takes that name, and the write of the real file then lands on it. A folder
# that did not come out whole is refused.
EXACT_TREE_ENTRIES=18
exact_tree() {
    local d=$1 n
    mkdir -p "$d/X/SUBDIR" "$d/X/Long Sub Directory" || return
    printf 'real' > "$d/X/ALPHAT~1.MID"
    printf 'root' > "$d/FOO.TXT"
    printf 'foo' > "$d/X/FOO.TXT"; printf 'bar12' > "$d/X/BAR.TXT"; printf 'zed1234' > "$d/X/ZED.TXT"
    printf 'n' > "$d/X/NOEXT"; printf 'ab' > "$d/X/A.B"; printf 'mixed' > "$d/X/MixCase.Txt"
    printf 'a0' > "$d/X/Alpha track 000000.mid"; printf 'a01' > "$d/X/Alpha track 000001.mid"
    printf 'space' > "$d/X/Alpha tr.mid"
    printf 'dots' > "$d/X/Two.dots.name.txt"; printf 'noextlong' > "$d/X/No extension long name"
    printf 'inner' > "$d/X/SUBDIR/INNER.TXT"; printf 'innerlong' > "$d/X/Long Sub Directory/Inner long name.dat"
    n=$(find "$d" -mindepth 1 | wc -l | tr -d ' ')
    if [ "$n" != "$EXACT_TREE_ENTRIES" ]; then
        echo "$tool: the folder came out with $n entries, not $EXACT_TREE_ENTRIES: $d" >&2
        return 1
    fi
}

# exact_whole <report>: EXACT's trailer counts the lines above it.
exact_whole() {
    awk -F'|' '$1 == "end" { split($2, a, "="); t = a[2] } $1 != "end" { n++ } END { exit !(n > 0 && n == t + 0) }' "$1"
}

# exact_reports <PROGRAM> <build A> <build B> [<D:'s mount options>], after run_begin and
# guest_build, with SECONDS_BOUND set: the program over exact.sh's folder, a copy per build
# because a program may create and remove files in it. Prints each build's path, version line
# and report whole, and leaves the reports in $tmp/report-A.txt and $tmp/report-B.txt.
exact_reports() {
    local program=$1 options=${4:-} label binary
    for label in A B; do
        if [ "$label" = A ]; then binary=$2; else binary=$3; fi
        exact_tree "$tmp/fx-$label" || invalid "could not make build $label's folder"
        guest_run "$label" "$binary" "$tmp/fx-$label" "$options" "$program.TXT" "$SECONDS_BOUND" "c:" "$program.EXE D:\\X C:\\$program.TXT"
        LC_ALL=C tr -d '\r' < "$guest_out" > "$tmp/report-$label.txt" || invalid "build $label's report could not be read"
        echo "$tool: build $label: $binary ($emu_version)"
        cat "$tmp/report-$label.txt"
        exact_whole "$tmp/report-$label.txt" || invalid "build $label's report has no line or no trailer"
    done
}

# reports_verdict: compares the two reports exact_reports left, prints the verdict and the lines
# that differ, and ends the script: 0 alike, 1 different.
reports_verdict() {
    local cmp_rc
    cmp -s "$tmp/report-A.txt" "$tmp/report-B.txt"
    cmp_rc=$?
    if [ "$cmp_rc" -eq 0 ]; then echo "$tool: ALIKE"; exit 0; fi
    if [ "$cmp_rc" -ne 1 ]; then invalid "cmp failed (exit $cmp_rc)"; fi
    echo "$tool: DIFFERENT, $(diff "$tmp/report-A.txt" "$tmp/report-B.txt" | command grep -a -c '^<') lines differ (A then B):"
    diff "$tmp/report-A.txt" "$tmp/report-B.txt" | command grep -a -E '^[<>]'
    exit 1
}

# fc_folder <dir> <files> <runs> <guest file FC's output is added to>: the folder fc.sh runs FC
# in. <files> empty files, the two that are compared, and RUNS.BAT, one run of FC per line: a
# batch file is DOS's, CR LF.
fc_folder() {
    local dir=$1 runs=$3 i=0
    folder_make "$dir" "$2" 83 || return
    printf 'the same line\r\n' > "$dir/ONE.TXT" || return
    cp "$dir/ONE.TXT" "$dir/TWO.TXT" || return
    {
        printf '@ECHO OFF\r\n'
        while [ "$i" -lt "$runs" ]; do printf 'FC ONE.TXT TWO.TXT >> %s\r\n' "$4"; i=$((i + 1)); done
    } > "$dir/RUNS.BAT"
}

# fc_compared <what the runs of FC printed>: how many of them said the two files do not differ.
fc_compared() {
    LC_ALL=C tr -d '\r' < "$1" 2> /dev/null | command grep -a -c -i '^No differences'
}

# xcopy_tree <dir>: the tree xcopy.sh copies. Files at the two lower levels, so that XCOPY has
# folders still to list while it looks up the files of the one it is in; more files in all than
# the emulator's search table has slots.
XCOPY_TOPS=6
XCOPY_SUBS=2
XCOPY_TOP_FILES=20
XCOPY_SUB_FILES=200
xcopy_tree() {
    local d=$1 t=0 s
    while [ "$t" -lt "$XCOPY_TOPS" ]; do
        folder_make "$d/T$t" "$XCOPY_TOP_FILES" 83 || return
        s=0
        while [ "$s" -lt "$XCOPY_SUBS" ]; do
            folder_make "$d/T$t/S$s" "$XCOPY_SUB_FILES" 83 || return
            s=$((s + 1))
        done
        t=$((t + 1))
    done
}

# xcopy_said <what XCOPY printed>: the count of its last line "<n> file(s) copied".
xcopy_said() {
    LC_ALL=C tr -d '\r' < "$1" | sed -n 's/^ *\([0-9][0-9]*\) [Ff]ile(s) copied.*/\1/p' | tail -n 1
}

# The label FINDPOS's labelled drive carries, on a build and on the DOS of an image.
# shellcheck disable=SC2034  # read by the scripts
FINDPOS_LABEL=FPLABEL

# template_tree <dir>: the root of the volume TEMPLATE searches; template.sh's --help lists it.
# No name here is the 8.3 alias a file system would give another.
TEMPLATE_LABEL=DISK1
TEMPLATE_TREE_FILES=8
template_tree() {
    local d=$1 n
    mkdir -p "$d" || return
    printf 'f' > "$d/FOO.TXT"; printf 'g' > "$d/FOO"; printf 'b' > "$d/BAR.TXT"
    printf 'p' > "$d/PROGRAM"; printf 't' > "$d/PROGRAM.TXT"
    printf 'a' > "$d/foo .txt"; printf 's' > "$d/program .txt"; printf 'l' > "$d/Program Files"
    n=$(find "$d" -mindepth 1 | wc -l | tr -d ' ')
    if [ "$n" != "$TEMPLATE_TREE_FILES" ]; then
        echo "$tool: the volume's folder came out with $n entries, not $TEMPLATE_TREE_FILES: $d" >&2
        return 1
    fi
}

# template_report <output of a run> <fat|host>: prints TEMPLATE's report out of what the run
# left, which opens with what the shell said of the volume. Fails, saying why, when the shell
# did not name the label or, on an image, did not copy every file.
template_report() {
    local copied
    if ! command grep -a -q "^ *Volume in drive [A-Z] is $TEMPLATE_LABEL *\$" "$1"; then
        echo "$tool: the shell does not say the volume is labelled $TEMPLATE_LABEL" >&2
        return 1
    fi
    if [ "$2" = fat ]; then
        copied=$(sed -n 's/^ *\([0-9][0-9]*\) [Ff]ile(s) copied.*/\1/p' "$1" | tail -n 1)
        if [ "$copied" != "$TEMPLATE_TREE_FILES" ]; then
            echo "$tool: the files did not reach the image whole: ${copied:-no count} copied of $TEMPLATE_TREE_FILES" >&2
            return 1
        fi
    fi
    command grep -a -E '^(label|fcblabel|quoted|fcbname|end)\|' "$1"
}

# dtadump_figures <report>: DTADUMP's report in four figures; fails when the report holds none
# of the lines one of them is read from.
#   template   a digest of the template and attribute bytes of every FindFirst dumped
#   untouched  of the calls that must leave a DTA alone, how many left its 43 bytes unchanged
#   resumed    of the searches such a call interrupted, how many returned the rest of the folder
#   fcb        a digest of what the FCB searches returned
dtadump_figures() {
    local templates lists counts
    templates=$(awk -F'|' '$1 == "dump" && $2 ~ /^template / { split($5, g, " "); print $2 "|" g[2] "|" g[3] }' "$1")
    lists=$(command grep -a '^list|fcb-' "$1")
    counts=$(awk -F'|' '
        $1 == "dump" && $4 ~ / dta=/ { calls++; if ($4 ~ / dta=unchanged$/) kept++ }
        $1 == "list" && $3 ~ / then more=[0-9]+ of [0-9]+$/ {
            n = split($3, w, " "); searches++
            if (w[n - 2] == "more=" w[n]) resumed++
        }
        END { if (calls && searches) printf "untouched=%d/%d resumed=%d/%d", kept, calls, resumed, searches }' "$1")
    if [ -z "$templates" ] || [ -z "$lists" ] || [ -z "$counts" ]; then return 1; fi
    echo "template=$(printf '%s\n' "$templates" | shasum -a 256 | cut -c1-12) $counts fcb=$(printf '%s\n' "$lists" | shasum -a 256 | cut -c1-12)"
}

is_83() {
    local stem=${1%%.*} ext=""
    case "$1" in *.*) ext=${1#*.} ;; esac
    case "$ext" in *.*) return 1 ;; esac
    [ "${#stem}" -ge 1 ] && [ "${#stem}" -le 8 ] && [ "${#ext}" -le 3 ]
}

# folder_resolve <folder> <on|off>, after folder_parse and run_begin: sets parent (what D: is),
# base (the folder's name on D:) and host_count.
folder_resolve() {
    if [ -n "$synth_count" ]; then
        parent=$tmp/tree base=DIR
        folder_make "$parent/$base" "$synth_count" "$synth_style" || invalid "could not make the folder"
    else
        parent=$(cd "$(dirname "$1")" && pwd) || fail_usage "cannot reach the folder's parent: $1"
        base=$(basename "$1")
        case "$base" in *' '*) fail_usage "the folder's name goes on a DOS command line: no spaces: $base" ;; esac
        if [ "$2" = off ] && ! is_83 "$base"; then
            fail_usage "with long names off the guest cannot reach a folder whose name is not 8.3: $base"
        fi
    fi
    # shellcheck disable=SC2034  # read by the scripts, for their result lines
    host_count=$(find "$parent/$base" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')
}

# conf_write <run dir, C:> <host dir for D:> <D:'s mount options> <autoexec line>...
# One machine for every script. cycles=max and the dynamic core because an answer here is the
# same at any guest speed and nothing is timed. conf_dos, when a script sets it, is one more
# line of [dos].
# A mount that names no label asks for an empty one: left alone, a Windows build labels the
# drive itself and a search for the label answers there what it does not answer elsewhere.
conf_write() {
    local run=$1 d=$2 options=$3 no_label=' -label ""'
    shift 3
    case "$options" in *-label*) ;; *) options="$options$no_label" ;; esac
    {
        printf '[dosbox]\nmemsize=64\n\n[cpu]\ncore=dynamic\ncycles=max\n\n[dos]\n%slfn=%s\n\n[autoexec]\n' "${conf_dos:+$conf_dos$'\n'}" "$lfn_conf"
        printf 'mount c "%s"%s\nmount d "%s"%s\n' "$(host_path "$run")" "$no_label" "$(host_path "$d")" "$options"
        printf '%s\n' "$@" exit
    } > "$run/run.conf"
}

# emu_start <build> <run dir> <file the run must leave there> <seconds> [launcher argument...]
# Headless and bounded; in the background, so a signal reaches this script while it runs. The
# launcher arguments are windows.ps1's options on Windows and the emulator's own elsewhere.
emu_start() {
    local binary=$1 run=$2 output=$3 seconds=$4
    shift 4
    emu_dir=$run
    if [ "$HOST_KIND" = windows ]; then
        powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass \
            -File "$(host_path "$here/windows.ps1")" -Build "$(host_path "$binary")" \
            -Run "$(host_path "$run")" -Output "$output" -Seconds "$seconds" "$@" \
            > "$run/launcher.txt" 2>&1 &
    else
        "$launcher" --conf "$run/run.conf" --binary "$binary" \
            --seconds "$seconds" --output "$run/$output" --log "$run/dosbox.log" \
            --report "$run/report.txt" ${1+-- "$@"} > "$run/launcher.txt" 2>&1 &
    fi
    emu_job=$!
}

# emu_finish <label>: waits, sets emu_version. Non-zero, with the launcher's own words, when
# the emulator failed or was cut off, the guest left no output, or the report names no build.
emu_finish() {
    local rc
    wait "$emu_job"
    rc=$?
    emu_job=""
    emu_version=$(sed -n 's/^[^ ]*: version: //p' "$emu_dir/report.txt" 2> /dev/null)
    if [ "$rc" -eq 0 ] && [ -n "$emu_version" ]; then return 0; fi
    echo "$tool: $1: the launcher exit $rc, version line \"$emu_version\"; what it said:" >&2
    cat "$emu_dir/launcher.txt" >&2
    return 3
}

emu_run() {
    local label=$1
    shift
    emu_start "$@"
    emu_finish "$label"
}

# guest_run <label> <build> <host dir for D:> <D:'s mount options> <output name> <seconds>
#           <autoexec line>...
# One run on a C: of its own, a copy of $tmp/c. Sets guest_out and emu_version.
guest_run() {
    local label=$1 binary=$2 d=$3 options=$4 output=$5 seconds=$6 run=$tmp/run-$1
    shift 6
    if ! mkdir -p "$run" || ! cp -R "$tmp/c/." "$run/"; then invalid "could not make the run directory of $label"; fi
    conf_write "$run" "$d" "$options" "$@"
    emu_run "$label" "$binary" "$run" "$output" "$seconds" || invalid "$label did not run to its end"
    # shellcheck disable=SC2034  # read by the scripts
    guest_out=$run/$output
}

# A run whose memory is read is killed past this resident size or working set, so a runaway
# cannot take the machine.
MEMORY_LIMIT_KB=6291456
MEMORY_SAMPLE_INTERVAL=0.2

# The emulator is the process whose executable is the build and whose arguments name the run's
# conf: the launcher and its timeout carry the same arguments under another executable.
emulator_pid() {
    local pid
    for pid in $(ps -Ao pid=,comm= | awk -v b="$1" '{ p = $1; sub(/^[ \t]*[0-9]+[ \t]+/, ""); if ($0 == b) print p }'); do
        case "$(ps -ww -o args= -p "$pid" 2>/dev/null)" in *"$2/run.conf"*) echo "$pid"; return 0 ;; esac
    done
    return 1
}

# The guest holds from HELD.TXT until GO.TXT: the emulator is read once it holds, then let go.
memory_sample_macos() {
    local binary=$1 run=$2 pid="" rss fp
    while kill -0 "$emu_job" 2>/dev/null; do
        if [ -z "$pid" ]; then pid=$(emulator_pid "$binary" "$run") || pid=""; fi
        if [ -n "$pid" ]; then
            if [ "$held_kb" -eq 0 ] && [ -f "$run/HELD.TXT" ]; then
                rss=$(ps -o rss= -p "$pid" 2>/dev/null | tr -d ' ')
                fp=$(footprint --noCategories -f bytes "$pid" 2>/dev/null | awk '/Footprint:/ { for (i = 1; i <= NF; i++) if ($i == "Footprint:") { print int($(i + 1) / 1024); exit } }')
                case "$rss" in ''|*[!0-9]*) ;; *) held_kb=$rss ;; esac
                case "$fp" in ''|*[!0-9]*) ;; *) held_other_kb=$fp ;; esac
                : > "$run/GO.TXT"
            else
                rss=$(ps -o rss= -p "$pid" 2>/dev/null | tr -d ' ')
            fi
            case "$rss" in
                ''|*[!0-9]*) ;;
                *)
                    samples=$((samples + 1))
                    if [ "$rss" -gt "$peak_kb" ]; then peak_kb=$rss; fi
                    if [ "$rss" -gt "$MEMORY_LIMIT_KB" ]; then kill -KILL "$pid" 2>/dev/null; memory_killed=1; fi
                    ;;
            esac
        fi
        sleep "$MEMORY_SAMPLE_INTERVAL"
    done
}

# memory_run <build> <run dir> <file the run must leave there> <seconds>, after conf_write: one
# run whose guest ends by holding (HELD.TXT in the run directory, until GO.TXT), read from
# outside meanwhile. Sets peak_kb, held_kb, held_other_kb and samples, and memory_names: on macOS
# the peak resident size, the resident size and the footprint while the guest holds, on Windows
# the peak working set, the working set and the private bytes.
memory_run() {
    local binary=$1 run=$2 output=$3 seconds=$4
    peak_kb=0 held_kb=0 held_other_kb=0 samples=0 memory_killed=0
    if [ "$HOST_KIND" = windows ]; then
        memory_names="ws ws private"
        emu_start "$binary" "$run" "$output" "$seconds" -Held HELD.TXT -Go GO.TXT -LimitKb "$MEMORY_LIMIT_KB"
    else
        memory_names="rss rss footprint"
        emu_start "$binary" "$run" "$output" "$seconds"
        memory_sample_macos "$binary" "$run"
    fi
    if ! emu_finish "the run"; then
        if [ "$memory_killed" -eq 1 ]; then invalid "the emulator passed $MEMORY_LIMIT_KB kB resident and was killed (peak $peak_kb kB)"; fi
        invalid "the emulator did not run to its end"
    fi
    if [ "$HOST_KIND" = windows ]; then
        # shellcheck disable=SC2046  # four numbers, split on purpose
        set -- $(sed -n 's/^windows\.ps1: memory: peak_ws_kb=\([0-9]*\) held_ws_kb=\([0-9]*\) held_private_kb=\([0-9]*\) samples=\([0-9]*\)$/\1 \2 \3 \4/p' "$run/report.txt")
        if [ $# -ne 4 ]; then invalid "the launcher's report has no memory line"; fi
        peak_kb=$1 held_kb=$2 held_other_kb=$3 samples=$4
    fi
}

# memory_figures: what memory_run read, as the scripts print it; INVALID when the emulator was
# not read while the guest held.
memory_figures() {
    if [ "$samples" -eq 0 ] || [ "$held_kb" -eq 0 ] || [ "$held_other_kb" -eq 0 ]; then
        invalid "the emulator's memory was not read while the guest held (samples=$samples held=$held_kb and $held_other_kb kB)"
    fi
    # shellcheck disable=SC2086  # three column names, split on purpose
    set -- $memory_names
    # shellcheck disable=SC2034  # read by the scripts
    memory_figures_out="peak_$1_kb=$peak_kb held_$2_kb=$held_kb held_$3_kb=$held_other_kb samples=$samples"
}

# log_count <text>: lines of the emulator's log that hold it; fails when it cannot be read.
log_count() {
    local n
    n=$(command grep -c -- "$1" "$emu_dir/dosbox.log")
    case "$n" in ''|*[!0-9]*) return 1 ;; esac
    echo "$n"
}
