# 6. The emulator's DOS answers as MS-DOS does

A search for a file or for the volume label answers a program as MS-DOS 6.22 and 7.10 do, on a
mounted folder, an overlay drive, a zip drive and a CD image. It is offered as two pull requests, and
proved on macOS and Windows against both MS-DOS booted from their own disks.

## What was wrong

Unpatched upstream answers a search otherwise than MS-DOS in a few lines outside every other
subject here. A path can end in an error code DOS does not give, a name with a leading space is
accepted, and the label comes back for any name.

The root of a mounted folder lists `.` and `..`, which a DOS root never does.

A CD image gives its files attribute 21h where MSCDEX gives 01h, and lists the label with the other
entries. For a directory it lacks it answers 3, where MSCDEX answers 2.

## What the fix changes

For a mounted folder, an overlay drive and a zip drive, INT 21h 4Eh checks the path before it reads a
directory, and the label and root searches follow one rule on the three drives.

The first byte of the DTA holds the drive counted from 1, as in DOS. It is [pull request 6877, "Answer INT 21h 4Eh and the
label and root searches as MS-DOS does"](https://github.com/joncampbell123/dosbox-x/pull/6877).

For a CD image, a file is 01h, a directory 10h and the label 09h. The label comes only to a search for
the label with 08h.

A missing directory answers 2, and a path that ends in a backslash is a directory with no entry in
it. It is [pull request 6878, "Answer a search on a CD image as MSCDEX
does"](https://github.com/joncampbell123/dosbox-x/pull/6878), on top of the first.

Both were merged into `main-ai` on 20 November 2026.

## The figures

Of the lines that a patched build changes against unpatched `main-ai`, those that equal what both
MS-DOS answer, on macOS, long names off:

| Test | Lines that change | `main-ai` | Folder half |
| --- | --- | --- | --- |
| EXACT | 17 | 0 | 17 |
| TEMPLATE on a FAT drive | 8 | 0 | 8 |
| TEMPLATE on a folder | 22 | 0 | 22 |
| DOSANS, disk without a label | 60 | 0 | 59 |
| DOSANS, disk labelled | 81 | 0 | 77 |

Source: `bench/exact.sh`, `bench/template.sh` and `bench/dosans.sh` against `bench/realdos.sh`. An overlay
drive gives the same lines as the folder; on a zip drive the root no longer lists `.` and `..`. Windows
gives the same, except one TEMPLATE line of the folder that differs by the short name NTFS makes.

Over a CD image, of the lines both MS-DOS answer alike:

| Test | Lines both MS-DOS agree on | `main-ai` | Folder half | CD half |
| --- | --- | --- | --- | --- |
| DOSANS | 703 | 404 | 428 | 494 |

Source: `bench/dosans.sh <build A> <build B> cd off` and `bench/realdos.sh <build> msdos622|msdos710 <image> dosans-cd`,
counted by `bench/agree.py`; the reports and the counts are in [results/macos/dos-answers](../results/macos/dos-answers/agree.txt). The 66 lines the CD half changes over the folder half all become what both
MS-DOS answer, and none that was right is wrong. Windows gives the same files, byte for byte.

## What a program can notice

For a path that DOS accepts, nothing. For a path it does not, the program gets DOS's error where it got
another, and no `.` or `..` in a root.

On a CD it gets the attributes MSCDEX gives, and the label only when it asks for it with 08h.

## How to check it

```sh
bench/dosans.sh <build A> <build B> cd off
bench/realdos.sh <build> msdos622 <image> dosans-cd
DIRCACHE_CD1_SYS=<CD1.SYS of a 6.22 disk> bench/realdos.sh <build> msdos710 <image> dosans-cd
bench/dosans.sh <A> <B> cd off > run.txt
bench/agree.py <7.10 report> <6.22 report> run.txt#A run.txt#B
bench/agree.py --differ <7.10 report> <6.22 report> <what exact.sh, template.sh or dosans.sh printed>
```

[bench/README.md](../bench/README.md#dosanssh) says what the scripts need. The folder half is run with
`bench/exact.sh`, `bench/template.sh` and `bench/dosans.sh <A> <B> labelled|unlabelled off`.

## What it needs

The CD half needs the folder half: its path check is the one it changes. Both stand on upstream
`main-ai` at `72ee221bf`.

## What is left

**Where the two MS-DOS answer alike and a build does not.** A root listed with all attributes
(3Fh) puts the label first where DOS puts it where its disk holds it. A search with 09h in a root
lists a file where DOS lists only the label.

**Searches that depend on the DTA.** A search that is read on after its DTA is restored, or beside a
live search, ends sooner than it does in DOS. That is [subject 4](04-dta.md)'s.

**What nothing referees.** UDF images, which MSCDEX does not read, and the long-name calls on a CD.
Those calls answer 2 for a file named as a directory where they answered 18; no real DOS answers them.

**FreeDOS.** It answers a CD with no drive MSCDEX can open, so the CD half is judged on the two
MS-DOS only. Where it differs from them the folder half follows them.
