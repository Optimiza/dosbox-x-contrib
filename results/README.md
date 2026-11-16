# Results

The lines the runs printed, kept so that a figure in the account can be read where it was
measured. Each file opens with the command, the host, the date and the builds, each build with
the commit it was made from and the sha256 of its executable.

| File | What it holds |
| --- | --- |
| `macos/battery-base-retention-exact-name.txt` | the whole battery with the MS-DOS cells: unpatched upstream, the retention build and the exact-name build |
| `macos/battery-base-dta.txt` | the whole battery with the MS-DOS cells: unpatched upstream and the DTA build |
| `windows/battery-base-retention-exact-name.txt` | the battery on Windows, the same three builds |
| `windows/battery-base-dta.txt` | the battery on Windows, unpatched upstream and the DTA build |
| `macos/pr6831-findlife.txt` | FINDLIFE on the exact-name build against the build of upstream pull request 6831: the lines that differ |
| `macos/pr6831-reporters-cases.txt` | the reporters' cases on the build of pull request 6831, and FC on the unpatched build in an empty folder |
| `windows/series-real-folder.txt` | memory held after 1 to 1,000 lookups in the large folder: unpatched, pull request 6831, retention |
| `windows/label-search-then-edited.txt` | one case of DRIFT on Windows: unpatched, the DTA build alone, and the DTA and retention branches merged |

A battery file is one line per cell, `cell|<name>|<long names>|<verdict>|<figures>`.
[`bench/README.md`](../bench/README.md) says what each cell runs and what its figures count. In
a run on three builds, `base` is unpatched upstream, `build` the second build named and `third`
the third; `base:build` and `third:build` are the comparisons.

The reports behind the cells of the macOS run on unpatched upstream and the retention build,
whole, are the recording the battery's own test plays:
[`bench/fixtures/battery`](../bench/fixtures/battery), one file per call, MS-DOS's among them
(`121-realdos.txt` to `132-realdos.txt`).

## What is the same in every run

Every build is upstream `main-ai` at `4e0b6adcf`, or a branch cut from it, plus the two lines of
[pull request 6822](https://github.com/joncampbell123/dosbox-x/pull/6822), without which that
revision does not compile. The patched builds are named by their branch and commit; the
branches are not published yet.

The large folder is a music library of 169,457 files with long names, read-only. On Windows it
is the same names as empty files, of which 169,452 could be made. Neither is kept here.

The MS-DOS cells boot the DOS of a Windows 98 SE hard disk image (MS-DOS 7.10) inside the
emulator, on macOS only. The image is not kept here either.

## What was replaced in the lines

The lines are as the runs printed them, with four things replaced: the path of each build by
its name; the path of a directory a run kept by `<the run's directory>`; the name of the one
file looked up in the large folder by `SONG.MID`; and, in the reason of the cells Windows does
not run, the name of the launcher these runs were made with on macOS by `the macOS launcher`.

That launcher was not `bench/launch.sh`: the runs were made with a larger one of ours that
gives the emulator the same arguments. `launch.sh` was then checked against it on unpatched
upstream and on patched builds: DRIFT, EXACT and DRIFT on the MS-DOS image print the same bytes
through either, the unit tests the same line, and a memory cell the same line but for the
memory figures.
