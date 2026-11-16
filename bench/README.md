# Instruments for DOSBox-X's directory cache

This folder holds the checks a change to how DOSBox-X lists a host folder
(`src/dos/drive_cache.cpp` and the search calls around it) has to pass: what two builds list,
what a search costs the emulator in memory, and what a program sees when it does anything but run
one search to its end. Each check is a host script and the DOS program it runs in the guest.

| script | guest program | it tells you |
| --- | --- | --- |
| `run.sh` | `listdump.c` | whether two builds list one folder byte for byte the same |
| `memory.sh` | `memprobe.c` | how much host memory a build keeps after a DOS program repeats one file call |
| `fc.sh` | the emulator's own `FC.EXE`, then `memprobe.c` to hold | how much host memory a build takes while a batch file runs FC again and again in a folder of files, and keeps after |
| `findlife.sh` | `findlife.c` | whether two builds answer alike when a search is interrupted, shared or outlived |
| `exact.sh` | `exact.c`, `SHELLT.BAT` | whether two builds answer alike to searches for one exact name |
| `drift.sh` | `drift.c` | whether two builds answer alike when a FindNext brings another pattern than its FindFirst had |
| `dtadump.sh` | `dtadump.c` | whether two builds leave the same bytes in a DTA and in an FCB around the find calls |
| `patlist.sh` | `patlist.c` | whether two builds return the same entries for patterns that hold a `*` before more characters |
| `template.sh` | `template.c` | whether two builds answer alike where the answer hangs on how the search template is padded: the label alone, a quoted name that ends in a space, an FCB's name |
| `findpos.sh` | `findpos.c` | whether two builds keep the place of a search where a program can move it, and leave the same behind after a search for the volume label alone |
| `ties.sh` | `ties.c` | whether two builds return two entries that share an 8.3 name in the same order |
| `enumstat.sh` | `enumstat.c` | how many entries a listing returns while every entry is looked up by name |
| `xcopy.sh` | the emulator's own `XCOPY.EXE` | how much of a tree of folders arrives when XCOPY copies it |
| `passfail.sh` | a program you hand it | how many checks of a self-testing DOS program pass on a build |
| `unit.sh` | none: the emulator's own unit tests | how many of a build's unit tests ran and failed |
| `realdos.sh` | `dosid.c` and one of `findlife.c`, `exact.c`, `enumstat.c`, `drift.c`, `dtadump.c`, `patlist.c`, `template.c`, `findpos.c`, `memprobe.c`, or the emulator's `FC.EXE` or `XCOPY.EXE` | what the DOS of a disk image answers to the same programs, the emulator being only the machine |
| `battery.sh` | every one above | all of it on two or three builds, one line per cell |

Every script prints its arguments, what it prints and its exit codes with `--help`. They share
one scheme: 0 the answer (alike, identical, measured), 1 the two builds differ, 2 bad usage,
3 INVALID, which means nothing was judged: the emulator failed or was cut off, the guest left no
output, a report has no trailer or disagrees with its own counts. An INVALID run keeps its
directory and names it.

## What they need

- Two DOSBox-X executables to compare, or one to measure. `unit.sh` needs a build that has the
  debugger: no other carries the unit tests.
- The DJGPP cross compiler (`DJDIR`, default `$HOME/djgpp`): each run builds its guest program
  from the source beside the script, so a run tests the source it sits with. A host with no
  DJGPP takes the guest programs built on another one: `DIRCACHE_PREBUILT` names the folder
  that holds them, as `<NAME>.EXE`.
- On macOS, GNU `timeout` on the `PATH`, under that name or as `gtimeout` (coreutils). The
  launcher is `launch.sh`, beside the scripts: it boots one build on a conf with SDL's dummy
  video driver, ends the run after a bound, and refuses a run whose guest left no output. The
  scripts read the build's version line from its report. `memory.sh` and `fc.sh` read the
  emulator's memory with the system's `ps` and `footprint`.
- On Windows the scripts run under Git Bash and the launcher is `windows.ps1`, beside them.
- `realdos.sh` needs a hard disk image whose DOS it can boot, and `passfail.sh` a program to
  run: neither is kept here. Their sections say what each must be.
- No window opens on either host, and nothing is written outside a directory made for the run
  (under `TMPDIR`).

