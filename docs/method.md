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

## The base

Every figure compares a patched build with unpatched upstream `main-ai` at `4e0b6adcf`. That
revision does not compile on macOS without two lines, so every build here carries them, the
base included.

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

## Both hosts

Every fix that is done is built and run on both hosts, with the same scripts.

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
