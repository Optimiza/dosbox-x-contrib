# Results

These are the lines the runs printed, kept so that a figure in the pages can be read where it
was measured. Each file opens with the command, the host, the date and the builds.

Each build is named with the commit it was made from and the sha256 of its executable.

## The files

| File | What it holds |
| --- | --- |
| [`macos/battery-base-retention-exact-name.txt`](macos/battery-base-retention-exact-name.txt) | the whole battery with the MS-DOS cells: unpatched upstream, the retention build and the exact-name build |
| [`macos/battery-base-dta.txt`](macos/battery-base-dta.txt) | the whole battery with the MS-DOS cells: unpatched upstream and the DTA build |
| [`windows/battery-base-retention-exact-name.txt`](windows/battery-base-retention-exact-name.txt) | the battery on Windows, the same three builds |
| [`windows/battery-base-dta.txt`](windows/battery-base-dta.txt) | the battery on Windows, unpatched upstream and the DTA build |
| [`macos/pr6831-findlife.txt`](macos/pr6831-findlife.txt) | FINDLIFE on the exact-name build against the build of upstream pull request 6831: the lines that differ |
| [`macos/pr6831-reporters-cases.txt`](macos/pr6831-reporters-cases.txt) | the reporters' cases on the build of pull request 6831, and FC on the unpatched build in an empty folder |
| [`windows/series-real-folder.txt`](windows/series-real-folder.txt) | memory held after 1 to 1,000 lookups in the large folder: unpatched, pull request 6831, retention |
| [`windows/label-search-then-edited.txt`](windows/label-search-then-edited.txt) | one case of DRIFT on Windows: unpatched, the DTA build alone, and the DTA and retention branches merged |
| [`macos/pr6831-regression-programs.txt`](macos/pr6831-regression-programs.txt) | the two regression programs attached to pull request 6831, on that pull request's own build |
| [`windows/pr6831-findlife.txt`](windows/pr6831-findlife.txt) | FINDLIFE on Windows, the build of pull request 6831 against the retention build: the remount case and the lines that differ |
| [`macos/dta-cases.txt`](macos/dta-cases.txt) | the DTA build's own lines behind three cells of its battery: two cases of FINDLIFE, one of EXACT, and its DRIFT report |

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
[bench/fixtures/battery](../bench/fixtures/battery), one file per call.

- The run is the macOS one on unpatched upstream and the retention build.
- MS-DOS's reports are among them: `121-realdos.txt` to `132-realdos.txt`.

## What is the same in every run

Three things hold for every file here.

- **The builds.** Every build is upstream `main-ai` at `4e0b6adcf`, or a branch cut from it,
  plus two lines without which that revision does not compile. The patched builds are named
  by their branch and commit; the branches are not published yet.
- **The large folder.** It is a music library of 169,457 files with long names, read-only. On
  Windows it is the same names as empty files, of which 169,452 could be made.
- Neither folder is kept here.
- **The MS-DOS cells.** They boot the DOS of a Windows 98 SE hard disk image (MS-DOS 7.10)
  inside the emulator, on macOS only. The image is not kept here either.

The two lines are
[pull request 6822, "fix(ide): give the ATAPI sector counters the type of the ATA ones"](https://github.com/joncampbell123/dosbox-x/pull/6822).

## What was replaced in the lines

The lines are as the runs printed them, with four things replaced:

| In the lines | Replaced by |
| --- | --- |
| the path of each build | its name |
| the path of a directory a run kept | `<the run's directory>` |
| the name of the one file looked up in the large folder | `SONG.MID` |
| the name of the launcher, in the reason of the cells Windows does not run | `the macOS launcher` |

That launcher was not `bench/launch.sh`. The runs were made with another launcher of ours,
not published, that gives the emulator the same arguments.

Five commands print the same through `launch.sh` and through that launcher:

| Command | What the two launchers give |
| --- | --- |
| `drift.sh` on unpatched upstream against a patched build | the same bytes |
| `exact.sh` on the same two builds | the same bytes |
| `realdos.sh` running DRIFT on the MS-DOS image | the same bytes |
| `unit.sh` | the same line |
| a `memory.sh` cell | the same line but for the memory figures |
