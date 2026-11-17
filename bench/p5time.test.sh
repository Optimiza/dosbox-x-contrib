#!/usr/bin/env bash
# p5time.sh's verdicts against one captured round, no emulator: bash p5time.test.sh
# fixtures/p5time holds the four runs of one A B B A round, unpatched upstream against the
# build that reads a folder in one pass, on synthetic:1000:83 with long names on: P5PROBE's
# ready file and its line, as each run left them. The times this plays are the stand-in's.
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
f=$here/fixtures
run() { "$here/p5time.sh" "$build_a" "$build_b" synthetic:1000:83 on 1 "$work/out-$t_cases" "$@"; }
# kept_conf: the conf of the first run, in the directory an INVALID run kept.
kept_conf() {
    local out kept
    out=$("$here/p5time.sh" "$build_a" "$build_b" synthetic:1000:83 on 1 "$work/out-conf" 2>&1)
    kept=$(printf '%s\n' "$out" | sed -n 's/.*the run is kept in \(.*\)$/\1/p' | head -n 1)
    cat "$kept/A-1-0/run.conf"
}

t_play "$f/p5time"
t_case "a round timed, the two builds' guest lines alike" 0 "p5time|1|A|seconds=" run
t_case "each run's guest line" 0 "|guest=p5|mode=f k=0 first=0 done=0 found=0" run
t_case "each build's times" 0 "p5time: B fastest=" run
t_derive "$f/p5time"; LC_ALL=C sed -i '' 's/first=0/first=18/' "$derived/2/P5.TXT"; t_play "$derived"
t_case "a build whose guest answers otherwise" 1 "p5time: the guest lines differ" run
t_derive "$f/p5time"; rm "$derived/1/READY.TXT"; t_play "$derived"
t_case "a guest that never made its ready file" 3 "A-1-0: the guest never made its ready file" run
t_derive "$f/p5time"; LC_ALL=C sed -i '' '/^end|/d' "$derived/1/P5.TXT"; t_play "$derived"
t_case "an emulator that ended before the guest's last line" 3 "A-1-0: the guest's step never ended" run
t_play "$f/p5time"
STUB_RC=3 t_case "the launcher refuses the run" 3 "the emulator did not run to its end" run
STUB_RC=3 t_case "the guest's clock is fixed" 0 "cycles=fixed 50000" kept_conf
t_case "no round" 2 "pairs is a number from 1" "$here/p5time.sh" "$build_a" "$build_b" synthetic:1000:83 on 0 "$work/out"
t_case "five arguments" 2 "usage:" "$here/p5time.sh" "$build_a" "$build_b" synthetic:1000:83 on 1
t_case "neither on nor off" 2 "on or off" "$here/p5time.sh" "$build_a" "$build_b" synthetic:1000:83 maybe 1 "$work/out"
t_case "its own help" 0 "usage: p5time.sh" "$here/p5time.sh" --help
t_end
