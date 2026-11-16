# dosbox-x-dircache

The bench and the account of a set of fixes to DOSBox-X's directory cache, offered upstream one
subject per pull request. `README.md` is the account a maintainer reads; `bench/` is what anyone
runs to get the same lines; `results/` holds the lines of the runs the account quotes. No
emulator source lives here.

## Where the rest lives

- The emulator branches belong to the fork `Optimiza/dosbox-x` and are not pushed there yet:
  `dircache-exact-name`,
  `dircache-retention`, `dircache-first-read`, `dircache-dta`, `dircache-alias`,
  `dircache-dos-answers`, `dircache-shell-dir`, `dircache-findstring`, `dircache-setattr` and
  `dyncore-cache-reset`. Each is cut from upstream `joncampbell123/dosbox-x` `main-ai` at
  `4e0b6adcf` or from the branch it needs (the table at the top of `README.md`), and every
  figure is compared with that base, whatever `main-ai` is today.
- The instruments are developed in the private repository `scry-dosbox-x`, branch `dircache`,
  folder `tests/dircache`. `bench/` is that folder as committed there, last taken at `a25e403`,
  with the changes listed below. The record of which subjects are delivered, and with what
  figures, is kept in that repository.
- The raw lines of every run are filed outside both repositories, by the work's own record;
  `results/` is made from them.

## Bringing `bench/` up to date

Take `tests/dircache` from a commit of `dircache` (`git archive <sha> tests/dircache`), never
from a working tree, and apply these changes, each of which must match:

1. `launch.sh`, `launch.test.sh` and `fixtures/stub-emulator.sh` exist only here: keep them.
2. `common.sh`: the launcher is `${DIRCACHE_LAUNCHER:-$here/launch.sh}`, called without
   `--mode`; `need_tools` checks that it is executable.
3. `fixtures/stub-dosbox-run.sh` is `fixtures/stub-launcher.sh` here, and `testlib.sh` hands it
   to the scripts through `DIRCACHE_LAUNCHER`.
4. `run.test.sh`: the case of a missing launcher uses `DIRCACHE_LAUNCHER`.
5. `battery.sh` and `README.md`: the launcher's name, the section "What they need", the
   sentence on `launch.test.sh`, and `--file` taking a pattern on a synthetic folder only.
6. `fixtures/battery`: the one file name of the large folder is `SONG.MID`.

Then, from a fresh clone: `shellcheck -x -P bench bench/*.sh bench/fixtures/*.sh`, every
`bench/*.test.sh` (they play captured runs, no emulator), and one real cell on unpatched
upstream and on a patched build whose output is compared, byte for byte, with what the same
commit of the private folder prints. Move the commit named above in the same change.

## A figure

- Every figure in `README.md` names the file under `results/` or `bench/fixtures/battery` that
  holds its line. A figure with no filed line does not go in.
- A result file is the lines as a run printed them, under a header with the command, the host,
  the date and each build's source commit and sha256. `results/README.md` lists the four things
  replaced in those lines; replace nothing else.
- A derived figure says how it is derived (the growth per call is the difference between two
  call counts divided by the calls between them, in MB of 1,024 kB).
- A subject that is not delivered gets one sentence in its section and no figure. When it
  closes: add its result files, write its section from them, and move its row in the table at
  the top and in the issues table.
- To reproduce a figure, run the cell its line names with the builds its file names;
  `bench/README.md` says what each script needs.

## Never committed here

- The MS-DOS disk image, the large folder or any of its file names, and the reporters' own
  attached files.
- A path of anyone's machine, a host name, a user name.
- How the work was organised: sessions, who coordinated them, what they cost.
- The assistant's name, outside the one sentence near the end of `README.md`, this file and
  `.claude/`.

Before a push, search the tree for each of those (`git grep` for a home directory path, the
host names, the private tooling's names), with a pattern known to match beside them as the
control. The repository is pushed only while it is private; its visibility is its owner's to
change.

## Writing

English everywhere. `README.md` is one person's account to another: the point first, the
effect before the name, tables where figures are compared, prose where the story is told. Its
last line is the credits line and stays as it is; the sentence on AI assistance appears once.
Commit messages are Conventional Commits, with no trailer.
