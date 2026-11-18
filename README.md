# DOSBox-X's directory cache on large folders: a test bench and what it measured

In a folder with many files, DOSBox-X takes memory on every file lookup, keeps it, stalls on the
first read and can cut a listing short. This repository holds the bench that measures it and
the account of nine fixes for DOSBox-X, each on a branch of its own. Eight are done, each proved
on the hosts it runs on.

## The subjects

Each subject is one fix and has one page: what was wrong, what the fix changes and the
figures.

| # | Subject | Branch | Needs | State |
| --- | --- | --- | --- | --- |
| 1 | [A search for one exact name does not copy the whole directory](docs/01-exact-name.md) | `dircache-exact-name` | nothing | proved on macOS and Windows |
| 2 | [A search's copy is released without ending a live search](docs/02-retention.md) | `dircache-retention` | subject 1 | proved on macOS and Windows |
| 3 | [The first read of a large folder](docs/03-first-read.md) | `dircache-first-read` | nothing | proved on macOS and Windows |
| 4 | [A find call does not disturb another search's DTA](docs/04-dta.md) | `dircache-dta` | nothing; one case on Windows needs subject 2 or 9 | proved on macOS and Windows |
| 5 | [No two entries of a folder share a short name](docs/05-alias.md) | `dircache-alias` | subject 3 | proved on macOS and Windows |
| 6 | [The emulator's DOS answers as MS-DOS does where the contrast found it differs](docs/06-dos-answers.md) | `dircache-dos-answers` | nothing | not delivered: two more real DOS referees come first |
| 9 | [An attribute change on Windows does not empty the directory cache](docs/09-setattr.md) | `dircache-setattr` | nothing | proved on Windows, the only host it changes |
| 10 | [The x86 dynamic core keeps its code-page handlers across a cache reset](docs/10-dyncore-cache-reset.md) | `dyncore-cache-reset` | nothing | proved on Windows; the macOS build has no such core |
| 11 | [A create keeps the directory cache, and a delete removes one entry](docs/11-create-delete.md) | `dircache-create-delete` | nothing | proved on macOS and Windows |

- Subjects 7 and 8 are withdrawn: the `DIR` fix of subject 7 is a commit of subject 4, and the
  defect of subject 8 was not there.
- Each is meant as one pull request for `main-ai`, but subject 2: it was written as a proposal
  on [another author's pull request for the same cost](docs/pr6831.md), which upstream has
  merged.
- Every branch is cut from upstream `main-ai` at `4e0b6adcf`, or from the branch it needs.
- None is published or offered yet. The numbers are this repository's own; a four-digit number
  is upstream's.

## The problem, and the case that showed it

Opening one file in a folder of 169,457 files made the emulator's memory grow by the size of
the whole directory, and it never came back. The folder was a music library, and the program
a DOS player.

| `access()` calls on one file | Memory the emulator held (kB) |
| --- | --- |
| 1 | 498,305 |
| 20 | 4,681,220 |

Source: `battery.sh --real-dos`, cells `memory real a <1|20> base`, in [results/macos/battery-base-retention-exact-name.txt](results/macos/battery-base-retention-exact-name.txt).

It is reported upstream as
[issue 6823, "FindFirst copies and retains the whole directory on every call"](https://github.com/joncampbell123/dosbox-x/issues/6823).
[The related upstream issues](docs/issues.md) and [the reporters' cases](docs/reporters.md)
have their own pages.

DOSBox-X keeps a cache of every host folder a DOS program looks into. Three costs sit in it,
all in `src/dos/drive_cache.cpp` and the search calls around it:

1. A program that only asks whether one file exists pays for every file of the folder. Every
   FindFirst copies and sorts the whole directory, whatever the pattern, and a libc `access`,
   `fopen` or `stat` makes one.
2. The copy outlives the search. It is freed when the search runs to its end, or when all
   2,048 search slots are taken and the emulator empties the whole table. That ends every
   search still in progress.
3. The first touch of a large folder stalls the emulator while the cache is built, and a
   create or a delete makes it read the folder again.

Subjects 1 and 2 fix the first two, subject 3 the stall and subject 11 the second read.
[Another author's pull request](docs/pr6831.md) addresses the second cost as well.

## How it is measured

- A check is a small DOS program and the host script that runs it headless in two builds and
  compares what they print.
- Every figure compares a patched build with unpatched upstream `main-ai` at `4e0b6adcf`.
- The referee is a real MS-DOS 7.10, booted inside the emulator from a Windows 98 SE disk
  image. MS-DOS 6.22 and FreeDOS are being added beside it.
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

Each push runs `shellcheck` and those tests on GitHub. A cell needs an emulator, so a reader
runs it by hand.

The branches and the bench were written with AI assistance (Claude Fable 5.2), so under the
project's Artificial Intelligence Policy they do not comply for `master` and are meant for
`main-ai`. I have reviewed them myself as well.

Developed by Optimiza ([Marcos Hernández](https://www.linkedin.com/in/optimiza/)), in collaboration with [MS-DOS Club](https://msdos.club) and its [podcast](https://www.ivoox.com/podcast-ms-dos-club_sq_f11160693_1.html).
