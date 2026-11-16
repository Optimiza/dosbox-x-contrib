# 9. An attribute change on Windows does not empty the directory cache

The cause is measured and the branch is not written yet.

## What was wrong

On Windows every change of a file's attributes costs a read of the whole folder, because it
empties the drive's whole cache. It is behind the Windows-only case of
[subject 4](04-dta.md).