`common.sh` holds what the scripts share: the arguments, the `<folder>` argument and the
synthetic folders, the conf every run boots, the launcher call and the INVALID exit. A run's
machine is written there once, so that two scripts never measure two machines. Every folder it
mounts gets an empty label unless the script names one: left to itself a Windows build labels a
mounted folder and a macOS build does not, and a search for the label would answer by host.

## The `<folder>` argument

`run.sh`, `memory.sh` and `passfail.sh` take a host directory, mounted read-only and reached
through its parent, or `synthetic:<count>:<83|long>`: a folder of `<count>` empty files made for
the run. `83` names are plain (`F0000000.TXT`); `long` names (`Alpha track 000000.mid` and seven
other words) collide in their first six letters, so the emulator has to number their 8.3 aliases.
A host directory's name goes on a DOS command line: no spaces, and an 8.3 name when long names
are off.

## run.sh: what two builds list

`LISTDUMP.EXE` writes one text file per build: every entry of a full 4Eh/4Fh enumeration
(attribute, time, date, size, 8.3 name), every entry of a full 714Eh/714Fh enumeration closed by
71A1h (attributes, the three times, size, long name, 8.3 alias, the conversion flags), and for
the first, middle and last entry of each, a missing name and the middle name in the other case,
what libc's `access` and `stat` and raw 716Ch and 714Eh answer. The script compares the two
files with `cmp`. The same build twice is the control: it must come out identical.

The two enumerations end with the guest's own count and the last line carries the number of
lookups; the script counts all three itself and refuses a dump that disagrees, that has no last
line, or that lists nothing but `.` and `..`.

Limits:

- Left out on purpose: the search state DOS keeps in the DTA's first 21 bytes, the handle 714Eh
  returns and the record's reserved bytes. They identify a search, not a file.
- Synthetic files are empty, so every size reads 0 and every time is the run's.
- The two builds read the same folder, made once per run: alias numbers depend on the order the
  host returns the files in, which two folders with the same names need not share.
- One search at a time. What happens to several is `findlife.sh`'s.

## memory.sh: what a search costs the emulator

`MEMPROBE.EXE` repeats one call on one file of the folder, then creates a file and waits for the
host to create another: the emulator's memory is read from outside with the calls done and the
DOS program still alive, and no guest clock is trusted for it. Run it at two call counts on one
build and read the difference; a number from one run says little.

The guest's line counts the calls that reached the file, and the script refuses a run where one
did not: a lookup that fails costs the emulator nothing and would read as "no growth".

On a synthetic folder `--file` takes a pattern as well as a name. With `--file '*.*'` mode `d`
repeats a search of the whole folder that is never continued, which is the search DOS has no
call to close: the difference between two call counts is what a build keeps for each one a
program leaves.

Mode `e` is a program that checks, one name after another, that each file of a folder is there:
it lists the folder, then looks each file up by a 4Eh search for its name and never continues
it. Every call names another file, where the other modes repeat one.

Limits:

- On macOS the figures are the resident size and the footprint. The resident size falls when the
  system compresses memory nobody touches, which is what an abandoned search is: read the
  footprint. On Windows they are the working set and the private bytes: read the private bytes.
- The run is killed, and INVALID, past a fixed resident size or working set, so a runaway
  cannot take the machine. A run that only grows in compressed memory is not stopped by it.
- With long names on, libc closes its own search handle when the name has no wildcard: `d` and
  `c` then measure what a build keeps after a search is closed, not what an open one holds.
  With long names off the search stays open, and in `c` it is still open when the child ends.

## fc.sh: a command run again and again in a folder of files

A batch file in the folder runs FC on two small files of it, once per line, the way a suite of
tests compares its results. The FC is the one the emulator carries on its `Z:` drive, started by
the emulator's own shell from inside the folder, so every search made is one a user's batch file
would cause. The emulator's memory is read as `memory.sh` reads it: sampled from outside while
FC runs, which gives the peak, and once more when the runs are over and a program that searches
nothing holds the guest. Read it at two run counts, and beside a run in a folder with no other
file: what the folder's size adds is the subject.

The script counts the runs whose FC said the two files do not differ and refuses a run where one
did not: a batch file that never reached FC would read as "no growth".

Limits:

- The peak is the resident size or the working set, sampled: a rise shorter than the interval
  between two samples is not seen.
- It is the emulator's FC. What another FC asks of the directory is not measured.

