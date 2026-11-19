# 10. The x86 dynamic core keeps its code-page handlers across a cache reset

A protected-mode program that ends no longer leaves memory behind in the x86 dynamic core. It is
proved on Windows. The macOS build here does not compile that core.

## What was wrong

Each protected-mode program the emulator starts changes the FPU's exception mask, and each change
resets the code cache of the x86 dynamic core. `cache_reset`, in
`src/cpu/core_dyn_x86/cache.h`, then dropped its free code-page handlers and allocated new ones,
so every program left about 6,400 kB behind.

It is outside the directory cache. It is carried here because the Windows proof of
[subject 2](02-retention.md) rests on it.

[Issue 6794, "Dynamic cores: free the old code pages when the cache is reset"](https://github.com/joncampbell123/dosbox-x/issues/6794)
reports the same leak upstream, and is open.

## What the fix changes

`cache_reset` keeps the free handlers it already has. The branch is `dyncore-cache-reset`, tag `archive/dyncore-cache-reset` of the fork, one
commit, `e1d62e10d`.

The patch attached to issue 6794 fixes it another way. By reading, it deletes the handlers in use
a second time.

## The figures

After the fix the memory held stops growing with each child program. The run is one child per
call, each ending with a search open, in a folder of 100 files:

| Memory held after the children, Windows | Unpatched (kB) | Patched (kB) |
| --- | --- | --- |
| After 1 child | 201,412 | 188,216 |
| After 20 children | 323,028 | 189,860 |

Source: `memory.sh <build> synthetic:100:83 off c <1|20>`, in [results/windows/dyncore.txt](../results/windows/dyncore.txt).

Each further child leaves 6,401 kB on unpatched upstream and 87 kB on the patched build. Each
figure is the growth between the two rows divided by the children between them.

Merged with [subject 2](02-retention.md), memory after children that end with a search open
stays flat on Windows too:

| Memory held, Windows, 50,000 files | Retention (kB) | Retention and this branch (kB) |
| --- | --- | --- |
| After 1 child | 233,048 | 220,168 |
| After 20 children | 353,860 | 220,180 |

Source: `memory.sh <build> synthetic:50000:83 off c <1|20>`, in [results/windows/dyncore.txt](../results/windows/dyncore.txt).

## What a program can notice

Nothing but the memory. The emulator's unit tests pass on the patched build and on its merge
with subject 2.

## How to check it

Read the memory after one child and after twenty:

```sh
bench/memory.sh <build> synthetic:100:83 off c 1
bench/memory.sh <build> synthetic:100:83 off c 20
```

[bench/README.md](../bench/README.md) says what each script needs.

## What it needs

Nothing. The figures' commit is cut from upstream `main-ai` at `4e0b6adcf`. The same change
stands on `main-ai` at `0dbfdad51` as `4458a606d`, merged as [pull request 6874, "Keep the x86 dynamic core's code page handlers across a cache reset"](https://github.com/joncampbell123/dosbox-x/pull/6874).

## What is left

**The other dynamic core.** It has the same leak by reading, in `cache_reset` of
`src/cpu/core_dynrec/cache.h`. It is reached only through the KVM core, which neither host here
can run, so it is named and not changed.

**The link stubs.** By reading, `cache_reset` writes its link stubs without `cache_remap_rw()`
where the code cache is kept read and execute. That is the same before and after this branch.
