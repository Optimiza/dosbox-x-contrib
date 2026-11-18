# 1. A search for one exact name does not copy the whole directory

A program that opens or checks one file in a large folder no longer makes the emulator keep a
copy of the whole folder. It is proved on macOS and Windows.

## What was wrong

A program that only asked whether one file exists paid for every file of the folder. Every
FindFirst copied and sorted the whole directory, whatever the pattern.

A libc `access`, `fopen` or `stat` reaches it, because the C library looks the name up with a
FindFirst.

## What the fix changes

A search for one name keeps only the entries that match.

- A FindFirst whose pattern has no `*` or `?` keeps the entries that match, one in every
  ordinary case, and not a sorted copy of the directory.
- Wildcard searches are untouched.
- A later FindNext can arrive with another pattern, because the program edited its DTA. The
  copy is made then, and the search goes on behind the entry already returned, as on unpatched
  upstream.

The branch is `dircache-exact-name`, two commits (`7e74299e2`, `73e09f70d`).

## The figures

The memory the emulator holds no longer grows with the calls. Each row is one call repeated on
one file, with long names on.

On macOS:

| Folder | Call | Unpatched, 1 → 20 calls (kB) | Per call | Patched, 1 → 20 calls (kB) |
| --- | --- | --- | --- | --- |
| 169,457 files | `access` | 498,305 → 4,681,220 | 215.0 MB | 277,584 → 277,681 |
| 169,457 files | `fopen` | 608,449 → 6,882,821 | 322.5 MB | 277,488 → 277,633 |
| 50,000 files | `access` | 262,544 → 1,499,681 | 63.6 MB | 197,600 → 197,424 |

Source: `battery.sh --real-dos`, cells `memory real <a|f> <1|20>` and `memory synthetic:50000:long a <1|20>`, `base` and `third`, in [results/macos/battery-base-retention-exact-name.txt](../results/macos/battery-base-retention-exact-name.txt).

On Windows:

| Folder | Call | Unpatched, 1 → 20 calls (kB) | Per call | Patched, 1 → 20 calls (kB) |
| --- | --- | --- | --- | --- |
| 169,452 files | `access` | 513,344 → 4,542,512 | 207.1 MB | 301,596 → 301,648 |
| 169,452 files | `fopen` | 619,436 → killed at the 6 GB limit | 310.6 MB | 301,720 → 301,528 |
| 50,000 files | `access` | 289,132 → 1,477,624 | 61.1 MB | 226,880 → 226,732 |

Source: `battery.sh`, the same cells, in [results/windows/battery-base-retention-exact-name.txt](../results/windows/battery-base-retention-exact-name.txt).

The growth per call is the difference between the two counts divided by the calls between
them, in MB of 1,024 kB. The Windows `fopen` row is derived from 1 and 5 calls, read apart:

| `fopen` calls, Windows, unpatched | Memory held (kB) |
| --- | --- |
| 1 | 619,572 |
| 5 | 1,891,860 |

Source: `memory.sh <build> <the large folder> on f <calls>`, in [results/windows/series-real-folder.txt](../results/windows/series-real-folder.txt).

What the builds list and answer is unchanged:

| Check | Over | Result |
| --- | --- | --- |
| LISTDUMP, every field a search returns | folders of 1,000, 10,000 and 50,000 files, and the large folder | byte-identical in 14 of 14 cells on each host |
| EXACT, one search per name, call and attribute | 362 questions about awkward names | its four judged sections read ALIKE on both hosts |
| The emulator's unit tests | 68 tests | pass on every build |

Source: `battery.sh`, cells `run`, `exact` and `unit`, in the same two files.

LISTDUMP lists a 4Eh and a 714Eh enumeration and a set of lookups by name, in order. It runs
with 8.3 and long names, long names on and off.

Each check compares the retention build, which contains this patch, with unpatched upstream
and with the exact-name build. So the three builds list alike.

## What a program can notice

A file created between FindFirst and FindNext is now returned if it sorts behind the entry
found. DRIFT's case `folder-gained-files` creates two files, and one of them sorts behind:

| Build | Entries the search returns after the first |
| --- | --- |
| Unpatched upstream | 6 |
| Patched | 7 |
| MS-DOS 7.10 | 8 |

Source: `battery.sh --real-dos --raw`, calls `drift.sh` and `realdos.sh msdos710 drift`, in [drift_base-build_off.txt](../bench/fixtures/battery/drift_base-build_off.txt) and [realdos_msdos710_drift_off.txt](../bench/fixtures/battery/realdos_msdos710_drift_off.txt).

## How to check it

Read the memory at two call counts on each build, then compare what the two builds list:

```sh
bench/memory.sh <unpatched> synthetic:50000:long on a 1
bench/memory.sh <unpatched> synthetic:50000:long on a 20
bench/memory.sh <patched> synthetic:50000:long on a 1
bench/memory.sh <patched> synthetic:50000:long on a 20
bench/run.sh <unpatched> <patched> synthetic:50000:long on
bench/exact.sh <unpatched> <patched> on
bench/drift.sh <unpatched> <patched> off
```

The memory figure is `held_footprint_kb` on macOS and `held_private_kb` on Windows.
[bench/README.md](../bench/README.md) says what each script needs.

## What it needs

Nothing. It stands alone.

## What is left

Nothing is released sooner: that is [subject 2](02-retention.md).

- A slot now holds one entry and not the folder, but the table still fills and is emptied.
  The first rows of subject 2's figures count it.
- A listing that looks every entry up through libc `stat` still stops short.
