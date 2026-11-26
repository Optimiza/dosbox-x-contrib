# dosbox-x-contrib

Fixes offered to DOSBox-X, one subject per pull request, with the bench that measured each.
The first set is the directory cache. No emulator source lives here.

**`.claude/rules/writing.md` binds every text a person reads here**: `README.md`, every page
under `docs/`, `bench/README.md`, `results/README.md`, this file, a commit body, and any text
drafted here for a pull request or a comment.

| Path | What it is |
| --- | --- |
| `README.md` | the front page a maintainer reads |
| `docs/` | one page per subject, and the pages the front page links to |
| `bench/` | what anyone runs to get the same lines |
| `results/` | the lines of the runs the pages quote |
| `tools/` | the check of the writing rules, and its test |

## Where the rest lives

- The emulator branches belong to the fork `Optimiza/dosbox-x`. The three branches merged
  upstream (`dircache-create-delete-mainai`, `dos-answers-path-mainai` and `dos-answers-cd-mainai`) are
  removed from it.
- `dta-searches-mainai` and `unmounted-drive-mainai` are merged and still on the fork. The
  branches kept there are `dircache-exact-name-mainai`, whose two commits stand in
  `dta-searches-mainai` now, and `dircache-dos-paths`, not offered.
- Upstream `main-ai` holds the merges of
  [pull request 6877, "Answer INT 21h 4Eh and the label and root searches as MS-DOS does"](https://github.com/joncampbell123/dosbox-x/pull/6877)
  and [pull request 6878, "Answer a search on a CD image as MSCDEX does"](https://github.com/joncampbell123/dosbox-x/pull/6878).
- It also holds the merges of
  [pull request 6887, "Answer "Invalid drive specification" instead of ending the emulator on an unmounted drive"](https://github.com/joncampbell123/dosbox-x/pull/6887)
  and [pull request 6889, "Answer a find call from the search it belongs to, as MS-DOS does"](https://github.com/joncampbell123/dosbox-x/pull/6889).
- No pull request of ours is open upstream. The draft 6776 was closed unmerged, by our own
  choice.
- Subjects 1 and 4 and the label slot of subject 2 were merged in pull request 6889, and
  subject 13 in pull request 6887. The tag of subject 2 stays on `4e0b6adcf`.
- Every figure in the pages is compared with `4e0b6adcf`, whatever `main-ai` is today, except
  those of subjects 1 and 4 and of subject 2's label slot, which are compared with `ac2787a42`.
- The instruments are developed in [`scry-mcp/scry-dosbox-x`](https://github.com/scry-mcp/scry-dosbox-x), branch `dircache`,
  folder `tests/dircache`. `bench/` is that folder as committed there, last taken at
  `b829ddc`, with the changes listed below.
- The record of which subjects are delivered, and with what figures, is kept in that
  repository.
- The raw lines of every run are filed outside both repositories, by the work's own record.
  `results/` is made from them.

## Bringing `bench/` up to date

Take `tests/dircache` from a commit of `dircache` (`git archive <sha> tests/dircache`), never
from a working tree. Then apply these changes, each of which must match:

1. `launch.sh`, `launch.test.sh` and `fixtures/stub-emulator.sh` exist only here: keep them.
2. `common.sh`: the launcher is `${DIRCACHE_LAUNCHER:-$here/launch.sh}`, called without
   `--mode`. `need_tools` checks that it is executable.
3. `fixtures/stub-dosbox-run.sh` is `fixtures/stub-launcher.sh` here, and `testlib.sh` hands
   it to the scripts through `DIRCACHE_LAUNCHER`.
4. `run.test.sh`: the case of a missing launcher uses `DIRCACHE_LAUNCHER`.
5. `battery.sh`: the launcher's name, in the reason of a cell that is not run.
6. `README.md` is this repository's own, written to the writing rules: keep it. A fact the
   private folder's page gained goes into the entry of its script.
7. `fixtures/battery`: the one file name of the large folder is `SONG.MID`.
8. `battery.sh` and `battery.test.sh`: the lock's folder is `dosbox-x-dircache`, never the
   private repository's name.
9. The reporters' archives are named by their issue, never by their file name, and their run is
   a run, not a session: `JUNKTEST_RUNS` in `battery.sh`, and the reporters' folder
   `junktest` in its tests and recordings.
10. The first comment lines of `p5probe.c`, `p5rep.c` and `attrcost.test.sh` say what the program
    does, never how the work was organised, and no comment names a run by its place in that
    work (`overlay.sh`'s answer of the three DOS).
11. `fixtures/judge/load.txt`: every process outside the run is named `app`.
12. `batch.sh` and the tests that start `judge.py` or `analyze.py` call `python3 -I`.
13. `common.sh` reads the emulator's exit code from the report line `launch.sh: exit code:`,
    and `fixtures/stub-launcher.sh` writes it so. `launch.test.sh` checks that `launch.sh`
    writes it.

Then check it, from a fresh clone:

- `shellcheck -x -P bench bench/*.sh bench/fixtures/*.sh bench/xcomsim/*.sh`;
- every `bench/*.test.sh`: they play captured runs, with no emulator;
- one real cell on unpatched upstream and on a patched build. Its output is compared, byte
  for byte, with what the same commit of the private folder prints.

14. `dtadump.c`, `drift.c`, `memprobe.c`, `memory.sh`, their tests and fixtures
    (`fixtures/dtadump-open-wild`, `fixtures/drift-star`, `fixtures/drift-moved`,
    `fixtures/drift-reused`, `fixtures/dtadump-fcb-star`, `fixtures/memory-kept`,
    `fixtures/memory-label`) and `bench/README.md` carry cases made here (`3ad07e6`, `7e9b1c0`,
    `85e61ad`, `c35f343`, `5c38bc8`, `35a81e8`, `615f753`, `c3385f4`, `b82e033`, `98815fb`), which
    the private folder's branch does not hold: carry them over, or the refresh drops them.

Move the commit named above in the same change.

## A figure

- Every figure in a page names the file under `results/` or `bench/fixtures/battery` that
  holds its line. A figure with no filed line does not go in.
- A result file is the lines as a run printed them, under a header with the command, the
  host, the date and each build's source commit and sha256.
- `results/README.md` lists the things replaced in those lines. Replace nothing else.
- A derived figure says how it is derived. The growth per call is the difference between two
  call counts divided by the calls between them, in MB of 1,024 kB.
- To reproduce a figure, run the cell its line names with the builds its file names.
  `bench/README.md` says what each script needs.

When a subject closes: add its result files, write its page from them, and move its row in the
table of `README.md`.

## Never committed here

- The MS-DOS disk image, the large folder or any of its file names, and the reporters' own
  attached files.
- A path of anyone's machine, a host name, a user name.
- How the work was organised: sessions, who coordinated them, what they cost.
- The assistant's name, outside the one sentence near the end of `README.md`, this file and
  `.claude/`.

Before a push, search the tree for each of those with `git grep`: a home directory path, the
host names, the private tooling's names. Run a pattern known to match beside them as the
control.

The repository is public. Each push to it is its owner's word.

## Writing

The rules are in `.claude/rules/writing.md`, which loads in every session here.

`tools/check-prose.sh` refuses a page over one of their limits, and `.githooks/pre-commit` runs
it on the staged pages at every commit. A fresh clone turns the hook on with
`git config core.hooksPath .githooks`. Its test is `bash tools/check-prose.test.sh`.

Commit messages are Conventional Commits, in English, with no trailer.
