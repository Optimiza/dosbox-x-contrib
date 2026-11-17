"""Tables of the timers' batch from its out dirs: README.md, "The timers".

usage: analyze.py <raw dir> <batch> [<batch>...]
Each <raw dir>/<batch> is a batch.sh out dir. Exit 3 when a cell has no timed run.
"""

import glob
import os
import re
import statistics
import sys
from typing import Any

LINE = re.compile(
    r"^(p5time|p5rep)\|(\d+)\|([AB])\|seconds=([\d.]+)\|t0=(\d+)\|t1=(\d+)\|pid=(\w+)\|guest=(.*)$"
)


def lines(path: str) -> list[str]:
    with open(path, errors="replace") as f:
        return f.readlines()


def runs(path: str) -> list[dict[str, Any]]:
    out = []
    for line in lines(path):
        m = LINE.match(line.rstrip("\n"))
        if m:
            out.append(
                {
                    "arm": m.group(3),
                    "s": float(m.group(4)),
                    "t0": int(m.group(5)),
                    "t1": int(m.group(6)),
                    "guest": m.group(8),
                }
            )
    return out


def fmt(x: float) -> str:
    return f"{x:.3f}" if x < 10 else f"{x:.1f}"


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__, file=sys.stderr)
        return 2
    raw, phases = sys.argv[1], sys.argv[2:]
    rc = 0
    rows: list[tuple[Any, ...]] = []
    hot: list[tuple[Any, ...]] = []
    for phase in phases:
        load = os.path.join(raw, phase, "load.txt")
        if not os.path.isfile(load) or not os.path.isfile(os.path.join(raw, phase, "jobs.txt")):
            print(f"analyze.py: INVALID: {raw}/{phase} is not a batch's out dir", file=sys.stderr)
            return 3
        idle = [
            (int(f[1]), float(f[4]))
            for f in (line.rstrip("\n").split("|") for line in lines(load))
            if f[0] == "cpu" and len(f) == 5
        ]
        jobs = [
            line.split("|")
            for line in lines(os.path.join(raw, phase, "jobs.txt"))
            if line.strip() and not line.startswith("#")
        ]
        for keys in jobs:
            cell, ka, kb = keys[0], keys[2], keys[3]
            tries = sorted(
                glob.glob(os.path.join(raw, phase, cell, "try*")),
                key=lambda p: int(p.rsplit("try", 1)[1]),
            )
            if not tries:
                print(f"{cell}: no try", file=sys.stderr)
                rc = 3
                continue
            t = tries[-1]
            calls = {os.path.basename(p)[:-4]: runs(p) for p in glob.glob(os.path.join(t, "*.out"))}
            ab = calls.get("AB", [])
            aa = {k[3:]: v for k, v in calls.items() if k.startswith("AA-")}
            if not ab or len(aa) != 2:
                print(f"{cell}: missing calls in {t}", file=sys.stderr)
                rc = 3
                continue
            a = [r["s"] for r in ab if r["arm"] == "A"]
            b = [r["s"] for r in ab if r["arm"] == "B"]
            spread, gap = {}, {}
            for k in (ka, kb):
                v = [r["s"] for r in aa[k]]
                spread[k] = max(v) - min(v)
                gap[k] = abs(
                    statistics.median([r["s"] for r in aa[k] if r["arm"] == "A"])
                    - statistics.median([r["s"] for r in aa[k] if r["arm"] == "B"])
                )
            ma, mb = statistics.median(a), statistics.median(b)
            noise = max(spread[ka], spread[kb])
            verdict = "ranked" if abs(ma - mb) > noise else "within noise"
            ratio = ma / mb if mb else float("inf")
            row: tuple[Any, ...] = (phase, cell, ka, kb, ma, min(a), max(a), mb, min(b), max(b))
            row += (ratio, spread[ka], gap[ka], spread[kb], gap[kb], verdict)
            rows.append(row + (len(a), len(aa[ka]), len(tries)))
            for name, rs in calls.items():
                for r in rs:
                    low = [i for (s, i) in idle if r["t0"] - 1 <= s <= r["t1"] and i < 10]
                    if low:
                        hot.append((phase, cell, name, r["arm"], r["s"], min(low)))
    print(
        "| cell | A | B | A median (fastest, slowest) | B median (fastest, slowest) | A/B "
        "| A's A/A spread, arm gap | B's A/A spread, arm gap | verdict "
        "| runs per build in A/B, in A/A | tries |"
    )
    print("|---|---|---|---|---|---|---|---|---|---|---|")
    for w in rows:
        print(
            f"| {w[1]} | {w[2]} | {w[3]} | {fmt(w[4])} ({fmt(w[5])}, {fmt(w[6])}) "
            f"| {fmt(w[7])} ({fmt(w[8])}, {fmt(w[9])}) | {w[10]:.2f} | {fmt(w[11])}, {fmt(w[12])} "
            f"| {fmt(w[13])}, {fmt(w[14])} | {w[15]} | {w[16]}, {w[17]} | {w[18]} |"
        )
    print()
    print("runs whose window holds a host sample under 10 % idle:")
    for h in hot:
        print(f"  {h[0]} {h[1]} {h[2]} arm {h[3]}: {fmt(h[4])} s, idle {h[5]}")
    if not hot:
        print("  none")
    if not rows and rc == 0:
        print("analyze.py: INVALID: no cell in the batches named", file=sys.stderr)
        return 3
    return rc


if __name__ == "__main__":
    sys.exit(main())
