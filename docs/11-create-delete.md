# 11. A create keeps the directory cache, and a delete removes one entry

A program that creates, deletes or renames files in a large folder no longer makes the emulator
read the whole folder again for each one. The files left keep their short names, so `DEL *.MID`
over long names deletes every file. It is proved on macOS and Windows.

## What was wrong

A create emptied the drive's whole directory cache, and a delete dropped its whole folder. So
the next search read the folder from the host again, once per file. `RD`, `MD` and a rename
dropped the folder in the same way.

The read after a delete numbered the aliases again, so the files left could change short name.
A program that held a short name then opened another file. The shell's `DEL *.MID`, over long
names that share their first letters, deleted half of them and said nothing.

## What the fix changes

Each change edits the one entry it touches, and the rest of the folder stays as it was read.
The branch is `dircache-create-delete`, tag `archive/dircache-create-delete` of the fork, six commits ending at `ee861536f`:

1. A delete removes the one entry.
2. A create of an 8.3 name keeps the cache.
3. A create of a long name keeps it too, and the new file takes the next free alias number.
4. `RD` removes the one directory, with what the cache held under it.
5. `MD` adds the one directory.
6. A rename moves the one entry.

The cache is still emptied where it cannot know the entry: on Windows when the file system made
the alias, in a folder it has not read, and on the overlay and PhysFS drives.

## The figures

After the fix a delete, a create, `RD`, `MD` and a rename leave every other short name in
place. The folder holds eight long names that share their first six letters, beside others, on
macOS:

| What a program does, long names on | Unpatched | Patched |
| --- | --- | --- |
| `DEL *.MID`: files left of 8 | 4 | none |
| A 41h delete of each name a search returned: files left | 4 | none |
| One delete: short names of the other files that move, of 8 | 7 | none |
| Two creates: short names a search returned that open another file, of 8 | 1 | none |
| One `RD`: short names of the other directories that move, of 7 | 7 | none |
| One `MD`: short names of the other directories that move, of 7 | 7 | none |
| One rename: short names of the other files that open another file | 6 | none |

Source: `delete.sh <unpatched> <patched> on`, in [results/macos/create-delete.txt](../results/macos/create-delete.txt).

With long names off the lines read the same, but for the creates and `MD`, which move nothing
there on either build.

On Windows NTFS gives the aliases, so unpatched upstream already moves no short name there. What
changes is the cost, which falls as on macOS, row for row:

| Ten changes in a folder of 10,000 files, Windows | Unpatched | Patched |
| --- | --- | --- |
| Creates: reads of the folder | 11 | 1 |
| Creates: entries read | 110,077 | 10,002 |
| Deletes: reads of the folder | 11 | 1 |
| Deletes: entries read | 110,077 | 10,012 |

Source: ten creates and ten deletes on counter builds of both, in [results/windows/create-delete.txt](../results/windows/create-delete.txt).

## What a program can notice

After a delete, a rename or an `RD`, the entries left keep their short names, where unpatched
upstream numbered them again. A listing after such a change can differ from upstream's, on
purpose.

A search left open inside a directory that `RD` removed, or that was renamed, reads on as
MS-DOS 7.10, MS-DOS 6.22 and FreeDOS 1.4 do: `..`, after a rename the directory's files, then
"no more files". Unpatched upstream returned an entry through another directory.

## How to check it

Run the delete probe on both builds, with long names on and off:

```sh
bench/delete.sh <unpatched> <patched> on
bench/delete.sh <unpatched> <patched> off
```

The `files the host holds at the end` line counts what each build left. The counts of the
Windows table come from counter builds the bench does not carry. [bench/README.md](../bench/README.md) says what each script needs.

## What it needs

Nothing. The figures' branch is cut from upstream `main-ai` at `4e0b6adcf`. The same change
stands on `main-ai` at `0dbfdad51`, its ninth commit being `36f7056be`.

A tenth commit leaves COPY's cache alone. It is offered as [pull request 6875, "Keep the directory cache when a local drive creates, deletes or renames"](https://github.com/joncampbell123/dosbox-x/pull/6875).

Merged with [subject 2](02-retention.md), one line has to set the folder's stamp where an entry
is removed, which git will not ask for.

## What is left

**A rename that changes only the case.** With long names on it never changes the host's case,
on unpatched upstream and on this branch alike. It is upstream's, and named.

**Windows with short names off.** Those cells need a test volume with 8.3 names disabled, a
setting of the host, and are not run.
