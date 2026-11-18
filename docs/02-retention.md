# 2. A search's copy is released without ending a live search

A program that looks thousands of files up while it lists a folder now gets the whole listing,
and the emulator's memory stays flat. It is proved on macOS and Windows.

## What was wrong

A listing could stop short, and the emulator kept a search's memory long after the search was
over. The copy was freed only when the search ran to its end, or when all 2,048 search slots
were taken.

Then the emulator emptied the whole table, which ended every search still in progress.

## What the fix changes

A search gives its memory back when it ends, and no live search is ended to make room.

- A search is named by its slot and a generation. A FindNext through a DTA whose slot went to
  another search answers "no more files" and never returns another folder's entry.
- A search for the volume label alone takes no slot.
- A long-name search ends with its handle (71A1h), and a path lookup with its answer.
- Searches of a whole folder share one sorted copy while the folder does not change.
- A full table gives back one slot, not all of them.
- Nothing is released when a process ends or by DTA address. That cannot be told apart from a
  search a real DOS would continue.

The branch is `dircache-retention`, five commits ending at `527476085`, on top of the
exact-name branch. The five are offered as one: with the first four alone, a listing that
looks every entry up by name stops at the table's reset. At the head it comes out whole.

It was written as a proposal on
[pull request 6831, "Release directory search snapshots when searches end"](https://github.com/joncampbell123/dosbox-x/pull/6831),
which upstream has since merged. [That pull request beside this branch](pr6831.md) has its own
page.

## The figures

Listings come out whole, a tree is copied whole and memory stays flat, as on MS-DOS where it
referees.

| What a program does | Unpatched | Exact-name alone | Retention | MS-DOS 7.10 |
| --- | --- | --- | --- | --- |
| 20,000 lookups that close their search: times the emulator emptied its search table | 29 | 29 | none | |
| 20,000 searches for the volume label: the same | 9 | 9 | none | |
| A whole-folder search left unfinished, 50,000 files: memory at 1 → 20 searches, macOS (kB) | 229,360 → 847,857 | 229,472 → 847,889 | 229,728 → 229,728 | |
| The same on Windows (kB) | 257,884 → 852,016 | 257,680 → 852,020 | 257,688 → 258,216 | |
| A listing of 3,000 files with libc `stat` on each, long names on: entries listed of 3,002 | 139 | 139 | 3,002 | no long names there |
| The same with long names off | 685 | 685 | 3,002 | 3,002 |
| XCOPY of a tree of 2,520 files in 18 folders: what arrived | 2,065 in 15 | 2,065 in 15 | 2,520 in 18 | 2,520 in 18 |
| Two searches read turn about, a lookup by name before every turn: entries each returned, of 42 and 32 | 28 and 28 | 28 and 28 | 42 and 32 | 42 and 32 |
| More whole-folder searches left open than the table has slots: a search started before them, of 42 | 34, and 30 entries of another folder | the same | 42 | 42 |

Source: `battery.sh --real-dos`, cells `memory synthetic:100:long <a|v> 20000`, `memory synthetic:50000:83 *.* d`, `enumstat s`, `xcopy`, `findlife` and `realdos`, in [results/macos/battery-base-retention-exact-name.txt](../results/macos/battery-base-retention-exact-name.txt) and [its Windows twin](../results/windows/battery-base-retention-exact-name.txt).

- The two FINDLIFE rows are its cases `turn-about-past-the-slots` and
  `left-open-past-the-slots`, in [findlife_base-build_on.txt](../bench/fixtures/battery/findlife_base-build_on.txt).
  MS-DOS's lines are in [realdos_msdos710_findlife_off.txt](../bench/fixtures/battery/realdos_msdos710_findlife_off.txt).
- Those two rows are read with long names on. MS-DOS has no long names, so its column is the
  same cases with long names off.
- The listing and table rows read the same on Windows. With long names off there, the
  retention build copies the whole tree and returns 42 and 32 in the turn-about case, in
  [results/windows/reporters.txt](../results/windows/reporters.txt).
- "none" in the first two rows is not evidence by itself: the retention build no longer has
  the log line they count. The evidence is that every one of the 20,000 calls found its file
  and every listing came out whole.

Against unpatched upstream, everything else answers the same:

| Check | Result on the retention build |
| --- | --- |
| LISTDUMP, every folder | byte for byte the same, 14 of 14 cells per host |
| EXACT's four judged sections | ALIKE |
| The emulator's unit tests | pass |
| The memory cells, long names on or off | none grows with the call count, but one on Windows |

Source: `battery.sh`, cells `run`, `exact`, `unit` and `memory`, in the same two files.

That one Windows cell is children that end with a search open:

| Host and build | Memory at 1 → 20 children (kB) |
| --- | --- |
| Windows, unpatched upstream | 264,088 → 980,000 |
| Windows, retention | 232,744 → 354,260 |
| Windows, retention with subject 10 merged | 220,168 → 220,180 |
| macOS, retention | 198,304 → 198,432 |

Source: `battery.sh`, cells `memory synthetic:50000:83 c <1|20>`, in the same two files; the merged build's `memory.sh` lines are in [results/windows/dyncore.txt](../results/windows/dyncore.txt).

The rise on Windows is not the directory cache's. It is a leak of the x86 dynamic core, which
[subject 10](10-dyncore-cache-reset.md) fixes, and with it merged the line holds flat.

## What a program can notice

Five answers move. Three go to MS-DOS's answer, and two are in long-name calls, where no real
DOS referees.

| What a program does | Unpatched | Retention | MS-DOS 7.10 |
| --- | --- | --- | --- |
| A FindNext after a search for the label alone | a file of the root | "no more files" | "no more files" |
| A label search that fails through the DTA of a live search: entries that search then returns | 1, from the root | 12 more | 12 |
| DRIFT's `label-search-then-edited`: entries returned after it | 4 | none | none |
| A 714Fh asked again after its search ended: entries a search then returns, of 32 | 1 | 32 | no long names there |
| A 714Eh turned away for want of a handle: entries its search then returns, of 42 | 3 | 42 | no long names there |

Source: `battery.sh --real-dos --raw`, calls `findpos.sh`, `drift.sh`, `findlife.sh` and `realdos.sh`, in [findpos_unlabelled_base-build_off.txt](../bench/fixtures/battery/findpos_unlabelled_base-build_off.txt), [drift_base-build_off.txt](../bench/fixtures/battery/drift_base-build_off.txt), [findlife_base-build_on.txt](../bench/fixtures/battery/findlife_base-build_on.txt), [realdos_msdos710_drift_off.txt](../bench/fixtures/battery/realdos_msdos710_drift_off.txt) and [realdos_msdos710_findpos_off.txt](../bench/fixtures/battery/realdos_msdos710_findpos_off.txt).

On Windows, with long names on, one more line differs: `fcb-wildcard-around-lfn-exact`, an FCB
search around a long-name call. It is in the section of EXACT that is printed and not judged.

There the retention build answers as every build does on macOS. The other two builds follow
the order of NTFS's aliases.

## How to check it

Count the table resets and read the memory on each build, then compare the answers and ask
MS-DOS:

```sh
bench/memory.sh <build> synthetic:100:long on a 20000
bench/memory.sh <build> synthetic:50000:83 off d 1 --file '*.*'
bench/memory.sh <build> synthetic:50000:83 off d 20 --file '*.*'
bench/enumstat.sh <unpatched> <patched>
bench/xcopy.sh <build> off
bench/findlife.sh <unpatched> <patched> off
bench/realdos.sh <patched> msdos710 <boot image> findlife
```

`slots_full=` counts the resets. [bench/README.md](../bench/README.md) says what each script
needs.

## What it needs

It needs [subject 1](01-exact-name.md). With long names off a libc `stat` is an exact-name
search that is never continued. Without that patch each one would still hold a whole folder.

## What is left

One thing is left, and it is declared.

**A search rewound by its saved DTA.** MS-DOS keeps the place of a search in the 21 bytes of
the DTA it reserves, so a program can rewind a search by putting saved bytes back. The
emulator keeps the place in its own table, before and after this branch.

| What a program does | The emulator returns | MS-DOS 7.10 returns |
| --- | --- | --- |
| Rewinds a search by its saved DTA | 7 more entries | 12 |
| Reads two copies of one DTA side by side | 6 and 6 | 12 and 12 |
| Puts a DTA back after its search ended | nothing | 15 |

Source: `battery.sh --real-dos --raw`, calls `findpos.sh` and `realdos.sh msdos710 findpos`, in [findpos_unlabelled_base-build_off.txt](../bench/fixtures/battery/findpos_unlabelled_base-build_off.txt) and [realdos_msdos710_findpos_off.txt](../bench/fixtures/battery/realdos_msdos710_findpos_off.txt).

Moving the place into the DTA is another design, and no program is known to need it. It is in
code where upstream already reverted a fix:
[pull request 5712, "Fix potential memory leaks in drive_cache.cpp"](https://github.com/joncampbell123/dosbox-x/pull/5712).
