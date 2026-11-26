# 14. A divide error ends the program as MS-DOS ends it, instead of filling the log forever

`XCOPY` to a drive with nothing mounted no longer hangs the emulator. The program ends with
"Divide overflow" on the console and the batch goes on, as MS-DOS 6.22 does with the same XCOPY. It
is proved on macOS and Windows.

## What was wrong

`xcopy c:\A.TXT q:\` with nothing on `Q:` asks the DOS for the destination's free space. The answer
leaves the cluster size at zero, and XCOPY divides its file size by it. The divide error reaches
the guest as INT 00h.

DOSBox-X left vector 00h at the BIOS callback stub. That stub logs `Illegal Unhandled Interrupt
Called 0` and runs an IRET. A divide error is a fault: what the CPU saved is the address of the
instruction that divided.

So the IRET ran that instruction again, it divided again, and the guest never got out. Each pass
wrote a line to the emulator's log, and the run had to be killed at its bound.

## What the fix changes

The DOS now installs its own handler for INT 00h. It writes `Divide overflow` to the CON device and
ends the current program through the same path INT 21h AH=4Ch uses, so the program's caller goes on
as it does after any program that ends. A guest OS that is booted gets the BIOS stub back.

The message goes to the console and not to the line's redirection, as MS-DOS does: with
`xcopy c:\A.TXT q:\ > C:\MSG.TXT` the file is left empty on both.

DOS 7.10 words the message in two lines of its own, and FreeDOS prints a stack dump. The text here
is the MS-DOS 6.22 form, the one the emulator reports by default.

## The figures

Unpatched is upstream `main-ai` at `0948c6a9b`. Each line runs in an emulator start of its own, with
the same command on `C:` as its control, and the control answers on every build:

| Line | Unpatched | Patched |
| --- | --- | --- |
| `xcopy c:\A.TXT q:\` | fills the log until its 10-second bound and never reaches its last line | ends the program; the run reaches its last line |
| `xcopy c:\A.TXT c:\` | `File cannot be copied onto itself` | the same |

Source: `nodrive.sh <unpatched> <patched>`, in [results/macos/nodrive.txt](../results/macos/nodrive.txt) and [results/windows/nodrive.txt](../results/windows/nodrive.txt).

The same line, run on real DOSes booted from their own disk images, with the emulator's XCOPY:

| DOS | What the console said | The line's redirected file | The batch's next command |
| --- | --- | --- | --- |
| MS-DOS 6.22 | `Divide overflow` | left empty | ran |
| MS-DOS 7.10 | `Your program caused a divide overflow error.` / `If the problem persists, contact your program vendor.` | left empty | ran |
| FreeDOS 1.4 | `Interrupt divide by zero, stack:` and a dump of the stack | left empty | ran |

## What a program can notice

A program that divides by zero, or whose divisor comes out zero, no longer takes the emulator with
it: it ends as it does on MS-DOS, and its caller sees the end of a program, not a hung machine.

A batch file that runs such a program goes on to its next line.

## How to check it

Run every line on the two builds:

```sh
bench/nodrive.sh <build without the fix> <build with the fix>
```

With an unpatched build the script exits 3 and names the XCOPY line; two builds with the fix exit 0.
[bench/README.md](../bench/README.md#nodrivesh) says what the script needs.

## What it needs

The branch is `unmounted-xcopy-mainai`, one commit on upstream `main-ai` at `0948c6a9b`.

## What is left

**The message's text.** Only DOS 5.00 and 6.22's is printed. A build that reports DOS 7 to its
programs still prints it, where MS-DOS 7.10 prints its own two lines.

**Protected mode.** A protected-mode program that divides ends the same on the unpatched build and
on the fix: a DJGPP program printed its line before the division and nothing after it, and the
batch went on. That case does not reach this vector.

**The exit code.** The handler passes 0, and MS-DOS 6.22 measured the same to the program's
caller, with a batch whose `IF ERRORLEVEL` tests sit below one and do not fire for it, while one
test at four does.

MS-DOS 7.10 and FreeDOS were not measured for it.
