# The related upstream issues

Eight upstream issues touch this work. The first table says what the work does for each, and
the second which pull request covers which.

| Upstream issue | State upstream | What the work does for it |
| --- | --- | --- |
| [Issue 6823, "FindFirst copies and retains the whole directory on every call"](https://github.com/joncampbell123/dosbox-x/issues/6823): the copy | open | covered, measured ([subject 1](01-exact-name.md)) |
| The same issue: the retention | open | covered, measured ([subject 2](02-retention.md)) |
| The same issue: the first read | open | covered, measured ([subject 3](03-first-read.md)) |
| [Issue 6827, "DOSBox-X consumes huge amounts of memory when running certain programs in directories with lots of files"](https://github.com/joncampbell123/dosbox-x/issues/6827) | open | covered, measured by a stand-in and by the reporter's own batch file, on macOS and Windows (subject 1) |
| [Issue 4904, "FindFirst (int21,4e) can invalidate handles stored in other DTA blocks"](https://github.com/joncampbell123/dosbox-x/issues/4904) | open | covered, measured by two stand-ins on macOS and Windows (subject 2) |
| [Issue 2485, "Cycle with test if file exists in directory with 1835 files will crash"](https://github.com/joncampbell123/dosbox-x/issues/2485) | closed | the memory behind it: covered, measured by a stand-in on macOS and Windows and by the reporter's own program (subject 1) |
| [Issue 3572, "Very slow response when querying a large directory"](https://github.com/joncampbell123/dosbox-x/issues/3572) | open | covered, measured on macOS (subject 3) |
| [Issue 5039, "Large number of files in dir stalls dosbox-x"](https://github.com/joncampbell123/dosbox-x/issues/5039) | closed | its later comment's case: covered, measured on macOS (subject 3) |
| [Issue 6794, "Dynamic cores: free the old code pages when the cache is reset"](https://github.com/joncampbell123/dosbox-x/issues/6794) | open | covered, measured on Windows; its attached patch is another fix (subject 10) |
| [Issue 6808, "main-ai no longer builds on macOS or Visual Studio since the IDE commit"](https://github.com/joncampbell123/dosbox-x/issues/6808) | closed | nothing to do here: every build carries its fix |

Source: each issue's page upstream, read when this page last changed; the figures are on each subject's page and on [the page of the reporters' cases](reporters.md).

| # | Pull request | Upstream issues it covers |
| --- | --- | --- |
| 1 | [A search for one exact name does not copy the whole directory](01-exact-name.md) | issues 6823, 6827 and 2485 |
| 2 | [A search's copy is released without ending a live search](02-retention.md) | issues 6823 and 4904 |
| 3 | [The first read of a large folder](03-first-read.md) | issues 6823, 3572 and 5039 |
| 4 | [A find call does not disturb another search's DTA](04-dta.md) | none: its defects have no issue upstream |
| 5 | [No two entries of a folder share a short name](05-alias.md) | none |
| 6 | [The emulator's DOS answers as MS-DOS does](06-dos-answers.md) | none |
| 9 | [An attribute change on Windows does not empty the directory cache](09-setattr.md) | none |
| 10 | [The x86 dynamic core keeps its code-page handlers across a cache reset](10-dyncore-cache-reset.md) | issue 6794 |
| 11 | [A create keeps the directory cache, and a delete removes one entry](11-create-delete.md) | none |

The fix for issue 6808 is
[pull request 6822, "fix(ide): give the ATAPI sector counters the type of the ATA ones"](https://github.com/joncampbell123/dosbox-x/pull/6822).
