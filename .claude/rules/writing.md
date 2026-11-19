# Writing: a person reads every page

These rules bind every text a person reads here, because the reader owes us nothing and gives
a page one minute. They are the owner's rules on writing for a person, made countable.

They bind `README.md`, every page under `docs/`, `bench/README.md`, `results/README.md`,
`CLAUDE.md`, this file, a commit body, and any text drafted here for a pull request or a
comment.

## The nine rules

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

## What counts

- A list item is a paragraph, and so is a numbered step.
- A bold label that opens a paragraph is one of its sentences.
- Words are counted outside tables and code blocks. A link counts as its text.
- A table cell is a phrase. Prose moved into a cell to pass the count breaks rule 2.
- A number that names a thing is not a figure: a DOS version, a call such as 4Eh, an issue.
- A table column headed `#` or `Exit code` holds names, so its numbers are not figures.

## The front page

`README.md` holds these and nothing else, in at most 700 words outside tables and code blocks:

- what this is, in three sentences;
- the table of the subjects, each with its state and a link to its page;
- the problem and the case that showed it, with one small table;
- how it is measured, in five lines with a link;
- how to run the bench, in a short block with a link;
- the sentence on AI assistance, once and as it is;
- the credits line, last and as it is.

The four sections after the opening are headed, in order: "The subjects", "The problem, and the
case that showed it", "How it is measured" and "Running it".

## A subject page

Each subject page, `docs/NN-*.md`, has these headings and no others, in this order. An empty one says "Nothing."

1. What was wrong
2. What the fix changes
3. The figures
4. What a program can notice
5. How to check it
6. What it needs
7. What is left

A subject not delivered yet has the first heading, one sentence of state and no figure.

## A script's entry

Each script in `bench/README.md` has the same fields in the same order: what it shows, how it
is called, what it prints, its exit codes, and what it does not show.

## Where the rest goes

| Page | What it holds |
| --- | --- |
| `docs/method.md` | how a figure is measured and who referees an answer |
| `docs/pr6831.md` | another author's pull request for the same cost, beside subject 2 |
| `docs/reporters.md` | the case of each related upstream issue, on every build |
| `docs/left.md` | what was seen and left |

## Before a push

Take the counts and write them in the last line of the commit body: the words of `README.md`
outside tables and code, the longest paragraph of each page in words, and the pages with a
paragraph over sixty. A page over a limit is not pushed.

The counts are taken by hand or by a script kept outside the repository.

`tools/check-prose.sh` enforces the limits of this file at every commit, through
`.githooks/pre-commit`. It writes each limit once, at its top, so a limit changed here is
changed there in the same commit. The CI workflow runs it too, on every push and pull request.
