# dosbox-x-dircache

The bench and the account of ten fixes to DOSBox-X's directory cache, offered upstream one
subject per pull request. No emulator source lives here.

**The section "Writing" below binds every text a person reads here**: `README.md`, every page
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
6. `README.md` is this repository's own, written to the rules below: keep it. A fact the
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

These rules bind every text a person reads here, because the reader owes us nothing and gives
a page one minute. They are the owner's rules on writing for a person, made countable.

### The nine rules

1. **The point first.** A page and each of its sections open with one sentence that says what
   the reader gets or what was found, as the effect on someone using the emulator. A function,
   a file or a call is named after that, because a name tells a stranger nothing.
2. **Short.** A sentence carries one fact, and one that can go without losing a fact goes. A
   paragraph is at most three sentences and sixty words, because a longer one is skipped.
3. **No account of the work.** A page says what is true now, never how it was found, and it
   does not stack caveats. The history is in the commits.
4. **A figure lives in a table.** A sentence holds at most two figures, because three cannot
   be compared in a line of prose. A table has at most five columns.
5. **A table of figures names its source.** One line under it, starting with `Source:`, gives
   the command and the file under `results/` or `bench/fixtures/battery` that holds its lines.
6. **One entry per thing, the same fields in the same order.** A reader who has read one entry
   then knows where to look in all of them. The fields are listed below.
7. **A reference names what it is.** An upstream issue or pull request is a link whose text
   says what it is, with its number beside it. A bare number sends the reader to a browser.
8. **Plain words.** Active voice, English, no em dash and no emphasis in capitals. A program's
   own literals, such as `INVALID`, keep their case.
9. **Complete is not long.** Nothing true is dropped to get short: it moves to the page of its
   subject or to one of the pages named below.

### What counts

- A list item is a paragraph, and so is a numbered step.
- A bold label that opens a paragraph is one of its sentences.
- Words are counted outside tables and code blocks. A link counts as its text.
- A table cell is a phrase. Prose moved into a cell to pass the count breaks rule 2.
- A number that names a thing is not a figure: a DOS version, a call such as 4Eh, an issue.

### The front page

`README.md` holds these and nothing else, in at most 700 words outside tables and code blocks:

- what this is, in three sentences;
- the table of the ten subjects, each with its state and a link to its page;
- the problem and the case that showed it, with one small table;
- how it is measured, in five lines with a link;
- how to run the bench, in a short block with a link;
- the sentence on AI assistance, once and as it is;
- the credits line, last and as it is.

### A subject page

Each of `docs/01-exact-name.md` to `docs/10-dyncore-cache-reset.md` has these headings and no
others, in this order. An empty one says "Nothing."

1. What was wrong
2. What the fix changes
3. The figures
4. What a program can notice
5. How to check it
6. What it needs
7. What is left

A subject not delivered yet has the first heading, one sentence of state and no figure.

### A script's entry

Each script in `bench/README.md` has the same fields in the same order: what it shows, how it
is called, what it prints, its exit codes, and what it does not show.

### Where the rest goes

| Page | What it holds |
| --- | --- |
| `docs/method.md` | how a figure is measured and who referees an answer |
| `docs/pr6831.md` | another author's pull request for the same cost, beside subject 2 |
| `docs/reporters.md` | the case of each related upstream issue, on every build |
| `docs/issues.md` | the related upstream issues and what the work does for each |
| `docs/left.md` | what was seen and left |

### Before a push

Take the counts and write them in the last line of the commit body: the words of `README.md`
outside tables and code, the longest paragraph of each page in words, and the pages with a
paragraph over sixty. A page over a limit is not pushed.

The counts are taken by hand or by a script kept outside the repository. No check is wired to
a commit, a push or CI: the owner has not asked for one.

Commit messages are Conventional Commits, in English, with no trailer.
