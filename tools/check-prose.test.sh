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
mkdir -p "$work/dash" "$work/front" "$work/empty" || exit 3
emdash=$(printf '\342\200\224')
sed "s/@EM_DASH@/$emdash/" "$fixtures/em-dash.md" > "$work/dash/em-dash.md" || exit 3
case "$(cat "$work/dash/em-dash.md")" in *"$emdash"*) ;; *) echo "INVALID: no em dash was written"; exit 3 ;; esac
expect "em dash" 1 "em-dash.md:3: em dashes: 1 (limit 0)
check-prose.sh: 1 page, 1 over a limit" "$work/dash" em-dash.md

# The front page: fourteen paragraphs of fifty words are its limit, a one-word heading is over.
: > "$work/front/README.md"
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14; do
    { cat "$fixtures/paragraph.md"; echo; } >> "$work/front/README.md" || exit 3
done
expect "a front page at its limit passes" 0 "check-prose.sh: 1 page, every one within the limits" "$work/front" README.md
echo "# Over" >> "$work/front/README.md"
expect "words outside tables and code on the front page" 1 "README.md:1: words outside tables and code: 701 (limit 700)
check-prose.sh: 1 page, 1 over a limit" "$work/front" README.md

expect "an empty folder is INVALID" 3 "check-prose.sh: INVALID: no page examined: not in a git repository" "$work/empty"
expect "an unknown option is usage" 2 "check-prose.sh: unknown option: --strict" "$fixtures" --strict 01-within.md
expect "a page that is not there is usage" 2 "check-prose.sh: cannot read the page: absent.md" "$fixtures" absent.md

if [ "$cases" -eq 0 ]; then echo "INVALID: no case ran"; exit 3; fi
echo "$cases cases, $failed failed"
[ "$failed" -eq 0 ]
