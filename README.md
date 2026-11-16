# DOSBox-X's directory cache on large folders: a test bench and what it measured

In a folder with many files, DOSBox-X takes memory on every file lookup, keeps it, and can cut
a listing short. This repository holds the bench that measures it and the account of ten
fixes, each meant for DOSBox-X as one pull request. Three are done and proved on macOS and
Windows, checked against a real MS-DOS 7.10.

## The ten subjects

Each subject is one pull request and has one page: what was wrong, what the fix changes and
the figures.

| # | Subject, one pull request each | Branch | Needs | State |
| --- | --- | --- | --- | --- |
| 1 | [A search for one exact name does not copy the whole directory](docs/01-exact-name.md) | `dircache-exact-name` | nothing | proved on macOS and Windows |
| 2 | [A search's copy is released without ending a live search](docs/02-retention.md) | `dircache-retention` | 1 | proved on macOS and Windows; two reporters' cases not run on Windows yet, and one Windows line waits for 10 |
| 3 | [The first read of a large folder](docs/03-first-read.md) | `dircache-first-read` | nothing | not started |
| 4 | [A find call does not disturb another search's DTA](docs/04-dta.md) | `dircache-dta` | nothing; one case on Windows also needs 2 | proved on macOS and Windows |
| 5 | [A generated 8.3 alias never equals a real 8.3 name](docs/05-alias.md) | `dircache-alias` | 3 | not started |
| 6 | [The emulator's DOS answers as MS-DOS does where the contrast found it differs](docs/06-dos-answers.md) | `dircache-dos-answers` | nothing | not started |
| 7 | [The shell's `DIR` prints the free space of the drive it listed](docs/07-shell-dir.md) | `dircache-shell-dir` | nothing | in progress |
| 8 | [`CommandLine::FindString` does not read past the last word](docs/08-findstring.md) | `dircache-findstring` | nothing | in progress |
| 9 | [An attribute change on Windows does not empty the directory cache](docs/09-setattr.md) | `dircache-setattr` | nothing | cause measured, branch not written |
| 10 | [The x86 dynamic core keeps its code-page handlers across a cache reset](docs/10-dyncore-cache-reset.md) | `dyncore-cache-reset` | nothing | cause measured, branch not written |

- Every branch is cut from upstream `main-ai` at `4e0b6adcf`, or from the branch it needs, and
  is meant for `main-ai`.
- None is published or offered yet. The links come when the pull requests are opened.
- The numbers 1 to 10 are this repository's own. A four-digit number is upstream's.
- A subject's page and its row here are brought up to date when it closes.

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
3. The first touch of a large folder stalls the emulator while the cache is built.

Subjects 1 and 2 fix the first two. The third is subject 3, not started.
[Another author's pull request](docs/pr6831.md) addresses the second cost as well.

## How it is measured

- A check is a small DOS program and the host script that runs it headless in two builds and
  compares what they print.
- Every figure compares a patched build with unpatched upstream `main-ai` at `4e0b6adcf`.
- The referee is a real MS-DOS 7.10, booted inside the emulator from a Windows 98 SE disk
  image.
- Every fix that is done is built and run on macOS and on Windows.
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

The branches and the bench were written with AI assistance (Claude Fable 5.2), so under the
project's Artificial Intelligence Policy they do not comply for `master` and are meant for
`main-ai`. I have reviewed them myself as well.

Developed by Optimiza ([Marcos Hernández](https://www.linkedin.com/in/optimiza/)), in collaboration with [MS-DOS Club](https://msdos.club) and its [podcast](https://www.ivoox.com/podcast-ms-dos-club_sq_f11160693_1.html).
