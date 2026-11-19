# 12. A path longer than the emulator's arrays answers "path not found" instead of ending it

A host path or an archive path past the length the emulator builds paths in no longer overruns its
stack. The drive answers "path not found", or MOUNT refuses the path. It is proved on macOS and
Windows.

## What was wrong

A drive on a host folder builds the host path of each DOS name in arrays of `CROSS_LEN`, 512
bytes. Nothing checked the length before it copied the mount path and the DOS path into them.

A mount path of 240 bytes or more also overran the drive's info line, a smaller array. A folder
name of 255 characters overran the array that receives a long name, by its terminator.

Three nested folders of 200 characters, reached by their 8.3 names, are enough. So is a zip that
holds such folders.

## What the fix changes

Each place that builds a path now checks that it fits. The cache and the drives answer "path not
found" when it does not, and an entry that does not fit is left out of a listing.

MOUNT refuses a host path that its drive's info line, which a saved state keeps, cannot hold. The
overlay drive checks once per call that its path fits, and for a call that writes, its marker
files too.

The branch is `dircache-longname`, four commits, each of which compiles.

## The figures

A build without the fix ends the emulator on its stack check, or on an access violation on
Windows. With the fix the three cases end normally and the controls list their file:

| Case | Unpatched | Patched |
| --- | --- | --- |
| MOUNT of a very long host path, then `DIR` | ends | survives |
| `DIR`, `TYPE` and `CD` of three nested folders of 200 characters | ends on macOS only | survives |
| A zip of long nested folders, then `DIR /S` | ends | survives |

Source: `longpath.sh on <build>`, in `results/macos/longpath.txt` and `results/windows/longpath.txt`.

Windows cannot hold the nested folders on the host, so that case does not end the emulator there.

## What a program can notice

Nothing for a path that fits: the listings of the folder, the exact-name searches and the DOS
answers read alike on both builds.

For a path that does not fit, a program now gets error 3, "path not found", where it ended the
emulator before.

## How to check it

Run the three cases on the two builds:

```sh
bench/longpath.sh on <build without the fix> <build with the fix>
```

[bench/README.md](../bench/README.md#longpathsh) says what the script needs.

## What it needs

Nothing. The branch stood on upstream `main-ai` at `0dbfdad51` and was merged.

## What is left

**Long names off.** The overlay's `RMDIR` does not list the folder it removes, on this branch and
on `main-ai`, so the check of its emptiness does not hold there.

**Image paths.** The info line of an image drive is cut at its array for an image path of 247
bytes or more, and a saved state of such a drive remounts the cut path.

**The same bug in other places.** `DOS_MakeName`, which copies a guest path of 255 bytes into an
array of 255, and `get_expanded_files` overrun the same way. They are not in this branch.
