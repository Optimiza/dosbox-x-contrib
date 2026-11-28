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
- It holds
  [pull request 6901, "End the program on a divide error, as MS-DOS does, instead of looping forever"](https://github.com/joncampbell123/dosbox-x/pull/6901),
  merged as `15a4e534a`; `unmounted-xcopy-mainai` is merged and still on the fork.
- No pull request of ours is open upstream. The draft 6776 was closed unmerged, by our own
  choice.
- Subjects 1 and 4 and the label slot of subject 2 were merged in
  [pull request 6889](https://github.com/joncampbell123/dosbox-x/pull/6889), subject 13 in
  [pull request 6887](https://github.com/joncampbell123/dosbox-x/pull/6887), and subject 14 in
  [pull request 6901](https://github.com/joncampbell123/dosbox-x/pull/6901). Subject 15 is
  offered as [pull request 6911](https://github.com/joncampbell123/dosbox-x/pull/6911), from
  `unmounted-answers-mainai`, not merged yet. The tag of subject 2 stays on `4e0b6adcf`.
- Every figure in the pages is compared with the commit its page names, whatever `main-ai` is
  today: `4e0b6adcf` for most, `ac2787a42` for subjects 1 and 4 and subject 2's label slot.
- The raw lines of every run are filed outside both repositories, by the work's own record.
  `results/` is made from them.

## The bench's conventions

- The launcher is `launch.sh`, reached through `DIRCACHE_LAUNCHER`; a script's own tests play
  captured runs and start no emulator.
- A Python that a script starts runs with `python3 -I`.
- The lock's folder is `dosbox-x-dircache`, and the one file name of the large folder is
  `SONG.MID`.
- The reporters' archives are named by their issue, never by their file name, and their run is
  a run, not a session: the folder `junktest` and `JUNKTEST_RUNS` in `battery.sh`.
- Every process outside a run is named `app` in `fixtures/judge/load.txt`.
- A comment in a program here says what the program does, never how the work was organised.

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
