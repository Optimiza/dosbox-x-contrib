# 15. Ten shell commands answer MS-DOS's message on a drive that is not mounted

Ten shell commands no longer report the path they cannot reach when the drive is not mounted.
`copy`, `del`, `type`, `truename`, `cd`, `md`, `rd`, `dir` and `ren` answer `Invalid drive
specification`, as MS-DOS 6.22 and 7.10 do, and `attrib` answers the DOSes' own
`Path not found - <the path>`. It is proved on macOS and Windows.

## What was wrong

The shell resolved a path before it looked at the drive. A path on a drive nothing was mounted on
failed inside the resolver, and each command reported what it made of that failure.

Six commands said `Path not found`. `cd q:\` said `Invalid directory - q:\`, `md` said
`Unable to create directory - q:\X` and `rd` said `Invalid path, not directory, or directory not
empty - q:\X`. `dir` and `ren` said nothing at all, which a batch file cannot tell from success.

## What the fix changes

Each of the ten commands now checks the drive its path names before its own path work. It reads
the drive the way the DOS path resolver does, so a quoted name is read alike.

Eight of them answer `Invalid drive specification`. `attrib` answers `Path not found - <the path>`,
which is what both DOSes print for a file on a drive that is not there.

`cd` keeps the hint it prints at the `Z:` prompt, where its message tells a new user how to mount a
drive.

## The figures

Unpatched is upstream `main-ai` at `a325b1292`. Each line runs in an emulator start of its own,
with the same command on `C:` as its control.

| Line | Unpatched | The branch | MS-DOS 6.22 and 7.10 |
| --- | --- | --- | --- |
| `copy-q` | `Path not found` | `Invalid drive specification` | `Invalid drive specification` |
| `del-q`, `type-q`, `truename-q` | `Path not found` | `Invalid drive specification` | `Invalid drive specification` |
| `cd-q` | `Path not found` | `Invalid drive specification` | `Invalid drive specification` |
| `cd-q-root` | `Invalid directory - q:\` | `Invalid drive specification` | `Invalid drive specification` |
| `md-q` | `Unable to create directory - q:\X` | `Invalid drive specification` | `Invalid drive specification` |
| `dir-q`, `ren-q` | nothing | `Invalid drive specification` | `Invalid drive specification` |
| `rd-q` | `Invalid path, not directory, or directory not empty - q:\X` | `Invalid drive specification` | `Invalid drive specification` |
| `quoted-q` | `Path not found` | `Invalid drive specification` | `Invalid drive specification`; 6.22 answers `Parameter format not correct` |
| `attrib-q` | `Path not found` | `Path not found - q:\A.TXT` | `Path not found - Q:\A.TXT`, as typed on 7.10 |

Source: `nodrive.sh <unpatched> <the branch>` on both hosts, and
`realdos.sh <unpatched> msdos710 <an image> nodrive` and the same with `msdos622`, all in
[results/macos/nodrive.txt](../results/macos/nodrive.txt); the `nodrive.sh` run on Windows is in
[results/windows/nodrive.txt](../results/windows/nodrive.txt).

The twelve lines are the only ones that differ between the two runs, and the script says so:
`DIFFERENT, 12 lines differ`. Against itself the branch answers the same on both builds, `ALIKE`
on both hosts.

The message does not depend on the DOS version the emulator reports: `del q:\A.TXT` answers
`Invalid drive specification` at every version `ver set` gives it, the default one and both MS-DOS
ones. That check and its control are filed under the same macOS result file, with the conf it ran
from.

## What a program can notice

A batch file that tests the error now sees a message where `dir` and `ren` printed nothing. The
message goes to the standard output, so `> FILE` captures it as the DOSes' own is captured.

A program that opens a file on such a drive gets the same DOS error it got before. The messages
changed; the calls did not.

## How to check it

```sh
bench/nodrive.sh <unpatched> <the branch>
```

Each line runs in an emulator start of its own, beside the same command on `C:`. The script says
`DIFFERENT, 10 lines differ`, and the ten lines are the ones in the table.

A control whose command prints nothing on a mounted drive answers nothing, on every build; the
script judges a run by whether it reached its last line, not by its answer.

The DOS column comes from `bench/realdos.sh` with an image of each DOS, as its own page says.

## What it needs

A DOSBox-X build of the branch on each host, and one of unpatched `main-ai` to compare against. The
bench needs the DJGPP cross compiler for `NODRIVE.EXE`, or a prebuilt copy, and GNU `timeout` on
macOS.

The DOS column needs a hard disk image of each MS-DOS, which is not kept in this repository.

## What is left

MS-DOS 6.22 has no quoting in its shell: `type "q:\A.TXT"` there is a parameter error, not a
drive error. 7.10 strips the quotes and answers as the branch does, and the branch reads a quoted
path as its own resolver does.

`attrib` echoes the path as it was typed, which is MS-DOS 7.10's form; MS-DOS 6.22 writes the drive
letter in capitals. One of the two can be matched, and the shell's own convention is the one taken.

FreeDOS 1.4 was asked the same lines and does not finish them. It answers the lines it reaches
differently from both MS-DOS, and `md q:\X` never returns, so `dir` and `ren` are never asked. Its
`RESULT.TXT` is in [results/macos/nodrive-freedos.txt](../results/macos/nodrive-freedos.txt), and
nothing here is filed from it as an answer.
