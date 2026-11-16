# 10. The x86 dynamic core keeps its code-page handlers across a cache reset

The cause is measured and the branch is not written yet.

## What was wrong

On Windows every child process that ends leaves memory behind. It is outside the directory
cache, and it is what does not hold in the proof of [subject 2](02-retention.md).
