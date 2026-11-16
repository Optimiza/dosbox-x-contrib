# DOSBox-X's directory cache on large folders: a test bench and what it measured

DOSBox-X keeps a cache of every host folder a DOS program looks into. In a folder with many
files that cache takes memory on every file lookup, keeps it, and can cut a listing short. This
repository holds the bench that measures it and the account of a set of fixes, each offered to
DOSBox-X as a pull request of its own: what was wrong, what each fix changes, and the lines
that show it on macOS and on Windows, checked against a real MS-DOS 7.10.

Three of the fixes are done and proved on both hosts. The rest are in progress or not started,
and this page says so where it reaches them: it is brought up to date as each one closes.

| # | Pull request, one subject each | Branch | Needs | State |
| --- | --- | --- | --- | --- |
| 1 | A search for one exact name does not copy the whole directory | `dircache-exact-name` | nothing | proved on macOS and Windows |
| 2 | A search's copy is released without ending a live search | `dircache-retention` | 1 | proved on macOS and Windows |
| 3 | The first read of a large folder | `dircache-first-read` | nothing | not started |
| 4 | A find call does not disturb another search's DTA | `dircache-dta` | nothing | proved on macOS and Windows |
| 5 | A generated 8.3 alias never equals a real 8.3 name | `dircache-alias` | 3 | not started |
| 6 | The emulator's DOS answers as MS-DOS does where the contrast found it differs | `dircache-dos-answers` | nothing | not started |
| 7 | The shell's `DIR` prints the free space of the drive it listed | `dircache-shell-dir` | nothing | in progress |
| 8 | `CommandLine::FindString` does not read past the last word | `dircache-findstring` | nothing | in progress |
| 9 | An attribute change on Windows does not empty the directory cache | `dircache-setattr` | nothing | cause measured, branch not written |
| 10 | The x86 dynamic core keeps its code-page handlers across a cache reset | `dyncore-cache-reset` | nothing | cause measured, branch not written |

Every branch is cut from upstream `main-ai` at `4e0b6adcf`, or from the branch it needs, and is
meant for `main-ai`. None is published yet: the branches are named here by their commits, and
the links come when the pull requests are opened.

## The problem, and the case that showed it

