# The reporters' cases

Three upstream issues have a case that can be rebuilt from its report. Each stops growing or
comes out whole on the patched builds.

## The cases

| Case | The upstream issue | What the stand-in does |
| --- | --- | --- |
| FC | [issue 6827, memory taken by programs run in folders with many files](https://github.com/joncampbell123/dosbox-x/issues/6827) | runs FC 300 times in a folder of 700 files |
| Lookups | [issue 2485, a test that each of 1,835 files exists crashes](https://github.com/joncampbell123/dosbox-x/issues/2485) | makes a FindFirst per file over 1,835 files |
| XCOPY | [issue 4904, a FindFirst can invalidate the searches of other DTAs](https://github.com/joncampbell123/dosbox-x/issues/4904), after the maintainer's reproduction | copies a tree of 2,520 files |
| Turn about | issue 4904, as its reporter describes it | reads two DTA searches turn about, of 42 and 32 entries |

These are stand-ins written from the reports: the emulator's own FC from a batch file, a
program that looks each file up by name, a tree made for the run.

The reporters' own attached files are run separately, and that result is not in this account
yet.

## Memory held: the FC and lookup cases

The exact-name patch closes both issues. The figures are memory held, in kB, on macOS with
long names off.

| Build | FC: held after 1 → 300 runs | FC: peak resident size at 300 runs | Lookups: held after 1 → 1,835 |
| --- | --- | --- | --- |
| Unpatched | 167,632 → 458,353 | 497,744 | 167,344 → 2,363,522 |
| Exact-name | 165,904 → 181,008 | 220,576 | 167,280 → 168,448 |
| Retention | 165,968 → 181,216 | 220,752 | 167,472 → 168,656 |
| Pull request 6831 | 167,392 → 181,696 | 221,248 | 167,376 → 167,408 |

Source: `battery.sh --real-dos`, cells `fc 700` and `memory synthetic:1835:83 e`, in [results/macos/battery-base-retention-exact-name.txt](../results/macos/battery-base-retention-exact-name.txt); pull request 6831's row in [results/macos/pr6831-reporters-cases.txt](../results/macos/pr6831-reporters-cases.txt).

MS-DOS 7.10 has no memory to read, so it is asked whether the same programs run whole:

| Case on MS-DOS 7.10 | Answer |
| --- | --- |
| FC, 300 runs | 300 of 300 compared |
| Lookups, 1,835 files | 1,835 of 1,835 found |

Source: `battery.sh --real-dos`, cells `realdos fc` and `realdos memprobe`, in the same battery file.

## What arrives: the XCOPY and turn-about cases

Their issue takes the retention. The run is on macOS: XCOPY with long names off, the turn
about with long names on.

| Build | XCOPY: files that arrived, of 2,520 | Turn about: entries each search returned, of 42 and 32 |
| --- | --- | --- |
| Unpatched | 2,065 | 28 and 28 |
| Exact-name | 2,065 | 28 and 28 |
| Retention | 2,520 | 42 and 32 |
| Pull request 6831 | 2,520 | 42 and 32 |
| MS-DOS 7.10 | 2,520 | 42 and 32 |

Source: `battery.sh --real-dos`, cells `xcopy`, `findlife` and `realdos`, in the same battery file; pull request 6831's row in [results/macos/pr6831-reporters-cases.txt](../results/macos/pr6831-reporters-cases.txt) and [results/macos/pr6831-findlife.txt](../results/macos/pr6831-findlife.txt).

MS-DOS has no long names, so its turn-about figure is the same case with long names off.

[Another author's pull request for the same cost (6831)](pr6831.md) has its own page.
