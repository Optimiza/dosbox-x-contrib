# 9. An attribute change on Windows does not empty the directory cache

On Windows a change of a file's attributes no longer makes the emulator read the whole folder
again. Windows now answers as the other hosts did already. It is proved on Windows, the only host
that compiles the line.

## What was wrong

On Windows `localDrive::SetFileAttr` emptied the drive's whole directory cache after every
attribute change, in `src/dos/drive_local.cpp`. So the next search read the folder from the host
again, and a C library `remove()` makes one such change.

Emptying the cache also restarted the search slots' numbers. A program that kept the DTA of an
ended search then read the search another folder had started.

The line came with upstream's `ATTRIB` support, and protects nothing a run of the bench can find.

## What the fix changes

The attribute change leaves the cache alone, as on every other host. The branch is
`dircache-setattr`, tag `archive/dircache-setattr` of the fork, one commit, `97d438ae9`. On `main-ai` at `0dbfdad51` it is
`dircache-setattr-mainai`, merged as [pull request 6873, "Keep the directory cache when a file's attributes change on Windows"](https://github.com/joncampbell123/dosbox-x/pull/6873).

## The figures

After the fix a saved search no longer returns another folder's entries. The case is a search
kept in a saved DTA across one attribute change, then a search of another folder of 22 files:

| What a program reads, Windows | Unpatched | Patched |
| --- | --- | --- |
| Entries of the other folder through the saved DTA | 19 | none |
| Files of the other folder its own search returns, of 22 | 3 | 22 |

Source: `attrprobe.sh <unpatched> <patched> on`, case `saved-dta-after-setattr`, in [results/windows/setattr.txt](../results/windows/setattr.txt).

The cost, counted by counter builds:

| Ten attribute changes in a folder, Windows | Unpatched | Patched |
| --- | --- | --- |
| Reads of the large folder | 11 | 1 |
| Entries read in the large folder | 1,860,253 | 169,143 |

Source: `attrcost.sh <build> <the large folder> s 10`, line `real-<build>-s`, in [results/windows/setattr.txt](../results/windows/setattr.txt).

## What a program can notice

Two side effects of the emptying go with it, and Windows now answers as the other hosts, whose
code never emptied the cache:

- a file the host adds while the emulator runs shows in a listing only after `RESCAN`;
- on a drive mounted on a whole host drive, such as `mount c c:\`, the label the guest gave it
  stays. Unpatched upstream put the host volume's label back after the change.

| What the guest sees after an attribute change, Windows | Unpatched | Patched |
| --- | --- | --- |
| A file the host added, in the next listing | listed | listed after `RESCAN` |
| The label of `C:` after the guest named it `GUEST` | the host's label | `GUEST` |

Source: a probe outside the bench, its `rescan` and `label` cases on both builds, in [results/windows/setattr.txt](../results/windows/setattr.txt).

## How to check it

Compare the saved DTA's answers, then count the reads with a counter build:

```sh
bench/attrprobe.sh <unpatched> <patched> on
bench/attrcost.sh <counter build> <a large folder> s 10
```

`bench/counters/count-dir.diff` makes a counter build of either branch. The two side effects
were shown by a probe the bench does not carry. [bench/README.md](../bench/README.md) says what each script needs.

## What it needs

Nothing. On Windows it also closes the case of [subject 4](04-dta.md) that otherwise needs
[subject 2](02-retention.md).

## What is left

**The overlay drive.** An attribute change on an overlay drive empties and rebuilds its cache on
every host, and leaves out the file it copies into the overlay (`Overlay_Drive::SetFileAttr`). There is no measure of either,
so both are named and not changed.
