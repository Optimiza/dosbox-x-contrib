# dosbox-x-contrib: fixes for DOSBox-X, with the bench that measured them

Fixes offered to DOSBox-X, each on a branch, with the bench that measured it. The
first set is the directory cache: in a large folder, DOSBox-X stalls on the first read, can give
two files one short name and ends searches MS-DOS continues.

## The subjects

Each subject is one fix and has one page: what was wrong, what the fix changes and the
figures.

| # | Subject | Branch | Needs | State |
| --- | --- | --- | --- | --- |
| 1 | [A search for one exact name does not copy the whole directory](docs/01-exact-name.md) | merged | nothing | [pull request 6889, "Answer a find call from the search it belongs to, as MS-DOS does"](https://github.com/joncampbell123/dosbox-x/pull/6889), merged; proved on macOS and Windows |
| 2 | [A search's copy is released without ending a live search](docs/02-retention.md) | tag `archive/dircache-retention` | subject 1 | superseded by [pull request 6831](docs/pr6831.md), merged, and [pull request 6852](https://github.com/joncampbell123/dosbox-x/pull/6852), merged; its label slot is in [pull request 6889, "Answer a find call from the search it belongs to, as MS-DOS does"](https://github.com/joncampbell123/dosbox-x/pull/6889), merged, proved on macOS and Windows |
| 3 | [The first read of a large folder](docs/03-first-read.md) | merged | nothing | [pull request 6853](https://github.com/joncampbell123/dosbox-x/pull/6853), merged |
| 4 | [A find call does not disturb another search's DTA](docs/04-dta.md) | merged | nothing | [pull request 6889, "Answer a find call from the search it belongs to, as MS-DOS does"](https://github.com/joncampbell123/dosbox-x/pull/6889), merged, which carries subjects 1 and 2's label slot with it; proved on macOS and Windows |
| 5 | [No two entries of a folder share a short name](docs/05-alias.md) | merged | subject 3 | [pull request 6854](https://github.com/joncampbell123/dosbox-x/pull/6854), merged |
| 6 | [The emulator's DOS answers as MS-DOS does](docs/06-dos-answers.md) | merged | nothing | [pull request 6877, "Answer INT 21h 4Eh and the label and root searches as MS-DOS does"](https://github.com/joncampbell123/dosbox-x/pull/6877), a folder, an overlay drive and a zip drive, and [pull request 6878, "Answer a search on a CD image as MSCDEX does"](https://github.com/joncampbell123/dosbox-x/pull/6878), on top of it; both merged |
| 9 | [An attribute change on Windows does not empty the directory cache](docs/09-setattr.md) | merged | nothing | [pull request 6873, "Keep the directory cache when a file's attributes change on Windows"](https://github.com/joncampbell123/dosbox-x/pull/6873), merged; proved on Windows, the only host it changes |
| 10 | [The x86 dynamic core keeps its code-page handlers across a cache reset](docs/10-dyncore-cache-reset.md) | merged | nothing | [pull request 6874, "Keep the x86 dynamic core's code page handlers across a cache reset"](https://github.com/joncampbell123/dosbox-x/pull/6874), merged; proved on Windows, the macOS build has no such core |
| 11 | [A create keeps the directory cache, and a delete removes one entry](docs/11-create-delete.md) | merged | nothing | [pull request 6875, "Keep the directory cache when a local drive creates, deletes or renames"](https://github.com/joncampbell123/dosbox-x/pull/6875), merged; proved on macOS and Windows |
| 12 | [A path longer than the emulator's arrays answers "path not found"](docs/12-longname.md) | merged | nothing | [pull request 6872, "Answer path not found for a host path past CROSS_LEN"](https://github.com/joncampbell123/dosbox-x/pull/6872), merged; proved on macOS and Windows |
| 13 | [A command on an unmounted drive answers "Invalid drive specification"](docs/13-unmounted-drive.md) | merged | nothing | [pull request 6887, "Answer "Invalid drive specification" instead of ending the emulator on an unmounted drive"](https://github.com/joncampbell123/dosbox-x/pull/6887), merged; proved on macOS and Windows |
| 14 | [A divide error ends the program as MS-DOS ends it](docs/14-xcopy-unmounted.md) | `unmounted-xcopy-mainai` | nothing | not opened yet; proved on macOS and Windows |

- Subjects 7 and 8 are withdrawn: the `DIR` fix of subject 7 is a commit of subject 4, and the
  defect of subject 8 was not there.
- [Issue 6851, "main-ai ends directory searches that MS-DOS continues"](https://github.com/joncampbell123/dosbox-x/issues/6851) says
  how the subjects are offered, one pull request each, but subjects 1 and 4 share one.
- Subject 11 stands on `main-ai` at `72ee221bf`, which has [pull request 6874, "Keep code page handlers across a cache reset"](https://github.com/joncampbell123/dosbox-x/pull/6874) merged.
- Subjects 1 and 4 and subject 2's label slot are one branch, `dta-searches-mainai`, on `main-ai` at `ac2787a42`.
  Each page names its commits.
- The numbers are this repository's own; a four-digit number is upstream's.

## The problem, and the case that showed it

At `4e0b6adcf`, opening one file in a folder of 169,457 files made the emulator's memory grow
by the whole directory, and it never came back. The folder was a music library.

| `access()` calls on one file | Memory the emulator held (kB) |
| --- | --- |
| 1 | 498,305 |
| 20 | 4,681,220 |

Source: `battery.sh --real-dos`, cells `memory real a <1|20> base`, in [results/macos/battery-base-retention-exact-name.txt](results/macos/battery-base-retention-exact-name.txt).

It is reported upstream as
[issue 6823, "FindFirst copies and retains the whole directory on every call"](https://github.com/joncampbell123/dosbox-x/issues/6823).
[The reporters' cases](docs/reporters.md) have their own page.

DOSBox-X caches every host folder a DOS program looks into. Three costs sit in that cache, in
`src/dos/drive_cache.cpp` and its search calls:

1. A program that only asks whether one file exists pays for every file of the folder. Every
   FindFirst copies and sorts the whole directory, whatever the pattern, and a libc `access`,
   `fopen` or `stat` makes one.
2. The copy outlives the search. It is freed when the search runs to its end, or when all
   2,048 search slots are taken and the emulator empties the whole table. That ends every
   search still in progress.
3. The first touch of a large folder stalls the emulator while the cache is built, and a
   create or a delete makes it read the folder again.

Subjects 1 and 2 fix the first two, subject 3 the stall and subject 11 the second read. The
three costs are described as they stand at `4e0b6adcf`.

Since then upstream merged [another author's pull request for the same cost](docs/pr6831.md),
so `main-ai` gives a search's memory back. It now ends four kinds of search that MS-DOS
continues: [issue 6851](https://github.com/joncampbell123/dosbox-x/issues/6851) shows them, and pull request 6852 keeps them alive.

## How it is measured

- A check is a small DOS program and the host script that runs it headless in two builds and
  compares what they print.
- Every figure compares a patched build with unpatched upstream `main-ai` at `4e0b6adcf`, or at `ac2787a42` where a page says so.
- The referee is a real MS-DOS 7.10, booted inside the emulator from a Windows 98 SE disk
  image. The bench boots MS-DOS 6.22 and FreeDOS beside it.
- Every fix that is done is built on macOS and on Windows, and proved on each host whose code
  it changes.
- A run that measured nothing reads INVALID, never as a pass.

[How it is measured](docs/method.md) has the rest, and [what was seen and left](docs/left.md)
lists what no fix here closes.

## Running it

A clone runs with two DOSBox-X executables, the DJGPP cross compiler and, on macOS, GNU
`timeout`. Nothing opens a window.

```sh
# the tests of the scripts themselves: no emulator, macOS only
for t in bench/*.test.sh; do bash "$t" || break; done

# one cell: an unpatched build against a patched one
bench/drift.sh <unpatched dosbox-x> <patched dosbox-x> off
```

[bench/README.md](bench/README.md) says what each script needs, shows and prints. The MS-DOS
cells need a hard disk image of your own whose DOS boots. The large folder is any folder of
yours.

Each push runs `shellcheck` and those tests on GitHub, but `battery.test.sh`, which needs eight
cores. A cell needs an emulator, so it runs by hand.

The branches and the bench were written with AI assistance (Claude Fable 5.2), so under the
project's Artificial Intelligence Policy they do not comply for `master` and are meant for
`main-ai`. I have reviewed them myself as well.

Developed by Optimiza ([Marcos Hernández](https://www.linkedin.com/in/optimiza/)), in collaboration with [MS-DOS Club](https://msdos.club) and its [podcast](https://www.ivoox.com/podcast-ms-dos-club_sq_f11160693_1.html).
