#!/usr/bin/env bash
# judge.py's verdicts against one cell of a real batch, no emulator: bash judge.test.sh
# fixtures/judge holds the timers' output of the cell 10000-83-on run twice (busy: another
# process held a core for two samples; quiet: its second try) and the host's samples around
# both, as loadwatch.sh took them.
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
f=$here/fixtures/judge
judge() { python3 -I "$here/judge.py" "$@"; }

t_case "a process outside the run that held a core for two samples" 0 "BUSY samples=10 idle_min=57.79 idle_mean=75.9 spikes=551:fseventsd:114,551:fseventsd:118,647:mobileassetd:81 sustained=551:fseventsd" judge "$f/load.txt" "$f/busy"
t_case "the same cell run again on a quiet host" 0 "QUIET samples=11 idle_min=64.65 idle_mean=75.6 spikes=none" judge "$f/load.txt" "$f/quiet"
t_derive "$f"; first=$(awk -F'|' '$1 == "top" && $3 == 551 && $5 >= 80 { print $2; exit }' "$f/load.txt")
awk -F'|' -v t="$first" '!($1 == "top" && $3 == 551 && $2 != t)' "$f/load.txt" > "$derived/load.txt"
t_case "one sample of it alone is a spike, named, not a busy host" 0 "QUIET samples=10 idle_min=57.79 idle_mean=75.9 spikes=551:fseventsd:" judge "$derived/load.txt" "$f/busy"
# The quiet try's first go: its window opens 15 s before it.
go=$(sed -n 's/.*|t0=\([0-9]*\)|.*/\1/p' "$f/quiet/"*.out | sort -n | head -n 1)
t_derive "$f"; awk -F'|' -v go="$go" 'BEGIN { OFS = "|" } $1 == "cpu" && $2 >= go && !done { $5 = "5.0"; done = 1 } { print }' "$f/load.txt" > "$derived/load.txt"
t_case "a sample with under a tenth of the CPU idle" 0 "sustained=idle 5 % at" judge "$derived/load.txt" "$f/quiet"
t_derive "$f"; command grep -a -v '^cpu|' "$f/load.txt" > "$derived/load.txt"
t_case "no sample of the host in the cell's window" 0 "BUSY samples=0" judge "$derived/load.txt" "$f/quiet"
mkdir "$work/empty"
t_case "a cell with no timed line" 3 "INVALID samples=0 no timed line" judge "$f/load.txt" "$work/empty"
t_case "one argument" 2 "usage: judge.py" judge "$f/load.txt"
t_end