## findlife.sh: a search that is not simply run to its end

Each case of `FINDLIFE.EXE` starts a search, does something else in the middle, and asks the
first search to go on: a second search through the same DTA with the first one's bytes saved and
restored, a FindFirst that fails, a child process that ends with searches open or uses its
parent's DTA, the drive unmounted and mounted again, a rescan, the FCB calls, two enumerations at
once through libc, a long-name search asked again after its end or turned away for want of a
handle, the folder listed again after it gained a file, more searches left open than the
emulator has room for, and two searches read turn about, each through its own DTA, while the
program looks a file up by name before every turn. A case reads `ok` when the answer is what a
search whose whole state is its DTA would give, `DIFFERS` when it is not, and `not judged` when
the case could not be set up.
The script compares the two builds' reports line by line.

Limits:

- It judges answers, never memory, and its two folders are small.
- The remount case needs the host's allocator to hand the new drive the address of the old one.
  Where it does not, both builds answer `ok` and the case has shown nothing.
- Some cases mirror the size of the emulator's search table (`SLOTS` in the source). These
  walk it once: `slot-reused-live` prints whether a live search really got the old slot, and
  is not judged when none did; `stale-dta-after-reuse` prints the same fact beside its answer;
  `lfn-next-after-its-end` walks until a search holds the table's first slot, and is not
  judged when none gets it. These make more calls than the table has slots:
  `lfn-first-with-no-handle-left`, and `left-open-past-the-slots` and
  `turn-about-past-the-slots`, which run at the end because the table is full when each ends.
- It searches with wildcards. The one case that looks a file up by its name does so to fill the
  table; what such a search answers is `exact.sh`'s.

## exact.sh, ties.sh, enumstat.sh: searches for one exact name

