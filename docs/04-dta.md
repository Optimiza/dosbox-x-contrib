# 4. A find call does not disturb another search's DTA

A program that runs one search inside another, or mixes the old and the long-name calls, now
gets every entry of both. It is proved on macOS and Windows.

## What was wrong

A search in progress lost its place when another find call wrote over its state. Unpatched
upstream has four such defects and one unchecked index.

- A FindFirst that fails after the search was set up has already overwritten the DTA's
  pattern. MS-DOS leaves the DTA as it was.
- A long-name FindFirst (714Eh) writes its pattern into whichever DTA is current, and breaks a
  4Eh search in progress.
- The FCB find calls and the emulator's own path lookups share one temporary DTA. So an FCB
  search does not survive a long-name call.
- The DTA's search template is padded with zeros where MS-DOS pads with spaces. So a template
  a program writes the MS-DOS way matches nothing.
- `isoDrive::FindNext` indexes its table with a number read from the guest.

Once a failed FindFirst leaves the DTA alone, one more defect shows. The shell's `DIR` takes the
drive of its free-space line from the DTA after its search. So a `DIR` that lists nothing prints
the free space of the drive an earlier search used.

## What the fix changes

Each find call writes only where its own search keeps its state.

- A FindFirst that fails leaves the DTA as it was.
- A 714Eh leaves the current DTA alone.
- The state of an FCB search lives in the program's FCB, as MS-DOS keeps it.
- The template is padded with spaces.
- The index `isoDrive::FindNext` reads from the guest is checked.
- `DIR` takes the drive of its free-space line from the path it listed.

The branch is `dircache-dta`, six commits ending at `8e5e74905`. The sixth fixes `DIR` and
removes the exception the second made for the shell's temporary DTA, which no longer needs one.

## The figures

Every interrupted search now returns the rest of its folder, and the bytes left in a DTA are
MS-DOS's.

| What is measured | Unpatched | Patched | MS-DOS 7.10 |
| --- | --- | --- | --- |
| A 4Eh search across a 714Eh made through the same DTA: entries returned of 42 | 3 | 42 | no long names there |
| An FCB search across a long-name call: files returned of 40 | 2 | 40 | no long names there |
| Calls that must leave a DTA alone: how many left its 43 bytes unchanged, long names off | 3 of 6 | 6 of 6 | 6 of 6 |
| The searches those calls interrupted: how many returned the rest of the folder | 3 of 6 | 6 of 6 | 6 of 6 |
| The template bytes of every FindFirst dumped, long names off (digest) | `1c5027e13814` | `8044d2aed1bc` | `8044d2aed1bc` |
| What the FCB searches return, macOS (digest) | `ce9cdd5c399c` | `f9c92156e849` | `f9c92156e849` |
| A FindFirst that fails with another pattern through an exact-name search's DTA: entries the search then returns | 6 | none | none |
| DRIFT, 25 cases of a FindNext that brings another pattern: lines that differ from MS-DOS's report | 8 | 2 | |

Source: `battery.sh --real-dos`, cells `findlife`, `dtadump`, `exact` and `drift`, in [results/macos/battery-base-dta.txt](../results/macos/battery-base-dta.txt); the patched build's own lines are in [results/macos/dta-cases.txt](../results/macos/dta-cases.txt).

- Unpatched upstream's and MS-DOS's reports are in `bench/fixtures/battery`:
  [findlife_base-build_on.txt](../bench/fixtures/battery/findlife_base-build_on.txt),
  [drift_base-build_off.txt](../bench/fixtures/battery/drift_base-build_off.txt),
  [realdos_msdos710_exact_off.txt](../bench/fixtures/battery/realdos_msdos710_exact_off.txt) and
  [realdos_msdos710_drift_off.txt](../bench/fixtures/battery/realdos_msdos710_drift_off.txt).
- On Windows the cells read the same but for one DRIFT case, told under "What it needs". They
  are in [results/windows/battery-base-dta.txt](../results/windows/battery-base-dta.txt).
- The FCB digest differs there only by the alias names NTFS gives.

Everything else answers as unpatched upstream:

| Check | Result on the patched build |
| --- | --- |
| LISTDUMP, every folder | byte-identical in 14 of 14 cells per host |
| EXACT's four judged sections | ALIKE |
| The memory cells | alike |

Source: `battery.sh`, cells `run`, `exact` and `memory`, in the same two battery files.

These figures are the fifth commit's. The sixth moves none of them: the fifth and sixth heads
read alike on every instrument that judges an answer, on both hosts. What it changes is the line
`DIR` prints:

| `DIR` of an empty volume after a `DIR` of another drive, macOS | Free space printed (bytes) |
| --- | --- |
| Unpatched upstream | 66,781,184 |
| The fifth commit without its exception, `DIR` not fixed | 2,013,265,920 |
| Patched, six commits | 66,781,184 |

Source: `template.sh <A> <B> fat on`, line `shell`, in [results/macos/dta-dir.txt](../results/macos/dta-dir.txt); the two heads' verdicts there and in [results/windows/dta-dir.txt](../results/windows/dta-dir.txt).

The empty volume has 66,781,184 bytes free. The larger figure is the free space of the host
drive mounted as `C:`.

## What a program can notice

A program sees the defects gone and nothing else. With long names on, a line of the patched
build differs from unpatched upstream only where it is one of the defects' own.

## How to check it

Compare the two builds, then ask MS-DOS for the same bytes:

```sh
bench/findlife.sh <unpatched> <patched> on
bench/dtadump.sh <unpatched> <patched> off
bench/exact.sh <unpatched> <patched> off
bench/drift.sh <unpatched> <patched> off
bench/realdos.sh <patched> msdos710 <boot image> dtadump
```

In the `dtadump` lines, `untouched=` and `resumed=` are the two counts of the table.
[bench/README.md](../bench/README.md) says what each script needs.

## What it needs

Nothing on macOS. On Windows one case also needs [subject 2](02-retention.md) or
[subject 9](09-setattr.md): DRIFT's `label-search-then-edited`, which this branch closes alone on
macOS.

| Build, on Windows | Entries returned after the label search |
| --- | --- |
| Unpatched upstream | 4 |
| The DTA build alone | 4 |
| The DTA and retention branches merged | none |
| The DTA and attribute branches merged | none |

Source: `drift.sh`, in [results/windows/label-search-then-edited.txt](../results/windows/label-search-then-edited.txt) and, for the last row, [results/windows/setattr.txt](../results/windows/setattr.txt).

MS-DOS returns none. The difference by host is the attribute change that empties the cache on
Windows only, which [subject 9](09-setattr.md) removes.

## What is left

Two things are left, each declared.

**One template case, with long names on.** A 4Fh after a 4Eh for a quoted name reads the
template the MS-DOS way when the name fills both fields and has a typed space as its eighth or
eleventh character.

No run shows a line that differs for it. Closing it would need a mark in DTA bytes a real DOS
does not write.

**Two DRIFT lines still differ from MS-DOS.** They are nobody's fix here.

- One is `folder-gained-files`, the files a folder gains during a search.
  [Subject 1](01-exact-name.md) has its figures.
- The other is the order in which a directory that lost an entry is read on.
