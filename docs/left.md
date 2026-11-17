# What was seen and left

Six things showed in the runs that no fix here closes. Each entry says what was seen, its
measured line and what becomes of it, so that it is known.

## FC leaves memory behind whatever the folder holds

300 runs of the emulator's FC leave about 15 MB on every build. It is not the directory
cache's, and it was not looked for.

| Build and folder | Memory held after 300 runs (kB) |
| --- | --- |
| Unpatched upstream, a folder with no other file | 182,128 |
| Exact-name, the folder of 700 files | 181,008 |
| Retention, the folder of 700 files | 181,216 |

Source: `fc.sh <base> 0 off 300`, in [results/macos/pr6831-reporters-cases.txt](../results/macos/pr6831-reporters-cases.txt); cells `fc 700 300`, in [results/macos/battery-base-retention-exact-name.txt](../results/macos/battery-base-retention-exact-name.txt).

## With long names on, a search matches by a wider rule than MS-DOS

A 4Eh search honours a `*` followed by more characters, and matches the long name too. It is
the emulator's long-name rule, which no real DOS referees, and it is left as it is.

| PATLIST, 15 patterns, on macOS | Digest of the list |
| --- | --- |
| Every build, long names off | `dfc20fe25661` |
| MS-DOS 7.10 | `dfc20fe25661` |
| Every build, long names on | `a8e695a8baca` |

Source: `battery.sh --real-dos`, cells `patlist` and `realdos patlist`, in [results/macos/battery-base-retention-exact-name.txt](../results/macos/battery-base-retention-exact-name.txt).

## Two DRIFT lines differ from MS-DOS on every build

A search reads a folder that changed under it otherwise than MS-DOS does.

| Case | The builds return | MS-DOS 7.10 returns | What becomes of it |
| --- | --- | --- | --- |
| `folder-gained-files` | 7 with the exact-name patch | 8 | half closed by [subject 1](01-exact-name.md) |
| `folder-lost-the-entry` | 5 more | none | the order a changed directory is read in, left |

Source: `battery.sh --real-dos --raw`, calls `drift.sh` and `realdos.sh drift`, in [drift_base-build_off.txt](../bench/fixtures/battery/drift_base-build_off.txt) and [realdos_drift_off.txt](../bench/fixtures/battery/realdos_drift_off.txt).

## The remount case answers by host on another author's build

The build of [another author's pull request for the same cost (6831)](pr6831.md) answers one
case differently on each host. The case needs the host's allocator to reuse an address, so no
claim rests on it.

| Host | A search on the remounted drive returns |
| --- | --- |
| macOS | 3 of 32 |
| Windows | 32 of 32 |

Source: `findlife.sh`, case `remount`, in [results/macos/pr6831-findlife.txt](../results/macos/pr6831-findlife.txt) and [results/windows/pr6831-findlife.txt](../results/windows/pr6831-findlife.txt).

## On Windows the unpatched build passes the bench's memory limit

In the large folder the unpatched build is killed before it ends 20 `fopen` calls. That is the
limit doing its work, and the cell is read from 1 and 5 calls.

| Cell, on Windows | Result |
| --- | --- |
| `memory real f 20 base` | killed at 6,291,456 kB of working set, INVALID |

Source: `battery.sh`, in [results/windows/battery-base-retention-exact-name.txt](../results/windows/battery-base-retention-exact-name.txt).

[The entry of `memory.sh`](../bench/README.md#memorysh) describes the limit.

## On Windows `ties.sh` is INVALID

No two entries share a short name there, because NTFS names the aliases. It is the script's
answer on such a host, not a failure.