`exact.sh` runs `EXACT.EXE` and then the shell's own commands (`SHELLT.BAT`) over a small folder
whose names cover the awkward ones: aliases, a real file named like an alias, a space, two dots,
no extension, subdirectories. It compares its sections one by one: `basic` (one search per name, call and
attribute), `life` (exact-name searches saved, nested, abandoned or met by a change of the
folder), `shell`, `tree` (the folder after the shell's commands) and `drift`. `drift` holds the
searches whose FindNext arrives with another pattern than their FindFirst had: the program edits
the DTA, or the emulator itself rewrites it. It is printed and compared, and it does not decide
the exit code, because what such a search answers is not something DOS defines.

`ties.sh` covers the one case where an exact name matches two entries: a long name and a real
file named like the alias the emulator gives it. Which of the two the host returns first decides
whether they tie at all, so the script is INVALID on a host where none do.

`enumstat.sh` lists a folder while looking every entry up by its exact name, the way a program
that shows sizes does, and prints how many entries the listing returned. It compares nothing:
read its rows against the last one, the listing alone.

## xcopy.sh: a tree copied by XCOPY

XCOPY lists a folder and looks every file up by name while the listing is open, then goes down
into the folders it found: searches nested as deep as the tree, with lookups by the thousand
between two entries of each. The script makes a tree with files at more than one level and more
files in all than the emulator's search table has slots, has the emulator's shell copy it with
the XCOPY the emulator carries on its `Z:` drive, and counts on the host how many files and
folders arrived. It compares nothing: read `copied` against `made`. `said` is XCOPY's own count,
which is the count of what it listed, not of what the tree held.

Limits:

- The copy is counted on the host, never by a listing of the guest: the emulator's listing is
  what is under test.
- The tree has 8.3 names only.

## drift.sh: a FindNext that brings another pattern

`exact.sh`'s `drift` section holds the cases the emulator itself produces. `DRIFT.EXE` is the
program's side of it, over the same folder: it starts a 4Eh search for one exact name, rewrites
the eleven pattern bytes of the DTA (to every name, to a wildcard, to another exact name padded
with spaces or with zeros, in small letters or in mixed case, twice), and reads the search to
its end; then the same after the DTA
was saved and restored around another search, beside a second search, after the folder gained or
lost files, and after a search for the volume label alone. It makes no long-name call, so
`realdos.sh` runs it whole. The script compares the two builds' reports line by line.

Limits:

- A search for one exact name only: what an edited whole-folder search answers is not here.
- Three cases create and remove files in the folder, so each build gets its own copy.

## findpos.sh: where a search keeps its place, and the label alone

A DOS keeps the place of a 4Eh search in the 21 bytes of the DTA it reserves for itself, so a
program can move a search: put back the bytes it saved earlier and read the same entries
again, or read two copies of one DTA side by side. `FINDPOS.EXE` does both, over the same
folder as `exact.sh`: a search rewound by its saved DTA, whole or the 21 bytes alone; a copy
read beside the original; a search read on from another address; a DTA put back after its
search ended; an ended DTA asked again beside a search in progress. Then what a search for
the volume label alone leaves behind: the label asked by every name, by a name it does not
have and by its own, each followed by FindNext; the label asked with everything else in the
root; and the label alone asked through the DTA of a search in progress, which is then read
on. The drive is mounted with a label or with none: the two runs differ in the label cases
only. It makes no long-name call, so `realdos.sh` runs it whole, on the disk as it is made
and on the same disk once that DOS has labelled it.

The script compares the two builds' reports line by line.

Limits:

- Searches of the whole folder only. What an edited search of one name answers is
  `drift.sh`'s.
- A label is a directory entry on a FAT disk and a name the mount gives on a host folder: the
  attribute a label search returns, and where the label stands in a listing of the root, are
  read with that in mind.

## dtadump.sh: what a find call leaves in a DTA and in an FCB

A program can read the block a search leaves behind, and the next call reads it too.
`DTADUMP.EXE` prints those bytes, over the same folder as `exact.sh`: the DTA after a 4Eh for
a list of patterns, with and without wildcards; around a 4Fh that finds nothing; before and
after a FindFirst that fails through the DTA of a search in progress, for each reason it can
fail, and before and after a 714Eh made while that DTA is the current one, each followed by the
search read to its end; a plain and an extended FCB before and after 11h and 12h, with the
entry each call leaves in the DTA; and what the FCB calls return when two searches run turn
about, when a 4Eh search runs in the middle, when the FCB is put back as it was before 11h, and
when it is copied and the search goes on from the copy. A dump is printed in groups, so that
the template and the attribute stand apart from the bytes a DOS keeps for itself. Those and
every time and date are printed as dashes: they belong to one DOS and to one run, and without
them two reports can be compared line by line. `realdos.sh` runs it whole; there 714Eh answers
that it does not exist.

The script prints each build's report and these figures of it, then compares the reports:

- `template`: a digest of the template and attribute bytes of every FindFirst dumped. Two
  reports with one digest hold the same bytes there.
- `untouched`: of the calls that must leave a DTA alone, how many left its 43 bytes unchanged.
  The program compares all 43, the dashed ones too.
- `resumed`: of the searches such a call interrupted, how many returned the rest of the folder.
- `fcb`: a digest of what the FCB searches returned.

Limits:

- The bytes a DOS keeps for itself are not compared: whether a search goes on is `resumed`'s.
- The ten bytes at +0Ch of an FCB are printed as they are. They hold a DOS's own numbers, so a
  build's lines there differ from another DOS's even when both keep the search in the FCB.
- The last case removes a file, so each build gets its own copy of the folder.

## patlist.sh: patterns with a `*` before more characters

With long names on DOSBox-X answers 4Eh by a wider rule than MS-DOS does: a `*` followed by
more characters is honoured, and the long name is matched as well as the 8.3 one. `PATLIST.EXE`
lists what a 4Eh search returns for the patterns where that shows, over the same folder as
`exact.sh`. The script compares the two builds' lists; `realdos.sh` gives the list of a DOS
with no long names, which a build answers with long names off.

Limits:

- A search run to its end, never edited: what an edited one answers is `drift.sh`'s.

## template.sh: where the padding of the template decides

A DOS keeps the pattern of a search as eleven bytes, eight of name and three of extension, and
what pads a short field decides a handful of answers. `TEMPLATE.EXE` asks for them on a volume
labelled `DISK1`, made for the run: a 4Eh for the label alone by a list of paths (none, the
label, its beginning, wildcards, another name) and the 4Fh calls after each; the same through
an extended FCB; a 4Eh for names between quotes whose name or extension ends in a space, beside
the same names without it; and the name bytes an FCB holds after 11h. The volume is a FAT16
image the build makes, labels and fills through its own shell, or a host folder mounted with
that label: the two kinds of drive do not answer a label search by the same code. In the report
`V:` stands for the volume's letter. `realdos.sh` runs it whole, on a disk it labels.

On the image the report ends with a line of the shell's own. Its `DIR` takes the drive whose
free space it prints from the block its search ran in, so a `DIR` of the volume while it is
still empty, asked right after a `DIR` of another drive, shows whose drive a search that found
nothing left there.

The script compares the two builds' reports line by line.

Limits:

- On the image the files arrive through the shell's `COPY`: with long names off they are there
  under their 8.3 names, and a build whose shell copies otherwise fills another volume. The
  script checks that the shell copied every file and names the label, nothing more.
- A quoted name is the emulator's own convention: a DOS without long names answers it with an
  error.

## unit.sh: the emulator's own unit tests

DOSBox-X carries unit tests in a build that has its debugger, run with `-tests` before any guest
starts. `unit.sh` runs them headless and prints their counts from the result file the emulator
writes. A failed test is an answer, not an INVALID run: read `failures=` and `errors=`.

## passfail.sh: a program that tests the folder it is started in

The guest changes into the folder on one drive and starts the program from another, so the
program's own file is not in what it lists. The script counts the lines that end in `PASS` and
in `FAIL`, in upper case, and reads the program's exit code. Exit 0 is not a pass: read `fail=`
and `exit=`. A run whose guest did not reach the folder, or whose program printed neither word,
is INVALID.

It is how the two regression programs attached to upstream pull request 6831, `FINDTEST` and
`LFNTEST`, are run. They are not kept here. Build them from their author's sources with Open
Watcom, in a folder that holds the source, with the compiler's folder in `WATCOM`:

```sh
WATCOM=$WATCOM INCLUDE=$WATCOM/h PATH=$WATCOM/<host folder>:$PATH wcl -bt=dos -ms -cc -q FINDTEST.C
```

`-cc` matters where file names keep their case: without it `wcl` hands a source ending in an
upper-case `.C` to the C++ compiler.

## realdos.sh: the same programs on a DOS that is not the emulator's

What a search ought to answer is decided by a DOS, and the emulator's own DOS is the thing under
test. `realdos.sh` boots the DOS of a hard disk image you hand it (the system disk of a
Windows 98: its kernel is MS-DOS 7) and runs FINDLIFE, EXACT, ENUMSTAT, DRIFT, DTADUMP, PATLIST,
TEMPLATE or FINDPOS there, or MEMPROBE's lookup of every file of a folder, the batch file of
`fc.sh` or the copy of `xcopy.sh`. The
emulator is only the PC: once the image boots, its DOS, its shell and its host-folder drives are
gone, and every INT 21h call is answered by the image's kernel over a FAT volume. The image is
not kept here and is never written: each run boots a copy.

A run launches the emulator once to stage, once to boot and once to collect. The emulator's own
shell first puts the programs and a DPMI host on the copy, with its own `FC.EXE` or `XCOPY.EXE`
when the run is theirs, makes a second FAT16 disk and copies the folders onto it with long names
off, so they arrive under the 8.3 names a program sees through the emulator's host-folder
drive. Then the
copy boots: its `AUTOEXEC.BAT` runs the programs, gathers their reports in one file and turns
the machine off through the BIOS's power management, and it never returns, so no Windows
starts. Last, the emulator's shell copies that file out of the image.

The output opens with whose DOS answered: its own `VER` line and what `DOSID.EXE` read (the
version, where the INT 21h vector points, whether the long-name calls answer, whether a Windows
is running, whether the emulator's `Z:` drive exists). A run answered from the emulator's ROM
segment, or one that has `Z:`, is INVALID, and so is one whose folders did not reach the disk
whole or whose batch did not reach its last line.

Limits:

- Long names off only. MS-DOS 7 without its Windows has no long-name calls (714Eh answers
  7100h), so the cases that need them read `not judged` or do nothing.
- FINDLIFE's `remount` and `rescan-mid-search` call the emulator's `MOUNT` and `RESCAN`, which
  no other DOS has: there both read `DIFFERS`, and that is the sign the two DOSes are not one.
  `slot-reused-live`, `stale-dta-after-reuse`, `left-open-past-the-slots` and
  `turn-about-past-the-slots` are sized by the emulator's search table; elsewhere they run and
  say only that a search survives that many others. The long-name cases among them are not
  judged.
- FINDPOS runs on the disk as the run makes it, which has no label (`findpos`), or after the
  image's own `LABEL` has named it (`findpos-labelled`): a run whose DOS then does not return
  that label is INVALID.
- `SHELLT.BAT` tests the emulator's shell and is not run, and there is no `ties` here: its two
  entries with one short name do not reach a FAT folder as two.
- The folders go through the emulator's shell, so the build named must be able to copy them:
  the script counts what was copied. A large folder, and the tree of `xcopy`, go through `COPY`
  a folder at a time, because `XCOPY` looks every file up while it lists and the emulator's
  search table fills first.
- `memprobe`, `fc` and `xcopy` say what that DOS answers, not what it holds: there is no memory
  to read. The FC and the XCOPY are the emulator's, run by the image's DOS, so the two DOSes are
  asked by one program; what the copy left is listed by that DOS's own `DIR`.
- It has been run on macOS only. The copy of the image is a clone where the file system has
  them and a whole copy elsewhere.

## battery.sh: all of it, one line per cell

`battery.sh <base> <build>` runs every script above in one fixed order and prints one line per
cell, so a change is read as two lists of lines: what a build answers, beside what the build it
started from answers. It judges nothing. Each line is one script's own verdict and what it
counted:

```
cell|<name>|<long names: on, off or ->|<verdict>|<figures>
```

- The name says the script, what it ran on, and `base:build` for a script that compares two
  builds, or `base` or `build` for one that measures a single build. A third build on the
  command line is what a branch stacked on another needs: `<build>` is compared with it as
  well (`third:build`), and it is measured beside the two.
- The verdict is the script's: `IDENTICAL` or `ALIKE`, `DIFFERENT`, `ran` for a script that
  compares nothing, `INVALID`, and `not run` where the host cannot run the cell.
- The figures are what the script counted: the table below names them. For `INVALID` and
  `not run` they say why.

It exits 0 when every cell ran and 3 when one is INVALID. A `DIFFERENT`, a failed test or a
memory figure that grew is for the reader: read `memory` cells two at a time, the same call at
its two counts.

Beyond what the scripts need, it takes from the environment the large real folder and one file
of it (`DIRCACHE_REAL_FOLDER`, `DIRCACHE_REAL_FILE`), the folder holding the two regression
programs (`DIRCACHE_REGRESSION`) and, with `--real-dos`, the disk image (`DIRCACHE_BOOT_IMAGE`).
`--raw <directory>` keeps what every script printed, one file per call: the lines that differ
are there, and the directory an INVALID run kept is named there.

Two runs on the same builds print the same lines apart from the memory figures. To compare two
outputs:

```sh
sed -E 's/((held|peak)_[a-z]+_kb)=[0-9]+/\1=N/' <output>
```

Limits:

- On Windows the scripts' own tests and the cells of `--real-dos` print `not run`: the first
  play captured runs through the macOS launcher, the second boot an image that stays on one
  host. A Windows run is read beside the lines a macOS run printed for them.
- Where the host's file system names the aliases, the cells that show an alias (`run` on long
  names, `enumstat` on long names) are that file system's, and `ties` is INVALID where it makes
  no two entries share a name.
- `--real-dos` condenses each report of the image's DOS to its counts and a digest. Which lines
  of a build's report differ from it is read from the two reports, under `--raw`.

### The cells

In the order they are printed. `<who>` is `base`, `build` or `third`; `<pair>` is `base:build`
or `third:build`. A cell whose third field is `-` has no long-name mode; the others are run with
long names on, off, or both, as the field says.

| cell | what it runs | its figures |
| --- | --- | --- |
| `selftest <name>.test.sh` | that script's own tests, no emulator | `cases=` how many ran, `failed=` how many of them failed |
| `run <folder> <pair>` | `run.sh` on a synthetic folder at each size and in each name style, then on the large real folder (`real`) | `entries=` the files on the host; for each build `4e=` and `lfn=`, the entries of the two enumerations, and `look=`, the lookups; `differing_lines=` when the dumps differ |
| `memory <folder> <mode> <calls> <who>` | `memory.sh`, the mode's call made that many times: on the large synthetic folder and on the real one, the modes that open or look up one file; on a folder of 8.3 names with long names off, a search left open (`d`), the same search with `*.*`, which the cell's name then carries, and a search still open when its process ends (`c`); on a small folder, calls enough to go round the search table many times over (`a`, and `v` for the volume label); and a lookup of each file of a folder in turn (`e`) | `entries=`; `ok=` the calls that reached the file; `slots_full=` how many times the emulator logged its search table full; `held_footprint_kb=` or `held_private_kb=`, the figure the host reads |
| `fc <files> <runs> <who>` | `fc.sh` in a folder of that many files, FC run that many times | `entries=`; `compared=` the runs that said the files do not differ; `slots_full=`; `peak_rss_kb=` or `peak_ws_kb=` while FC ran; the held figure once the runs are over |
| `findlife <pair>` | `findlife.sh` | for each build `cases=` and how many read `ok`, `DIFFERS` (`differs=`) and `not judged`; `differ=` the cases whose lines differ between the two |
| `exact <pair>` | `exact.sh` | each section as `<name>=ALIKE:<lines>` or `<name>=DIFFERENT:<lines of A>/<lines of B>`; `differ=` the lines' cases |
| `drift <pair>` | `drift.sh` | `cases=`; `sha256=` the start of each build's report digest, A then B, so a build whose report is the one the image's DOS gives shows in the line; `differ=` |
| `dtadump <pair>` | `dtadump.sh` | the script's figures for each build (`template=`, `untouched=`, `resumed=`, `fcb=`: see its section); `differing_lines=`. Where they equal the figures of the image's DOS, the build leaves in a DTA what that DOS leaves |
| `patlist <pair>` | `patlist.sh` | `patterns=`; `sha256=` of each report; `differ=` |
| `template <fat or host> <pair>` | `template.sh` on a FAT image, then on a host folder | `lines=`; `sha256=` of each report; `differing_lines=` |
| `findpos <labelled or unlabelled> <pair>` | `findpos.sh` on a drive with a label, then with none | `cases=`; `sha256=` of each report; `differ=` |
| `ties <pair>` | `ties.sh` | `ties=` the pairs of entries that share a short name; `differ=` |
| `enumstat <mode> <names> <who>` | one row of `enumstat.sh` | `listed=` the entries the listing returned; `looked_up_ok=` the lookups that found their entry; `last=` the last name listed; `slots_full=`; `out_of_range=` how many times the emulator logged a slot number out of range |
| `xcopy <who>` | `xcopy.sh` | `made=` and `dirs_made=`, the files and folders of the tree; `copied=` and `dirs_copied=`, those that arrived; `said=` XCOPY's own count; `slots_full=`; `out_of_range=` |
| `passfail <program> <folder> <who>` | `passfail.sh` with each regression program in a small and in a large folder | `sha256=` of the program; `entries=`; `pass=`, `fail=`; `exit=` its exit code |
| `unit <who>` | `unit.sh` | `tests=`, `failures=`, `errors=`, `disabled=` |
| `realdos <program>` | with `--real-dos`, `realdos.sh` with `<build>` as the machine | `dos=` the version that answered; the counts the build's own cell carries; `sha256=` of the report. `realdos enumstat <mode> <names>` is one row; `realdos memprobe`, `realdos fc` and `realdos xcopy` carry the counts of their one line and no digest |

### The lines to expect

The lines of one whole run are kept with the tests, not here. `fixtures/battery` is that run as
`--raw` keeps it, unpatched upstream as base and a patched build, with `--real-dos`: one file
per call, its exit code and arguments on the first line and what the script printed below.
`battery.test.sh` plays it back and names, case by case, the line each kind of cell must print
from it. The other fixtures hold, in the same way, what one run of each script left, and each
`<name>.test.sh` names the lines that script must print from them.

## The tests of the scripts themselves

Each script has a `<name>.test.sh` beside it that proves its verdicts without an emulator: green,
different, INVALID and bad usage, on the inputs that produce each. `fixtures/stub-launcher.sh`
stands in for the launcher and plays what real runs left, kept under `fixtures/`; its header says
how they were captured. `launch.test.sh` tests the launcher itself, against
`fixtures/stub-emulator.sh`, which stands in for a build. `battery.test.sh` plays one level up: `fixtures/stub-script.sh` stands in
for every script and plays what each printed in one real run of the battery. Run one with
`bash <name>.test.sh`; `battery.sh` runs them as its first cells, all but its own. They play
through the macOS launcher, so they run on macOS only, and `memory.test.sh` also needs its `ps`
and `footprint`.
