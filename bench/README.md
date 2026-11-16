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
| [`drift.sh`](#driftsh) | `drift.c` | whether two builds answer alike when a FindNext brings another pattern than its FindFirst had |
| [`findpos.sh`](#findpossh) | `findpos.c` | whether two builds keep the place of a search where a program can move it, and leave the same behind after a search for the volume label alone |
| [`dtadump.sh`](#dtadumpsh) | `dtadump.c` | whether two builds leave the same bytes in a DTA and in an FCB around the find calls |
| [`patlist.sh`](#patlistsh) | `patlist.c` | whether two builds return the same entries for patterns that hold a `*` before more characters |
| [`template.sh`](#templatesh) | `template.c` | whether two builds answer alike where the answer hangs on how the search template is padded |
| [`unit.sh`](#unitsh) | none: the emulator's own unit tests | how many of a build's unit tests ran and failed |
| [`passfail.sh`](#passfailsh) | a program you hand it | how many checks of a self-testing DOS program pass on a build |
| [`realdos.sh`](#realdossh) | `dosid.c` and one of the programs above | what the DOS of a disk image answers to the same programs, the emulator being only the machine |
| [`battery.sh`](#batterysh) | every one above | all of it on two or three builds, one line per cell |
| [`launch.sh`](#launchsh) | none | nothing by itself: it is the launcher the scripts call on macOS |
| [`windows.ps1`](#windowsps1) | none | nothing by itself: it is the launcher the scripts call on Windows |

Every script prints its arguments, what it prints and its exit codes with `--help`.

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
- The two launchers have codes of their own: their entries list them.

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
- `realdos.sh` needs a hard disk image whose DOS it can boot, and `passfail.sh` a program to
  run. Neither is kept here: their entries say what each must be.
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

`run.sh`, `memory.sh` and `passfail.sh` take a folder of yours or make one for the run.

| Form | The folder |
| --- | --- |
| a host directory | mounted read-only and reached through its parent |
| `synthetic:<count>:83` | `<count>` empty files with plain names, such as `F0000000.TXT` |
| `synthetic:<count>:long` | `<count>` empty files with long names: `Alpha track 000000.mid` and seven other words |

- The long names collide in their first six letters, so the emulator has to number their 8.3
  aliases.
- A host directory's name goes on a DOS command line: no spaces, and an 8.3 name when long
  names are off.

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
| `untouched=<n>/<m>` | of the calls that must leave a DTA alone, how many left its 43 bytes unchanged |
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

## realdos.sh

**What it shows.** What the DOS of a disk image answers to the same programs. What a search
ought to answer is decided by a DOS, and the emulator's own DOS is the thing under test.

- The image is a hard disk whose first partition starts MS-DOS 7, as the system disk of a
  Windows 98 does. It is not kept here and is never written: each run boots a copy.
- The emulator is only the PC. Once the image boots, its DOS, its shell and its host-folder
  drives are gone.
- Every INT 21h call is answered by the image's kernel over a FAT volume.

**How it is called.**

```sh
realdos.sh <build> <boot image> <program>
```

| `<program>` | What runs on the image's DOS |
| --- | --- |
| `id` | which DOS answers, and nothing else |
| `findlife` | FINDLIFE over the two folders `findlife.sh` makes |
| `exact` | EXACT over the folder `exact.sh` makes |
| `enumstat` | ENUMSTAT in its modes `s`, `x` and `n` over 3,000 files with 8.3 names |
| `drift`, `dtadump`, `patlist` | that program over the folder `exact.sh` makes |
| `template` | TEMPLATE over the files `template.sh` makes, in the root of the run's disk, which is then labelled `DISK1` |
| `findpos` | FINDPOS over the folder `exact.sh` makes, on the run's disk as it is made: with no label |
| `findpos-labelled` | the same once the image's own `LABEL` has named the disk `FPLABEL` |
| `memprobe` | MEMPROBE in its mode `e` over 1,835 files with 8.3 names |
| `fc` | the emulator's `FC.EXE` run 300 times from a batch file, as `fc.sh` runs it, in a folder of 700 files |
| `xcopy` | the emulator's `XCOPY.EXE` over the tree `xcopy.sh` makes |

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
the program's report whole.

- Whose DOS answered is its own `VER` line and what `DOSID.EXE` read: the version, where the
  INT 21h vector points, whether the long-name calls answer, whether a Windows is running,
  and whether the emulator's `Z:` drive exists.
- For `enumstat` the report is one line per mode. For `dtadump` the figures `dtadump.sh`
  prints come first.
- For `memprobe` it is the guest's line. For `fc` it is how many runs said the two files do
  not differ.
- For `xcopy` it is how many files and folders the tree holds, how many of each that DOS's
  own `DIR` lists under the copy, and the count XCOPY printed.

**Exit codes.** `0` the report is the image's DOS's, `2` usage, `3` INVALID.

- A run answered from the emulator's ROM segment, or one that has `Z:`, is INVALID.
- So is one whose folders did not reach the disk whole, whose image did not boot, whose batch
  did not reach its last line, or whose report is cut short.
- With `findpos-labelled`, a run whose DOS does not return that label is INVALID.

**What it does not show.**

- Long names off only. MS-DOS 7 without its Windows has no long-name calls (714Eh answers
  7100h), so the cases that need them read `not judged` or do nothing.
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
- `memprobe`, `fc` and `xcopy` say what that DOS answers, not what it holds: there is no
  memory to read.
- The FC and the XCOPY are the emulator's, run by the image's DOS, so the two DOSes are asked
  by one program. What the copy left is listed by that DOS's own `DIR`.
- It has been run on macOS only. The copy of the image is a clone where the file system has
  them and a whole copy elsewhere.

## battery.sh

**What it shows.** All of it on two or three builds, one line per cell. So a change is read
as two lists of lines: what a build answers, beside what the build it started from answers.

It judges nothing. Each line is one script's own verdict and what it counted.

**How it is called.**

```sh
battery.sh [--real-dos] [--raw <directory>] <base> <build> [<third build>]
```

| Argument | What it is |
| --- | --- |
| `<base>` | the DOSBox-X executable `<build>` is compared with |
| `<build>` | the one under test |
| `<third build>` | another one `<build>` is compared with as well, and measured beside the two: what a branch stacked on another needs |
| `--real-dos` | adds the cells on the DOS of a disk image, with `<build>` as the machine |
| `--raw <directory>` | keeps there what every script printed, one file per call; the directory is empty or absent |

Beyond what the scripts need, it takes these from the environment:

| Variable | What it names |
| --- | --- |
| `DIRCACHE_REAL_FOLDER` | the large host folder of the cells named `real`: a name with no space that fits 8.3 |
| `DIRCACHE_REAL_FILE` | a file of it, as the guest names it |
| `DIRCACHE_REGRESSION` | the folder holding `FINDTEST.EXE` and `LFNTEST.EXE` |
| `DIRCACHE_BOOT_IMAGE` | with `--real-dos`, the disk image `realdos.sh` boots |
| `DIRCACHE_SCRIPTS` | the folder the scripts are run from, by default this one: the seam of `battery.test.sh` |

**What it prints.** The builds with their sha256, one line per cell, and a last line with how
many cells it printed, how many INVALID and how many not run.

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

Two runs on the same builds print the same lines apart from the memory figures. To compare
two outputs:

```sh
sed -E 's/((held|peak)_[a-z]+_kb)=[0-9]+/\1=N/' <output>
```

**Exit codes.** `0` every cell ran, `2` usage, `3` at least one cell is INVALID. What the
scripts printed is then kept and named, unless `--raw` already keeps it.

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
- `--real-dos` condenses each report of the image's DOS to its counts and a digest. Which
  lines of a build's report differ from it is read from the two reports, under `--raw`.

### The cells

The cells are printed in this order. `<who>` is `base`, `build` or `third`; `<pair>` is
`base:build` or `third:build`.

A cell whose third field is `-` has no long-name mode. The others are run with long names on,
off, or both, as the field says.

| Cell | What it runs | Its figures |
| --- | --- | --- |
| `selftest <name>.test.sh` | that script's own tests, no emulator | `cases=`, `failed=` |
| `run <folder> <pair>` | `run.sh` on a synthetic folder at each size and in each name style, then on the large real folder (`real`) | `entries=`, `4e=`, `lfn=`, `look=`, `differing_lines=` |
| `memory <folder> <mode> <calls> <who>` | `memory.sh`, the mode's call made that many times, on the folders listed below | `entries=`, `ok=`, `slots_full=`, `held_footprint_kb=` or `held_private_kb=` |
| `fc <files> <runs> <who>` | `fc.sh` in a folder of that many files, FC run that many times | `entries=`, `compared=`, `slots_full=`, `peak_rss_kb=` or `peak_ws_kb=`, the held figure |
| `findlife <pair>` | `findlife.sh` | `cases=`, `ok=`, `differs=`, `not judged`, `differ=` |
| `exact <pair>` | `exact.sh` | one figure per section, `differ=` |
| `drift <pair>` | `drift.sh` | `cases=`, `sha256=`, `differ=` |
| `dtadump <pair>` | `dtadump.sh` | `template=`, `untouched=`, `resumed=`, `fcb=`, `differing_lines=` |
| `patlist <pair>` | `patlist.sh` | `patterns=`, `sha256=`, `differ=` |
| `template <fat or host> <pair>` | `template.sh` on a FAT image, then on a host folder | `lines=`, `sha256=`, `differing_lines=` |
| `findpos <labelled or unlabelled> <pair>` | `findpos.sh` on a drive with a label, then with none | `cases=`, `sha256=`, `differ=` |
| `ties <pair>` | `ties.sh` | `ties=`, `differ=` |
| `enumstat <mode> <names> <who>` | one row of `enumstat.sh` | `listed=`, `looked_up_ok=`, `last=`, `slots_full=`, `out_of_range=` |
| `xcopy <who>` | `xcopy.sh` | `made=`, `dirs_made=`, `copied=`, `dirs_copied=`, `said=`, `slots_full=`, `out_of_range=` |
| `passfail <program> <folder> <who>` | `passfail.sh` with each regression program in a small and in a large folder | `sha256=`, `entries=`, `pass=`, `fail=`, `exit=` |
| `unit <who>` | `unit.sh` | `tests=`, `failures=`, `errors=`, `disabled=` |
| `realdos <program>` | with `--real-dos`, `realdos.sh` with `<build>` as the machine | `dos=`, the counts the build's own cell carries, `sha256=` |

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
| `peak_rss_kb=`, `peak_ws_kb=` | the peak while FC ran |
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
| `dos=` | the version of the DOS that answered |

The `memory` cells run on these folders:

- on the large synthetic folder and on the real one, the modes that open or look up one file;
- on a folder of 8.3 names with long names off: a search left open (`d`), the same search
  with `*.*`, which the cell's name then carries, and a search still open when its process
  ends (`c`);
- on a small folder, calls enough to go round the search table many times over: `a`, and `v`
  for the volume label;
- a lookup of each file of a folder in turn (`e`).

How to read some figures:

- In `drift`, a build whose report is the one the image's DOS gives shows in the line: the
  two digests are equal.
- In `dtadump`, where the figures equal those of the image's DOS, the build leaves in a DTA
  what that DOS leaves.
- `realdos enumstat <mode> <names>` is one row.
- `realdos memprobe`, `realdos fc` and `realdos xcopy` carry the counts of their one line and
  no digest.

### The lines to expect

The lines of one whole run are kept with the tests, under `fixtures/battery`.

- It is that run as `--raw` keeps it, with `--real-dos`: unpatched upstream as base, and a
  patched build.
- Each call has one file: its exit code and arguments on the first line, and what the script
  printed below.
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

**Exit codes.** `0` the emulator ran and the run left its output, `1` the emulator failed,
`2` usage, `3` INVALID: the output is absent, empty or was not written by this run, or the
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
- `battery.sh` runs them as its first cells, all but its own.
- They play through the macOS launcher, so they run on macOS only. `memory.test.sh` also
  needs its `ps` and `footprint`.
