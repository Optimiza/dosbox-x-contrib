# 15. Nine shell commands answer MS-DOS's message on a drive that is not mounted

`copy`, `del`, `type`, `attrib`, `truename`, `cd`, `md`, `dir` and `ren` now answer
`Invalid drive specification` when their path is on a drive with nothing mounted, as MS-DOS 6.22
and 7.10 do. `attrib` answers the DOSes' own `Path not found - <the path>`. It is proved on macOS
and Windows.

## What was wrong

The shell resolved a path before it looked at the drive. A path on a drive nothing was mounted on
failed inside the resolver, and each command reported what it made of that failure.

Six commands said `Path not found`. `cd q:\` said `Invalid directory - q:\`, and `md` said
`Unable to create directory - q:\X`. `dir` and `ren` said nothing at all, which a batch file cannot
tell from success.

## What the fix changes

Each of the nine commands now checks the drive its path names before its own path work. It reads
the drive the way the DOS path resolver does, so a quoted name is read alike.

Eight of them answer `Invalid drive specification`. `attrib` answers `Path not found - <the path>`,
which is what both DOSes print for a file on a drive that is not there.

`cd` keeps the hint it prints at the `Z:` prompt, where its message tells a new user how to mount a
drive.

## The figures

Unpatched is upstream `main-ai` at `0948c6a9b`. Each line runs in an emulator start of its own,
with the same command on `C:` as its control, and the control answers on every build.

| Line | Unpatched | The branch | MS-DOS 6.22 and 7.10 |
| --- | --- | --- | --- |
| `copy-q` | `Path not found` | `Invalid drive specification` | `Invalid drive specification` |
| `del-q`, `type-q`, `truename-q` | `Path not found` | `Invalid drive specification` | `Invalid drive specification` |
| `cd-q` | `Path not found` | `Invalid drive specification` | `Invalid drive specification` |
| `cd-q-root` | `Invalid directory - q:\` | `Invalid drive specification` | `Invalid drive specification` |
| `md-q` | `Unable to create directory - q:\X` | `Invalid drive specification` | `Invalid drive specification` |
| `dir-q`, `ren-q` | nothing | `Invalid drive specification` | `Invalid drive specification` |
| `attrib-q` | `Path not found` | `Path not found - q:\A.TXT` | `Path not found - Q:\A.TXT` |

Source: `nodrive.sh <unpatched> <the branch>`, in [results/macos/nodrive.txt](../results/macos/nodrive.txt)
and [results/windows/nodrive.txt](../results/windows/nodrive.txt).

The ten lines are the only ones that differ between the two runs, and the script says so:
`DIFFERENT, 10 lines differ`. Against itself the branch answers the same on both builds, `ALIKE`
on both hosts.

The message does not depend on the DOS version the emulator reports. `del q:\A.TXT` answers
`Invalid drive specification` at every version `ver set` gives it, the default one and both
MS-DOS ones. A control on a missing file of a mounted drive answers its own message, and those
lines are in the same file.

## What a program can notice

A batch file that tests the error now sees a message where `dir` and `ren` printed nothing. The
message goes to the standard output, so `> FILE` captures it as the DOSes' own is captured.

A program that opens a file on such a drive gets the same DOS error it got before. The messages
changed; the calls did not.

## How to check it

```sh
bench/nodrive.sh <unpatched> <the branch>
```

Each line runs in an emulator start of its own, beside the same command on `C:`. A line that does
not answer as the table says is a regression, and so is a control that answers nothing.

The whole battery is the second check: `make`-free, `bash bench/*.test.sh`, 39 scripts.

## What it needs

A DOSBox-X build on each host, made from the branch. Nothing else: `Q:` is never mounted, and the
bench needs no image.

## What is left

`rd` is outside this subject: it still answers `Invalid path, not directory, or directory not
empty - q:\X`, and neither DOS has been asked that line.

MS-DOS's answer to a quoted path was not measured on either DOS. The shell reads the quote as the
resolver reads it, but no bench line covers it.

`attrib` echoes the path as it was typed, which is MS-DOS 7.10's form; MS-DOS 6.22 writes the drive
letter in capitals. One of the two can be matched, and the shell's own convention is the one taken.

FreeDOS 1.4 was asked the same lines and does not finish them. It answers every line differently
from both MS-DOS, and `md q:\X` never returns: the batch stops there and does not come back in half
an hour. Nothing here is filed from FreeDOS.
