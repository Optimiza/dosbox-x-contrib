"""Counts, for each build's report of a CD or a folder, the lines that two real DOS answer alike and it matches: README.md, "agree.py".

usage: agree.py <one DOS's report> <another DOS's report> <build report>...
       agree.py --differ <one DOS's report> <another DOS's report> <output of a comparing script>
The DOS reports are what realdos.sh printed (each line named by its DOS), the build reports what
dosans.sh printed or DOSANS.EXE left; dosans.sh prints two builds' reports in one file, and
<file>#A and <file>#B name the part of each. The first build is the base: the last line says how many of the
lines the last build changes against it equal both DOS.
prints: one line per build with the lines it equals out of those both DOS answer alike, and that last line
With --differ the third file is what exact.sh, template.sh, dosans.sh and the like print, which holds only
the lines that differ, A's marked < and B's marked >; the lines of each side that equal both DOS are counted.
exit: 0 counted | 2 usage | 3 INVALID, no line of the two DOS reports could be judged
"""

import re
import sys

NAMES = ("msdos622:", "msdos710:", "freedos:")
# Lines that carry a time, an address or a place in a DOS's own memory: not an answer to compare.
NOISE = ("chain|", "end|", "section", "dta|", "dev|")


def load(path: str) -> dict[str, str]:
    """A report; <file>#A or <file>#B is the part dosans.sh and its like printed for that build."""
    lines: dict[str, str] = {}
    part = None
    if "#" in path:
        path, _, part = path.rpartition("#")
    current = None
    with open(path, errors="replace") as handle:
        for raw in handle:
            line = raw.rstrip("\r\n")
            if part:
                header = re.match(r"^[a-z.]+: build ([AB])\b", line)
                if header:
                    current = header.group(1)
                    continue
                if re.match(r"^[a-z.]+: (ALIKE|DIFFERENT)", line):
                    current = None
                if current != part:
                    continue
            head, _, rest = line.partition("|")
            if head in ("msdos622", "msdos710", "freedos"):
                line = rest
            if not line or line.startswith(NOISE) or line.startswith("realdos.sh:"):
                continue
            if line[:2] in ("< ", "> "):
                line = line[2:]
            found = re.search(r"\|err=", line)
            lines[line[: found.start()] if found else line] = line
    return lines


def differ() -> int:
    first, second = load(sys.argv[2]), load(sys.argv[3])
    agreed = {key: line for key, line in first.items() if second.get(key) == line}
    if not agreed:
        print("agree.py: INVALID: the two DOS answered no line alike", file=sys.stderr)
        return 3
    sides: dict[str, list[tuple[str, str]]] = {"<": [], ">": []}
    with open(sys.argv[4], errors="replace") as handle:
        for raw in handle:
            line = raw.rstrip("\r\n")
            if line[:2] in ("< ", "> ") and not line[2:].startswith(NOISE):
                found = re.search(r"\|err=", line[2:])
                sides[line[0]].append((line[2: 2 + found.start()] if found else line[2:], line[2:]))
    if not sides["<"] and not sides[">"]:
        print("agree.py: INVALID: the output holds no line that differs", file=sys.stderr)
        return 3
    for mark, name in (("<", "A"), (">", "B")):
        equal = sum(1 for key, line in sides[mark] if agreed.get(key) == line)
        print(f"lines of build {name} that differ: {len(sides[mark])}, equal to both DOS: {equal}")
    return 0


def main() -> int:
    if len(sys.argv) == 5 and sys.argv[1] == "--differ":
        return differ()
    if len(sys.argv) < 4:
        print(__doc__, file=sys.stderr)
        return 2
    first, second = load(sys.argv[1]), load(sys.argv[2])
    agreed = {key: line for key, line in first.items() if second.get(key) == line}
    if not agreed:
        print("agree.py: INVALID: the two DOS answered no line alike", file=sys.stderr)
        return 3
    print(f"lines both DOS answer alike: {len(agreed)} of {len(set(first) | set(second))}")
    builds = [load(path) for path in sys.argv[3:]]
    for path, build in zip(sys.argv[3:], builds):
        equal = sum(1 for key, line in agreed.items() if build.get(key) == line)
        print(f"{path.rsplit('/', 1)[-1]}: equal to both DOS on {equal} of {len(agreed)}")
    if len(builds) > 1:
        base, last = builds[0], builds[-1]
        changed = [key for key in agreed if base.get(key) != last.get(key)]
        right = sum(1 for key in changed if last.get(key) == agreed[key])
        spoiled = sum(1 for key in agreed if base.get(key) == agreed[key] and last.get(key) != agreed[key])
        print(f"lines the last build changes against the first: {len(changed)}, now equal to both DOS: {right}, were right and are now wrong: {spoiled}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
