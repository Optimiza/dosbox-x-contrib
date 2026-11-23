# 4. A find call does not disturb another search's DTA

A program that runs one search inside another, mixes the old and the long-name calls, or puts a
saved DTA back now gets what MS-DOS gives. It is proved on macOS and Windows, and is to be
offered together with the pieces of subjects 1 and 2 as one pull request.

## What was wrong

A search in progress loses its place when another call writes over its state. Unpatched upstream
`main-ai` at `ac2787a42` has these defects.

- A FindFirst that fails after the search was set up has already overwritten the DTA's pattern.
  MS-DOS leaves the DTA as it was.
- A long-name FindFirst (714Eh) writes its pattern into whichever DTA is current, and breaks a
  4Eh search in progress.
- The FCB find calls and the emulator's own path lookups share one temporary DTA. So an FCB
  search does not survive a long-name call.
- AH=0Fh, which opens an FCB by wildcards, writes the entry it finds into the program's DTA.
- With long names off, the DTA's search template is padded with zeros where MS-DOS pads with
  spaces. So a template a program writes the MS-DOS way matches nothing, and a `*` in it is read
  as a wildcard.
- A DTA a program saved, put back and edited has lost its search, because a search for one name
  is released when another FindFirst goes through its DTA. That came with
  [pull request 6831, "Release directory search snapshots when searches end"](https://github.com/joncampbell123/dosbox-x/pull/6831).
- With long names on, a template a program edited is matched as a wildcard pattern: a full-length
  name in small letters matches where MS-DOS's does not.
- `isoDrive::FindNext` indexes its table with a number read from the guest. No run shows an
  effect.

## What the fix changes

Each find call writes only where its own search keeps its state, and a search survives what the
program does to its DTA.

- A FindFirst that fails leaves the DTA as it was.
- A 714Eh, and an AH=0Fh open by wildcards, leave the program's DTA alone.
- The state of an FCB search lives in the program's FCB, as MS-DOS keeps it.
- With long names off, the template is padded with spaces, and a `*` in it is the character it
  is.
- A search for one name goes on when the program restores its DTA and edits it. It is cheap
  because [subject 1](01-exact-name.md) keeps one entry for it and not the folder.
- With long names on, a template the program edited is read as with them off, in a DTA and in an
  FCB. Each search the directory cache tracks keeps the 11 bytes its FindFirst wrote, and a
  template that differs from them was edited.
- That record belongs to its slot's generation and drive, so a later search that gets the same
  number is not read as edited.
- A search for one name goes on when its folder is renamed: it is widened once the rename has
  succeeded.
- The searches for one name a program leaves kept are released when it ends.
- The index `isoDrive::FindNext` reads from the guest is checked.
- A search for the volume label that finds none gives its slot back, which is
  [subject 2](02-retention.md)'s.

The branch is `dta-searches-mainai`, on upstream `main-ai` at `ac2787a42`, nineteen commits, head
`3f2e6d08f`. It is proved and not pushed. Its commits, in order:

- `e900909c8` keeps the DTA search template in the form MS-DOS writes.
- `7c76f4fe5` leaves the DTA as it was when a FindFirst finds nothing.
- `fde39c582` keeps the long-name FindFirst out of the DTA.
- `f3fd01df8` keeps an FCB search's state in the program's FCB.
- `3d3ca9555` leaves the name of an FCB that AH=0Fh opens by wildcards as written.
- `76ff8f783` leaves the program's DTA alone when AH=0Fh opens by wildcards.
- `47f78348c` matches a `*` in a DTA template a program writes as itself.
- `3779d25a2` checks the search number `isoDrive::FindNext` takes from the DTA.
- `d957231fb` and `892497054` are [subject 1](01-exact-name.md): the exact-name search, and the
  search that goes on when FindNext brings another pattern.
- `01d8efc7e` keeps a search for one name that another FindFirst through its DTA replaced.
- `7d45b51d4` gives back the search slot of a label search that finds no label.
- `cb2e60cf6` reads a template a program edited the same with long names on.
- `c8fd18dea` widens a search for one name before its folder is renamed.
- `9c3bdb928` reads an FCB search's template as its FindFirst wrote it with long names on.
- `c8f5d14aa` releases the kept searches for one name when their program ends.
- `9dbb3cc4c` matches a search's template record by its slot's generation and drive.
- `35781d468` widens a search after its folder was renamed, not before.
- `3f2e6d08f` adds the `CHANGELOG` entries.

## The figures

Every interrupted search returns the rest of its folder, and the bytes left in a DTA are MS-DOS's.
On macOS, long names off unless a row says on, against unpatched `main-ai` at `ac2787a42`:

| What is measured | Unpatched | Patched | MS-DOS 7.10 |
| --- | --- | --- | --- |
| A 4Eh search across a 714Eh made through the same DTA, long names on: entries returned of 42 | 3 | 42 | no long names there |
| An FCB search across a long-name call, long names on: files returned of 40 | 2 | 40 | 40 |
| Calls that must leave a DTA alone: how many left its 43 bytes unchanged | 3 of 7 | 7 of 7 | 7 of 7 |
| The searches those calls interrupted: how many returned the rest of the folder | 3 of 6 | 6 of 6 | 6 of 6 |
| The template bytes of every FindFirst dumped (digest) | `1c5027e13814` | `8044d2aed1bc` | `8044d2aed1bc` |
| What the FCB searches return (digest) | `27e8db5e7991` | `8c1c0a9f4233` | `8c1c0a9f4233` |
| A label search that finds none, through the DTA of a live search: entries the search then returns | 0 | 12 | 12 |

Source: `dtadump.sh`, `findlife.sh` and `findpos.sh`, in [results/macos/dta-searches-answers.txt](../results/macos/dta-searches-answers.txt); MS-DOS 7.10's lines are in [results/macos/dta-searches-msdos.txt](../results/macos/dta-searches-msdos.txt).

DRIFT edits the DTA between a FindFirst and its FindNext, and counts the entries the search
returns. Of its 34 cases, these read differently on the two builds and as MS-DOS, long names off:

| Case | Unpatched | Patched | MS-DOS 7.10 |
| --- | --- | --- | --- |
| To a later exact name | 0 | 1 | 1 |
| To a later full-length name in small letters | 1 | 0 | 0 |
| To a later exact name, padded with zeros | 1 | 0 | 0 |
| To a later name with a star | 1 | 0 | 0 |
| To a star for the name | 4 | 0 | 0 |
| Edited twice | 1 | 2 | 2 |
| Saved, put back and edited | 0 | 6 | 6 |
| A label search, then edited | 2 | 0 | 0 |
| In a folder whose rename failed, then edited | 0 | 1 | 1 |

Source: `drift.sh base dta off`, in [results/macos/dta-searches-answers.txt](../results/macos/dta-searches-answers.txt); MS-DOS 7.10's lines are in [results/macos/dta-searches-msdos.txt](../results/macos/dta-searches-msdos.txt).

Counted line by line, with the `ALPHAT~` entry numbers made alike, the patched build equals
MS-DOS's on 32 of the 34 lines. Unpatched upstream equals it on 22. The two that differ are told
under "What is left".

Six other DRIFT cases and seven FCB searches hold what the fix could have broken. They all read
as unpatched upstream and as MS-DOS:

| Case | Unpatched | Patched | MS-DOS 7.10 |
| --- | --- | --- | --- |
| A search for one name, its folder renamed, then edited to a wildcard: entries returned | 1 | 1 | 1 |
| The same, with a new folder made under the old name | 1 | 1 | 1 |
| The same, with the folder removed, and with a new one made after | 0 | 0 | 0 |
| A search of `*.TXT` that gets the number of an abandoned search, after the table was emptied | 4 | 4 | 4 |
| An FCB search for every name, with `?` or with `*`, long names on: files found | 12 | 12 | 12 |
| An FCB search with `*` for the name: files found | 5 | 5 | 5 |
| An FCB search for a full name, with `*` for the extension or in small letters: files found | 4 | 4 | 4 |

Source: `drift.sh base dta off` and `drift.sh base dta on`, cases `in-a-folder-*` and `after-the-search-table-emptied`, and `dtadump.sh base dta on`, lines `list|fcb-*`, in [results/macos/dta-searches-answers.txt](../results/macos/dta-searches-answers.txt); MS-DOS 7.10's lines are in [results/macos/dta-searches-msdos.txt](../results/macos/dta-searches-msdos.txt).

The saved and restored case read six names before [pull request 6831, "Release directory search snapshots when searches end"](https://github.com/joncampbell123/dosbox-x/pull/6831) merged, and none from its merge on:

| Build of upstream `main-ai` | Entries returned |
| --- | --- |
| Before the merge | 6 |
| The merge | 0 |
| The merge of [pull request 6852, "Keep a search alive when its DTA is reused or its child process ends"](https://github.com/joncampbell123/dosbox-x/pull/6852) | 0 |

Source: `drift.sh`, case `saved-and-restored-then-edited`, in [results/macos/dta-restored-bisect.txt](../results/macos/dta-restored-bisect.txt).

With long names on, a template the program edited is read as MS-DOS reads it. Windows 98's own
DOS box has long names, ran the first 27 of the 34 cases, and agrees with MS-DOS on these:

| Case, entries returned, long names on | Unpatched | Patched | Windows 98 |
| --- | --- | --- | --- |
| To a later full-length name in small letters | 1 | 0 | 0 |
| To a later full-length name in mixed case | 1 | 0 | 0 |
| To a later exact name, padded with zeros | 1 | 0 | 0 |
| To a later name with a star | 0 | 0 | 0 |
| To a star for the name | 0 | 0 | 0 |
| To a later exact name in small letters | 0 | 0 | 0 |
| To a later exact name in mixed case | 0 | 0 | 0 |

Source: `drift.sh base dta on`, in [results/macos/dta-searches-answers.txt](../results/macos/dta-searches-answers.txt); Windows 98's report is in [results/macos/dta-searches-win98.txt](../results/macos/dta-searches-win98.txt).

Everything else answers as unpatched upstream:

| Check | Result on the patched build |
| --- | --- |
| LISTDUMP, 18 synthetic folders and the large folder, long names on and off | byte-identical in every cell |
| EXACT's four judged sections | ALIKE, long names on and off |
| FINDLIFE and DIRGONE, long names off | ALIKE |
| The patched build against itself, twice | ALIKE in 36 of 36 cells |
| 300 child programs that each leave kept searches for one name: times the search table was emptied | none, as unpatched |

Source: `run.sh`, `exact.sh`, `findlife.sh`, `dirgone.sh` and `memory.sh <build> synthetic:100:83 off k 300`, in [results/macos/dta-searches-run.txt](../results/macos/dta-searches-run.txt), [results/macos/dta-searches-answers.txt](../results/macos/dta-searches-answers.txt), [results/macos/dta-searches-alike.txt](../results/macos/dta-searches-alike.txt) and [results/macos/dta-searches-memory.txt](../results/macos/dta-searches-memory.txt).

On Windows the cells read as on macOS, but for the alias names NTFS gives and the host's `NUL`
device, which are equal in both builds. LISTDUMP is byte-identical in 18 of 18 cells. With long
names on, the seven cases of the table above read as on macOS.

| What is measured, on Windows | Unpatched | Patched |
| --- | --- | --- |
| A 4Eh search across a 714Eh made through the same DTA, long names on: entries returned of 42 | 3 | 42 |
| An FCB search across a long-name call, long names on: files returned of 40 | 2 | 40 |
| Calls that must leave a DTA alone: how many left its 43 bytes unchanged | 3 of 7 | 7 of 7 |
| The searches those calls interrupted: how many returned the rest of the folder | 3 of 6 | 6 of 6 |
| A label search that finds none, through the DTA of a live search: entries the search then returns | 0 | 12 |
| A DTA saved, put back and edited: entries returned | 0 | 6 |
| A label search, then edited: entries returned | 2 | 0 |
| A search for one name, its folder renamed, then edited to a wildcard: entries returned | 1 | 1 |
| A search for one name, its folder rename failed, then edited: entries returned | 0 | 1 |
| A search of `*.TXT` that gets the number of an abandoned search, after the table was emptied: entries returned | 4 | 4 |
| An FCB search with `*` for the name, long names off: files found | 5 | 5 |
| 300 child programs that each leave kept searches for one name: times the search table was emptied | none | none |

Source: `dtadump.sh`, `findlife.sh`, `findpos.sh` and `drift.sh`, in [results/windows/dta-searches-answers.txt](../results/windows/dta-searches-answers.txt); `memory.sh <build> synthetic:100:83 off k 300` in [results/windows/dta-searches-memory.txt](../results/windows/dta-searches-memory.txt); LISTDUMP and the control run in [results/windows/dta-searches-run.txt](../results/windows/dta-searches-run.txt) and [results/windows/dta-searches-alike.txt](../results/windows/dta-searches-alike.txt).

The index `isoDrive::FindNext` has no such line. Thirteen numbers past the table, each tried five
times, all answer 18 on both builds, in [results/macos/dta-iso-index.txt](../results/macos/dta-iso-index.txt). The evidence is a read of
`src/dos/drive_iso.cpp`, where the number indexes the table unchecked.

## What a program can notice

A program sees the defects gone. With long names on, a line of the patched build differs from
unpatched upstream only where it is one of the defects' own.

A file created between a FindFirst and its FindNext is also returned now if it sorts behind the
entry found. That is [subject 1](01-exact-name.md)'s.

## How to check it

Compare the two builds, then ask MS-DOS for the same bytes:

```sh
bench/findlife.sh <unpatched> <patched> on
bench/dtadump.sh <unpatched> <patched> off
bench/exact.sh <unpatched> <patched> on
bench/drift.sh <unpatched> <patched> off
bench/drift.sh <unpatched> <patched> on
bench/findpos.sh <unpatched> <patched> unlabelled off
bench/realdos.sh <unpatched> msdos710 <boot image> dtadump
```

In the `dtadump` lines, `untouched=` and `resumed=` are the two counts of the first table.
[bench/README.md](../bench/README.md) says what each script needs.

## What it needs

Nothing. The branch stands on `main-ai` at `ac2787a42`, and its exact-name commits are
[subject 1](01-exact-name.md)'s: the restored-DTA fix keeps a one-name search alive, and
that search is the one subject 1 makes cheap.

## What is left

**A template a program edited, on a FAT or CD image with long names on.** The fix reaches the
searches the directory cache tracks, which are a mounted host folder's. On those images the
template is read as before, and no case measured it.

Closing it needs a record of the template for searches the cache does not track.

**Two DRIFT lines still differ from MS-DOS.** They are nobody's fix here.

- One is `folder-gained-files`: the branch returns 7 entries where MS-DOS returns 8.
- The other is `folder-lost-the-entry`: the branch returns 5 entries where MS-DOS returns none,
  because the emulator reads on where MS-DOS stops.

**`tree q:` and `tree 1:` leave the shell's DTA replaced.** `CMD_TREE` returns without putting it
back, and six commands after it showed no effect.

It is left out. [Pull request 6887, "Answer "Invalid drive specification" instead of ending the emulator on an unmounted drive"](https://github.com/joncampbell123/dosbox-x/pull/6887) edits the same function.
