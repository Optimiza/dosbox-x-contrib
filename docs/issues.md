# The related upstream issues

Nine upstream issues touch this work. The first table says what the work does for each, and
the second which subject and which offered pull request covers which.

| Upstream issue | State upstream, read 2026-11-18 | What the work does for it |
| --- | --- | --- |
| [Issue 6823, "FindFirst copies and retains the whole directory on every call"](https://github.com/joncampbell123/dosbox-x/issues/6823): the copy | open | covered, measured ([subject 1](01-exact-name.md)) |
| The same issue: the retention | open | covered upstream by [pull request 6831, "Release directory search snapshots when searches end"](https://github.com/joncampbell123/dosbox-x/pull/6831), merged; subject 2 measures another design ([subject 2](02-retention.md)) |
| The same issue: the first read | open | covered, measured ([subject 3](03-first-read.md)) |
| [Issue 6827, "DOSBox-X consumes huge amounts of memory when running certain programs in directories with lots of files"](https://github.com/joncampbell123/dosbox-x/issues/6827) | open | covered, measured by a stand-in and by the reporter's own batch file, on macOS and Windows (subject 1) |
| [Issue 4904, "FindFirst (int21,4e) can invalidate handles stored in other DTA blocks"](https://github.com/joncampbell123/dosbox-x/issues/4904) | open | covered, measured by two stand-ins on macOS and Windows (subject 2); pull request 6852 bears on it |
| [Issue 2485, "Cycle with test if file exists in directory with 1835 files will crash"](https://github.com/joncampbell123/dosbox-x/issues/2485) | closed | the memory behind it: covered, measured by a stand-in on macOS and Windows and by the reporter's own program (subject 1) |
| [Issue 3572, "Very slow response when querying a large directory"](https://github.com/joncampbell123/dosbox-x/issues/3572) | open | covered, measured on macOS (subject 3) |
| [Issue 5039, "Large number of files in dir stalls dosbox-x"](https://github.com/joncampbell123/dosbox-x/issues/5039) | closed | its later comment's case: covered, measured on macOS (subject 3) |
| [Issue 6794, "Dynamic cores: free the old code pages when the cache is reset"](https://github.com/joncampbell123/dosbox-x/issues/6794) | open | covered, measured on Windows; its attached patch is another fix (subject 10) |
| [Issue 6851, "main-ai ends directory searches that MS-DOS continues"](https://github.com/joncampbell123/dosbox-x/issues/6851) | open | reported by this work; pull request 6852, merged, fixes it |
| [Issue 6808, "main-ai no longer builds on macOS or Visual Studio since the IDE commit"](https://github.com/joncampbell123/dosbox-x/issues/6808) | closed | nothing to do here: every build carries its fix |

Source: each issue's page upstream, read with `gh issue view` on the date the column names; the figures are on each subject's page and on [the page of the reporters' cases](reporters.md).

| # | Subject | Upstream issues it covers | Offered as |
| --- | --- | --- | --- |
| 1 | [A search for one exact name does not copy the whole directory](01-exact-name.md) | issues 6823, 6827 and 2485 | not offered |
| 2 | [A search's copy is released without ending a live search](02-retention.md) | issues 6823 and 4904 | superseded by pull request 6831 and [pull request 6852, "Keep a search alive when its DTA is reused or its child process ends"](https://github.com/joncampbell123/dosbox-x/pull/6852), for issue 6851 |
| 3 | [The first read of a large folder](03-first-read.md) | issues 6823, 3572 and 5039 | [pull request 6853, "Read a large folder without comparing every name with every other"](https://github.com/joncampbell123/dosbox-x/pull/6853) |
| 4 | [A find call does not disturb another search's DTA](04-dta.md) | none: its defects have no issue upstream | not offered: to be redone on `main-ai`, which has pull request 6852 now |
| 5 | [No two entries of a folder share a short name](05-alias.md) | none | [pull request 6854, "Give each entry of a folder a short name of its own"](https://github.com/joncampbell123/dosbox-x/pull/6854) |
| 6 | [The emulator's DOS answers as MS-DOS does](06-dos-answers.md) | none | not offered |
| 9 | [An attribute change on Windows does not empty the directory cache](09-setattr.md) | none | not offered |
| 10 | [The x86 dynamic core keeps its code-page handlers across a cache reset](10-dyncore-cache-reset.md) | issue 6794 | not offered |
| 11 | [A create keeps the directory cache, and a delete removes one entry](11-create-delete.md) | none | not offered |

Source: each pull request's page upstream, read with `gh pr view` on the same date; each is open on `main-ai`.

The fix for issue 6808 is
[pull request 6822, "fix(ide): give the ATAPI sector counters the type of the ATA ones"](https://github.com/joncampbell123/dosbox-x/pull/6822).
