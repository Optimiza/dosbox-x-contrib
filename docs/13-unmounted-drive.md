# 13. A command on a drive that is not mounted answers "Invalid drive specification" instead of ending the emulator

`LABEL`, `VOL`, `TREE` and `CD` on a drive with nothing mounted, or with no mounted drive current,
no longer end the emulator. `IMGMAKE` and `START` go on as with `C:` current. It is proved on macOS
and Windows, and merged upstream as
[pull request 6887, "Answer "Invalid drive specification" instead of ending the emulator on an unmounted drive"](https://github.com/joncampbell123/dosbox-x/pull/6887).

## What was wrong

`LABEL Q:` with nothing mounted on `Q:` ended the emulator: the shell read the drive's entry
without checking that a drive was there.

The same happened when the current drive was not mounted. A program gets there with INT 21h
AH=0Eh, DL=0, which accepts `A:` with nothing mounted on it. Then `LABEL`, `VOL`, `TREE` and
`IMGMAKE` with no drive named ended the emulator, and `CD` printed `A:\`.

On Windows, `IMGMAKE x.img -source q` and `START /HID` ended it too.

## What the fix changes

Each place that takes a drive now checks that one is mounted. `LABEL`, `VOL`, `TREE` and `CD`
answer "Invalid drive specification". `IMGMAKE` and `START` no longer read the missing drive, and
answer as they do with `C:` current.

`VOL 1:` and `TREE 1:` check the letter before they index the drive table. Their answer was
already the same.

MS-DOS 6.22 and 7.10 answer `LABEL Q:` with "Invalid drive specification" too. With an empty `A:`
current they raise a critical error first, and then print each command's own message.

The branch is `unmounted-drive-mainai`, six commits on upstream `main-ai` at `ac2787a42`. Each
compiles:

1. `LABEL` answers invalid drive when the drive is not mounted.
2. `VOL` answers it when the current drive is not mounted.
3. `TREE` answers it when the current drive is not mounted.
4. `IMGMAKE` and `START` check that the current drive is mounted.
5. `CD` answers it when the current drive is not mounted.
6. The CHANGELOG line.

## The figures

Unpatched is upstream `main-ai` at `ac2787a42`. Each line runs in an emulator start of its own,
with the same command on `C:` as its control, and the controls answer on every build. "Ends" is a
segmentation fault on macOS and an access violation on Windows:

| Command | Unpatched | Patched |
| --- | --- | --- |
| `LABEL Q: X`, `LABEL Q:`, `LABEL Q:X` | ends | Invalid drive specification |
| `LABEL X`, `LABEL`, `VOL`, `TREE`, with `A:` current | ends | Invalid drive specification |
| `CD`, with `A:` current | answers `A:\` | Invalid drive specification |
| `IMGMAKE x.img -t fd_1440`, `-t hd -size 4`, with `A:` current | ends | makes the image |
| `IMGMAKE x.img -source q`, with `A:` current, on Windows | ends | Unable to read floppy. |
| `START /HID whoami.exe`, with `A:` current, on Windows | ends | starts the program |
| `VOL 1:`, `TREE 1:` | Invalid drive specification | Invalid drive specification |

Source: `nodrive.sh <unpatched> <patched>`, in [results/macos/nodrive.txt](../results/macos/nodrive.txt) and [results/windows/nodrive.txt](../results/windows/nodrive.txt).

The two Windows rows have no macOS line: `IMGMAKE -source` and `START` are built on Windows only.

## What a program can notice

A program that never leaves a mounted drive current sees nothing.

A program that selects an unmounted `A:` or `B:` and then runs a shell command that reads the
current drive now gets "Invalid drive specification", where the emulator ended or `CD` printed
`A:\`.

## How to check it

Run every line on the two builds:

```sh
bench/nodrive.sh <build without the fix> <build with the fix>
```

| Exit code | Meaning |
| --- | --- |
| 0 | the builds answer alike |
| 1 | they differ |
| 3 | a line ended the emulator, or the run cannot be trusted |

With an unpatched build the script exits 3 and names each line that ended it. Two builds with the
fix exit 0.

[bench/README.md](../bench/README.md#nodrivesh) says what the script needs. `bench/realdos.sh`
asks a real MS-DOS the lines on `Q:`.

## What it needs

Nothing. The branch stands on upstream `main-ai` at `ac2787a42`.

## What is left

**Left alone on purpose.** INT 21h AH=0Eh still accepts an unmounted `A:` or `B:`. MS-DOS accepts
an empty `A:` too, and refusing it would change what programs see today, with no proof that
nothing depends on it.

DOSBox-X has no critical-error state for an unmounted letter, so the message is the one it already
gives for `VOL Q:`.

**Other answers.** Other commands on an unmounted drive answer differently from MS-DOS. They are
not part of this fix.
