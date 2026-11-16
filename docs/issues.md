# The related upstream issues

Seven upstream issues touch this work. The table says what the work does for each, and which
subject does it.

| Upstream issue | State upstream | What the work does for it |
| --- | --- | --- |
| [6823, FindFirst copies and retains the whole directory on every call](https://github.com/joncampbell123/dosbox-x/issues/6823): the copy | open | covered, measured ([subject 1](01-exact-name.md)) |
| The same issue: the retention | open | covered, measured ([subject 2](02-retention.md)) |
| The same issue: the first read | open | not yet ([subject 3](03-first-read.md)) |
| [6827, DOSBox-X consumes huge amounts of memory when running certain programs in directories with lots of files](https://github.com/joncampbell123/dosbox-x/issues/6827) | open | covered, measured by a stand-in on macOS (subject 1) |
| [4904, FindFirst (int21,4e) can invalidate handles stored in other DTA blocks](https://github.com/joncampbell123/dosbox-x/issues/4904) | open | covered, measured by two stand-ins on macOS; not run on Windows yet (subject 2) |
| [2485, Cycle with test if file exists in directory with 1835 files will crash](https://github.com/joncampbell123/dosbox-x/issues/2485) | closed | the memory behind it: covered, measured by a stand-in on macOS (subject 1) |
| [3572, Very slow response when querying a large directory](https://github.com/joncampbell123/dosbox-x/issues/3572) | open | not yet (subject 3) |
| [5039, Large number of files in dir stalls dosbox-x](https://github.com/joncampbell123/dosbox-x/issues/5039) | closed | not yet (subject 3) |
| [6808, main-ai no longer builds on macOS or Visual Studio since the IDE commit](https://github.com/joncampbell123/dosbox-x/issues/6808) | closed | nothing to do here: every build carries its fix |

The fix for the last one is
[pull request 6822, "fix(ide): give the ATAPI sector counters the type of the ATA ones"](https://github.com/joncampbell123/dosbox-x/pull/6822).

The stand-ins and their figures are on [the page of the reporters' cases](reporters.md).
