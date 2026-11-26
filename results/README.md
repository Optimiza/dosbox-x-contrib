# Results

These are the lines the runs printed, kept so that a figure in the pages can be read where it
was measured. Each file opens with the command, the host, the date and the builds.

Each build is named with the commit it was made from and the sha256 of its executable.

In the files whose names begin `dta-`, a line starting `# ` after the header opens a section: the
command and its exit code, which the run printed apart from its lines.

## The files

| File | What it holds |
| --- | --- |
| [`macos/battery-base-retention-exact-name.txt`](macos/battery-base-retention-exact-name.txt) | the whole battery with the MS-DOS cells: unpatched upstream, the retention build and the exact-name build |
| [`macos/battery-base-dta.txt`](macos/battery-base-dta.txt) | the whole battery with the MS-DOS cells: unpatched upstream and the DTA build |
| [`windows/battery-base-retention-exact-name.txt`](windows/battery-base-retention-exact-name.txt) | the battery on Windows, the same three builds |
| [`windows/battery-base-dta.txt`](windows/battery-base-dta.txt) | the battery on Windows, unpatched upstream and the DTA build |
| [`macos/pr6831-findlife.txt`](macos/pr6831-findlife.txt) | FINDLIFE on the exact-name build against the build of upstream pull request 6831: the lines that differ |
| [`macos/pr6831-reporters-cases.txt`](macos/pr6831-reporters-cases.txt) | the reporters' cases on the build of pull request 6831, and FC on the unpatched build in an empty folder |
| [`windows/series-real-folder.txt`](windows/series-real-folder.txt) | memory held after a growing count of lookups in the large folder: unpatched, pull request 6831, retention |
| [`windows/label-search-then-edited.txt`](windows/label-search-then-edited.txt) | one case of DRIFT on Windows: unpatched, the DTA build alone, and the DTA and retention branches merged |
| [`macos/pr6831-regression-programs.txt`](macos/pr6831-regression-programs.txt) | the two regression programs attached to pull request 6831, on that pull request's own build |
| [`windows/pr6831-findlife.txt`](windows/pr6831-findlife.txt) | FINDLIFE on Windows, the build of pull request 6831 against the retention build: the remount case and the lines that differ |
| [`macos/dta-cases.txt`](macos/dta-cases.txt) | the DTA build's own lines behind three cells of its battery: two cases of FINDLIFE, one of EXACT, and its DRIFT report |
| [`macos/launchers.txt`](macos/launchers.txt) | five commands through `bench/launch.sh` and through the launcher the battery files were made with |
| [`windows/reporters.txt`](windows/reporters.txt) | the reporters' cells on Windows: the exact-name and retention builds |
| [`macos/dta-dir.txt`](macos/dta-dir.txt), [`windows/dta-dir.txt`](windows/dta-dir.txt) | the shell's `DIR` line on the DTA branch, and its fifth head against its sixth |
| [`macos/dta-searches-answers.txt`](macos/dta-searches-answers.txt) | the answers of the search-fix branch against unpatched `main-ai` at `ac2787a42`: DTADUMP, DRIFT, FINDLIFE, EXACT, FINDPOS, TEMPLATE and DIRGONE |
| [`macos/dta-searches-alike.txt`](macos/dta-searches-alike.txt) | the verdict lines of the same scripts with the branch as both builds, run twice |
| [`macos/dta-searches-run.txt`](macos/dta-searches-run.txt) | LISTDUMP on the large folder and on the synthetic folders, unpatched against the branch |
| [`macos/dta-searches-memory.txt`](macos/dta-searches-memory.txt) | memory held: the label slot, the searches child programs leave kept, a synthetic folder and the large folder, unpatched against the branch |
| [`macos/dta-searches-msdos.txt`](macos/dta-searches-msdos.txt) | what MS-DOS 7.10 and MS-DOS 6.22 answered to DTADUMP and DRIFT, and MS-DOS 7.10 to FINDLIFE, FINDPOS and TEMPLATE |
| [`macos/dta-searches-win98.txt`](macos/dta-searches-win98.txt) | DRIFT and DTADUMP inside Windows 98 SE's DOS box, with its version and the folder it read |
| [`windows/dta-searches-answers.txt`](windows/dta-searches-answers.txt) | the same answers on Windows: unpatched `main-ai` against the branch |
| [`windows/dta-searches-alike.txt`](windows/dta-searches-alike.txt) | the verdict lines of those scripts with the branch as both builds, run twice, on Windows |
| [`windows/dta-searches-run.txt`](windows/dta-searches-run.txt) | LISTDUMP on Windows: the large folder and the synthetic folders, unpatched against the branch |
| [`windows/dta-searches-memory.txt`](windows/dta-searches-memory.txt) | memory held on Windows: the label slot, the searches child programs leave kept and the large folder, unpatched against the branch |
| [`macos/dta-restored-bisect.txt`](macos/dta-restored-bisect.txt) | the case `saved-and-restored-then-edited` on three builds of upstream `main-ai`: before another author's pull request merged, after it, and after the next |
| [`macos/dta-iso-index.txt`](macos/dta-iso-index.txt) | a probe that sets the search number of a CD image's DTA past the table, in several runs, unpatched and the branch |
| [`macos/first-read-wall.txt`](macos/first-read-wall.txt) | the seconds a first read takes: unpatched, first-read and alias builds |
| [`macos/first-read-listings.txt`](macos/first-read-listings.txt) | what unpatched and first-read builds list, compared in every folder |
| [`macos/first-read-memory.txt`](macos/first-read-memory.txt) | memory held after a first read: unpatched and first-read builds |
| [`windows/first-read-counts.txt`](windows/first-read-counts.txt) | how often a first read runs each costly loop, counted on Windows |
| [`macos/alias.txt`](macos/alias.txt), [`windows/alias.txt`](windows/alias.txt) | each build's short names judged against the host's files: unpatched and alias builds |
| [`windows/setattr.txt`](windows/setattr.txt) | an attribute change on Windows: a saved DTA, the reads it costs, its side effects |
| [`windows/dyncore.txt`](windows/dyncore.txt) | memory held after child programs on Windows: unpatched, dynamic-core, retention and the two merged |
| [`macos/create-delete.txt`](macos/create-delete.txt), [`windows/create-delete.txt`](windows/create-delete.txt) | a delete, a create, `RD`, `MD` and a rename, and on Windows the reads they cost |
| [`macos/longname.txt`](macos/longname.txt), [`windows/longname.txt`](windows/longname.txt) | whether the emulator survives a path past its arrays, on `main-ai` and with the fix, and the listings that read alike |
| [`macos/setattr-mainai.txt`](macos/setattr-mainai.txt), [`windows/setattr-mainai.txt`](windows/setattr-mainai.txt) | an attribute change on `main-ai`: the saved search, and the reads of the folder it costs |
| [`macos/dyncore-mainai.txt`](macos/dyncore-mainai.txt), [`windows/dyncore-mainai.txt`](windows/dyncore-mainai.txt) | memory held after child programs on `main-ai`, with and without the fix |
| [`macos/create-delete-mainai.txt`](macos/create-delete-mainai.txt), [`windows/create-delete-mainai.txt`](windows/create-delete-mainai.txt) | the same cases as subject 11 on `main-ai`, and on `main-ai` with the branches of subjects 3 and 5 |
| [`macos/scry-create-delete.txt`](macos/scry-create-delete.txt), [`windows/scry-create-delete.txt`](windows/scry-create-delete.txt) | the fork's scry before and after create-delete was merged into it: long paths, the cases of subject 11 and the COPY case |
| [`macos/nodrive.txt`](macos/nodrive.txt), [`windows/nodrive.txt`](windows/nodrive.txt) | what each shell command answers on a drive that is not mounted: unpatched upstream against the fix, and the fix against itself; on macOS also a base against itself with the XCOPY line, and what both real MS-DOS answer to the same lines |
| [`macos/dos-answers/`](macos/dos-answers/README.txt), [`windows/dos-answers/`](windows/dos-answers/README.txt) | the DOS answers of a mounted folder, an overlay drive, a zip drive and a CD image: what both MS-DOS answered, what each comparing script printed on `main-ai` and on the two halves, and what `agree.py` counted |

