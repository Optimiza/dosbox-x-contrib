# Instruments for DOSBox-X's directory cache

These are the checks a change to how DOSBox-X lists a host folder has to pass. Each check is a
host script and the DOS program it runs in the guest.

They cover what two builds list, what a search costs the emulator in memory, and what a
program sees when it does anything but run one search to its end. The code under test is
`src/dos/drive_cache.cpp` and the search calls around it.

| Script | Guest program | It tells you |
| --- | --- | --- |
| [`run.sh`](#runsh) | `listdump.c` | whether two builds list one folder byte for byte the same |
| [`memory.sh`](#memorysh) | `memprobe.c` | how much host memory a build keeps after a DOS program repeats one file call |
| [`fc.sh`](#fcsh) | the emulator's own `FC.EXE`, then `memprobe.c` to hold | how much host memory a build takes while a batch file runs FC again and again, and keeps after |
| [`findlife.sh`](#findlifesh) | `findlife.c` | whether two builds answer alike when a search is interrupted, shared or outlived |
| [`exact.sh`](#exactsh) | `exact.c`, `SHELLT.BAT` | whether two builds answer alike to searches for one exact name |
| [`ties.sh`](#tiessh) | `ties.c` | whether two builds return two entries that share an 8.3 name in the same order |
| [`enumstat.sh`](#enumstatsh) | `enumstat.c` | how many entries a listing returns while every entry is looked up by name |
| [`xcopy.sh`](#xcopysh) | the emulator's own `XCOPY.EXE` | how much of a tree of folders arrives when XCOPY copies it |
| [`xcomsim.sh`](#xcomsimsh) | `xcomsim.c` | whether two listings, each through its own DTA, survive the lookups X-COM Apocalypse makes between their turns |
| [`drift.sh`](#driftsh) | `drift.c` | whether two builds answer alike when a FindNext brings another pattern than its FindFirst had |
| [`findpos.sh`](#findpossh) | `findpos.c` | whether two builds keep the place of a search where a program can move it, and leave the same behind after a search for the volume label alone |
| [`dtadump.sh`](#dtadumpsh) | `dtadump.c` | whether two builds leave the same bytes in a DTA and in an FCB around the find calls |
| [`patlist.sh`](#patlistsh) | `patlist.c` | whether two builds return the same entries for patterns that hold a `*` before more characters |
| [`template.sh`](#templatesh) | `template.c` | whether two builds answer alike where the answer hangs on how the search template is padded |
| [`dosans.sh`](#dosanssh) | `dosans.c` | whether two builds answer alike where DOS parses a path, for 4Eh and for 3Dh, 43h and 3Bh |
| [`overlay.sh`](#overlaysh) | `findpos.c` | whether an overlay drive answers the label and root searches as the host folder under it and as DOS |
| [`attrprobe.sh`](#attrprobesh) | `attrprb.c` | whether two builds answer alike when a file is deleted or has its attribute changed while searches are open |
| [`delete.sh`](#deletesh) | `delprb.c` | whether two builds delete the same files of a folder of long names, and keep the short names of the files left |
| [`dirgone.sh`](#dirgonesh) | `dirgone.c` | whether two builds answer alike when a search is left open in a directory that is then removed or renamed |
| [`lfnren.sh`](#lfnrensh) | `lfnren.c` | whether the short names of a directory's long-named files still open the same files after a rename of the directory |
| [`attrsem.sh`](#attrsemsh) | `attrsem.c`, then the shell's `ATTRIB` and `DIR` | whether two builds answer alike around a change of the hidden, system and read-only attributes |
| [`sidefx.sh`](#sidefxsh) | `sidefx.c`, or the shell's `VOL` and `LABEL` | what else an attribute change does: a file the host added shows, or a label the guest set is overwritten |
| [`attrcost.sh`](#attrcostsh) | `attrcost.c` | how many times a build reads a folder from the host while a program changes attributes, deletes or creates files in it |
| [`resprb.sh`](#resprbsh) | `resprb.c` | how much host memory a build keeps after a program repeats a child process, a change of the FPU's control word, or a search |
| [`aliases.sh`](#aliasessh) | `aliases.c` | whether two entries of a folder share a short name, and whether each short name opens its own file |
| [`unit.sh`](#unitsh) | none: the emulator's own unit tests | how many of a build's unit tests ran and failed |
| [`passfail.sh`](#passfailsh) | a program you hand it | how many checks of a self-testing DOS program pass on a build |
| [`junktest.sh`](#junktestsh) | the batch files a reporter attached to an upstream issue, then `memprobe.c` to hold | how much host memory a build keeps after the reporter's own run |
| [`dirtest.sh`](#dirtestsh) | the program a reporter attached to an upstream issue, then `memprobe.c` to hold | how much host memory a build keeps after that program looked up every file of its folder |
| [`realdos.sh`](#realdossh) | `dosid.c` and one of the programs above | what a real DOS (MS-DOS 7.10, MS-DOS 6.22 or FreeDOS) booted from a disk image answers to the same programs, the emulator being only the machine |
| [`p5time.sh`](#p5timesh) | `p5probe.c` | how long the first read of a folder takes on two builds, timed from the host |
| [`p5rep.sh`](#p5repsh) | `p5rep.c`, then the shell's `DIR` | how long the shell's `DIR`, or one open of a file, takes in a folder the emulator has not read |
| [`batch.sh`](#batchsh) | the two above | a list of timed cells, each run against itself too, on a host that is watched |
| [`loadwatch.sh`](#loadwatchsh) | none | nothing by itself: it samples the host while `batch.sh` runs |
| [`judge.py`](#judgepy) | none | whether one cell of `batch.sh` ran on a quiet host |
| [`analyze.py`](#analyzepy) | none | the tables of what `batch.sh` left |
| [`battery.sh`](#batterysh) | every one above; the timers, `attrcost.sh` and `resprb.sh` by their tests only | all of it on two or three builds, one line per cell |
| [`launch.sh`](#launchsh) | none | nothing by itself: it is the launcher the scripts call on macOS |
| [`windows.ps1`](#windowsps1) | none | nothing by itself: it is the launcher the scripts call on Windows |

Every shell script prints its arguments, what it prints and its exit codes with `--help`.

## The exit codes

Every check shares one scheme, so a run that judged nothing never reads as a pass.

| Exit code | Meaning |
| --- | --- |
| 0 | the answer: alike, identical or measured |
| 1 | the two builds differ |
| 2 | bad usage |
| 3 | INVALID: nothing was judged |

- A run is INVALID when the emulator failed or was cut off, when the guest left no output, or
  when a report has no trailer or disagrees with its own counts.
- An INVALID run keeps its directory and names it.
- The two launchers and `batch.sh` have codes of their own: their entries list them.

## What they need

A run needs builds to compare, a way to build the guest programs, and a launcher. No window
opens on either host.

- Two DOSBox-X executables to compare, or one to measure. `unit.sh` needs a build that has the
  debugger: no other carries the unit tests.
- The DJGPP cross compiler (`DJDIR`, default `$HOME/djgpp`). Each run builds its guest program
  from the source beside the script, so a run tests the source it sits with.
- A host with no DJGPP takes the guest programs built on another one. `DIRCACHE_PREBUILT`
  names the folder that holds them, as `<NAME>.EXE`.
- On macOS, GNU `timeout` on the `PATH`, under that name or as `gtimeout` (coreutils).
- On macOS the launcher is `launch.sh`, beside the scripts. The scripts read the build's
  version line from its report.
- On macOS `memory.sh` and `fc.sh` read the emulator's memory with the system's `ps` and
  `footprint`.
- On Windows the scripts run under Git Bash and the launcher is `windows.ps1`, beside them.
- `realdos.sh` needs a hard disk image of each DOS it boots, and `passfail.sh` a program to
  run. You bring them: none is kept here, and their entries say what each must be.
- `junktest.sh` and `dirtest.sh` need the files two reporters attached to their upstream
  issues. They are not kept here: their entries say where each comes from.
- `attrcost.sh`, and the `resets=` figure of `resprb.sh`, need a build with a counter: the
  source with a diff of [`counters/`](#counters) applied.
- The timers run on macOS only. They need `python3`, version 3.10 or later, with its standard
  library alone, and the host's `top` and `sysctl`.
- Nothing is written outside a directory made for the run, under `TMPDIR`.

## What the scripts share

`common.sh` holds what every script shares, so that two scripts never measure two machines.

- It holds the arguments, the `<folder>` argument and the synthetic folders, the conf every
  run boots, the launcher call and the INVALID exit.
- A run's machine is written there once.
- Every folder it mounts gets an empty label unless the script names one. Left to itself a
  Windows build labels a mounted folder and a macOS build does not, so a search for the label
  would answer by host.

## The `<folder>` argument

`run.sh`, `memory.sh`, `passfail.sh` and `aliases.sh` take a folder of yours or make one for
the run.

| Form | The folder |
| --- | --- |
| a host directory | mounted read-only and reached through its parent |
| `synthetic:<count>:83` | `<count>` empty files with plain names, such as `F0000000.TXT` |
| `synthetic:<count>:long` | `<count>` empty files with long names: `Alpha track 000000.mid` and seven other words |
| `synthetic:<count>:dots` | names that end in `" ."` beside names whose alias starts with the same letters and then a character below `.` |
| `synthetic:<count>:mix` | short stems such as `"A  l.mid"`, whose aliases share a prefix with the long style's, then the long style's names |
| `synthetic:<count>:wine` | long names such as `wine long name 000.txt`, each beside a real file named as the Wine-style short name the emulator gives it |

- The long names collide in their first six letters, so the emulator has to number their 8.3
  aliases.
- A host directory's name goes on a DOS command line: no spaces, and an 8.3 name when long
  names are off.
- The last three styles are what a change to the alias code has to meet. `dots` is a folder
  where the order of the emulator's list of aliases decides an alias, and `mix` one where the
  jump to the next free number fails throughout.
- `wine` is a folder where the emulator's Wine-style lookup finds entries.
- A count a style's names cannot fill is refused as usage, with the reason. `dots` takes
  twelve names a character, `mix` more names than its short stems, and `wine` pairs of names.
- A folder that does not come out with every name is INVALID. Windows' file system takes off
  the `" ."` that ends some `dots` names, so the battery does not run that folder there.

## run.sh

**What it shows.** Whether two builds list one folder byte for byte the same. `LISTDUMP.EXE`
writes one text file per build, and the script compares the two with `cmp`.

The file holds:

- every entry of a full 4Eh/4Fh enumeration: attribute, time, date, size, 8.3 name;
- every entry of a full 714Eh/714Fh enumeration closed by 71A1h: attributes, the three times,
  size, long name, 8.3 alias, the conversion flags;
- what libc's `access` and `stat` and raw 716Ch and 714Eh answer for the first, middle and
  last entry of each, for a missing name, and for the middle name in the other case.

**How it is called.** The same build twice is the control: it must come out identical.

```sh
run.sh <build A> <build B> <folder> <on|off>
```

`<folder>` takes every style of [the `<folder>` argument](#the-folder-argument).

**What it prints.** Each build's path, version line and counts, then `IDENTICAL` or
`DIFFERENT` with the first differing lines.

**Exit codes.** `0` identical, `1` different, `2` usage, `3` INVALID.

- The two enumerations end with the guest's own count, and the last line carries the number of
  lookups. The script counts all three itself.
- It refuses a dump that disagrees with its counts, that has no last line, or that lists
  nothing but `.` and `..`.

**What it does not show.**

- The search state DOS keeps in the DTA's first 21 bytes, the handle 714Eh returns and the
  record's reserved bytes are left out on purpose. They identify a search, not a file.
- Synthetic files are empty, so every size reads 0 and every time is the run's.
- The two builds read the same folder, made once per run. Alias numbers depend on the order
  the host returns the files in, which two folders with the same names need not share.
- One search at a time. What happens to several is `findlife.sh`'s.

## memory.sh

**What it shows.** How much host memory a build keeps after a DOS program repeats one file
call. `MEMPROBE.EXE` repeats one call on one file of the folder, then creates a file and waits
for the host to create another.

- The emulator's memory is read from outside, with the calls done and the DOS program still
  alive. No guest clock is trusted for it.
- Run it at two call counts on one build and read the difference. A number from one run says
  little.
- MEMPROBE turns off the `glob()` DJGPP's start-up runs on every argument. That `glob()` asks
  the attributes of the file a path names, and so reads its folder before the mode's first
  call.

**How it is called.**

```sh
memory.sh <build> <folder> <on|off> <mode> <calls> [--file <name>]
```

| Mode | The call the guest repeats |
| --- | --- |
| `a` | `access` |
| `s` | `stat` |
| `d` | a FindFirst, never continued |
| `o` | open, read, close |
| `f` | `fopen`, `fread`, `fclose` |
| `r` | a raw 716Ch open, read, close |
| `v` | a 4Eh for the volume label |
| `c` | child processes that each make one FindFirst |
| `e` | a 4Eh for each file of the folder in turn, by its name, never continued |

- `--file <name>` is the file inside `<folder>` the guest names, as the guest can reach it. A
  host directory needs it; a synthetic folder defaults to its first file.
- On a synthetic folder `--file` takes a pattern as well as a name. With `--file '*.*'` mode
  `d` repeats a search of the whole folder that is never continued, which is the search DOS
  has no call to close.
- Mode `e` is a program that checks, one name after another, that each file of a folder is
  there. It lists the folder first, and `<calls>` past its size start over.

**What it prints.** One line: the call, the folder, three memory figures in kB of 1,024
bytes, then the counts and the build.

| Host | The three memory figures |
| --- | --- |
| macOS | `peak_rss_kb`, `held_rss_kb`, `held_footprint_kb`: the peak resident size, the resident size and the footprint while the guest holds |
| Windows | `peak_ws_kb`, `held_ws_kb`, `held_private_kb`: the peak working set, the working set and the private bytes |

After them come the number of samples, how many "All slots full" lines the emulator logged,
the guest's own line, the emulator's version line and its path.

**Exit codes.** `0` measured, `2` usage, `3` INVALID.

- The guest's line counts the calls that reached the file, and the script refuses a run where
  one did not. A lookup that fails costs the emulator nothing and would read as "no growth".
- A run is also INVALID when the guest was not read while it held, or when the emulator failed
  or passed the memory limit.

**What it does not show.**

- On macOS read the footprint. The resident size falls when the system compresses memory
  nobody touches, which is what an abandoned search is.
- On Windows read the private bytes.
- The run is killed, and INVALID, past a fixed resident size or working set, so a runaway
  cannot take the machine. A run that only grows in compressed memory is not stopped by it.
- With long names on, libc closes its own search handle when the name has no wildcard. So `d`
  and `c` then measure what a build keeps after a search is closed, not what an open one
  holds.
- With long names off the search stays open, and in `c` it is still open when the child ends.

## fc.sh

**What it shows.** How much host memory a build takes while a batch file runs FC again and
again in a folder of files, and how much it keeps after. It is the way a suite of tests
compares its results.

- `D:\DIR` holds `<files>` empty files with 8.3 names, `ONE.TXT` and `TWO.TXT`, which are
  equal, and `RUNS.BAT`, one line `FC ONE.TXT TWO.TXT` per run.
- The FC is the one the emulator carries on its `Z:` drive, started by the emulator's own
  shell from inside the folder. So every search made is one a user's batch file would cause.
- The memory is sampled from outside while FC runs, which gives the peak. It is read once
  more when the runs are over and MEMPROBE, which searches nothing, holds the guest.
- Read it at two run counts, and beside a run in a folder with no other file. What the
  folder's size adds is the subject.

**How it is called.**

```sh
fc.sh <build> <files> <on|off> <runs>
```

**What it prints.** One line: the folder and the runs, then the three memory figures
`memory.sh` prints, the first being the peak while FC ran.

After them come the number of samples, how many "All slots full" lines the emulator logged,
how many runs of FC said the two files do not differ, the emulator's version line and its
path.

**Exit codes.** `0` measured, `2` usage, `3` INVALID.

- The script counts the runs whose FC said the two files do not differ, and refuses a run
  where one did not. A batch file that never reached FC would read as "no growth".
- A run is also INVALID when the guest was not read while it held, or when the emulator failed
  or passed the memory limit.

**What it does not show.**

- The peak is the resident size or the working set, sampled. A rise shorter than the interval
  between two samples is not seen.
- It is the emulator's FC. What another FC asks of the directory is not measured.

## findlife.sh

**What it shows.** Whether two builds answer alike when a search is not simply run to its
end. Each case of `FINDLIFE.EXE` starts a search, does something else in the middle, and asks
the first search to go on.

What a case does in the middle:

- a second search through the same DTA, with the first one's bytes saved and restored;
- a FindFirst that fails;
- a child process that ends with searches open, or uses its parent's DTA;
- the drive unmounted and mounted again, or a rescan;
- the FCB calls;
- two enumerations at once through libc;
- a long-name search asked again after its end, or turned away for want of a handle;
- the folder listed again after it gained a file;
- more searches left open than the emulator has room for;
- two searches read turn about, each through its own DTA, while the program looks a file up
  by name before every turn.

A case reads one of three words:

| Word | Meaning |
| --- | --- |
| `ok` | the answer is what a search whose whole state is its DTA would give |
| `DIFFERS` | it is not |
| `not judged` | the case could not be set up |

**How it is called.**

```sh
findlife.sh <build A> <build B> <on|off>
```

**What it prints.** Each build's path, version line and report whole, then the lines that
differ. The script compares the two reports line by line.

**Exit codes.** `0` alike, `1` different, `2` usage, `3` INVALID: a run collected nothing, or
a report has no case or no trailer.

**What it does not show.**

- It judges answers, never memory, and its two folders are small.
- The remount case needs the host's allocator to hand the new drive the address of the old
  one. Where it does not, both builds answer `ok` and the case has shown nothing.
- It searches with wildcards. The one case that looks a file up by its name does so to fill
  the table; what such a search answers is `exact.sh`'s.

Some cases mirror the size of the emulator's search table, `SLOTS` in the source:

- `slot-reused-live` walks the table once. It prints whether a live search really got the old
  slot, and is not judged when none did.
- `stale-dta-after-reuse` walks it once too, and prints the same fact beside its answer.
- `lfn-next-after-its-end` walks until a search holds the table's first slot, and is not
  judged when none gets it.
- `lfn-first-with-no-handle-left`, `left-open-past-the-slots` and `turn-about-past-the-slots`
  make more calls than the table has slots. The last two run at the end, because the table is
  full when each ends.

## exact.sh

**What it shows.** Whether two builds answer alike to searches for one exact name. It runs
`EXACT.EXE` and then the shell's own commands (`SHELLT.BAT`) over a small folder whose names
cover the awkward ones.

The folder, `D:\` in the guest:

| Names | What they are |
| --- | --- |
| `FOO.TXT` | a root file, for the volume-label searches |
| `X\FOO.TXT`, `BAR.TXT`, `ZED.TXT`, `NOEXT`, `A.B`, `MixCase.Txt` | names that fit 8.3 |
| `X\Alpha track 000000.mid`, `...000001.mid` | long names whose aliases are numbered |
| `X\ALPHAT~1.MID` | a real file named like the first alias |
| `X\Alpha tr.mid` | a name with a space that fits 8.3 |
| `X\Two.dots.name.txt`, `X\No extension long name` | two dots, and no extension |
| `X\SUBDIR\INNER.TXT`, `X\Long Sub Directory\Inner long name.dat` | subdirectories |

It compares its sections one by one:

| Section | What it holds |
| --- | --- |
| `basic` | one search per name, call and attribute |
| `life` | exact-name searches saved, nested, abandoned or met by a change of the folder |
| `shell` | what the shell's commands print for exact names |
| `tree` | the folder after the shell's commands |
| `drift` | the searches whose FindNext arrives with another pattern than their FindFirst had |

In `drift` the program edits the DTA, or the emulator itself rewrites it.

**How it is called.**

```sh
exact.sh <build A> <build B> <on|off>
```

**What it prints.** One verdict per section.

**Exit codes.** `0` when `basic`, `life`, `shell` and `tree` are alike, `1` when one of them
differs, `2` usage, `3` INVALID: a run collected nothing, a report has no trailer, or a
section is empty.

**What it does not show.** `drift` is printed and compared, and it does not decide the exit
code. What such a search answers is not something DOS defines.

## ties.sh

**What it shows.** Whether two builds return two entries that share an 8.3 name in the same
order. It is the one case where an exact name matches two entries.

- The folder holds 30 subdirectories and 12 pairs of files.
- A pair is a long name, such as `aaa aaa.txt`, and a real file named like the alias the
  emulator would give it, `AAAAAA~1.TXT`.

**How it is called.**

```sh
ties.sh <build A> <build B>
```

**What it prints.** Each build's report and the verdict.

**Exit codes.** `0` alike, `1` different, `2` usage, `3` INVALID: a run collected nothing, or
no two entries share a short name on this host.

**What it does not show.** Which of a pair the host returns first decides whether they tie at
all, so the number of ties is the host's.

## enumstat.sh

**What it shows.** How many entries a listing returns while every entry is looked up by its
exact name, the way a program that shows sizes does.

**How it is called.**

```sh
enumstat.sh <build>...
```

It runs six rows on each build:

| Long names | Mode | Names | The row |
| --- | --- | --- | --- |
| on | `l` | long | a 714Eh listing, libc `stat()` on every entry |
| on | `s` | long | a 4Eh listing, libc `stat()` on every entry |
| on | `x` | 8.3 | a 4Eh listing, a raw 4Eh exact-name search on every entry, never continued |
| off | `s` | 8.3 | a 4Eh listing, libc `stat()` on every entry |
| off | `x` | 8.3 | a 4Eh listing, a raw 4Eh exact-name search on every entry |
| off | `n` | 8.3 | a 4Eh listing alone: the count the others are read against |

**What it prints.** One line per build and row:

- long names on or off, and the folder's names;
- the guest's own line: listing mode, entries listed, lookups that found their entry, the
  last name listed;
- how many times the emulator logged its search table full, and a slot number out of range;
- the emulator's version line and path.

**Exit codes.** `0` every run printed its line, `2` usage, `3` INVALID: a run collected
nothing, or its line is not ENUMSTAT's.

**What it does not show.** It compares nothing. Read its rows against the last one, the
listing alone.

## xcopy.sh

**What it shows.** How much of a tree of folders arrives when XCOPY copies it. XCOPY lists a
folder and looks every file up by name while the listing is open, then goes down into the
folders it found.

- The searches are nested as deep as the tree, with lookups by the thousand between two
  entries of each.
- `D:\TREE` holds folders three levels deep, with files at the two lower levels. It holds
  more files in all than the emulator's search table has slots.
- The shell makes `D:\COPY` and runs `XCOPY D:\TREE\*.* D:\COPY /S /E /Y`, with the XCOPY the
  emulator carries on its `Z:` drive.

**How it is called.**

```sh
xcopy.sh <build> <on|off>
```

**What it prints.** One line:

- `made` and `dirs_made`: the files and folders the tree holds;
- `copied` and `dirs_copied`: how many of each are under `D:\COPY` afterwards, counted on the
  host;
- `said`: the count XCOPY itself printed, or `-` when it printed none;
- how many times the emulator logged its search table full, and a slot number out of range;
- the emulator's version line and path.

**Exit codes.** `0` the run printed its line, `2` usage, `3` INVALID: the emulator failed or
was cut off, or XCOPY printed nothing.

**What it does not show.**

- It compares nothing: read `copied` against `made`.
- `said` is the count of what XCOPY listed, not of what the tree held.
- The copy is counted on the host, never by a listing of the guest. The emulator's listing is
  what is under test.
- The tree has 8.3 names only.

## xcomsim.sh

**What it shows.** Whether two listings, each through its own DTA, survive the lookups a game
makes between their turns. It is the case of
[upstream issue 4904, "FindFirst (int21,4e) can invalidate handles stored in other DTA blocks"](https://github.com/joncampbell123/dosbox-x/issues/4904).

`XCOMSIM.EXE` is a model of X-COM Apocalypse, not the game. It asks DOS what the game asked, in
the game's order, and reads two listings across those calls.

| Part | Where it comes from |
| --- | --- |
| the lookups | measured: every FindFirst of an INT 21h trace of the game, its name as passed and its attribute word, in `xcomsim/calls.txt` |
| one DTA for every lookup | measured: the game's DOS extender pointed every SetDTA at one real-mode buffer |
| the listing | the issue's account: FindFirst through DTA A, FindFirst through DTA B, then FindNext on each in turn |
| `--relay` | inferred: the listing goes through the lookups' buffer, its DTA bytes copied out and back, as an extender relays a protected-mode FindNext |

- The guest replays the lookups as loads, one load being the whole sequence, until past the
  emulator's search table.
- At the listing point the two listings start, with lookups between their turns.
- `xcomsim/extract.sh <trace>` writes the calls file from such a trace.

**How it is called.** `D:\XCOMA` holds every name the game found as a small file of the
script's own, and is the current directory. `D:\LISTA` and `D:\LISTB` hold the two listings'
folders.

```sh
xcomsim.sh <build A> <build B> <on|off> [--listing-at <lookup>] [--between <n>] [--relay]
```

**What it prints.** Each build's path, version line and report whole, then one line per build
and the verdict on the two reports.

- `listing=<found>/<expected> <found>/<expected> lost=<n>` is the guest's verdict. Each
  expected count is a listing of that folder run alone first.
- `slots_full=` counts the emulator's search table emptied, and `out_of_range=` a FindNext
  through a slot that was gone.
- A lookup that answers otherwise than it did in the game prints a `lookup-differs` line.

**Exit codes.** `0` alike, `1` different, `2` usage, `3` INVALID: an emulator failed or was cut
off, or a report has no verdict or no trailer.

**What it does not show.**

- The calls file holds names and calls only, nothing of the game's files. The CD's lookups are
  skipped, being another drive's.
- `--listing-at` and `--between` are the model's choices. Their defaults put the table's limit
  inside the listing.
- The trace held no FindNext, so the listing and the relay are not measured from the game.
- It makes no long-name call, so `realdos.sh` runs it whole, with its listing through its own
  DTAs (`xcomsim`) or relayed (`xcomsim-relay`).

## drift.sh

**What it shows.** Whether two builds answer alike when a FindNext brings another pattern
than its FindFirst had. `exact.sh`'s `drift` section holds the cases the emulator itself
produces; `DRIFT.EXE` is the program's side of it, over the same folder.

It starts a 4Eh search for one exact name, rewrites the eleven pattern bytes of the DTA, and
reads the search to its end. It rewrites them:

- to every name, or to a wildcard;
- to another exact name, padded with spaces or with zeros;
- in small letters or in mixed case;
- twice.

Then it does the same in other situations:

- after the DTA was saved and restored around another search;
- beside a second search;
- after the folder gained or lost files;
- after a search for the volume label alone.

**How it is called.**

```sh
drift.sh <build A> <build B> <on|off>
```

**What it prints.** Each build's path, version line and report whole, then the lines that
differ. The script compares the two reports line by line.

**Exit codes.** `0` alike, `1` different, `2` usage, `3` INVALID: a run collected nothing, or
a report has no case or no trailer.

**What it does not show.**

- A search for one exact name only. What an edited whole-folder search answers is not here.
- Three cases create and remove files in the folder, so each build gets its own copy.
- It makes no long-name call, so `realdos.sh` runs it whole.

## findpos.sh

**What it shows.** Whether two builds keep the place of a search where a program can move it,
and what a search for the volume label alone leaves behind.

A DOS keeps the place of a 4Eh search in the 21 bytes of the DTA it reserves for itself. So a
program can put back the bytes it saved earlier and read the same entries again, or read two
copies of one DTA side by side.

`FINDPOS.EXE` does both, over the same folder as `exact.sh`:

- a search rewound by its saved DTA, whole or the 21 bytes alone;
- a copy read beside the original;
- a search read on from another address;
- a DTA put back after its search ended;
- an ended DTA asked again beside a search in progress.

Then what a search for the volume label alone leaves behind:

- the label asked by every name, by a name it does not have and by its own, each followed by
  FindNext;
- the label asked with everything else in the root;
- the label alone asked through the DTA of a search in progress, which is then read on.

**How it is called.** The drive is mounted with the label `FPLABEL` or with none. The two
runs differ in the label cases only.

```sh
findpos.sh <build A> <build B> <labelled|unlabelled> <on|off>
```

**What it prints.** Each build's path, version line and report whole, then the verdict and
the lines that differ.

**Exit codes.** `0` alike, `1` different, `2` usage, `3` INVALID: a run collected nothing, or
a report has no line or no trailer.

**What it does not show.**

- Searches of the whole folder only. What an edited search of one name answers is
  `drift.sh`'s.
- A label is a directory entry on a FAT disk and a name the mount gives on a host folder.
  Read the attribute a label search returns, and where the label stands in a listing of the
  root, with that in mind.
- It makes no long-name call, so `realdos.sh` runs it whole: on the disk as it is made, and
  on the same disk once that DOS has labelled it.

## dtadump.sh

**What it shows.** Whether two builds leave the same bytes in a DTA and in an FCB around the
find calls. A program can read the block a search leaves behind, and the next call reads it
too.

`DTADUMP.EXE` prints those bytes, over the same folder as `exact.sh`:

- the DTA after a 4Eh for a list of patterns, with and without wildcards;
- the DTA around a 4Fh that finds nothing;
- the DTA before and after a FindFirst that fails through the DTA of a search in progress,
  for each reason it can fail;
- the DTA before and after a 714Eh made while that DTA is the current one;
- a plain and an extended FCB before and after 11h and 12h, with the entry each call leaves
  in the DTA.

After each of the two interrupting calls, the search is read to its end. Then it prints what
the FCB calls return in four situations:

- when two searches run turn about;
- when a 4Eh search runs in the middle;
- when the FCB is put back as it was before 11h;
- when it is copied and the search goes on from the copy.

**How it is called.**

```sh
dtadump.sh <build A> <build B> <on|off>
```

**What it prints.** Each build's path, version line and report whole, a line of figures per
build, then the verdict and the lines that differ.

| Figure | What it counts |
| --- | --- |
| `template=<digest>` | the template and attribute bytes of every FindFirst dumped; two reports with one digest hold the same bytes there |
| `untouched=<n>/<m>` | of the calls that must leave a DTA alone, how many left all of its bytes unchanged |
| `resumed=<n>/<m>` | of the searches such a call interrupted, how many returned the rest of the folder |
| `fcb=<digest>` | what the FCB searches returned |

- A dump is printed in groups, so that the template and the attribute stand apart from the
  bytes a DOS keeps for itself.
- Those bytes and every time and date are printed as dashes. They belong to one DOS and to
  one run, and without them two reports can be compared line by line.
- For `untouched` the program compares all 43 bytes, the dashed ones too.

**Exit codes.** `0` alike, `1` different, `2` usage, `3` INVALID: a run collected nothing, or
a report has no trailer or lacks the lines the figures are read from.

**What it does not show.**

- The bytes a DOS keeps for itself are not compared. Whether a search goes on is `resumed`'s.
- The ten bytes at +0Ch of an FCB are printed as they are. They hold a DOS's own numbers, so
  a build's lines there differ from another DOS's even when both keep the search in the FCB.
- The last case removes a file, so each build gets its own copy of the folder.
- `realdos.sh` runs it whole. There 714Eh answers that it does not exist.

## patlist.sh

**What it shows.** Whether two builds return the same entries for patterns that hold a `*`
before more characters. With long names on DOSBox-X answers 4Eh by a wider rule than MS-DOS
does.

- A `*` followed by more characters is honoured, and the long name is matched as well as the
  8.3 one.
- `PATLIST.EXE` lists what a 4Eh search returns for the patterns where that shows, over the
  same folder as `exact.sh`.
- `realdos.sh` gives the list of a DOS with no long names, which a build answers with long
  names off.

**How it is called.**

```sh
patlist.sh <build A> <build B> <on|off>
```

**What it prints.** Each build's path, version line and report whole, then the verdict and
the lines that differ.

**Exit codes.** `0` alike, `1` different, `2` usage, `3` INVALID: a run collected nothing, or
a report has no pattern or no trailer.

**What it does not show.** A search run to its end, never edited. What an edited one answers
is `drift.sh`'s.

## template.sh

**What it shows.** Whether two builds answer alike where the answer hangs on how the search
template is padded. A DOS keeps the pattern of a search as eleven bytes, eight of name and
three of extension, and what pads a short field decides a handful of answers.

`TEMPLATE.EXE` asks for them on a volume labelled `DISK1`, made for the run:

- a 4Eh for the label alone by a list of paths (none, the label, its beginning, wildcards,
  another name), and the 4Fh calls after each;
- the same through an extended FCB;
- a 4Eh for names between quotes whose name or extension ends in a space, beside the same
  names without it;
- the name bytes an FCB holds after 11h.

The volume's root holds eight files: `FOO.TXT`, `FOO`, `BAR.TXT`, `PROGRAM`, `PROGRAM.TXT`,
`foo .txt`, `program .txt` and `Program Files`.

**How it is called.**

```sh
template.sh <build A> <build B> <fat|host> <on|off>
```

| Volume | What it is |
| --- | --- |
| `fat` | a FAT16 image each build makes, labels and fills through its own shell |
| `host` | a host folder mounted with that label |

The two kinds of drive do not answer a label search by the same code.

**What it prints.** Each build's path, version line and report whole, then the verdict and
the lines that differ. In the report `V:` stands for the volume's letter.

On the image the report ends with a line of the shell's own. It is the free space `DIR` gives
for the volume while it is still empty, asked right after a `DIR` of another drive.

The shell's `DIR` takes the drive whose free space it prints from the block its search ran
in. So that line shows whose drive a search that found nothing left there.

**Exit codes.** `0` alike, `1` different, `2` usage, `3` INVALID: a run collected nothing,
the volume did not come out labelled or whole, or a report has no line or no trailer.

**What it does not show.**

- On the image the files arrive through the shell's `COPY`. With long names off they are
  there under their 8.3 names, and a build whose shell copies otherwise fills another volume.
- The script checks that the shell copied every file and names the label, nothing more.
- A quoted name is the emulator's own convention. A DOS without long names answers it with an
  error.
- `realdos.sh` runs it whole, on a disk it labels.

## dosans.sh

**What it shows.** Whether two builds answer alike where DOS parses a path, before it reads a
directory. A change to the parsing shows in every call it reaches.

`DOSANS.EXE` asks 4Eh for each shape, then the calls that parse a path the same way: 3Dh open,
43h get and set attributes, 3Bh change directory.

- The shapes: a path that ends in a backslash, dots that climb above the root or resolve to it,
  a leading space, two dots, quotes.
- The four calls then get shapes of their own, from the root and from `D:\X`. Among them are a
  space inside a name, a character no 8.3 name holds, a wildcard, a device, a missing directory.
- Then the root listed with each attribute, the label asked by name, and the bytes a search
  keeps in the DTA.
- Then a device found by a search, names with a space made through an FCB, and where each
  device's header lies in memory.
- The set call writes back the attribute the get call read, so no file changes.

**How it is called.** Over the same folder as `exact.sh`, a copy per build, on a drive with the
label `FPLABEL` or with none.

```sh
dosans.sh <build A> <build B> <labelled|unlabelled> <on|off>
```

**What it prints.** Each build's path, version line and report whole, then the verdict and the
lines that differ.

**Exit codes.** `0` alike, `1` different, `2` usage, `3` INVALID: a run collected nothing, or a
report has no line or no trailer.

**What it does not show.**

- The `chain` lines are where that DOS keeps its device drivers' headers, an address no other
  DOS shares. A device's size in a search is that address's segment on MS-DOS, so the `dev`
  lines differ between DOS.
- A real DOS answers with long names off only. With long names on, nothing referees.
- `realdos.sh` runs it on the disk as made (`dosans`) and once that DOS has labelled it
  (`dosans-labelled`).

## overlay.sh

**What it shows.** Whether an overlay drive answers the label and root searches as the host
folder under it and as DOS. `MOUNT D <dir> -t overlay` reads the folder through its own copy of
the host folder's FindNext, so a rule given to one can miss the other.

**How it is called.** It runs FINDPOS twice on one build: over the host folder, then with an
overlay on it, over an empty directory of the run's own.

```sh
overlay.sh <build> <labelled|unlabelled> <on|off>
```

**What it prints.** Each `label-` line of the two runs, then three checks:

- the two runs' `label-` lines are alike;
- on the overlay, a FindNext after a search for the label alone answers 18;
- on the overlay, the root lists no `.` or `..`.

The last two are what MS-DOS 6.22, MS-DOS 7.10 and FreeDOS 1.4 answer, labelled or not. The
other lines that differ follow, not judged.

**Exit codes.** `0` the three checks hold, `1` one does not, `2` usage, `3` INVALID: `findpos.sh`
did not answer, or a run printed no label line.

**What it does not show.**

- The overlay answers some other lines otherwise than its folder on every build: the size of a
  real 8.3 file whose name another file's alias carries, and an alias path through a long-named
  directory. They are listed, not judged.
- `DIRCACHE_OVERLAY` in `common.sh` puts any script's runs on an overlay: a glob matched against
  a run's name, such as `B` for build B's runs or `'*'` for all.

## attrprobe.sh

**What it shows.** Whether two builds answer alike when a file is deleted, or has its
attribute changed, while searches are open. Either call drives the emulator to drop what it
cached of a folder, and on some hosts all of the drive's.

`ATTRPRB.EXE` runs searches of a whole folder, three entries read first, across these calls:

- nothing in between, as the control;
- libc's `remove()` of a file the search has not reached, which makes a 4301h before it
  deletes;
- 41h alone on such a file;
- 4301h on another file of the folder;
- 4301h in one folder while a search of another is open;
- a search of each folder open across one 4301h.

Last, it saves the DTA of a search of `X` that then runs to its end. After a 4301h and a search
of `Y`, it puts the saved bytes back and asks FindNext through them. The same with no 4301h is
the control.

**How it is called.** Each build's drive holds `X`, with 40 files, and `Y`, with 20. Each build
gets its own copy, because the program removes and makes files in `X`.

```sh
attrprobe.sh <build A> <build B> <on|off>
```

**What it prints.** Each build's path, version line and report whole, then the verdict and
the lines that differ. A line carries how many entries the search returned of what it held,
how many were the other folder's, and whether the removed file came back.

**Exit codes.** `0` alike, `1` different, `2` usage, `3` INVALID: a run collected nothing, a
folder listed nothing, or a report has no line or no trailer.

**What it does not show.**

- The answer depends on the host. Where the emulator keeps the drive's cache across an
  attribute change, every build reads alike and the cell shows nothing.
- Its test plays the line a build answers differently with, which proves the comparison bites
  on such a host.
- Long names are on or off for the guest, but ATTRPRB itself makes no long-name call.

## delete.sh

**What it shows.** Whether two builds delete the same files of a folder of long names, and keep
the short names of the files left. A program that deletes the files a search returns deletes
each by the short name the search gave it, and goes on with the search.

That only works while the files left keep their short names. So `delete.sh` makes, for each
build, folders of the same eight long names, `Alpha track 000000.mid` to `...000007.mid`.

- Every file holds its own name, so reading a file opened by a short name says which file that
  name reached.
- After the run the script counts the files the host still holds in each folder, and the
  directories left in `R`.

| Folder | What happens there |
| --- | --- |
| `S` | the shell's `DEL D:\S\*.MID` |
| `L` | `DELPRB.EXE` deletes each name a search returns through 41h, as a program does |
| `W` | DELPRB deletes it through 7141h with a wildcard |
| `A` | listed, with what each short name opens, before and after one 41h and after a 3Ch of an 8.3 name |
| `A`, then | renamed: the first long name to `RENAMED.TXT` (56h), one long name to itself in capitals (7156h), then the old long name made again (716Ch) |
| `P` | a search kept open across a delete of the entry it just returned and of a later one |
| `C` | a search kept open across a 3Ch and a 716Ch, with `C` listed before and after |
| `R` | eight directories of the same names without the extension, each with an `ID.TXT` naming it |

In `R`, DELPRB does these, reading `R` after each step and searching inside each directory:

- it reads which directory each short name reaches, empties and removes `ALPHAT~1` with `RD`
  while a search is open inside it, and reads the seven left again;
- it makes `NEWDIR` (39h) and `Alpha track new` (7139h), and removes `NEWDIR` again;
- it renames the first directory with an `ID.TXT` to `RENAMED` (56h), and makes its old long
  name again (7139h).

**How it is called.**

```sh
delete.sh <build A> <build B> <on|off>
```

**What it prints.** Each build's path, version line and report whole, and the files the host
holds in each folder at the end. Then each build's counts, each step read against the listing
just before it, and last the verdict and the lines that differ.

| Step | What is counted |
| --- | --- |
| one delete in `A` | the short names that open another file |
| `C`'s search across the creates | the short names it returned that open another file |
| `C` after the creates | how many listed, of how many, creates answered, names listed twice, earlier names opening another file |
| the `RD` in `R` | the short names that reach another directory; how many `R` lists |
| one rename in `A` | listed, of how many, renamed, listed twice, earlier names opening another file, whether `RENAMED.TXT` opens the renamed file |
| a case-only rename in `A` | the short names that moved |
| the renamed file's old long name made again | earlier names opening another file; the short name it takes beside the renamed file's old one |
| the MD in `R` | listed, of how many, made, listed twice, earlier names reaching another directory |
| `NEWDIR` removed again | listed, of how many, earlier names reaching another directory |
| a search inside each directory of `R` | the directories that list other entries than their own, after the MD and after the rename |
| one rename in `R` | as for `A`, with whether `RENAMED` reaches the renamed directory |
| the renamed directory's old long name made again | as for the file |

- A build that keeps every short name reads zero in each "another" count. It gives a name made
  again a free short name, never the renamed one's.
- A search inside a renamed directory misses its `ID.TXT` when the cache holds the directory
  as a file.
- With long names off, an MD the cache holds as a file shows when `NEWDIR` is removed again.

**Exit codes.** `0` alike, `1` different, `2` usage, `3` INVALID: a run collected nothing, a
folder did not list its eight files before the deletes or is gone after them, or a report has
no line or no trailer.

**What it does not show.**

- With long names off, 7141h, 716Ch, 7139h and 7156h are not offered, and their lines say so
  on every build. The case-only rename and the old long names made again then count nothing.
- The short names are the emulator's own where it makes them. Where the host's file system
  gives each long name its short name, as Windows does with short names on, the deletes do not
  move them.
- There every build reads alike and the cell shows nothing: its test plays the lines that
  differ.
- No real DOS in reach has long names, so nothing referees the folders of long names. A search
  across a delete of an 8.3 name is FINDLIFE's and DRIFT's, which a real DOS referees.
- A search open inside a directory that is removed or renamed is `dirgone.sh`'s, with 8.3
  names.

## dirgone.sh

**What it shows.** What a FindNext answers once the directory its search is reading has gone.
A real DOS reads the directory it started on, by its place on the disk, whatever has become of
its name since.

`D:\G` holds five directories, each with `ID.TXT` and `TWO.TXT`, and `DIRGONE.EXE` makes six more
there first. Each case opens a search of one of them with attribute 10h and reads its first
entry, `.`. Then it does one thing and reads on with 4Fh until the search fails.

| Case | What is done to the directory |
| --- | --- |
| `kept` | nothing: the control |
| `rd` | emptied by 41h before the search, removed by 3Ah |
| `rd-remade` | the same, then made again empty under its old name |
| `ren` | renamed by 56h |
| `ren-remade` | renamed, then a new empty directory made under its old name |
| `rd-late-remade` | emptied once the search is open, removed, then made again with an `ID.TXT` |
| `rd-parent-ren` | removed, then its parent renamed |
| `rd-parent-rd` | removed, then its parent removed |
| `ren-parent` | its parent renamed |
| `ren-twice` | renamed, then renamed again |
| `ren-then-rd` | renamed, then removed under its new name |

**How it is called.** Each build gets its own copy of the folder. Every name is 8.3.

```sh
dirgone.sh <build A> <build B> <on|off>
```

**What it prints.** Each build's path, version line and report whole, then the lines that
differ.

A line reads `gone|<case>|first= entry= op= made= next= rest=`: the 4Eh's error and entry, the
errors of what the case did and of the 4Fh that ended the search, and every name returned.

**Exit codes.** `0` alike, `1` different, `2` usage, `3` INVALID: a run collected nothing, or a
report has no case or no trailer.

**What it does not show.**

- `rd-remade` cannot tell a build that follows the removed directory from one that reads the
  new one, both being empty. `rd-late-remade` can, since the new directory holds a file.
- FreeDOS can give a directory made right after a removal the removed one's place on the disk.
  In DIRGONE's sequence that place is not free, and FreeDOS answers as both MS-DOS.
- Every call is one MS-DOS 6.22 has, so `realdos.sh` runs it whole on the three DOS.

## lfnren.sh

**What it shows.** Whether the short names of a directory's long-named files still open the
same files once the directory is renamed.

`LFNREN.EXE` makes `A` and `C` in an empty `D:\L`, each with three long-named files whose content
is a word of the name. It deletes the first by its short name, so the two left keep `~2` and
`~3`, which a fresh read of the folder would not give them.

- `listed`: `A` listed whole, renamed `AR` by 56h, and each name it gave opened under `AR`.
- `search`: a search of `C` opened and its `.` read, `C` renamed `CR`, the search read to its
  end, and each name it returned opened under `CR`.

**How it is called.** Long names are on, since the files are made by 716Ch.

```sh
lfnren.sh <build A> <build B>
```

**What it prints.** Each build's path, version line and report whole, then the lines that
differ. A line per name gives the open's error and what the file holds.

**Exit codes.** `0` alike, `1` different, `2` usage, `3` INVALID: a run collected nothing, or a
report has no line or no trailer.

**What it does not show.** No real DOS in reach has long names, so nothing referees it.

## attrsem.sh

**What it shows.** Whether anything a program reads changes when a build stops emptying its
directory cache after an attribute change.

`ATTRSEM.EXE` works on the folder `X`, which holds ten files and the directory `SUB`:

- it makes a file hidden, system, both, read-only, archive off and back;
- after each it asks 4300h, a 4Eh for its name with and without the hidden bits in the mask,
  an open for writing, and the listing;
- it hides and shows `SUB`, and hides a file a search in progress has not reached.

Then the shell's own `ATTRIB +H`, `ATTRIB +S`, `DIR /B`, `DIR /B /A` and `ATTRIB` run, and the
same undone.

**How it is called.**

```sh
attrsem.sh <build A> <build B> <on|off>
```

**What it prints.** Each build's path, version line and report whole, ATTRSEM's lines first
and the shell's after them as `shell|<line>`. Then the verdict and the lines that differ.

**Exit codes.** `0` alike, `1` different, `2` usage, `3` INVALID: a run collected nothing, a
report has no line or no trailer, or the shell left nothing.

**What it does not show.** Its red is on Windows, where the cache is emptied at every
attribute change. On macOS every build reads alike, and its test plays the lines that differ.

## sidefx.sh

**What it shows.** What else goes with emptying the cache at an attribute change, long names
off. A build that empties it can show a file the host added behind its back, or overwrite a
label the guest set.

| Mode | What runs |
| --- | --- |
| `rescan` | `SIDEFX.EXE` lists `D:\X` and reads D:'s label, waits while the script adds `NEW.TXT` from the host, lists again, sets one file read-only and lists a third time; then the shell's `DIR`, `RESCAN D:` and `DIR` |
| `label` | Windows only: the host's `C:\` mounted as the guest's C:, then `VOL`, `LABEL C:GUEST`, `VOL` twice, `ATTRIB +R` on a file of the run's own folder, `VOL` |

- In `rescan`, a build that empties its cache at the attribute change lists the host's file
  there. One that does not lists it only after `RESCAN`.
- In `label`, C: is the one kind of mount whose label the guest can change and the host
  volume's label can overwrite.

**How it is called.**

```sh
sidefx.sh <rescan|label> <build A> <build B>
```

**What it prints.** Each build's path, version line and lines whole, then the verdict and the
lines that differ.

**Exit codes.** `0` alike, `1` different, `2` usage, or `label` on a host that is not Windows,
`3` INVALID: a run did not end, the guest never waited for the host, a report has no end, or
the shell's lines are missing.

**What it does not show.**

- Its red is on Windows. On macOS every build reads alike, and its test plays the lines that
  differ.
- `label` reaches the run's folder by its 8.3 path, so it needs that folder on C: and short
  names on there.

## attrcost.sh

**What it shows.** How many times a build reads a folder from the host while a program changes
attributes, deletes or creates files in it. It counts what emptying the cache at every
attribute change costs.

`ATTRCOST.EXE` searches the folder twice, then repeats one call `<K>` times, each followed by a
4Eh for another file's name. The script reads the build's log for each read of a folder from
the host.

**How it is called.**

```sh
attrcost.sh <build> <folder> <mode> <K>
```

| Mode | The call repeated |
| --- | --- |
| `b` | none: the baseline |
| `s` | 4301h on a file |
| `m` | libc's `remove()` of a file made for it: 4301h, then 41h |
| `u` | 41h alone on a file made for it |
| `c` | a file created and closed: 3Ch, then 3Eh |

- `<build>` is the source with `counters/count-dir.diff` applied. The diff applies to unpatched
  upstream and to the branches cut from it.
- `<folder>` is `synthetic:<count>:83` or a host directory. A host folder's names are made as
  empty files in the run's own folder, because the program deletes and makes files.
- `<K>` runs from `1` to `2000`, and the folder holds at least `<K>` plus two plain files.
- Long names are off.

**What it prints.** One line: the mode, `<K>`, the folder and its entries before and after,
then these counts, ATTRCOST's own lines, the emulator's version line and its path.

| Figure | What it counts |
| --- | --- |
| `host_reads=` | every read of a folder the build logged |
| `reads_of_the_folder=` | those of the folder itself |
| `entries_read=` | the entries those reads brought |
| `done=`, `found=` | the calls that answered, and the 4Eh that did |
| `guest_us=` | the loop's time on the guest's clock |

**Exit codes.** `0` measured, `2` usage, `3` INVALID: the build logged no read of a folder,
ATTRCOST did not reach its trailer, or the emulator failed. The baseline always reads the
folder once, so a log with no read is a build that does not count.

**What it does not show.**

- The count of reads does not depend on the host's load. `guest_us=` does.
- Its red is on Windows. On macOS every build reads alike, and its test plays the lines that
  differ.
- The counter's log lines carry the tag the diff writes, `HOST-DIR-READ`. A build counted by
  another diff is not read.

## resprb.sh

**What it shows.** How much host memory a build keeps after a program repeats one thing, read as
`memory.sh` reads it. It shows the memory each protected-mode program the guest starts leaves
behind.

**How it is called.** `RESPRB.EXE` works over a folder of 100 empty files with 8.3 names, long
names off.

```sh
resprb.sh <build> <mode> <calls> [--core <dynamic|normal>]
```

| Mode | What RESPRB repeats |
| --- | --- |
| `c` | a protected-mode child that starts a search and ends: `memory.sh`'s mode `c` |
| `n` | a protected-mode child that returns at once, with no search |
| `w` | a protected-mode child that runs a search of the folder to its end |
| `r` | a real-mode child that starts a search and ends: no DPMI, no FPU |
| `q` | a real-mode child that ends at once |
| `p` | no child and no search: FNINIT, then FLDCW with three exceptions unmasked |
| `d` | no child: a search started and never continued |

- Mode `p` makes the two control words a protected-mode child's start-up goes through.
- `--core` is the emulator's CPU core. It defaults to `dynamic`, as every script here runs.

**What it prints.** One line: the mode, the calls, the core, then the three memory figures
`memory.sh` prints. Then `resets=`, the guest's own line, the emulator's version line and its
path.

- `resets=` is how many times the x86 dynamic core reset its code cache. It needs a build of
  the source with `counters/count-dyn.diff` applied.
- It reads `none` when the log holds no reset: a build without that counter, or the normal
  core. The memory figures need no counter.

**Exit codes.** `0` measured, `2` usage, `3` INVALID: a repetition did not answer, the guest
was not read while it held, or the emulator failed or passed the memory limit.

**What it does not show.**

- macOS's build compiles no x86 dynamic core, so there `resets=` is always `none`.
- Its red is on Windows. On macOS every build reads alike, and its test plays the lines that
  differ.
- The counter's log lines carry the tag the diff writes, `DYN-CACHE-RESET`. A build counted by
  another diff is not read.

## counters/

**What it holds.** The diffs that make a build count what no guest program can see: how many
times the emulator does something inside one call. Each adds log lines and changes nothing a
program sees.

| Diff | Applies to | Its log lines give |
| --- | --- | --- |
| `count-dir.diff` | unpatched upstream, and the retention and create-and-delete branches | `HOST-DIR-READ`: each read of a folder from the host, its entries, the running total and the folder. `attrcost.sh` reads it |
| `count-dyn.diff` | unpatched upstream | `DYN-CACHE-RESET`: each reset of the x86 dynamic core's code cache, the code pages it dropped and the bytes they held. `resprb.sh` reads it |
| `count-first-read.diff` | unpatched upstream | `5P`: at each folder read, FindFirst and emptying of the cache, the running count of every loop of a first read |
| `count-shadow.diff` | unpatched upstream | the `5P` lines, and `5S`: how often a faster way to place, check or number an alias, computed beside the code it would replace, answers differently |

**How it is used.** Apply one diff to the source with `git apply`, and build as any other build.

**What it does not show.** No script reads the `5P` and `5S` lines: they are read from the log.
The loops `5P` counts are the entries read, the aliases made, the duplicate check's compares,
the Wine-style lookup's hashes and the alias list's compares and moves.

## aliases.sh

**What it shows.** Whether two entries of a folder share a short name, and whether each short
name opens the file it was listed for. A short name is how a DOS program reaches a file.

- `run.sh` cannot see a name listed twice: both builds list it twice the same way.
- `aliases.sh` judges one build against the host, which knows each file's size.

**How it is called.**

```sh
aliases.sh cases <on|off> [--parent <dir>] <build>...
aliases.sh folder <on|off> <folder> <build>...
```

- `cases` makes a folder in which every file has a size of its own. It holds real files named
  like aliases beside the long names whose alias the emulator could make the same.
- Those real files are `AAAAAA~1.TXT`, `SIBLIN~2.DAT`, `TENTH~10.DAT`, a name with no
  extension, one in lower case, and a file named like a directory's alias.
- It also holds two families of long names alone whose numbering loses count, eight real files
  named as the Wine-style short names of eight long names, and controls.
- `ALIASES.EXE` lists the folder through 4Eh and through 714Eh, searches for and opens every
  short name it saw, and opens every long name.
- `--parent <dir>` makes the folder there. On a volume that tells case apart, the folder also
  gets names that differ only in case.
- `folder` lists a host folder, mounted read-only, or a synthetic one of any style.

**What it prints.** For `cases`, one line of figures per build, and below it the names behind
each figure.

| Figure | What it counts |
| --- | --- |
| `entries`, `host` | the entries 4Eh listed; the entries the host holds |
| `names_shared` | short names more than one entry is listed under |
| `exact_search_not_one` | short names whose search returns other than one entry |
| `real_name_not_its_own` | files whose own name is 8.3 and does not open them |
| `files_no_short_name_opens` | files no listed short name opens |
| `listed_with_another_size` | with long names on, entries listed with another file's size, or a directory listed as a file |
| `name_opens_another_file` | with long names on, aliases that open another file than the one listed |
| `long_name_opens_another_file` | with long names on, long names that open another file through 716Ch |

- Every figure `0`, with `entries` equal to `host`, says that no two entries share a short
  name, and that each short name opens its own file.
- For `folder`: `entries`, `host`, `names_shared` and `entries_sharing`. With long names on,
  also `matched`, the entries whose long name the host holds, and `listed_with_another_size`.
- `folder` prints no file name of the folder.

**Exit codes.** `0` every build measured, and the figures alike where several were given, `1`
two builds' figures differ, `2` usage, `3` INVALID.

- A run is INVALID when it collected nothing, or its report has no trailer or not the lines it
  counts.
- It is also INVALID when a listing came back empty, or the folder did not come out whole.

**What it does not show.**

- Where the host's file system gives each long name its short name, as Windows does with short
  names on, the aliases are the file system's. The folder comes out with no shared name on
  every build.
- The real files named like aliases are written before the long names, so the folder is whole
  there too.
- On a volume that tells case apart, with long names on, a long-name call finds a name without
  case. `readme.txt` opens `README.TXT`, and a search for `MIXED.DAT` returns its two
  look-alikes.
- `exact_search_not_one` and `long_name_opens_another_file` count those on every build. Each
  file stays reachable by its own short name.
- The Wine-style names are written in the script, as the emulator computes them for the eight
  long names. A change to that hash is a change to the script.

## unit.sh

**What it shows.** How many of a build's own unit tests ran and failed. DOSBox-X carries unit
tests in a build that has its debugger, run with `-tests` before any guest starts.

**How it is called.**

```sh
unit.sh <build>
```

**What it prints.** One line: how many tests ran, how many failed, erred or are disabled,
then the emulator's version line and path. The counts come from the result file the emulator
writes.

**Exit codes.** `0` the tests ran, `2` usage, `3` INVALID: the emulator left no result file,
the file is cut short or counts no test, or the emulator failed and the file names no
failure.

**What it does not show.** Exit `0` is not a pass. A failed test is an answer, not an INVALID
run: read `failures=` and `errors=`.

## passfail.sh

**What it shows.** How many checks of a self-testing DOS program pass on a build. The program
takes no arguments, searches its current directory and prints one line ending in `PASS` or
`FAIL` per check.

The guest changes into the folder on one drive and starts the program from another. So the
program's own file is not in what it lists.

**How it is called.**

```sh
passfail.sh <build> <folder> <on|off> <program>
```

It is how `FINDTEST` and `LFNTEST` are run, the two regression programs attached to
[upstream pull request 6831, "Release directory search snapshots when searches end"](https://github.com/joncampbell123/dosbox-x/pull/6831).
They are not kept here.

Build them from their author's sources with Open Watcom, in a folder that holds the source,
with the compiler's folder in `WATCOM`:

```sh
WATCOM=$WATCOM INCLUDE=$WATCOM/h PATH=$WATCOM/<host folder>:$PATH wcl -bt=dos -ms -cc -q FINDTEST.C
```

`-cc` matters where file names keep their case. Without it `wcl` hands a source ending in an
upper-case `.C` to the C++ compiler.

**What it prints.** What the program printed, then one line: the program and the start of its
sha256, how many of its lines end in `PASS` and in `FAIL`, its exit code, and the emulator's
version line and path.

**Exit codes.** `0` ran, `2` usage, `3` INVALID: the guest did not reach the folder, the
program printed no `PASS` or `FAIL` line, or the run collected nothing.

**What it does not show.** Exit `0` is not a pass: read `fail=` and `exit=`. The script
counts `PASS` and `FAIL` in upper case only.

## junktest.sh

**What it shows.** How much host memory a build keeps after the run a reporter attached to
[upstream issue 6827, memory taken by programs run in folders with many files](https://github.com/joncampbell123/dosbox-x/issues/6827).
Its batch files run FC again and again, and fill the folder with empty files to run it among.

- The files are the reporter's, with no licence stated, so they are not kept here. Download the
  archive from the issue into a folder of its own, unpack it there, and hand the script that
  folder.
- A folder that is absent, or lacks one of the files, is INVALID. Nothing in it runs on the
  host: the script copies the folder into its run directory, and the emulator runs it.

**How it is called.**

```sh
junktest.sh <build> <folder> <on|off> <batch>...
```

- The batch files are `300`, `JUNK` or `DJUNK`, called in the order given from the root of the
  drive the folder is, as the issue mounts it.
- `300 JUNK 300` is the run the issue describes, and its first steps alone say what each adds.
- FC is the one on the emulator's `Z:` drive, as in the report. `300.BAT` sends FC's answers to
  `NUL`, so the script first asks FC once to show it compares the reporter's two files there.
- The runs are counted from what the batch files print to the console, which the emulator logs.
  Then MEMPROBE, which searches nothing, holds while the host reads the emulator.

**What it prints.** One line:

- the batch files, the folder's entries at the end, and how many of them are `.TMP` files;
- how many lines `300.BAT` counted its runs with, and how many batch files said they were done;
- the three memory figures `memory.sh` prints, the first being the peak while the batch files
  ran;
- the samples, how many "All slots full" and "ID out of range" lines the emulator logged, its
  version line and its path.

**Exit codes.** `0` measured, `2` usage, `3` INVALID.

- A run is INVALID when the folder is absent or lacks one of the reporter's files, or FC did
  not compare them.
- It is also INVALID when a batch file did not reach its end, the guest was not read while it
  held, or the emulator failed or passed the memory limit.

**What it does not show.**

- What the reporter saw on another host is not what this run measures: the figures are this
  host's.
- The reporter's conf leaves long names off, which is what the battery runs.
- The counts come from the emulator's log and its console logging, `[dos] log console`, which
  every run of it turns on.

## dirtest.sh

**What it shows.** How much host memory a build keeps after the program a reporter attached to
[upstream issue 2485, a test that each of 1,835 files exists crashes](https://github.com/joncampbell123/dosbox-x/issues/2485)
has looked up every file of its folder.

- The archive holds a FoxPro program, with its runtime and DOS extender inside, and the folder
  `DATA` of files it lists and looks up one by one.
- The files are the reporter's, with no licence stated, so they are not kept here. Download the
  archive from the issue into a folder of its own, unpack it there, and hand the script that
  folder.
- A folder that is absent, or lacks `DIRTEST.EXE` or `DATA`, is INVALID. The script copies the
  folder into its run directory, and the emulator runs it.

**How it is called.** `DIRTEST.EXE` runs from the root of the drive the folder is.

```sh
dirtest.sh <build> <folder> <on|off>
```

- The program ends on an error dialog its runtime raises after the loop: the program's own
  `SET STEP ON`, which the reporter explains in the issue.
- The dialog waits for a key. So the emulator types Enter every few seconds from before the
  program starts (`AUTOTYPE`), and the first one after the dialog is up cancels it.
- The program draws on the screen, so its work is counted from the INT 21h calls the emulator
  logs between the shell starting it and the shell's next prompt.
- Then MEMPROBE, which searches nothing, holds while the host reads the emulator.

**What it prints.** One line:

- the files in `DATA`;
- the 4Fh calls of the program's listing, and the 4Eh calls: the listing's first, one per
  lookup, and the few its runtime makes for itself;
- the three memory figures `memory.sh` prints, the first being the peak while it ran;
- the samples, how many "All slots full" and "ID out of range" lines the emulator logged, its
  version line and its path.

**Exit codes.** `0` measured, `2` usage, `3` INVALID.

- A run is INVALID when the folder is absent or incomplete, or the program did not start, did
  not return or did not look every file of `DATA` up.
- It is also INVALID when the guest was not read while it held, or the emulator failed or
  passed the memory limit.

**What it does not show.**

- `AUTOTYPE` keeps time on the host's clock, not the guest's, and presses Enter for a bounded
  time. A program that has not reached its dialog by then holds the run to its bound, which is
  INVALID.
- A key typed before the dialog is up is lost to it. So the keys cannot be counted to end with
  the program, and some are still pending when the run ends.
- On Windows the emulator exits with 0xC0000409 when keys are still pending, on every build.
  The script takes that exit as the run's end once it has read MEMPROBE's line, and says so in
  a line of its own.
- What the reporter saw on another host is not what this run measures: the figures are this
  host's.
- The counts come from the emulator's log, `[log] int21`, which every run of it turns on.

## realdos.sh

**What it shows.** What a real DOS answers to the same programs. What a search ought to answer
is decided by a DOS, and the emulator's own DOS is the thing under test.

- The emulator is only the PC. Once the image boots, its DOS, its shell and its host-folder
  drives are gone.
- Every INT 21h call is answered by the image's kernel over a FAT volume.
- Three DOS can referee, so an answer is called DOS's only where they agree.

| `<dos>` | The image you bring | How the run starts it |
| --- | --- | --- |
| `msdos710` | the system disk of a Windows 98, whose kernel is MS-DOS 7.10 | its `CONFIG.SYS` and `AUTOEXEC.BAT`, tools in `C:\WINDOWS\COMMAND` |
| `msdos622` | a hard disk MS-DOS 6.22 was installed on, raw or VHD | the same files, tools in `C:\DOS` |
| `freedos` | FreeDOS 1.4's USB Lite image, as freedos.org gives it | `FDCONFIG.SYS`, whose `SHELL` line starts the run's `AUTOEXEC.BAT`; tools in `C:\FREEDOS\BIN` |

No image is kept here. The image's first partition starts that DOS, and it is never written:
each run boots a copy.

**How it is called.**

```sh
realdos.sh <build> <dos> <boot image> <program>
realdos.sh <build> <dos> <boot image> junktest|dirtest <folder>
```

| `<program>` | What runs on the image's DOS |
| --- | --- |
| `id` | which DOS answers, and nothing else |
| `findlife` | FINDLIFE over the two folders `findlife.sh` makes |
| `exact` | EXACT over the folder `exact.sh` makes |
| `enumstat` | ENUMSTAT in its modes `s`, `x` and `n` over a folder of files with 8.3 names |
| `drift`, `dtadump`, `patlist` | that program over the folder `exact.sh` makes |
| `template` | TEMPLATE over the files `template.sh` makes, in the root of the run's disk, which is then labelled `DISK1` |
| `findpos` | FINDPOS over the folder `exact.sh` makes, on the run's disk as it is made: with no label |
| `findpos-labelled` | the same once the image's own `LABEL` has named the disk `FPLABEL` |
| `dosans`, `dosans-labelled` | DOSANS over the folder `exact.sh` makes, on the disk as made, then once it is labelled `FPLABEL` |
| `memprobe` | MEMPROBE in its mode `e` over a folder of files with 8.3 names |
| `fc` | the emulator's `FC.EXE` run again and again from a batch file, as `fc.sh` runs it, in a folder of files |
| `xcopy` | the emulator's `XCOPY.EXE` over the tree `xcopy.sh` makes |
| `dirgone` | DIRGONE over the folder `dirgone.sh` makes |
| `xcomsim`, `xcomsim-relay` | XCOMSIM over the drive `xcomsim.sh` makes, its listing through its own DTAs, then relayed |
| `junktest` | the reporter's batch files of `junktest.sh`, unpacked in `<folder>`, in the run the issue describes, with the emulator's `FC.EXE` |
| `dirtest` | the reporter's program of `dirtest.sh`, unpacked in `<folder>`, with Enter typed as `dirtest.sh` types it |

- The folder of `enumstat` holds 3,000 files, and that of `memprobe` 1,835.
- `fc` runs FC 300 times, in a folder of 700 files.

A run launches the emulator three times: to stage, to boot and to collect.

1. The emulator's own shell puts the programs and a DPMI host on the copy, with its own
   `FC.EXE` or `XCOPY.EXE` when the run is theirs. The programs go to `C:\RD`.
2. It makes a second FAT16 disk, `D:`, and copies the folders onto it with long names off. So
   they arrive under the 8.3 names a program sees through the emulator's host-folder drive.
3. The copy boots. Its `AUTOEXEC.BAT` runs the programs, gathers their reports in one file and
   turns the machine off through the BIOS's power management.
4. `AUTOEXEC.BAT` never returns, so no Windows starts.
5. The emulator's shell copies that file out of the image.

**What it prints.** The machine's path and version line, the image, whose DOS answered, then
the program's report whole. Every line names the DOS: the script's own start
`realdos.sh: <dos>: `, and the report's start `<dos>|`.

- Whose DOS answered is its own `VER` line and what `DOSID.EXE` read: the version, where the
  INT 21h vector points, whether the long-name calls answer, whether a Windows is running,
  and whether the emulator's `Z:` drive exists.
- For `enumstat` the report is one line per mode. For `dtadump` the figures `dtadump.sh`
  prints come first.
- For `memprobe` it is the guest's line. For `fc` it is how many runs said the two files do
  not differ.
- For `xcopy` it is how many files and folders the tree holds, how many of each that DOS's
  own `DIR` lists under the copy, and the count XCOPY printed.
- For `xcomsim` and `xcomsim-relay` it is XCOMSIM's report, then its `listing=` verdict on a
  line of the script's own.
- For `junktest` it is the counts `junktest.sh` prints, but memory. For `dirtest` it is how
  many files `DATA` holds, whether the program returned, and what that DOS's `DIR` lists.

**Exit codes.** `0` the report is the image's DOS's, `2` usage, `3` INVALID.

- A run answered from the emulator's ROM segment, or one that has `Z:`, is INVALID.
- So is one whose folders did not reach the disk whole, whose image did not boot, whose batch
  did not reach its last line, or whose report is cut short.
- With `findpos-labelled`, a run whose DOS does not return that label is INVALID.

**What it does not show.**

- Long names off only. None of the three has long-name calls without a driver, so the cases
  that need them read `not judged` or do nothing.
- MS-DOS 7.10 and FreeDOS answer 714Eh with 7100h. MS-DOS 6.22 returns from 71h with the carry
  clear, so a long-name case there reads whatever the registers held: its lines are not an
  answer.
- FreeDOS's USB Lite image carries `LABEL` only as a package. `findpos-labelled` and
  `dosans-labelled` install it there with FreeDOS's own installer before they label the disk.
- FINDLIFE's `remount` and `rescan-mid-search` call the emulator's `MOUNT` and `RESCAN`,
  which no other DOS has. There both read `DIFFERS`, and that is the sign the two DOSes are
  not one.
- `slot-reused-live`, `stale-dta-after-reuse`, `left-open-past-the-slots` and
  `turn-about-past-the-slots` are sized by the emulator's search table. Elsewhere they run
  and say only that a search survives that many others.
- The long-name cases among them are not judged.
- `SHELLT.BAT` tests the emulator's shell and is not run. There is no `ties` here: its two
  entries with one short name do not reach a FAT folder as two.
- The folders go through the emulator's shell, so the build named must be able to copy them.
  The script counts what was copied.
- A large folder, and the tree of `xcopy`, go through `COPY` a folder at a time. `XCOPY`
  looks every file up while it lists, and the emulator's search table fills first.
- `memprobe`, `fc`, `xcopy`, `xcomsim` and `xcomsim-relay` say what that DOS answers, not what
  it holds: there is no memory to read.
- The FC and the XCOPY are the emulator's, run by the image's DOS, so the two DOSes are asked
  by one program. What the copy left is listed by that DOS's own `DIR`.
- `junktest` and `dirtest` say only whether the reporter's files run there to their end.
- `junktest` runs in a folder of the disk, not its root, because a FAT16 root holds fewer
  entries than `JUNK.BAT` makes. Each batch file runs through a `COMMAND /C` of its own, so
  that what it prints can be counted.
- `dirtest` cannot count the program's calls there, since that DOS's INT 21h is not the
  emulator's. Its loop reads the FAT folder from its start for every file, so it is the
  longest run of the script.
- `dirtest` types its keys from before the boot. When the DOS turns the machine off with keys
  still to type, the emulator can die in its AUTOTYPE thread. That exit is taken, with a line
  that says so, only when the DOS's batch reached its last section.
- It has been run on macOS only. The copy of the image is a clone where the file system has
  them and a whole copy elsewhere; a VHD keeps its extension, by which the emulator knows it.
- Every conf that mounts an image says `ver=7.1`. Under a lower reported version the emulator
  asks about a FAT32 or LBA partition in a native dialog, which a headless run cannot answer.

## p5time.sh

**What it shows.** How long the first read of a folder takes on two builds, timed from the
host. `P5PROBE.EXE` makes one 4Eh for `<folder>\*.*` on a folder the emulator has not read.

- A first read is a wall time, so it is never a battery cell. It is taken through `batch.sh`,
  detached, on a host nobody else is loading.
- Each run is a fresh emulator. The guest makes a ready file and waits.
- The clock is the host's monotonic one. It starts when the host makes the go file and stops at
  the guest's last line.
- The two builds run interleaved, A B B A in each round, so that a drift of the host's speed
  falls on both alike.

**How it is called.**

```sh
p5time.sh <build A> <build B> <folder> <on|off> <pairs> <out dir>
```

- `<folder>` is a synthetic folder, made once under `P5_FOLDERS`, or a host directory mounted
  read-only. The same build twice is the A/A pair.
- `<pairs>` is how many A B B A rounds. `<out dir>` keeps each run's guest line, the
  launcher's report and the emulator's pid.

**What it prints.** A line naming the two builds, one line per run, and one per build with its
fastest, median and slowest time.

```
p5time|<round>|<A|B>|seconds=<s>|t0=<epoch>|t1=<epoch>|pid=<emulator>|guest=<line>
```

**Exit codes.** `0` timed, the two builds' guest lines alike, `1` the guest lines differ, `2`
usage, `3` INVALID: a run did not reach its last line, or the emulator failed.

**What it does not show.**

- The guest runs at a fixed clock, `TIMER_CYCLES` in `common.sh`. What is timed is host code
  inside one call, so the guest's speed barely enters it.
- A factor between two builds measured at the fixed clock holds at `cycles=max`, within the
  spread of one build against itself.
- One run's time says little. Read it beside each build's spread against itself, which
  `batch.sh` gives.

## p5rep.sh

**What it shows.** How long the shell's `DIR`, or one open of a file, takes in a folder the
emulator has not read, on two builds. It works as `p5time.sh` does, with a step chosen by
`<case>`.

**How it is called.**

```sh
p5rep.sh <build A> <build B> <folder> <on|off> <case> <pairs> <out dir>
```

| `<case>` | The step timed |
| --- | --- |
| `dir` | the shell's `DIR` of the folder |
| `dir:<name>` | the shell's `DIR` of one file of the folder |
| `open:<name>` | one 716Ch open of one file, with long names on |
| `fopen:<name>` | the C library's `fopen` of one file |

- The clock stops at a stop file. The shell makes it right after its `DIR`, and `P5REP.EXE` as
  soon as its open returns.
- `DIR`'s count is read after the clock stopped.
- P5REP turns off DJGPP's `glob()` of its arguments. Run before `main`, it would make the first
  read of the folder a path names before the timed step.

**What it prints.** As `p5time.sh` prints, with a line naming the case, and `p5rep` at the head
of each run's line.

**Exit codes.** `0` timed, the two builds' guest lines alike, `1` the guest lines differ, `2`
usage, `3` INVALID.

- A run is INVALID when the step did not run: no ready or stop file, no guest line, a `DIR`
  that counted no file, or an open that failed.
- It is also INVALID when the emulator failed.

**What it does not show.** One run's time says little. Read it beside each build's spread
against itself, which `batch.sh` gives.

## batch.sh

**What it shows.** A list of timed cells, run detached, each judged quiet or busy. Each cell is
three calls of its timer: the two builds against each other, and each against itself, which
gives the spread a difference has to exceed.

**How it is called.**

```sh
batch.sh <jobs file> <out dir>
```

Each line of the jobs file is one cell, and `#` starts a comment:

```
<label>|<p5time|p5rep>|<key A>|<key B>|<folder>|<on|off>|<case or ->|<pairs>
```

| Variable | What it names |
| --- | --- |
| `P5_BUILD_<KEY>` | the DOSBox-X executable a key of the jobs file names: `BASE` is `P5_BUILD_BASE` |
| `P5_SCRIPTS` | the folder the timers, `loadwatch.sh` and `judge.py` are run from, by default this one: the seam of `batch.test.sh` |

- The synthetic folders are made once, before anything is timed.
- `loadwatch.sh` samples the host every ten seconds throughout. After a cell's three calls,
  `judge.py` says whether it ran on a quiet host.
- A BUSY cell is run again, whole, until the host has been busy for an hour. A cell with no
  timed line is not judged, and the batch goes on.

**What it prints.** Nothing on the terminal but a refusal. `<out dir>` gets `batch.log`, `load.txt`,
`pids.txt`, `jobs.txt`, and `<label>/try<n>/` for each cell and try.

- `<label>/try<n>/` holds each call's output, its runs' files and `judge.txt`.
- `jobs.txt` is the jobs file, which `analyze.py` reads.

**Exit codes.** `0` every cell ran quiet, `2` usage or a key no build is named for, `3` a timer
call was INVALID, a cell held no timed line or a folder could not be made, `4` BUSY: the host
was not quiet for over an hour.

**What it does not show.** It ranks nothing: `analyze.py` makes the tables.

## loadwatch.sh

**What it shows.** Nothing by itself: it samples the host while `batch.sh` runs. It reads
macOS's `top` and `sysctl`.

**How it is called.**

```sh
loadwatch.sh <out file> <seconds>
```

**What it prints.** Every `<seconds>` it appends to `<out file>` the load average, the CPU's
user, system and idle shares, and the ten processes using the most CPU. They come from `top`'s
second sample, because the first has no interval to measure a share over.

```
load|<epoch>|<1 5 15 min>
cpu|<epoch>|<user>|<sys>|<idle>
top|<epoch>|<pid>|<ppid>|<cpu %>|<command>
```

**Exit codes.** `2` usage. Otherwise it runs until it is killed.

**What it does not show.** Only the ten busiest processes are named. A burst of short
processes shows only in the idle share.

## judge.py

**What it shows.** Whether one cell of `batch.sh` ran on a quiet host, from the samples
`loadwatch.sh` took in the cell's window. Either of its two rules makes the cell BUSY.

- A process outside the run used 80 % of a core or more in two consecutive samples: a core
  taken. One sample alone is a spike, named and let pass.
- The run's emulators are known by the pids the timers recorded.
- Any sample of the cell's window had under 10 % of the whole CPU idle: a burst of short
  processes that no list of processes shows.

**How it is called.**

```sh
python3 -I judge.py <load.txt> <cell try dir>
```

**What it prints.** `QUIET` or `BUSY`, then the samples, the lowest and mean idle share, and
the spikes. A BUSY cell also has `sustained=`, naming what made it so.

**Exit codes.** `0` judged, `2` usage, `3` INVALID: the cell holds no timed line. A cell with
no sample of the host in its window is BUSY.

**What it does not show.** It judges the host, never the builds.

## analyze.py

**What it shows.** The tables of the timers' batch, from the out dirs `batch.sh` left.

**How it is called.** Each `<raw dir>/<batch>` is an out dir of `batch.sh`.

```sh
python3 -I analyze.py <raw dir> <batch>...
```

**What it prints.** A table, one row per cell, from its last try:

- each build's median, with its fastest and slowest, and the factor between the two;
- each build's spread against itself, and the gap between the two arms of that A/A call;
- the verdict, the runs per build, and the tries.

Then it lists the runs whose window holds a host sample under 10 % idle.

- The verdict is `ranked` when the difference of the medians exceeds both builds' spread
  against themselves. It is `within noise` otherwise.

**Exit codes.** `0` the tables, `2` usage, `3` INVALID: an argument is not an out dir of
`batch.sh`, a cell has no try or misses a call, or no cell was found.

**What it does not show.** Only the last try of each cell is read.

## battery.sh

**What it shows.** All of it on two or three builds, one line per cell. So a change is read
as two lists of lines: what a build answers, beside what the build it started from answers.

It judges nothing. Each line is one script's own verdict and what it counted.

**How it is called.**

```sh
battery.sh [--real-dos] [--raw <directory>] [--only <group>]... <base> <build> [<third build>]
```

| Argument | What it is |
| --- | --- |
| `<base>` | the DOSBox-X executable `<build>` is compared with |
| `<build>` | the one under test |
| `<third build>` | another one `<build>` is compared with as well, and measured beside the two: what a branch stacked on another needs |
| `--real-dos` | adds the cells on the three real DOS, with `<build>` as the machine |
| `--raw <directory>` | keeps there what every script printed, one file per call, and `schedule.txt`; the directory is empty or absent |
| `--only <group>` | runs one group of cells and prints every other cell as `not run`; given again, one more group |

The groups are `selftest`, `answers`, `folders`, `gone`, `dosans`, `overlay`, `attrsem`,
`delete`, `aliases`, `memory`, `realdos` and `reporters`. Its `--help` names the cells of each.

Beyond what the scripts need, it takes these from the environment:

| Variable | What it names |
| --- | --- |
| `DIRCACHE_REAL_FOLDER` | the large host folder of the cells named `real`: a name with no space that fits 8.3 |
| `DIRCACHE_REAL_FILE` | a file of it, as the guest names it |
| `DIRCACHE_REGRESSION` | the folder holding `FINDTEST.EXE` and `LFNTEST.EXE` |
| `DIRCACHE_BOOT_MSDOS710`, `DIRCACHE_BOOT_MSDOS622`, `DIRCACHE_BOOT_FREEDOS` | with `--real-dos`, the disk image of each DOS `realdos.sh` boots: all three are needed |
| `DIRCACHE_JUNKTEST` | the reporter's files of `junktest.sh`, unpacked |
| `DIRCACHE_DIRTEST` | the reporter's files of `dirtest.sh`, unpacked |
| `XDG_STATE_HOME` | where the lock is kept, in `dosbox-x-dircache/` under it; by default `~/.local/state` |
| `DIRCACHE_SCRIPTS` | the folder the scripts are run from, by default this one: the seam of `battery.test.sh` |
| `DIRCACHE_MEMORY_KB` | the host's memory in kB, by default what the host says: a seam of `battery.test.sh` |

- The cells of the reporters' files come last. Without their variable, each prints one `not
  run` cell that says so.
- `attrcost.sh`, `resprb.sh` and the timers run by their tests only. Their own figures are
  read on their own.

**What it prints.** The builds with their sha256, how many calls run at once and in how much
memory, then one line per cell. A last line says how many cells it printed, how many INVALID
and how many not run.

```
cell|<name>|<long names: on, off or ->|<verdict>|<figures>
```

- The name says the script, what it ran on, and which build. It ends in `base:build` or
  `third:build` for a script that compares two builds, and in `base`, `build` or `third` for
  one that measures a single build.
- The verdict is the script's: `IDENTICAL` or `ALIKE`, `DIFFERENT`, `ran` for a script that
  compares nothing, `INVALID`, and `not run` where the host cannot run the cell.
- The figures are what the script counted: the table below names them. For `INVALID` and
  `not run` they say why.
- With `--raw`, the lines that differ are in the kept files, and the directory an INVALID run
  kept is named there.
- A kept file is named by its call: the cell's name and its long-name field. The cell `memory
  synthetic:50000:83 *.* d 20 base` with `off` is `memory_synthetic-50000-83_@.@_d_20_base_off.txt`.
- `schedule.txt` says when each call started and ended, in which lane, and beside how many
  others.

Two runs on the same builds print the same lines apart from the memory figures. To compare
two outputs:

```sh
sed -E 's/((held|peak)_[a-z]+_kb)=[0-9]+/\1=N/' <output>
```

**Exit codes.** `0` every cell ran, `2` usage, `3` at least one cell is INVALID or `--only`
left cells out. What the scripts printed is then kept and named, unless `--raw` already keeps
it.

- A run with `--only` exits `3`, as every incomplete battery does. It is what a change is
  checked with while it is made, and the whole battery is what closes it.

**What it does not show.**

- A `DIFFERENT`, a failed test or a memory figure that grew is for the reader. Read `memory`
  cells two at a time, the same call at its two counts.
- On Windows the scripts' own tests and the cells of `--real-dos` print `not run`. The first
  play captured runs through the macOS launcher; the second boot an image that stays on one
  host.
- A Windows run is read beside the lines a macOS run printed for them.
- Where the host's file system names the aliases, the cells that show an alias are that file
  system's: `run` on long names and `enumstat` on long names. `ties` is INVALID where no two
  entries share a name.
- `--real-dos` condenses each report of a real DOS to its counts and a digest. Which lines of
  a build's report differ from it is read from the two reports, under `--raw`.
- The memory each cell is planned for is what a macOS run recorded, on Windows too. There,
  what bounds a cell that holds more is the limit past which `memory.sh` kills a run.

### How the calls run

The lines come out in one fixed order whatever order the calls ran in: the battery first runs
every call, then reads what each printed. Two lanes run at once.

- The scripts' tests and the answers run one after another.
- The memory cells, the reporters' runs and the arms of the real DOS run several at a time,
  within half the host's cores and half its memory. The real DOS's arms start first, being the
  longest runs and holding no folder.
- A memory cell counts for the most memory its recording in `fixtures/battery` shows on any
  build, so a build is planned for as the unpatched base's worst.
- A cell that needs over half of that memory runs with no other memory cell beside it. A cell
  nobody has recorded counts for all of it.

A cell is a footprint read from outside the emulator, not a time: a neighbour slows a run, it
does not change what the run holds. The resident sizes, `peak_rss_kb`, are the exception.

- The system compresses memory nobody touches, and it compresses more when the host is full.
  So a peak is read with the host's load in mind; the footprint counts compressed memory too.
- A run that holds a `memory`, `realdos` or `reporters` group first takes a lock: a directory
  in `dosbox-x-dircache/` under `XDG_STATE_HOME` that holds its pid.
- A second such run on the host waits for the first to end, because two at once can exhaust
  the host's memory. A lock whose pid is gone was left by a battery that did not end cleanly,
  and is taken.

### The cells

The cells are printed in this order. `<who>` is `base`, `build` or `third`; `<pair>` is
`base:build` or `third:build`.

A cell whose third field is `-` has no long-name mode. The others are run with long names on,
off, or both, as the field says.

| Cell | What it runs | Its figures |
| --- | --- | --- |
| `selftest <name>.test.sh` | that script's own tests, no emulator | `cases=`, `failed=` |
| `run <folder> <pair>` | `run.sh` on a synthetic folder at each size in the styles `83` and `long`, then on the large real folder (`real`), then on a folder of each of the styles `dots`, `mix` and `wine` | `entries=`, `4e=`, `lfn=`, `look=`, `differing_lines=` |
| `memory <folder> <mode> <calls> <who>` | `memory.sh`, the mode's call made that many times, on the folders listed below | `entries=`, `ok=`, `slots_full=`, `held_footprint_kb=` or `held_private_kb=` |
| `fc <files> <runs> <who>` | `fc.sh` in a folder of that many files, FC run that many times | `entries=`, `compared=`, `slots_full=`, `peak_rss_kb=` or `peak_ws_kb=`, the held figure |
| `findlife <pair>` | `findlife.sh` | `cases=`, `ok=`, `differs=`, `not judged`, `differ=` |
| `exact <pair>` | `exact.sh` | one figure per section, `differ=` |
| `drift <pair>` | `drift.sh` | `cases=`, `sha256=`, `differ=` |
| `dirgone <pair>` | `dirgone.sh` | `cases=`, `sha256=`, `differ=` |
| `lfnren <pair>` | `lfnren.sh`, long names on | `lines=`, `sha256=`, `differ=` |
| `dtadump <pair>` | `dtadump.sh` | `template=`, `untouched=`, `resumed=`, `fcb=`, `differing_lines=` |
| `patlist <pair>` | `patlist.sh` | `patterns=`, `sha256=`, `differ=` |
| `template <fat or host> <pair>` | `template.sh` on a FAT image, then on a host folder | `lines=`, `sha256=`, `differing_lines=` |
| `findpos <labelled or unlabelled> <pair>` | `findpos.sh` on a drive with a label, then with none | `cases=`, `sha256=`, `differ=` |
| `dosans <labelled or unlabelled> <pair>` | `dosans.sh` | `lines=`, `sha256=`, `differing_lines=` |
| `overlay <labelled or unlabelled> <who>` | `overlay.sh` on one build, long names on and off | `label=`, `next=`, `dots=`, `other_lines=` |
| `attrprobe <pair>` | `attrprobe.sh` | `cases=`, `sha256=`, `differ=` |
| `attrsem <pair>` | `attrsem.sh` | `lines=`, `shell=`, `sha256=`, `differ=` |
| `sidefx <rescan or label> <pair>` | `sidefx.sh`, long names off; `label` on Windows only | `lines=`, `sha256=`, `differ=` |
| `delete <pair>` | `delete.sh` | `lines=`, `sha256=`, the files and directories each build left, `differ=` |
| `ties <pair>` | `ties.sh` | `ties=`, `differ=` |
| `aliases cases <who>` | `aliases.sh cases` on one build, long names on and off | the figures of `aliases.sh` |
| `aliases real <who>` | `aliases.sh folder on` on the large real folder, one build | `entries=`, `host=`, `names_shared=`, `entries_sharing=`, `matched=`, `listed_with_another_size=` |
| `enumstat <mode> <names> <who>` | one row of `enumstat.sh` | `listed=`, `looked_up_ok=`, `last=`, `slots_full=`, `out_of_range=` |
| `xcopy <who>` | `xcopy.sh` | `made=`, `dirs_made=`, `copied=`, `dirs_copied=`, `said=`, `slots_full=`, `out_of_range=` |
| `xcomsim <own or relayed> <pair>` | `xcomsim.sh`, the listing through its own DTAs, then with `--relay` | for each build, A then B: `listing=`, `slots_full=`, `out_of_range=` |
| `passfail <program> <folder> <who>` | `passfail.sh` with each regression program in a small and in a large folder | `sha256=`, `entries=`, `pass=`, `fail=`, `exit=` |
| `unit <who>` | `unit.sh` | `tests=`, `failures=`, `errors=`, `disabled=` |
| `realdos <dos> <program>` | with `--real-dos`, `realdos.sh` on each of `msdos710`, `msdos622` and `freedos`, with `<build>` as the machine | `dos=`, the counts the build's own cell carries, `sha256=` |
| `junktest <batch files> <who>` | `junktest.sh` with the reporter's run and its first steps | `entries=`, `junk=`, `counted=`, `done=`, `slots_full=`, `out_of_range=`, the peak, the held figure |
| `dirtest <who>` | `dirtest.sh` | `files=`, `calls_4f=`, `calls_4e=`, `slots_full=`, `out_of_range=`, the peak, the held figure |

What each figure counts:

| Figure | What it counts |
| --- | --- |
| `cases=` | the tests of a `selftest` that ran; elsewhere, the cases of a report |
| `failed=` | the tests that failed |
| `entries=` | the files on the host |
| `4e=`, `lfn=` | for each build, the entries of the two enumerations |
| `look=` | for each build, the lookups |
| `differing_lines=` | the lines that differ, when the dumps or the reports differ |
| `ok=` | in `memory`, the calls that reached the file; in `findlife`, the cases that read `ok` |
| `differs=`, `not judged` | for each build, the cases that read `DIFFERS` and `not judged` |
| `differ=` | the cases whose lines differ between the two builds |
| `slots_full=` | how many times the emulator logged its search table full |
| `out_of_range=` | how many times the emulator logged a slot number out of range |
| `held_footprint_kb=`, `held_private_kb=` | the memory figure the host reads once the calls or the runs are over |
| `peak_rss_kb=`, `peak_ws_kb=` | the peak while FC, the reporter's batch files or the reporter's program ran |
| `compared=` | the runs that said the files do not differ |
| `<name>=ALIKE:<lines>` | a section of `exact` that is alike |
| `<name>=DIFFERENT:<lines of A>/<lines of B>` | a section of `exact` that differs |
| `sha256=` | the start of a report's digest, A then B; in `passfail`, of the program |
| `template=`, `untouched=`, `resumed=`, `fcb=` | the figures of `dtadump.sh`: its entry says what each counts |
| `patterns=`, `lines=` | the patterns or the lines of a report |
| `ties=` | the pairs of entries that share a short name |
| `listed=` | the entries the listing returned |
| `looked_up_ok=` | the lookups that found their entry |
| `last=` | the last name listed |
| `made=`, `dirs_made=` | the files and folders of the tree |
| `copied=`, `dirs_copied=` | those that arrived |
| `said=` | XCOPY's own count |
| `pass=`, `fail=`, `exit=` | the lines that end in `PASS` and in `FAIL`, and the program's exit code |
| `tests=`, `failures=`, `errors=`, `disabled=` | the unit tests that ran, failed, erred and are disabled |
| `dos=` | the version that DOS reports |
| `label=` | in `overlay`, whether the overlay's label lines are the host folder's: `ALIKE` or `DIFFERENT` |
| `next=` | in `overlay`, `18` when a FindNext after the label alone finds nothing, as DOS, `other` when it goes on |
| `dots=` | in `overlay`, `none` or `listed`: the root's dot entries |
| `other_lines=` | in `overlay`, the lines that differ and are not judged |
| `listing=` | in `xcomsim`, the guest's verdict: each listing's found and expected entries, and how many were lost |
| `shell=` | in `attrsem`, the shell's lines after ATTRSEM's |
| `entries_sharing=`, `matched=` | the figures of `aliases.sh folder`: its entry says what each counts |
| `junk=` | the folder's `.TMP` files at the end |
| `counted=`, `done=` | the lines `300.BAT` counted its runs with, and the batch files that ended |
| `files=` | the files in the reporter's `DATA` |
| `calls_4f=`, `calls_4e=` | the program's find calls |
| `returned=` | in `realdos dirtest`, whether the program returned |

The `memory` cells run on these folders:

- on the large synthetic folder and on the real one, the modes that open or look up one file;
- on a folder of 8.3 names with long names off: a search left open (`d`), the same search
  with `*.*`, which the cell's name then carries, and a search still open when its process
  ends (`c`);
- on a small folder, calls enough to go round the search table many times over: `a`, and `v`
  for the volume label;
- a lookup of each file of a folder in turn (`e`).

How to read some figures:

- In `drift`, a build whose report is the one a real DOS gives shows in the line: the two
  digests are equal.
- In `dtadump`, where the figures equal those of a real DOS, the build leaves in a DTA what
  that DOS leaves.
- A `realdos` digest is taken with the DOS's name off its lines. So two DOS, or a DOS and a
  build, can be told equal from the line.
- `realdos <dos> enumstat <mode> <names>` is one row.
- `realdos <dos> memprobe`, `fc`, `xcopy`, `xcomsim` and `xcomsim-relay` carry the counts of
  their one line and no digest.
- `realdos <dos> junktest` and `dirtest` do the same. They run last, and only where the
  reporters' files are named.
- In `delete`, the files and directories each build left read `A(S=<n> ...)` for one build
  and `B(...)` for the other. `differ=` names each step whose lines differ as `<kind>:<step>`.

### The lines to expect

The lines of one whole run are kept with the tests, under `fixtures/battery`.

- It is that run as `--raw` keeps it, with `--real-dos` and the reporters' files named:
  unpatched upstream as base, and a patched build.
- Each call has one file, named by the call: its exit code and arguments on the first line,
  and what the script printed below.
- A cell added on two branches of these instruments adds a file of its own name on each, so
  the two merge without renaming the others.
- The calls added after that run were recorded on their own, with the builds they need. The
  header of `battery.test.sh` names each.
- `battery.test.sh` plays it back and names, case by case, the line each kind of cell must
  print from it.
- The other fixtures hold, in the same way, what one run of each script left. Each
  `<name>.test.sh` names the lines that script must print from them.

## launch.sh

**What it shows.** Nothing by itself: it is the launcher the scripts call on macOS. It boots
one build on a conf with SDL's dummy video driver, so no window opens.

**How it is called.**

```sh
launch.sh --conf <file> --binary <build> --seconds <n> --output <file> --log <file> --report <file> [-- <argument for the emulator>...]
```

| Option | What it names |
| --- | --- |
| `--conf <file>` | the DOSBox-X conf the run boots |
| `--binary <build>` | the DOSBox-X executable |
| `--seconds <n>` | the bound: the run is ended after that long |
| `--output <file>` | the file the run must leave: the guest's, through a mounted folder |
| `--log <file>` | where the emulator writes its log; its stderr goes to `<file>.err` |
| `--report <file>` | where the report goes |

**What it prints.** A report file with the build's version line and the exit code.

**Exit codes.** `0` the emulator ran and the run left its output, the emulator's own code
when it failed, `2` usage, `3` INVALID: the output is absent, empty or was not written by this run, or the
log is empty.

**What it does not show.** A run that reaches its bound is not a failure by that alone: what
it left decides.

## windows.ps1

**What it shows.** Nothing by itself: it is the launcher the scripts call on Windows. It boots
the run's conf headless and bounded on one build, and reads the emulator's memory from outside.

**How it is called.**

```sh
powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File windows.ps1 -Build <dosbox-x.exe> -Run <directory holding run.conf> -Output <file the guest leaves there> -Seconds <bound> [-Held <file> -Go <file> -LimitKb <working set limit>] [-UnitTests]
```

- With `-Held` and `-Go`, a guest that creates `<Run>\<Held>` is read at that moment, and let
  go by creating `<Run>\<Go>`. It is the handshake MEMPROBE waits on.
- What is read is the working set and the private bytes.
- With `-UnitTests` the build runs its own unit tests instead of a guest, and writes their
  result to `<Run>\<Output>`.

**What it prints.** A report file, `<Run>\report.txt`.

**Exit codes.** `0` the emulator exited 0 and the guest left its output, `2` bad usage, `3`
INVALID: the emulator failed, was cut off at the bound or the limit, left no output, or its
log names no build.

**What it does not show.** It never exits `1`: an unforeseen error is no verdict about a
build.

## The tests of the scripts themselves

Each script has a `<name>.test.sh` beside it that proves its verdicts without an emulator:
green, different, INVALID and bad usage, on the inputs that produce each.

```sh
bash <name>.test.sh
```

- `fixtures/stub-launcher.sh` stands in for the launcher and plays what real runs left, kept
  under `fixtures/`. Its header says how they were captured.
- `launch.test.sh` tests the launcher itself, against `fixtures/stub-emulator.sh`, which
  stands in for a build.
- `battery.test.sh` plays one level up. `fixtures/stub-script.sh` stands in for every script
  and plays what each printed in one real run of the battery.
- `fixtures/stub-powershell.sh` stands in for PowerShell running `windows.ps1`, for the cases
  of `dirtest.test.sh` that play a Windows run.
- `batch.test.sh` plays the timers, the sampler and the judge through stand-ins of its own.
  `judge.test.sh` plays one cell of a real batch and the host's samples around it.
- `battery.sh` runs them as its first cells, all but its own and `launch.test.sh`.
- They play through the macOS launcher, so they run on macOS only. `memory.test.sh` and the
  tests of the other scripts that read memory also need its `ps` and `footprint`.
- `batch.test.sh` and `judge.test.sh` run `judge.py` and `analyze.py` with `python3 -I`.
