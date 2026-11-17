#!/usr/bin/env bash
# batch.sh's verdicts with stand-ins for the timers, the sampler and the judge, no emulator:
# bash batch.test.sh. The timer plays a run of each build, the slow one ten times slower; the
# judge answers the verdicts STUB_VERDICTS lists, one per cell try, in turn; analyze.py reads
# what the batch left.
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
s=$work/p5scripts
mkdir -p "$s" "$work/F" || exit 3
cat > "$s/p5time.sh" <<'EOT'
#!/usr/bin/env bash
now=$(date +%s)
for who in A B; do
    if [ "$who" = A ]; then b=$1; else b=$2; fi
    case "$b" in *slow*) t=2.000 ;; *) t=0.200 ;; esac
    echo "p5time|1|$who|seconds=$t|t0=$now|t1=$now|pid=1|guest=p5|mode=f"
done
exit "${STUB_TIMER_RC:-0}"
EOT
cat > "$s/loadwatch.sh" <<'EOT'
#!/usr/bin/env bash
while :; do echo "cpu|$(date +%s)|1|1|98" >> "$1"; sleep 1; done
EOT
cat > "$s/judge.py" <<'EOT'
import os
import sys

state = os.path.join(os.environ["STUB_STATE"], "verdicts")
done = int(open(state).read()) if os.path.exists(state) else 0
verdicts = os.environ["STUB_VERDICTS"].split()
open(state, "w").write(str(done + 1))
print(verdicts[min(done, len(verdicts) - 1)] + " samples=1")
sys.exit(3 if verdicts[min(done, len(verdicts) - 1)] == "INVALID" else 0)
EOT
chmod +x "$s/p5time.sh" "$s/loadwatch.sh"
printf 'one|p5time|BASE|HEAD|%s|on|-|1\n' "$work/F" > "$work/jobs.txt"
export P5_SCRIPTS=$s P5_BUILD_BASE=$work/slow-base P5_BUILD_HEAD=$work/head
# batch <verdicts>: one batch, its out dir fresh; its log and exit code kept.
batch() {
    rm -rf "$work/out" "$STUB_STATE/verdicts"
    STUB_VERDICTS=$1 "$here/batch.sh" "$work/jobs.txt" "$work/out" > "$work/said.txt" 2>&1
    echo $? > "$work/rc"
}
logged() { cat "$work/out/batch.log" "$work/said.txt"; return "$(cat "$work/rc")"; }

batch QUIET
t_case "a cell that ran quiet" 0 "one try 1: QUIET" logged
t_case "its three calls" 0 "one try 1: AA-HEAD exit 0" logged
t_case "the tables, the base ranked slower" 0 "| one | BASE | HEAD | 2.000 (2.000, 2.000) | 0.200 (0.200, 0.200) | 10.00 |" python3 -I "$here/analyze.py" "$work" out
batch "BUSY QUIET"
t_case "a cell that ran busy is run again" 0 "one try 2: QUIET" logged
batch INVALID
t_case "a cell with no timed line is not run again" 3 "one try 1: INVALID" logged
t_case "and has no second try" 1 "" test -d "$work/out/one/try2"
STUB_TIMER_RC=3 batch QUIET
t_case "a timer call that was INVALID" 3 "one try 1: AB exit 3" logged
P5_BUILD_HEAD="" batch QUIET
t_case "a key no build is named for" 2 "one: no build named for BASE or HEAD" logged
t_case "the tables of what is not a batch" 3 "is not a batch's out dir" python3 -I "$here/analyze.py" "$work" none-such
t_case "one argument" 2 "usage: batch.sh" "$here/batch.sh" "$work/jobs.txt"
t_case "no jobs file" 2 "no jobs file" "$here/batch.sh" "$work/none" "$work/out"
t_end
