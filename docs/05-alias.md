# 5. No two entries of a folder share a short name

Every entry of a folder now has a short name of its own, and each short name opens its own
file. It is proved on macOS and Windows, and it costs no time a run can see.

## What was wrong

Two entries of a folder could share one 8.3 name, so a program that opened that name could get
the other file. The emulator made such pairs for three reasons:

- it gave a long name an alias that another file already has as its real 8.3 name;
- its numbering could give one alias to several long names that share a prefix;
- with long names off on a case-sensitive volume, two names that differ only in case kept the
  same short name.

## What the fix changes

A folder is read in two rounds: first the names that are their own 8.3 name, then the
generated aliases in the host's order. A real 8.3 name always stays its file's. An alias whose
name is taken takes the next free number, as NTFS does.

The figures are from `dircache-alias`, one commit, `55845db57`, kept as the tag `archive/commit-55845db57` of the fork. It is built on
[subject 3](03-first-read.md), whose two lookup tables it replaces with one set of the short
names read.

The same change on `main-ai` is `024637876`, on the branch `dircache-alias-mainai`; its earlier version, `8b0c52a22`, is the tag `archive/commit-8b0c52a22`. It is offered
as [pull request 6854, "Give each entry of a folder a short name of its own"](https://github.com/joncampbell123/dosbox-x/pull/6854).

## The figures

After the fix no two entries share a short name, and every file opens by its own. The folder
is made of the three cases and judged against the files the host holds:

| What the bench finds, macOS, long names on | Unpatched | Patched |
| --- | --- | --- |
| Short names shared by two entries or more | 17 | none |
| Files no short name opens | 19 | none |
| Real 8.3 names that open another file | 11 | none |

Source: `aliases.sh cases on`, in [results/macos/alias.txt](../results/macos/alias.txt).

With long names off the same three counts fall from the same figures to none.

In the large folder, with long names on:

| The large folder, macOS | Unpatched | Patched |
| --- | --- | --- |
| Short names shared | 1,048 | none |
| Entries that share one | 7,684 | none |
| Entries listed with the size of another file | 6,633 | none |

Source: `aliases.sh folder on <the large folder>`, in [results/macos/alias.txt](../results/macos/alias.txt).

On Windows NTFS gives most aliases, so fewer cases arise there. The branch still closes the two
that do:

| What the bench finds, Windows | Unpatched | Patched |
| --- | --- | --- |
| Real names with a Wine-style shape that open another file | 8 | none |
| Short names shared in a folder where the host named half the files | 2 | none |

Source: `aliases.sh cases on` and `aliases.sh folder on` on that folder, in [results/windows/alias.txt](../results/windows/alias.txt).

Timed against subject 3 alone, its first reads of long names are within the noise: the
`alias-*` cells of [results/macos/first-read-wall.txt](../results/macos/first-read-wall.txt),
read from the later table where a cell was timed twice.

## What a program can notice

An entry that shared a short name gets one of its own, so its alias can differ from upstream's.
A folder with no shared name lists byte for byte as before.

| Listing of the large folder, macOS, long names on | Entries |
| --- | --- |
| Short names that differ from unpatched upstream | 16,500 |
| Of those, outside a family that shared a name upstream | none |

Source: the listings `aliases.sh folder on` reads on both builds, compared entry by entry, derived in the last line of [results/macos/alias.txt](../results/macos/alias.txt).

## How to check it

Judge each build's short names against the host's files:

```sh
bench/aliases.sh cases on <unpatched> <patched>
bench/aliases.sh folder on <a large folder> <unpatched> <patched>
```

[bench/README.md](../bench/README.md) says what each script needs.

## What it needs

[Subject 3](03-first-read.md). Both change how an alias is made, and an existence check
written on upstream's structures would bring back the cost subject 3 removes.

## What is left

**A long-name call on a case-sensitive volume.** With long names on it opens the first name
that matches without case. Each file stays reachable by its own short name.

**A short name a network server makes up.** It could equal another file's real name. NTFS and
VFAT cannot do that, and neither host here has such a server, so it is read and not run.

**The bench's folder of names that end in a dot.** It cannot run on Windows, which strips the
trailing dot, so that case is measured on macOS only.
