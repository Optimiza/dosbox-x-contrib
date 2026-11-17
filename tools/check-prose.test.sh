#!/usr/bin/env bash
# Each limit of check-prose.sh refuses its fixture with the one finding it must print; a page
# at every limit passes; no page is INVALID; an unknown option is usage.
set -u
here=$(cd "$(dirname "$0")" && pwd) || exit 3
check=$here/check-prose.sh
fixtures=$here/fixtures
work=$(mktemp -d "${TMPDIR:-/tmp}/check-prose-test.XXXXXX") || exit 3
trap 'rm -rf "$work"' EXIT
cases=0 failed=0
# Copies of paragraph.md that bring the front-page fixture to its limit of words.
FRONT_PADDING=12

# expect <what it shows> <exit code wanted> <whole output wanted> <directory> <argument>...
expect() {
    local what=$1 want_rc=$2 want=$3 dir=$4 out rc
    shift 4
    out=$(cd "$dir" && "$check" "$@" 2>&1)
    rc=$?
    cases=$((cases + 1))
    if [ "$rc" -eq "$want_rc" ] && [ "$out" = "$want" ]; then
        echo "ok   $what"
    else
        failed=$((failed + 1))
        printf 'FAIL %s: exit %s, wanted %s\n--- printed\n%s\n--- wanted\n%s\n' "$what" "$rc" "$want_rc" "$out" "$want"
    fi
}

refused() {
    expect "$1" 1 "$3
check-prose.sh: 1 page, 1 over a limit" "$fixtures" "$2"
}

expect "a page at every limit passes" 0 "check-prose.sh: 1 page, every one within the limits" "$fixtures" 01-within.md

refused "words in a paragraph" paragraph-words.md \
    "paragraph-words.md:3: words in a paragraph: 61 (limit 60)"
refused "sentences in a paragraph" paragraph-sentences.md \
    "paragraph-sentences.md:3: sentences in a paragraph: 4 (limit 3)"
refused "figures in a sentence" sentence-figures.md \
    "sentence-figures.md:3: figures in a sentence: 3 (limit 2)"
refused "columns in a table" table-columns.md \
    "table-columns.md:3: columns in a table: 6 (limit 5)"
refused "the seven headings in order" 02-headings.md \
    "02-headings.md:7: subject page heading 2: \"The figures\" (limit \"What the fix changes\")"
refused "no third-level heading on a subject page" 03-heading-level.md \
    "03-heading-level.md:7: subject page heading level: 3 (limit 2)"
refused "an upstream number no link names" upstream-number.md \
    "upstream-number.md:3: bare upstream number: 6827 (limit none outside a link that names it)"
refused "an upstream number that opens a sentence" upstream-number-capital.md \
    "upstream-number-capital.md:3: bare upstream number: 6827 (limit none outside a link that names it)"
refused "a bare #number" hash-number.md \
    "hash-number.md:3: bare upstream number: #6822 (limit none outside a link that names it)"

# The em dash is written here, so no committed file carries one.
mkdir -p "$work/dash" "$work/empty" || exit 3
emdash=$(printf '\342\200\224')
sed "s/@EM_DASH@/$emdash/" "$fixtures/em-dash.md" > "$work/dash/em-dash.md" || exit 3
case "$(cat "$work/dash/em-dash.md")" in *"$emdash"*) ;; *) echo "INVALID: no em dash was written"; exit 3 ;; esac
expect "em dash" 1 "em-dash.md:3: em dashes: 1 (limit 0)
check-prose.sh: 1 page, 1 over a limit" "$work/dash" em-dash.md

# A table of figures names its source; a relative link resolves.
refused "a table of figures with no Source: line" table-source.md \
    "table-source.md:3: source of a table of figures: none (limit a Source: line under it)"
expect "a relative link to a page or a heading that is not there" 1 "broken-link.md:3: relative link: absent-page.md (limit a file that exists)
broken-link.md:3: relative link: 01-within.md#no-such-heading (limit a heading that exists)
check-prose.sh: 1 page, 1 over a limit" "$fixtures" broken-link.md

