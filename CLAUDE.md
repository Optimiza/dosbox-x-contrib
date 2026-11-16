# dosbox-x-dircache

The bench and the account of ten fixes to DOSBox-X's directory cache, offered upstream one
subject per pull request. No emulator source lives here.

**`.claude/rules/writing.md` binds every text a person reads here**: `README.md`, every page
under `docs/`, `bench/README.md`, `results/README.md`, this file, a commit body, and any text
drafted here for a pull request or a comment.

| Path | What it is |
| --- | --- |
| `README.md` | the front page a maintainer reads |
| `docs/` | one page per subject, and the pages the front page links to |
| `bench/` | what anyone runs to get the same lines |
| `results/` | the lines of the runs the pages quote |

## Where the rest lives

- The emulator branches belong to the fork `Optimiza/dosbox-x` and are not pushed there yet.
  The table at the top of `README.md` names the ten.
- Each branch is cut from upstream `joncampbell123/dosbox-x` `main-ai` at `4e0b6adcf`, or from
  the branch it needs. Every figure is compared with that base, whatever `main-ai` is today.
- The instruments are developed in the private repository `scry-dosbox-x`, branch `dircache`,
  folder `tests/dircache`. `bench/` is that folder as committed there, last taken at
  `a25e403`, with the changes listed below.
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

Then check it, from a fresh clone:

- `shellcheck -x -P bench bench/*.sh bench/fixtures/*.sh`;
- every `bench/*.test.sh`: they play captured runs, with no emulator;
- one real cell on unpatched upstream and on a patched build. Its output is compared, byte
  for byte, with what the same commit of the private folder prints.

Move the commit named above in the same change.

## A figure

- Every figure in a page names the file under `results/` or `bench/fixtures/battery` that
  holds its line. A figure with no filed line does not go in.
- A result file is the lines as a run printed them, under a header with the command, the
  host, the date and each build's source commit and sha256.
- `results/README.md` lists the four things replaced in those lines. Replace nothing else.
- A derived figure says how it is derived. The growth per call is the difference between two
  call counts divided by the calls between them, in MB of 1,024 kB.
- To reproduce a figure, run the cell its line names with the builds its file names.
  `bench/README.md` says what each script needs.

When a subject closes: add its result files, write its page from them, and move its row in the
table of `README.md` and in `docs/issues.md`.

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

The repository is pushed only while it is private. Its visibility is its owner's to change.

## Writing

The rules are in `.claude/rules/writing.md`, which loads in every session here.

Commit messages are Conventional Commits, in English, with no trailer.
