# What was seen and left

These things showed in the runs or in upstream's code, and no fix here closes them. Each entry
says what was seen, how and what becomes of it. What is left of one subject is on its own page.

## FC leaves memory behind whatever the folder holds

Runs of the emulator's FC leave memory behind even where the directory costs nothing. Unpatched
upstream holds as much in a folder with no other file, so it is not the directory cache's.

| Build and folder | Held after 1 run (kB) | Held after 300 runs (kB) |
| --- | --- | --- |
| Exact-name, the folder of 700 files | 165,904 | 181,008 |
| Retention, the folder of 700 files | 165,968 | 181,216 |
| Unpatched upstream, a folder with no other file | not run | 182,128 |

Source: `fc.sh <base> 0 off 300`, in [results/macos/pr6831-reporters-cases.txt](../results/macos/pr6831-reporters-cases.txt); cells `fc 700 300`, in [results/macos/battery-base-retention-exact-name.txt](../results/macos/battery-base-retention-exact-name.txt).

## With long names on, a search matches by a wider rule than MS-DOS

A 4Eh search honours a `*` followed by more characters, and matches the long name too. It is
the emulator's long-name rule, which no real DOS referees, and it is left as it is.

| PATLIST, 15 patterns, on macOS | Digest of the list |
| --- | --- |
| Every build, long names off | `dfc20fe25661` |
| MS-DOS 7.10 | `dfc20fe25661` |
| Every build, long names on | `a8e695a8baca` |

Source: `battery.sh --real-dos`, cells `patlist` and `realdos patlist`, in [results/macos/battery-base-retention-exact-name.txt](../results/macos/battery-base-retention-exact-name.txt).

## Two DRIFT lines differ from MS-DOS on every build

A search reads a folder that changed under it otherwise than MS-DOS does.

| Case | The builds return | MS-DOS 7.10 returns | What becomes of it |
| --- | --- | --- | --- |
| `folder-gained-files` | 7 with the exact-name patch | 8 | half closed by [subject 1](01-exact-name.md) |
| `folder-lost-the-entry` | 5 more | none | the order a changed directory is read in, left |

Source: `battery.sh --real-dos --raw`, calls `drift.sh` and `realdos.sh msdos710 drift`, in [drift_base-build_off.txt](../bench/fixtures/battery/drift_base-build_off.txt) and [realdos_msdos710_drift_off.txt](../bench/fixtures/battery/realdos_msdos710_drift_off.txt).

## The remount case answers by host on another author's build

The build of [another author's pull request for the same cost (6831)](pr6831.md) answers one
case differently on each host. The case needs the host's allocator to reuse an address, so no
claim rests on it.

| Host | A search on the remounted drive returns |
| --- | --- |
| macOS | 3 of 32 |
| Windows | 32 of 32 |

Source: `findlife.sh`, case `remount`, in [results/macos/pr6831-findlife.txt](../results/macos/pr6831-findlife.txt) and [results/windows/pr6831-findlife.txt](../results/windows/pr6831-findlife.txt).

## On Windows the unpatched build passes the bench's memory limit

In the large folder the unpatched build is killed before it ends 20 `fopen` calls. That is the
limit doing its work, and the cell is read from 1 and 5 calls.

| Cell, on Windows | Result |
| --- | --- |
| `memory real f 20 base` | killed at 6,291,456 kB of working set, INVALID |

Source: `battery.sh`, in [results/windows/battery-base-retention-exact-name.txt](../results/windows/battery-base-retention-exact-name.txt).

[The entry of `memory.sh`](../bench/README.md#memorysh) describes the limit.

## On Windows `ties.sh` is INVALID

No two entries share a short name there, because NTFS names the aliases. It is the script's
answer on such a host, not a failure.

## Subject 7 is a commit of subject 4

The shell's `DIR` printed the free space of another drive only once a failed FindFirst left a
DTA alone. [Subject 4](04-dta.md) leaves the shell's own temporary DTA as a failed search ran it,
so `DIR` prints its own volume's line, and subject 7 is no pull request of its own.

Source: `template.sh <unpatched> <patched> fat on`, line `shell`, in [results/macos/dta-searches-answers.txt](../results/macos/dta-searches-answers.txt).

## Subject 8 is withdrawn: the defect was not there

An option given as the last word, as in `MOUNT D C:\X -label`, reads nothing past the end of
the command line. `CommandLine::FindString` checks the end before it reads the word after an
option, so there is nothing to fix.

## A command line ending in `--` erases a position past its end

On `dosbox-x --`, `CommandLine::GetOpt` erases an iterator that no longer names an element, in
`src/misc/setup.cpp`. It was read and not run, and it is not reported yet.

## The shell's `LS` and `TREE` leave its DTA switched

`LS Q:\NOSUCH\`, and `TREE Q:` on a drive that is not mounted, return without putting back the
shell's own DTA, in `src/shell/shell_cmds.cpp`. They were read and not run, and they are not
reported yet.

## Drive Z: keeps one place for all its searches

Two FCB searches of `Z:` read turn about disturb each other, because the virtual drive keeps one
search place, in `src/dos/drive_virtual.cpp`. It was read and not run, and it is not reported
yet.

## An overlay file named like a base file's alias is not listed

The overlay drive never adds such a file to its listing. It was read and not run: the overlay
drive needs a design of its own. It is not reported yet.

## On Windows an exit with typed keys pending ends with 0xC0000409

The emulator ends so when it exits with `AUTOTYPE` keys still pending, on every build, and
macOS exits cleanly. It was measured on Windows, and it is upstream's. The bench's `dirtest.sh`
types no more keys than it needs.

## One run of the unit tests on Windows ended at its start

Once, on the alias build, the emulator's unit tests ended with 0xC0000409 in their first second,
with nothing logged. Every other run of them passed, on every build, and so do the branches on
`main-ai` on both hosts, the offered alias branch among them. The single failure is not
reproduced.