# The front page: the fixture with <n> paragraphs of fifty words where it says @PADDING@.
mkdir -p "$work/front/docs" || exit 3
cp "$fixtures/01-within.md" "$fixtures/paragraph.md" "$work/front/docs/" || exit 3
front() {
    local k
    { sed '/^@PADDING@$/,$d' "$fixtures/front-page.md"
      for ((k = 0; k < $1; k++)); do cat "$fixtures/paragraph.md"; echo; done
      sed '1,/^@PADDING@$/d' "$fixtures/front-page.md"; } > "$work/front/README.md"
}
# variant <awk program>: the unpadded front page changed by it; a program that changes nothing is INVALID.
variant() {
    front 0 || exit 3
    awk "$1" "$work/front/README.md" > "$work/front/variant" || exit 3
    if cmp -s "$work/front/README.md" "$work/front/variant"; then echo "INVALID: a variant changed nothing: $1"; exit 3; fi
    mv "$work/front/variant" "$work/front/README.md" || exit 3
}
front_refused() {
    expect "$1" 1 "README.md:$2
check-prose.sh: 1 page, 1 over a limit" "$work/front" README.md
}

front 0 || exit 3
expect "a front page with every part passes" 0 "check-prose.sh: 1 page, every one within the limits" "$work/front" README.md
front "$FRONT_PADDING" || exit 3
expect "a front page at its limit of words passes" 0 "check-prose.sh: 1 page, every one within the limits" "$work/front" README.md
awk '{ sub(/^A table shows it\.$/, "A table shows it all."); print }' "$work/front/README.md" > "$work/front/variant" || exit 3
cmp -s "$work/front/README.md" "$work/front/variant" && { echo "INVALID: the word was not added"; exit 3; }
mv "$work/front/variant" "$work/front/README.md" || exit 3
expect "words outside tables and code on the front page" 1 "README.md:1: words outside tables and code: 701 (limit 700)
check-prose.sh: 1 page, 1 over a limit" "$work/front" README.md

variant '{ sub(/^## How it is measured$/, "## How we measure"); print }'
front_refused "the front page's sections, in order" '22: front page section 3: "How we measure" (limit "How it is measured")'
variant '{ print } NR == 3 { print ""; print "A second paragraph opens the page." }'
front_refused "one paragraph says what this is" "5: front page opening paragraphs: 2 (limit 1)"
variant '{ sub(/\[A subject of its own\]\(docs\/01-within\.md\)/, "A subject of its own"); print }'
front_refused "each subject links to its page" "9: front page subject row: no page link (limit a link to docs/NN-*.md)"
variant '{ print } NR == 19 { print ""; print "| Calls | Memory held (kB) |"; print "| --- | --- |"; print "| 20 | 4,681,220 |"; print ""; print "Source: the same." }'
front_refused "one small table in the problem" "21: front page tables in the problem: 2 (limit 1)"
variant '{ print } NR == 25 { print "- One more line."; print "- And one more."; print "- And another."; print "- And the last." }'
front_refused "how it is measured, in five lines" "22: front page lines in how it is measured: 6 (limit 5)"
variant 'NR < 31 || NR > 33'
front_refused "a block of commands in running it" "29: front page code blocks in running it: 0 (limit 1)"
variant 'NR != 37'
front_refused "the sentence on AI assistance, once" "1: front page AI line: 0 (limit 1)"
variant '{ print } END { print ""; print "Thanks to all." }'
front_refused "the credits line last" '41: front page last line: not the credits line (limit the line starting "Developed by Optimiza")'

expect "an empty folder is INVALID" 3 "check-prose.sh: INVALID: no page examined: not in a git repository" "$work/empty"
expect "an unknown option is usage" 2 "check-prose.sh: unknown option: --strict" "$fixtures" --strict 01-within.md
expect "a page that is not there is usage" 2 "check-prose.sh: cannot read the page: absent.md" "$fixtures" absent.md

if [ "$cases" -eq 0 ]; then echo "INVALID: no case ran"; exit 3; fi
echo "$cases cases, $failed failed"
[ "$failed" -eq 0 ]
