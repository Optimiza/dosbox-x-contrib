# 7. The shell's `DIR` prints the free space of the drive it listed

In progress.

## What was wrong

After a search that finds nothing, `DIR` can print the free space of another drive. The shell
takes the drive of its free-space line from the DTA after the search.