Pull request 6831 is
[another author's pull request, "Release directory search snapshots when searches end"](https://github.com/joncampbell123/dosbox-x/pull/6831).

## How to read a battery file

A battery file is one line per cell:

```
cell|<name>|<long names>|<verdict>|<figures>
```

[bench/README.md](../bench/README.md#the-cells) says what each cell runs and what its figures
count. In a run on three builds the lines name the builds so:

| Name in the lines | The build |
| --- | --- |
| `base` | unpatched upstream |
| `build` | the second build named |
| `third` | the third build named |
| `base:build`, `third:build` | the two comparisons |

The whole reports behind one run are kept too, as the recording the battery's own test plays:
[bench/fixtures/battery](../bench/fixtures/battery), one file per call, named by the call.

- The run is the macOS one on unpatched upstream and the retention build.
- MS-DOS's reports are among them: the `realdos_*` files.

## What is the same in every run

These hold for every file here.

- **The builds.** Every build is upstream `main-ai` at `4e0b6adcf`, or a branch cut from it,
  plus two lines without which that revision does not compile, but the files named `dta-` are of
  `ac2787a42` and its branch. The patched builds are named by their branch and commit.
- **The branches.** Only the branches offered upstream are published, on the fork
  `Optimiza/dosbox-x`.
- **The large folder.** A music library of 169,457 files with long names, read-only and not
  kept here. On Windows it is the same names as empty files, of which 169,452 could be made.
- **The MS-DOS cells.** They boot the DOS of a Windows 98 SE hard disk image (MS-DOS 7.10)
  inside the emulator, on macOS only, and some of them an MS-DOS 6.22 one. The images are not kept here either.

The two lines are
[pull request 6822, "fix(ide): give the ATAPI sector counters the type of the ATA ones"](https://github.com/joncampbell123/dosbox-x/pull/6822).

## What was replaced in the lines

The lines are as the runs printed them, with these things replaced:

| In the lines | Replaced by |
| --- | --- |
| the path of each build | its name |
| the path of a directory a run kept | `<the run's directory>` |
| the name of the one file looked up in the large folder | `SONG.MID` |
| the path of the large folder | `<the large folder>` |
| the name of the launcher, in the reason of the cells Windows does not run | `the macOS launcher` |
| the path of the MS-DOS 7.10 boot image | `<a Windows 98 SE hard disk image>` |
| the path of the MS-DOS 6.22 boot image | `<an MS-DOS 6.22 hard disk image>` |
| the carriage returns of the files read off the Windows 98 image | removed |

That launcher was not `bench/launch.sh`. The runs were made with another launcher of ours,
not published, that gives the emulator the same arguments.

Five commands print the same through `launch.sh` and through that launcher, in
[macos/launchers.txt](macos/launchers.txt):

| Command | What the two launchers give |
| --- | --- |
| `drift.sh` on unpatched upstream against a patched build | the same bytes |
| `exact.sh` on the same two builds | the same bytes |
| `realdos.sh` running DRIFT on the MS-DOS image | the same bytes |
| `unit.sh` | the same line |
| a `memory.sh` cell | the same line but for the memory figures, `samples` and `guest_us`, which also differ between two runs through `launch.sh` |