A DOS player was pointed at a music library of 169,457 files in one folder. Opening a single
file there made the emulator's memory grow by the size of the whole directory, and it never
came back: after one call to `access()` the emulator held 498,305 kB, after twenty
4,681,220 kB. It is reported upstream as
[issue 6823, "FindFirst copies and retains the whole directory on every call"](https://github.com/joncampbell123/dosbox-x/issues/6823).
Three costs sit behind it, all in `src/dos/drive_cache.cpp` and the search calls around it:

1. Every FindFirst copies and sorts the whole directory, whatever the pattern. A program that
   only asks whether one file exists pays for all of them. A libc `access`, `fopen` or `stat`
   reaches it, because the C library looks the name up with a FindFirst.
2. The copy outlives the search. It is freed when the search runs to its end, or when all
   2,048 search slots are taken and the emulator empties the whole table, which ends every
   search still in progress.
3. The first touch of a large folder stalls the emulator while the cache is built.

The first two are fixed by pull requests 1 and 2. The third is pull request 3, not started.

## How it is measured

A check here is a small DOS program and the host script that runs it headless in two builds
and compares what they print: what a search returns, byte for byte, or how much memory the
emulator holds once the guest has made its calls and waits. Every script answers with the same
four exit codes (the answer, the builds differ, bad usage, INVALID), and INVALID means nothing
was judged: a run that measured nothing never reads as a pass. `battery.sh` runs all of them in
a fixed order and prints one line per cell, 219 cells on three builds, so a change is read as
two lists of lines. The scripts, the guest programs' sources and their tests are in
[`bench/`](bench/README.md); the lines of the runs quoted below are in
[`results/`](results/README.md).

**The base.** Every figure compares a patched build with unpatched upstream `main-ai` at
`4e0b6adcf`. That revision does not compile on macOS without the two lines of
[pull request 6822, "fix(ide): give the ATAPI sector counters the type of the ATA ones"](https://github.com/joncampbell123/dosbox-x/pull/6822),
so every build here carries them, the base included.

**The referee is MS-DOS 7.10.** What a search ought to answer is decided by a DOS, and the
emulator's own DOS is the thing under test. `realdos.sh` boots the DOS of a Windows 98 SE disk
image inside the emulator, which is then only the PC: every INT 21h call is answered by that
kernel over a FAT volume, and the run refuses to count if the answer came from the emulator's
own DOS. Where MS-DOS answers, a patched build has to answer the same in what its patch
changes. Where a patched build differs from unpatched upstream and MS-DOS agrees with the
patch, that is said. Where unpatched upstream already differs from MS-DOS outside a patch's
subject, it is upstream's and is listed, not hidden. MS-DOS 7 without its Windows has no
long-name calls, so with long names on there is no referee: the reference is the documented
call.

**Both hosts.** Every patch is built and run on macOS (Apple silicon, SDL2) and on Windows
(x64, Visual Studio, SDL1), with the same scripts under Git Bash. Windows matters twice: it is
where [issue 6827](https://github.com/joncampbell123/dosbox-x/issues/6827) was reported from,
and there the 8.3 aliases come from NTFS and not from the emulator, so the cells that show an
alias are the file system's.

**Memory.** On macOS the figure is the footprint, read from outside while the guest holds; the
resident size falls when the system compresses memory nobody touches, which is what an
abandoned search is. On Windows it is the private bytes. A figure from one run says little: a
cell is read at two call counts, and the growth per call is the difference divided by the
calls between them.

## 1. A search for one exact name does not copy the whole directory

Branch `dircache-exact-name`, two commits (`7e74299e2`, `73e09f70d`). It stands alone.

A FindFirst whose pattern has no `*` or `?` now keeps the entries that match, one in every
ordinary case, and not a sorted copy of the directory. Wildcard searches are untouched. If a
later FindNext arrives with another pattern, because the program edited its DTA, the copy is
made then and the search goes on behind the entry already returned, as on unpatched upstream.

Memory held after 1 and after 20 calls on one file, long names on:

| Host | Folder | Call | Unpatched, 1 → 20 calls (kB) | Per call | Patched, 1 → 20 calls (kB) |
| --- | --- | --- | --- | --- | --- |
| macOS | 169,457 files | `access` | 498,305 → 4,681,220 | 215.0 MB | 277,584 → 277,681 |
| macOS | 169,457 files | `fopen` | 608,449 → 6,882,821 | 322.5 MB | 277,488 → 277,633 |
| macOS | 50,000 files | `access` | 262,544 → 1,499,681 | 63.6 MB | 197,600 → 197,424 |
| Windows | 169,452 files | `access` | 513,344 → 4,542,512 | 207.1 MB | 301,596 → 301,648 |
| Windows | 169,452 files | `fopen` | 619,436 → killed at the 6 GB limit | 310.6 MB, from 1 and 5 calls | 301,720 → 301,528 |
| Windows | 50,000 files | `access` | 289,132 → 1,477,624 | 61.1 MB | 226,880 → 226,732 |

From the cells `memory real <a|f> <1|20>` and `memory synthetic:50000:long a <1|20>`, `base`
and `third`, of `results/macos/battery-base-retention-exact-name.txt` and its Windows twin; the
Windows `fopen` per call is from `results/windows/series-real-folder.txt` (619,572 kB at 1
call, 1,891,860 at 5).

What two builds list is unchanged. LISTDUMP writes every field a search returns, in order, for
a 4Eh and a 714Eh enumeration and a set of lookups by name, over folders of 1,000, 10,000 and
50,000 files, 8.3 and long names, long names on and off, and the large folder. In the runs on
three builds the retention build, which contains this patch, is compared with unpatched
upstream and with the exact-name build: both comparisons are byte-identical in 14 of 14 cells
on each host (the `run` cells of the same files), so the three list alike. EXACT asks 362
questions about awkward names, one search per name, call and attribute; its four judged
sections read ALIKE in the same two comparisons on both hosts. The emulator's 68 unit tests
pass on every build.

One thing a program can see. A file created between FindFirst and FindNext is now returned if
it sorts behind the entry found. DRIFT's `folder-gained-files` creates two such files:
unpatched upstream returns 6 more entries, the patched build 7, MS-DOS 7.10 all 8
(`bench/fixtures/battery/092-drift.txt` and `124-realdos.txt`).

What it does not do alone: nothing is released sooner. A slot now holds one entry and not the
folder, but the table still fills and is emptied, 29 times in 20,000 lookups on both builds,
and a listing that looks every entry up through libc `stat` still stops short. That is the
next pull request.

## 2. A search's copy is released without ending a live search

Branch `dircache-retention`, five commits ending at `527476085`, on top of the exact-name
branch. It needs pull request 1: with long names off a libc `stat` is an exact-name search that
is never continued, and without that patch each one would still hold a whole folder. The five
commits are offered as one: with the first four alone a listing that looks every entry up by
name stops at the table's reset, and at the head it comes out whole.

It is offered as a proposal on
[pull request 6831, "Release directory search snapshots when searches end"](https://github.com/joncampbell123/dosbox-x/pull/6831),
which addresses the same cost and is discussed below.

What changes: a search is named by its slot and a generation, so a FindNext through a DTA
whose slot went to another search answers "no more files" and never returns another folder's
entry; a search for the volume label alone takes no slot; a long-name search ends with its
handle (71A1h) and a path lookup with its answer; searches of a whole folder share one sorted
copy while the folder does not change; and a full table gives back one slot, not all of them.
Nothing is released when a process ends or by DTA address: that cannot be told apart from a
search a real DOS would continue.

| What a program does | Unpatched | Exact-name alone | Retention | MS-DOS 7.10 |
| --- | --- | --- | --- | --- |
| 20,000 lookups that close their search: times the emulator emptied its search table | 29 | 29 | none | |
| 20,000 searches for the volume label: the same | 9 | 9 | none | |
| A whole-folder search left unfinished, 50,000 files: memory at 1 → 20 searches, macOS (kB) | 229,360 → 847,857 | 229,472 → 847,889 | 229,728 → 229,728 | |
| The same on Windows (kB) | 257,884 → 852,016 | 257,680 → 852,020 | 257,688 → 258,216 | |
| A listing of 3,000 files with libc `stat` on each, long names on: entries listed of 3,002 | 139 | 139 | 3,002 | no long names there |
| The same with long names off | 685 | 685 | 3,002 | 3,002 |
| XCOPY of a tree of 2,520 files in 18 folders: what arrived | 2,065 in 15 | 2,065 in 15 | 2,520 in 18 | 2,520 in 18 |
| Two searches read turn about, a lookup by name before every turn: entries each returned, of 42 and 32 | 28 and 28 | 28 and 28 | 42 and 32 | 42 and 32 |
| More whole-folder searches left open than the table has slots: a search started before them, of 42 | 34, and 30 entries of another folder | the same | 42 | 42 |

From `results/macos/battery-base-retention-exact-name.txt`: the cells `memory synthetic:100:long
<a|v> 20000` (`slots_full=`), `memory synthetic:50000:83 *.* d`, `enumstat s long`, `enumstat s
83`, `xcopy`, and FINDLIFE's `turn-about-past-the-slots` and `left-open-past-the-slots`
(`bench/fixtures/battery/087-findlife.txt`; MS-DOS: `121-realdos.txt`). The listing and table
rows read the same on Windows (`results/windows/battery-base-retention-exact-name.txt`), where
the XCOPY and turn-about cells have not been run yet. The retention build no longer has the
log line the first two rows count, so "none" there is not evidence by itself: the evidence is
that every one of the 20,000 calls found its file and every listing came out whole.

Against unpatched upstream the retention build lists every folder byte for byte (14 of 14
cells per host), EXACT's four judged sections read ALIKE, the unit tests pass, and no memory
cell grows with the call count, long names on or off, but the one Windows cell named below.
The other answers that move are these. Three go to MS-DOS's answer: a FindNext after a search
for the label alone answers "no more files" where upstream returned a file of the root; a
label search that fails through the DTA of a live search leaves that search whole (12 more
entries, upstream 1 from the root, MS-DOS 12); and DRIFT's `label-search-then-edited` returns
nothing more where upstream returned 4 entries. Two are in long-name calls, where no real DOS
referees: a 714Fh asked again after its search ended no longer reads another search (a search
then returns 32 of 32 entries, upstream 1), and a 714Eh turned away for want of a handle no
longer leaves its search open (42 of 42, upstream 3).

**What it leaves, declared.** MS-DOS keeps the place of a search in the 21 bytes of the DTA it
reserves, so a program can rewind a search by putting saved bytes back. The emulator keeps the
place in its own table, before and after this branch: a search rewound by its saved DTA
returns 7 more entries where MS-DOS returns 12; two copies of one DTA read side by side return
6 and 6 where MS-DOS returns 12 and 12; a DTA put back after its search ended returns nothing
where MS-DOS returns 15 (`bench/fixtures/battery/104-findpos.txt`, and `128-realdos.txt`).
Moving the place into the DTA is another design in code where upstream already reverted a fix
([pull request 5712, "Fix potential memory leaks in drive_cache.cpp"](https://github.com/joncampbell123/dosbox-x/pull/5712)),
and no program is known to need it.

**On Windows, one line of this branch's proof does not hold yet.** Children that end with a
search open leave memory behind on unpatched upstream and on the retention build alike:
264,088 → 980,000 kB and 232,744 → 354,260 kB at 1 and 20 children, where macOS reads
198,304 → 198,432 kB with the retention. It is not the directory cache's: its cause is the
subject of pull request 10.

### Pull request 6831 beside it

[Pull request 6831](https://github.com/joncampbell123/dosbox-x/pull/6831) is another author's
and came first. It releases a search's copy when the search is replaced, closed or its process
ends, and it does remove the growth: it closes the reporters' cases below. I ran it and its two
regression programs with these instruments and posted what they showed on the pull request
([the comment](https://github.com/joncampbell123/dosbox-x/pull/6831#issuecomment-6889077629),
[its follow-up with the MS-DOS confirmation](https://github.com/joncampbell123/dosbox-x/pull/6831#issuecomment-6889773432),
[the gist with the report and three guest programs](https://gist.github.com/Optimiza/a4a2f4a2aace2ca21dfed75fd4324258)).
Its regression programs, FINDTEST and LFNTEST, pass on its build, on unpatched upstream and on
every branch here (10 checks of 10, each).

What it changes for a program is that a release can end a search a real DOS would continue.
These are the cases, the same on unpatched upstream and on the branches here:

| Case | Unpatched and the branches here | Pull request 6831 | MS-DOS 7.10 |
| --- | --- | --- | --- |
| A second FindFirst through the same DTA address, the first search's bytes saved and restored: the first search then returns | 42 of 42 | 3 of 42 | 42 of 42 |
| A FindFirst that fails before it touches the DTA: the search in progress then returns | 42 of 42 | 3 of 42 | 42 of 42 |
| A child starts a search in its parent's DTA and ends; the parent reads on | 32 of 32 | 1 of 32 | 32 of 32 |
| Two enumerations at once through libc, long names off | 42 of 42 | 1 of 42 | 42 of 42 |
| A saved DTA whose slot went to a search of another folder | no entry of the other folder | an entry of the other folder | |
| The drive unmounted and mounted again, a search on the new drive | 32 of 32 | 3 of 32, not in every run | |

From `results/macos/pr6831-findlife.txt` (the exact-name build against the pull request's) and
`bench/fixtures/battery/121-realdos.txt`. The retention build answers the six as unpatched
upstream does.

It also leaves two things the retention branch closes: 20,000 searches for the volume label
still empty its table 9 times (`results/macos/pr6831-reporters-cases.txt`), and on Windows its
memory is bounded but not flat. In the large folder there, memory after 1 and after 1,000
`access` calls reads 301,304 → 503,152 kB on its build and 301,708 → 301,100 kB on the
retention build (`results/windows/series-real-folder.txt`).

## 3. The first read of a large folder

Not started: the first touch of a large folder has not been profiled yet in the way this
account requires, so there is no figure for it here.

## 4. A find call does not disturb another search's DTA

Branch `dircache-dta`, five commits ending at `29879873b`. It stands alone.

Four defects of unpatched upstream, each a find call writing where another search keeps its
state, and one unchecked index met on the way:

- A FindFirst that fails after the search was set up has already overwritten the DTA's
  pattern. MS-DOS leaves the DTA as it was.
- A long-name FindFirst (714Eh) writes its pattern into whichever DTA is current, and breaks a
  4Eh search in progress.
- The FCB find calls and the emulator's own path lookups share one temporary DTA, so an FCB
  search does not survive a long-name call. The state now lives in the program's FCB, as
  MS-DOS keeps it.
- The DTA's search template is padded with zeros where MS-DOS pads with spaces, so a template
  a program writes the MS-DOS way matches nothing.
- `isoDrive::FindNext` indexes its table with a number read from the guest; it is now checked.

| What is measured | Unpatched | Patched | MS-DOS 7.10 |
| --- | --- | --- | --- |
| A 4Eh search across a 714Eh made through the same DTA: entries returned of 42 | 3 | 42 | no long names there |
| An FCB search across a long-name call: files returned of 40 | 2 | 40 | no long names there |
| Calls that must leave a DTA alone: how many left its 43 bytes unchanged, long names off | 3 of 6 | 6 of 6 | 6 of 6 |
| The searches those calls interrupted: how many returned the rest of the folder | 3 of 6 | 6 of 6 | 6 of 6 |
| The template bytes of every FindFirst dumped, long names off (digest) | `1c5027e13814` | `8044d2aed1bc` | `8044d2aed1bc` |
| What the FCB searches return, macOS (digest) | `ce9cdd5c399c` | `f9c92156e849` | `f9c92156e849` |
| A FindFirst that fails with another pattern through an exact-name search's DTA: entries the search then returns | 6 | none | none |
| DRIFT, 25 cases of a FindNext that brings another pattern: lines that differ from MS-DOS's report | 8 | 2 | |

From the cells `findlife`, `dtadump`, `exact` and `drift` of
`results/macos/battery-base-dta.txt`, and the reports in `bench/fixtures/battery`
(`087-findlife.txt`, `092-drift.txt`, `124-realdos.txt`). The two DRIFT lines left are nobody's
fix here: one is the second new file of `folder-gained-files`, the other the order in which a
directory that lost an entry is read on. On Windows the cells read the same
(`results/windows/battery-base-dta.txt`), with the FCB digest different only by the alias
names NTFS gives.

Everything else answers as unpatched upstream: the listings are byte-identical in 14 of 14
cells per host, EXACT's four judged sections read ALIKE, and the memory cells are alike. With
long names on, a line of the patched build differs from unpatched upstream only where it is
one of the defects' own.

**One case needs pull request 2 on Windows.** DRIFT's `label-search-then-edited` is closed by
this branch on macOS, where it returns nothing more, as MS-DOS. On Windows the DTA build alone
still returns 4 entries, as unpatched upstream does, and the two branches merged return none
(`results/windows/label-search-then-edited.txt`). The reason is the subject of pull request 9.

**What it leaves, declared.** With long names on, a 4Fh after a 4Eh for a quoted name that
fills both fields and has a typed space as its eighth or eleventh character reads the template
the MS-DOS way. It was found by reading, no run showed a line differing for it, and closing it
would need a mark in DTA bytes a real DOS does not write.

## 5. A generated 8.3 alias never equals a real 8.3 name

Not started. The emulator can give a long name an alias that another file already has as its
real name, so two entries share one short name; it is built on pull request 3.

## 6. The emulator's DOS answers as MS-DOS does where the contrast found it differs

Not started. The contrast with MS-DOS found lines where unpatched upstream answers otherwise
outside every other subject here (an error code, a leading space accepted in a name, the label
in a listing of the root); they are fixed together, last.

## 7. The shell's `DIR` prints the free space of the drive it listed

In progress. The shell's `DIR` takes the drive of its free-space line from the DTA after the
search, so after a search that finds nothing it can print another drive's.

## 8. `CommandLine::FindString` does not read past the last word

In progress. An option given as the last word of a command line, with no value after it, is
read past the end.

## 9. An attribute change on Windows does not empty the directory cache

The cause is measured and the branch is not written yet. On Windows every change of a file's
attributes empties the drive's whole cache, which costs a read of the folder each time and is
behind the Windows-only case of pull request 4.

## 10. The x86 dynamic core keeps its code-page handlers across a cache reset

The cause is measured and the branch is not written yet. It is outside the directory cache:
it is what leaves memory behind per child process on Windows in pull request 2's proof.

## The reporters' cases

Each related upstream issue is reproduced as its reporter describes it, on every build.

| The case | Unpatched | Exact-name | Retention | Pull request 6831 | MS-DOS 7.10 |
| --- | --- | --- | --- | --- | --- |
| [Issue 6827](https://github.com/joncampbell123/dosbox-x/issues/6827): FC run 300 times in a folder of 700 files. Memory held after 1 → 300 runs (kB) | 167,632 → 458,353 | 165,904 → 181,008 | 165,968 → 181,216 | 167,392 → 181,696 | 300 of 300 compared |
| The same: peak resident size at 300 runs (kB) | 497,744 | 220,576 | 220,752 | 221,248 | |
| [Issue 2485](https://github.com/joncampbell123/dosbox-x/issues/2485): a FindFirst per file over 1,835 files. Memory held after 1 → 1,835 lookups (kB) | 167,344 → 2,363,522 | 167,280 → 168,448 | 167,472 → 168,656 | 167,376 → 167,408 | 1,835 of 1,835 found |
| [Issue 4904](https://github.com/joncampbell123/dosbox-x/issues/4904), as the maintainer reproduced it: XCOPY of a tree, files that arrived of 2,520 | 2,065 | 2,065 | 2,520 | 2,520 | 2,520 |
| Issue 4904, as its reporter describes it: two DTA searches read turn about, of 42 and 32 | 28 and 28 | 28 and 28 | 42 and 32 | 42 and 32 | 42 and 32 |

macOS, long names off but for the turn-about row, from the cells `fc 700`, `memory
synthetic:1835:83 e`, `xcopy` and `findlife` of
`results/macos/battery-base-retention-exact-name.txt`, with pull request 6831's column from
`results/macos/pr6831-reporters-cases.txt` and `results/macos/pr6831-findlife.txt`. The
exact-name patch closes issues 6827 and 2485; issue 4904 takes the retention.

These are stand-ins written from the reports: the emulator's own FC from a batch file, a
program that looks each file up by name, a tree made for the run. The reporters' own attached
files are being run now and their result is not filed yet.

## What was seen and left

| Seen | The measured line | What becomes of it |
| --- | --- | --- |
| 300 runs of the emulator's FC leave about 15 MB whatever the folder holds, on every build | unpatched upstream in a folder with no other file: 182,128 kB held after 300 runs; in the folder of 700 files the patched builds hold 181,008 and 181,216 kB | not the directory cache's and not looked for; named to the maintainer |
| With long names on, 4Eh matches by a wider rule than MS-DOS: a `*` followed by more characters is honoured and the long name is matched too | PATLIST, 15 patterns: every build's list with long names off is MS-DOS's (digest `dfc20fe25661`), with long names on another (`a8e695a8baca`) | the emulator's long-name rule, which no real DOS referees; named to the maintainer |
| Two DRIFT lines differ from MS-DOS on every build | `folder-gained-files`: 7 of MS-DOS's 8 with the exact-name patch; `folder-lost-the-entry`: 5 more where MS-DOS returns none | the first is half closed by pull request 1; the second is the order a changed directory is read in, left |
| Pull request 6831's build answers the remount case differently from run to run | 3 of 32 in some runs, 32 of 32 in others | the case needs the host's allocator to reuse an address; no claim rests on it |
| On Windows the unpatched build passes the bench's memory limit in the large folder | `fopen` at 20 calls: killed at 6,291,456 kB of working set, INVALID | the limit doing its work; the cell is read from 1 and 5 calls |
| On Windows `ties.sh` is INVALID | no two entries share a short name there: NTFS names the aliases | the script's answer on such a host, not a failure |

The sources are the same result files; the PATLIST digests are in the `patlist` and `realdos
patlist` cells.

## The related upstream issues

| Upstream issue | State upstream | What the work does for it |
| --- | --- | --- |
| [6823, FindFirst copies and retains the whole directory on every call](https://github.com/joncampbell123/dosbox-x/issues/6823) | open | the copy: covered, measured (pull request 1); the retention: covered, measured (pull request 2); the first read: not yet (pull request 3) |
| [6827, DOSBox-X consumes huge amounts of memory when running certain programs in directories with lots of files](https://github.com/joncampbell123/dosbox-x/issues/6827) | open | covered, measured by a stand-in (pull request 1) |
| [4904, FindFirst (int21,4e) can invalidate handles stored in other DTA blocks](https://github.com/joncampbell123/dosbox-x/issues/4904) | open | covered, measured by two stand-ins (pull request 2) |
| [2485, Cycle with test if file exists in directory with 1835 files will crash](https://github.com/joncampbell123/dosbox-x/issues/2485) | closed | the memory behind it: covered, measured by a stand-in (pull request 1) |
| [3572, Very slow response when querying a large directory](https://github.com/joncampbell123/dosbox-x/issues/3572) | open | not yet (pull request 3) |
| [5039, Large number of files in dir stalls dosbox-x](https://github.com/joncampbell123/dosbox-x/issues/5039) | closed | not yet (pull request 3) |
| [6808, main-ai no longer builds on macOS or Visual Studio since the IDE commit](https://github.com/joncampbell123/dosbox-x/issues/6808) | closed | nothing to do here: [pull request 6822](https://github.com/joncampbell123/dosbox-x/pull/6822) is the fix every build here carries |

## Running it

A clone runs with two DOSBox-X executables, the DJGPP cross compiler and, on macOS, GNU
`timeout`; nothing here opens a window. The tests of the scripts themselves need no emulator:

```sh
for t in bench/*.test.sh; do bash "$t" || break; done
```

One cell, an unpatched build against a patched one:

```sh
bench/drift.sh <unpatched dosbox-x> <patched dosbox-x> off
```

[`bench/README.md`](bench/README.md) says what each script needs, what it prints and where its
limits are, and how the whole battery is called. The MS-DOS cells need a hard disk image of
your own whose DOS boots; the large folder is any folder of yours.

The branches and the bench were written with AI assistance (Claude Fable 5.2), so under the
project's Artificial Intelligence Policy they do not comply for `master` and are meant for
`main-ai`. I have reviewed them myself as well.

Developed by Optimiza ([Marcos Hernández](https://www.linkedin.com/in/optimiza/)), in collaboration with [MS-DOS Club](https://msdos.club) and its [podcast](https://www.ivoox.com/podcast-ms-dos-club_sq_f11160693_1.html).
