#!/usr/bin/env bash
# Runs EXACT.EXE and SHELLT.BAT headless on two DOSBox-X builds, each over its own copy of one
# small folder, and compares what they answer to searches for one exact name. See README.md
# beside this script.
set -u

usage() {
    cat <<'EOT'
usage: exact.sh <build A> <build B> <on|off>

  <build A>, <build B>  two DOSBox-X executables (the same one twice is the A/A control)
  <on|off>              the guest's long file names ([dos] lfn)

the folder, D:\ in the guest:
  FOO.TXT                                   a root file, for the volume-label searches
  X\FOO.TXT BAR.TXT ZED.TXT NOEXT A.B MixCase.Txt        names that fit 8.3
  X\Alpha track 000000.mid, ...000001.mid   long names whose aliases are numbered
  X\ALPHAT~1.MID                            a real file named like the first alias
  X\Alpha tr.mid                            a name with a space that fits 8.3
  X\Two.dots.name.txt, X\No extension long name
  X\SUBDIR\INNER.TXT, X\Long Sub Directory\Inner long name.dat

prints one verdict per section: basic and life (EXACT's own), shell (what the shell's commands
print for exact names), tree (the folder after the shell's commands) and drift. drift holds the
searches whose FindNext arrives with another pattern than their FindFirst had: it is printed and
compared, and it does not decide the exit code.

environment:
  DJDIR                 the DJGPP cross toolchain (default: $HOME/djgpp)
  DIRCACHE_PREBUILT     a folder holding EXACT.EXE built on another host, instead of DJGPP

exit: 0 basic, life, shell and tree are alike | 1 one of them differs | 2 usage
      3 INVALID: a run collected nothing, a report has no trailer, or a section is empty; the
        run's directory is kept and named
EOT
}

SECONDS_BOUND=900

if [ $# -eq 1 ] && [ "$1" = "--help" ]; then usage; exit 0; fi
if [ $# -ne 3 ]; then usage >&2; exit 2; fi
build_a=$1 build_b=$2 lfn=$3

tool=exact.sh
here=$(cd "$(dirname "$0")" && pwd) || exit 2
if [ ! -f "$here/common.sh" ]; then echo "exact.sh: common.sh is missing beside the script" >&2; exit 3; fi
# shellcheck source=common.sh
. "$here/common.sh"
need_builds "$build_a" "$build_b"
lfn_parse "$lfn"
need_tools

run_begin exact
guest_build EXACT "$tmp/c" || invalid "EXACT did not build"
cp "$here/SHELLT.BAT" "$tmp/c/" || invalid "SHELLT.BAT is missing beside the script"

# What the emulator itself logged during the last run: its search table filling, and a search
# asked to go on with a slot number past the table.
counters() {
    local full range
    full=$(log_count 'All slots full') || invalid "the emulator's log could not be read"
    range=$(log_count 'ID out of range') || invalid "the emulator's log could not be read"
    echo "exact.sh: build $1, $2: slots_full=$full out_of_range=$range"
}

run_one() {
    local label=$1 binary=$2 f
    exact_tree "$tmp/fx-$label" || invalid "could not make build $label's folder"
    guest_run "$label-exact" "$binary" "$tmp/fx-$label" "" EXACT.TXT "$SECONDS_BOUND" "c:" 'EXACT.EXE D:\X C:\EXACT.TXT'
    echo "exact.sh: build $label: $binary ($emu_version)"
    LC_ALL=C tr -d '\r' < "$guest_out" > "$tmp/exact-$label.txt" || invalid "build $label's report could not be read"
    exact_whole "$tmp/exact-$label.txt" \
        || invalid "build $label: EXACT's report has no trailer or its count disagrees"
    counters "$label" EXACT
    guest_run "$label-shell" "$binary" "$tmp/fx-$label" "" SH.TXT "$SECONDS_BOUND" "c:" 'call SHELLT.BAT'
    LC_ALL=C tr -d '\r' < "$guest_out" > "$tmp/shell-$label.txt" || invalid "build $label's shell report could not be read"
    command grep -q '^END$' "$tmp/shell-$label.txt" || invalid "build $label: the shell test did not reach its end"
    counters "$label" "the shell test"
    # The folder after the shell's commands: every directory, and every file with its size.
    (cd "$tmp/fx-$label" && find . | LC_ALL=C sort | while IFS= read -r f; do
        if [ -f "$f" ]; then printf '%s %s\n' "$f" "$(wc -c < "$f" | tr -d ' ')"; else printf '%s\n' "$f"; fi
    done) > "$tmp/tree-$label.txt" || invalid "build $label's folder could not be listed"
}

echo "exact.sh: long names $lfn"
run_one A "$build_a"
run_one B "$build_b"

status=0
section() {
    local name=$1 file=$2 pattern=$3 a b
    command grep -a -E "$pattern" "$tmp/$file-A.txt" > "$tmp/sec-A.txt"; a=$(wc -l < "$tmp/sec-A.txt" | tr -d ' ')
    command grep -a -E "$pattern" "$tmp/$file-B.txt" > "$tmp/sec-B.txt"; b=$(wc -l < "$tmp/sec-B.txt" | tr -d ' ')
    if [ "$a" -eq 0 ] || [ "$b" -eq 0 ]; then echo "exact.sh: $name: INVALID, no line ($a and $b)"; status=3; return; fi
    if cmp -s "$tmp/sec-A.txt" "$tmp/sec-B.txt"; then echo "exact.sh: $name: ALIKE ($a lines)"; return; fi
    echo "exact.sh: $name: DIFFERENT ($a and $b lines), the lines that differ (A then B):"
    diff "$tmp/sec-A.txt" "$tmp/sec-B.txt" | command grep -a -E '^[<>]'
    if [ "$name" != drift ] && [ "$status" -ne 3 ]; then status=1; fi
}
section basic exact '^basic\|'
section life exact '^life\|'
section shell shell '.'
section tree tree '.'
section drift exact '^drift\|'
echo "exact.sh: the life and drift lines of build A:"
command grep -a -E '^(life|drift)\|' "$tmp/exact-A.txt"
if [ "$status" -eq 3 ]; then invalid "a section is empty"; fi
exit "$status"
