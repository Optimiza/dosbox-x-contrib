# 3. The first read of a large folder

The first touch of a large folder no longer stalls the emulator, and no listing changes. In the
large folder it is 22 to 64 times faster. It is proved on macOS and Windows.

## What was wrong

The first read of a folder took a time that grows with the square of its size. Each new name
was compared with every name read before it, in four loops of `src/dos/drive_cache.cpp`:

- the duplicate check, which asks whether an 8.3 name was already read, with long names on;
- the place of a new 8.3 alias in the sorted list of aliases, found by walking the list;
- the number of a new alias, found by walking every alias of its prefix;
- the Wine-style lookup, which hashes every entry read so far for each name shaped `ABCD~XYZ`.

[Issue 3572, "Very slow response when querying a large directory"](https://github.com/joncampbell123/dosbox-x/issues/3572)
and a later comment of
[issue 5039, "Large number of files in dir stalls dosbox-x"](https://github.com/joncampbell123/dosbox-x/issues/5039)
report it with `DIR`. The first `fopen` in the large folder pays it too, as
[issue 6823, "FindFirst copies and retains the whole directory on every call"](https://github.com/joncampbell123/dosbox-x/issues/6823)
reports.

## What the fix changes

Each loop asks a table or makes a binary search instead of walking, one commit per loop. The
figures are from `dircache-first-read`, tag `archive/dircache-first-read` of the fork, ending at `f8fca9bd0`. The same four commits, on
`main-ai`, are `dircache-first-read-mainai`, ending at `2840025d8`:

1. A new alias finds its place in the sorted list by binary search.
2. The duplicate check asks a set of the names read so far.
3. The Wine-style lookup asks a set too.
4. A new alias jumps to the last number of its prefix, where every alias of the prefix has the
   same number of digits. Elsewhere it walks as before.

## The figures

The stall is gone wherever there was one. Where unpatched upstream had none, both builds are
within the noise.

| A first read, macOS | Patched build, seconds | Times faster than unpatched |
| --- | --- | --- |
| 169,000 files with 8.3 names, long names on | 0.483 | 531 |
| 169,000 files with long names, long names on | 1.44 | 65 |
| The large folder, long names on | 1.11 | 64 |
| The large folder, long names off | 1.04 | 22 |
| 8.3 names with long names off, 10,000 to 169,000 files | 0.021 to 0.352 | within the noise |

Source: `p5time.sh`, cells `169000-83-on`, `169000-long-on`, `real-on`, `real-off` and the `83-off` cells, in [results/macos/first-read-wall.txt](../results/macos/first-read-wall.txt); a cell timed twice is read from its later table.

- Each time is the median of runs interleaved with unpatched upstream's.
- A cell counts only when the two builds differ by more than each build's spread against itself.
- Unpatched upstream's own seconds move between batches more than the factor does, so the page
  gives the factor.

The reporters' cases, timed the same way:

| Upstream case, macOS | Patched build, seconds | Times faster than unpatched |
| --- | --- | --- |
| Issue 3572: `DIR` of 50,000 files with 8.3 names, long names on | 0.432 | 31 |
| Issue 3572: `DIR` of one of those files | 0.117 | 117 |
| Issue 5039: `DIR` of 50,000 long names | 0.653 | 5.7 |
| Issue 6823: one 716Ch open in the large folder | 1.12 | 63 |
| Issue 6823: one C library `fopen` there | 1.28 | 53 |

Source: `p5rep.sh`, cells `r3572-*`, `r5039-*` and, in its third table, `r6823-*`, in [results/macos/first-read-wall.txt](../results/macos/first-read-wall.txt).

With long names off the two `DIR` cases of issue 3572 take the same time on both builds.

On Windows NTFS gives every file its 8.3 alias, so the two alias loops never run there. The
other two do, and the counts fall as on macOS:

| What a first read does, Windows, long names on | Unpatched | Patched |
| --- | --- | --- |
| Compares for the duplicate check, 169,000 files with 8.3 names | 14,280,753,501 | 169,001 lookups |
| Compares for the duplicate check, the large folder | 4,791,379,669 | 61,109 lookups |
| Hashes for the Wine-style lookup, the large folder | 55,558,527 | 169,108 |

Source: a first read of each folder on counter builds of both, in [results/windows/first-read-counts.txt](../results/windows/first-read-counts.txt).

The read keeps more memory while it runs, and part of it stays:

| Held after the first read, macOS, long names on | Unpatched (kB) | Patched (kB) |
| --- | --- | --- |
| The large folder, first run | 610,465 | 628,129 |
| The large folder, second run | 608,769 | 625,713 |
| 50,000 long names | 295,537 | 297,281 |

Source: `memory.sh <build> <folder> on f 1`, in [results/macos/first-read-memory.txt](../results/macos/first-read-memory.txt).

In the large folder that is 16.5 to 17.3 MB more, each the difference of one pair of runs. A
MB here is 1,024 kB. The difference is 2.8 to 2.9 % of what unpatched upstream holds.

## What a program can notice

Nothing but the speed. Every listing is byte for byte upstream's, aliases included, in every
folder of the bench and in the large folder, with long names on and off.

## How to check it

Time a first read on both builds, then compare what they list:

```sh
bench/p5time.sh <unpatched> <patched> synthetic:169000:83 on 2 <out dir>
bench/p5rep.sh <unpatched> <patched> synthetic:50000:83 on dir 3 <out dir>
bench/run.sh <unpatched> <patched> synthetic:50000:long on
```

Run each pair a second time with one build against itself: that spread is the noise. The
counts of the Windows table come from counter builds the bench does not carry.
[bench/README.md](../bench/README.md) says what each script needs.

## What it needs

Nothing. The figures' branch is cut from upstream `main-ai` at `4e0b6adcf`; the branch offered
as [pull request 6853, "Read a large folder without comparing every name with every other"](https://github.com/joncampbell123/dosbox-x/pull/6853)
stands on `main-ai` at `218ec1894`. [Subject 5](05-alias.md) is built on it.

## What is left

**The tail of the long-name list.** After this branch the largest cost left in a read of long
names is the move of that list's tail at each insert. The whole read of 169,000 long names is
the 1.44 seconds of the first table, so it is named as the next cost and not proposed.

**A drive mounted on the large folder.** Mounting the folder as the root of a drive makes the
same first read inside `MOUNT`, earlier.
