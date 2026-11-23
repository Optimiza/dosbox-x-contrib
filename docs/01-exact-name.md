# 1. A search for one exact name does not copy the whole directory

A program that opens or checks one file in a large folder no longer makes the emulator copy the
whole folder for it. On macOS the peak memory in the large folder falls from 546,800 kB to about
326,000 kB. It is proved on macOS and Windows, and is to be offered with [subject 4](04-dta.md).

## What was wrong

A program that only asked whether one file exists paid for every file of the folder. Every
FindFirst copied and sorted the whole directory, whatever the pattern.

A libc `access`, `fopen` or `stat` reaches it, because the C library looks the name up with a
FindFirst.

On upstream `main-ai` at `ac2787a42` the copy is given back when the call ends. So memory no
longer grows with the calls, but each call still builds the copy, and the emulator holds the
folder's size after one call.

## What the fix changes

A search for one name keeps only the entries that match.

- A FindFirst whose pattern has no `*` or `?` keeps the entries that match, one in every
  ordinary case, and not a sorted copy of the directory.
- Wildcard searches are untouched.
- A later FindNext can arrive with another pattern, because the program edited its DTA. The
  copy is made then, and the search goes on behind the entry already returned.
- A rename of the folder makes that copy first, so the search goes on as MS-DOS's does.
- The searches for one name a program leaves kept are released when it ends.

The commits are `d957231fb` and `892497054`, and the two corrections `c8fd18dea` and `c8f5d14aa`,
of the branch `dta-searches-mainai`, on `main-ai` at `ac2787a42`, with the commits of
[subject 4](04-dta.md). The fork keeps them as well on
`dircache-exact-name-mainai`, which stands on the merge of
[pull request 6831, "Release directory search snapshots when searches end"](https://github.com/joncampbell123/dosbox-x/pull/6831).

## The figures

The peak falls, and the memory held after one call falls with it. After 20 calls on macOS the
memory held is a little higher. On macOS, one call repeated on one file, long names on:

| Folder and call | Held after 1 call, unpatched → patched (kB) | Held after 20, unpatched → patched (kB) | Peak, unpatched → patched (kB) |
| --- | --- | --- | --- |
| 169,457 files, `access` | 387,649 → 286,785 to 287,889 | 279,409 → 286,753 to 288,161 | 546,800 → 325,712 to 326,816 |
| 169,457 files, a FindFirst | 387,617 → 286,801 to 288,304 | 278,961 → 286,801 to 287,456 | 546,816 → 325,744 to 327,264 |
| 50,000 files, `access` | 214,048 → 200,352 | 213,984 → 200,272 | 303,696 → 239,328 |

Source: `memory.sh <build> <the large folder> on <a|d> <1|20> --file SONG.MID` and `memory.sh <build> synthetic:50000:long on a <1|20>`, in [results/macos/dta-searches-memory.txt](../results/macos/dta-searches-memory.txt). The patched cells of the large folder are three samples each, so they read as a range.

After the repeated calls the patched build holds 7,300 to 8,800 kB more than unpatched on the
large folder. Where those kB come from is not examined.

On Windows, one call repeated on one file in the large folder of 169,452 files, long names on:

| Call | Held after 1 call, unpatched → patched (kB) | Held after 20, unpatched → patched (kB) | Peak, unpatched → patched (kB) |
| --- | --- | --- | --- |
| `access` | 297,700 to 298,012 → 301,504 to 301,568 | 332,936 to 333,956 → 301,632 to 301,740 | 486,232 to 487,256 → 280,772 to 280,824 |
| A FindFirst | 298,248 to 298,340 → 301,556 to 301,572 | 333,280 to 333,836 → 301,484 to 301,636 | 486,596 to 486,804 → 280,732 to 280,808 |

Source: `memory.sh <build> <the large folder> on <a|d> <1|20> --file SONG.MID`, three samples each, in [results/windows/dta-searches-memory.txt](../results/windows/dta-searches-memory.txt).

There the patched build, against unpatched:

- holds 3,200 to 3,900 kB more after one call;
- holds 31,200 to 32,400 kB less after the repeated calls;
- peaks 205,400 to 206,500 kB lower.

Its memory does not move with the calls.

The cell's field is `held_footprint_kb` on macOS and `held_private_kb` on Windows.

What the builds list and answer is unchanged:

| Check | Result |
| --- | --- |
| LISTDUMP, every field a search returns, 18 synthetic folders and the large folder | byte-identical, long names on and off |
| EXACT, one search per name, call and attribute | its four judged sections read ALIKE, long names on and off |

Source: `run.sh` and `exact.sh`, in [results/macos/dta-searches-run.txt](../results/macos/dta-searches-run.txt) and [results/macos/dta-searches-answers.txt](../results/macos/dta-searches-answers.txt).

LISTDUMP lists a 4Eh and a 714Eh enumeration and a set of lookups by name, in order. It runs
with 8.3 and long names.

## What a program can notice

A file created between FindFirst and FindNext is now returned if it sorts behind the entry
found. DRIFT's case `folder-gained-files` creates two files, and one of them sorts behind:

| Build | Entries the search returns after the first |
| --- | --- |
| Unpatched upstream | 6 |
| Patched | 7 |
| MS-DOS 7.10 | 8 |

Source: `drift.sh base dta off`, in [results/macos/dta-searches-answers.txt](../results/macos/dta-searches-answers.txt); MS-DOS 7.10's line is in [results/macos/dta-searches-msdos.txt](../results/macos/dta-searches-msdos.txt).

## How to check it

Read the memory at two call counts on each build, then compare what the two builds list:

```sh
bench/memory.sh <unpatched> <the large folder> on a 1 --file <a file in it>
bench/memory.sh <unpatched> <the large folder> on a 20 --file <a file in it>
bench/memory.sh <patched> <the large folder> on a 1 --file <a file in it>
bench/memory.sh <patched> <the large folder> on a 20 --file <a file in it>
bench/run.sh <unpatched> <patched> synthetic:50000:long on
bench/exact.sh <unpatched> <patched> on
bench/drift.sh <unpatched> <patched> off
```

[bench/README.md](../bench/README.md) says what each script needs.

## What it needs

It stands alone. In the branch it goes with [subject 4](04-dta.md)'s fix for a restored DTA,
which keeps a search for one name alive, and that search is the one this makes cheap.

## What is left

The memory held after 20 calls on macOS is a little higher, as the figures show, and nothing explains it yet.

[Subject 2](02-retention.md) has the search slots: a table that fills is still emptied whole.
