# How it is measured

Every figure here comes from a run anyone can repeat: two builds, one DOS program, and a real
MS-DOS as the referee. This page says how a check works and how to read its lines.

## A check

A check is a small DOS program and the host script that runs it headless in two builds. The
script compares what the two print:

- what a search returns, byte for byte;
- or how much memory the emulator holds once the guest has made its calls and waits.

Every check answers with the same four exit codes:

| Exit code | Meaning |
| --- | --- |
| 0 | the answer: alike, identical or measured |
| 1 | the two builds differ |
| 2 | bad usage |
| 3 | INVALID: nothing was judged |

A run that measured nothing never reads as a pass.

The scripts, the guest programs' sources and their tests are in
[bench/](../bench/README.md). The lines of the runs the pages quote are in
[results/](../results/README.md).

## The battery

`battery.sh` runs every check in a fixed order and prints one line per cell. So a change is
read as two lists of lines.

| Battery run | Cells printed |
| --- | --- |
| macOS, three builds, with the MS-DOS cells | 219 |

Source: `battery.sh --real-dos <base> <retention> <exact-name>`, the header of [results/macos/battery-base-retention-exact-name.txt](../results/macos/battery-base-retention-exact-name.txt).

In a run on three builds the lines name the builds so:

| Name in the lines | The build |
| --- | --- |
| `base` | unpatched upstream |
| `build` | the retention build |
| `third` | the exact-name build |

## The guest programs

Each guest program asks the emulator one kind of question. The pages name them in capitals.

| Program | What it does |
| --- | --- |
| LISTDUMP | writes everything a build lists of a folder |
| MEMPROBE | repeats one file call and then holds, so the emulator's memory can be read |
| EXACT | asks for one exact name in every way a program can |
| FINDLIFE | interrupts a search, shares it or outlives it, one named case at a time |
| DRIFT | brings a FindNext another pattern than its FindFirst had |
| DTADUMP | prints the bytes a find call leaves in a DTA or an FCB |
| FINDPOS | moves a search by its saved DTA and asks for the volume label alone |
| PATLIST | lists what patterns with a `*` before more characters return |
| ALIASES | judges every short name a build lists against the files the host holds |
| DELPRB | deletes, creates, renames and removes entries, and says which short names moved |
| ATTRPRB | keeps a search in a saved DTA across an attribute change |
| P5PROBE | makes the first search of a folder the emulator never read, for a timer |
| P5REP | waits for the host's go, then makes one reporter's call, for a timer |
| RESPRB | starts child programs one after another, so the memory each leaves can be read |

## The base

Every figure compares a patched build with unpatched upstream `main-ai` at `4e0b6adcf`, except
those of subjects 1 and 4 and subject 2's label slot, which use `ac2787a42`. The older revision
does not compile on macOS without two lines, so its builds carry them, the base included.

The two lines are
[pull request 6822, "fix(ide): give the ATAPI sector counters the type of the ATA ones"](https://github.com/joncampbell123/dosbox-x/pull/6822).

## The referee is MS-DOS 7.10

What a search ought to answer is decided by a DOS, and the emulator's own DOS is the thing
under test. So `realdos.sh` boots the DOS of a Windows 98 SE disk image inside the emulator,
which is then only the PC.

Every INT 21h call is answered by that kernel over a FAT volume. The run refuses to count if
the answer came from the emulator's own DOS.

The answers are read by these rules:

- Where MS-DOS answers, a patched build has to answer the same in what its patch changes.
- Where a patched build differs from unpatched upstream and MS-DOS agrees with the patch, the
  page says so.
- Where unpatched upstream already differs from MS-DOS outside a patch's subject, it is
  upstream's. It is listed, not hidden.
- With long names on there is no referee: MS-DOS 7 without its Windows has no long-name calls.
  The reference is then the documented call.

`realdos.sh` boots MS-DOS 6.22 and FreeDOS too, each from an image the reader brings. Where
the three agree, an answer is "as MS-DOS"; where they differ, the pages will say which DOS
answers what.

## Both hosts

Every fix that is done is built on both hosts and proved, with the same scripts, on each host
whose code it changes.

| Host | Build |
| --- | --- |
| macOS, Apple silicon | SDL2 |
| Windows, x64 | Visual Studio, SDL1 |

On Windows the scripts run under Git Bash.

Windows matters twice:

- It is where
  [issue 6827, "DOSBox-X consumes huge amounts of memory when running certain programs in directories with lots of files"](https://github.com/joncampbell123/dosbox-x/issues/6827),
  was reported from.
- There the 8.3 aliases come from NTFS and not from the emulator. So the cells that show an
  alias are the file system's.

## Memory

The memory figure is read from outside the emulator, while the guest holds.

| Host | The figure read |
| --- | --- |
| macOS | the footprint |
| Windows | the private bytes |

On macOS the resident size is not used: it falls when the system compresses memory nobody
touches, which is what an abandoned search is.

A figure from one run says little. A cell is read at two call counts, and the growth per call
is the difference divided by the calls between them.

## Time

A time is taken by the host's clock around one step of the guest, never by the guest's clock.
The guest waits for a file the host makes, and the clock stops when the guest's answer appears.

- Each run is a fresh emulator, and the two builds take turns: A, B, B, A.
- Each build is also run against itself. The spread of those runs is the noise, and a
  difference counts only when it is larger than both builds' noise.
- The host is sampled while the runs last. A cell run while another program was busy is run
  again whole.
- The timers in [bench/](../bench/README.md) run the guest at a fixed clock. The figures of
  [subject 3](03-first-read.md) were taken with the guest's clock at its maximum.

A time on one host moves more between hours than the factor between two builds moves. So a
page gives the factor, or unpatched upstream's seconds as the range of two batches.

## Counting

Some costs are counted rather than timed: how often the emulator reads a folder, or resets the
code cache. A counter build is a build with one of the diffs of `bench/counters/` applied, which
logs each such event under a tag, `HOST-DIR-READ` or `DYN-CACHE-RESET`. `attrcost.sh` and
`resprb.sh` read those lines.
