"""Says whether one cell of the timers' batch ran on a quiet host: README.md, "The timers".

usage: judge.py <load.txt> <cell try dir>
prints: QUIET|BUSY samples=<n> idle_min=<%> idle_mean=<%> spikes=<pid:cmd:cpu,...>
exit: 0 judged | 2 usage | 3 INVALID, the cell holds no timed line
"""

import glob
import os
import re
import sys

THRESHOLD = 80.0
IDLE_FLOOR = 10.0


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    load, cell = sys.argv[1], sys.argv[2]
    t0s, t1s, mine = [], [], set()
    for path in glob.glob(os.path.join(cell, "*.out")):
        with open(path, errors="replace") as handle:
            out = handle.readlines()
        for line in out:
            m = re.search(r"\|t0=(\d+)\|t1=(\d+)\|pid=(\w+)\|", line)
            if m:
                t0s.append(int(m.group(1)))
                t1s.append(int(m.group(2)))
                mine.add(m.group(3))
    if not t0s:
        print("INVALID samples=0 no timed line in the cell: nothing to judge")
        return 3
    # 15 s before the first go, so that a short window still holds one sample of every 10 s.
    lo, hi = min(t0s) - 15, max(t1s) + 2
    stamps: list[int] = []
    idle: list[float] = []
    top: dict[int, dict[str, tuple[str, float]]] = {}
    with open(load, errors="replace") as file:
        samples = file.readlines()
    for line in samples:
        f = line.rstrip("\n").split("|")
        if f[0] == "cpu" and len(f) == 5 and lo <= int(f[1]) <= hi:
            stamps.append(int(f[1]))
            idle.append(float(f[4]))
        elif f[0] == "top" and len(f) >= 6 and lo <= int(f[1]) <= hi:
            try:
                cpu = float(f[4])
            except ValueError:
                continue
            if f[2] not in mine and cpu >= THRESHOLD:
                top.setdefault(int(f[1]), {})[f[2]] = (f[5], cpu)
    busy = [f"idle {i:g} % at {s}" for s, i in zip(stamps, idle, strict=True) if i < IDLE_FLOOR]
    ordered = sorted(stamps)
    for a, b in zip(ordered, ordered[1:], strict=False):
        for pid in top.get(a, {}):
            if pid in top.get(b, {}):
                busy.append(f"{pid}:{top[a][pid][0]}")
    spikes = sorted({f"{pid}:{c}:{v:.0f}" for t in top.values() for pid, (c, v) in t.items()})
    verdict = "BUSY" if busy else "QUIET"
    if not stamps:
        verdict = "BUSY"
        busy = ["no sample of the host in the window"]
    print(
        f"{verdict} samples={len(stamps)} idle_min={min(idle) if idle else 'none'} "
        f"idle_mean={sum(idle) / len(idle) if idle else 0:.1f} spikes={','.join(spikes) or 'none'}"
        + (f" sustained={','.join(sorted(set(busy)))}" if busy else "")
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
