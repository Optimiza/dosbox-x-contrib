#!/usr/bin/env bash
# Refuses a page a person reads that breaks a countable limit of the writing rules.
# bash and awk because the bench already needs them; python3 is not something a clone needs.
set -u

# The limits of the writing rules, written here once.
FRONT_PAGE_WORDS=700
PARAGRAPH_WORDS=60
PARAGRAPH_SENTENCES=3
SENTENCE_FIGURES=2
TABLE_COLUMNS=5
SUBJECT_HEADINGS='What was wrong|What the fix changes|The figures|What a program can notice|How to check it|What it needs|What is left'
# A link that names an upstream number says what it is in at least this many words.
LINK_WORDS=3

usage() {
    cat <<EOT
usage: check-prose.sh [<page>...]

Refuses a page that breaks a limit of the writing rules: one line per finding, with its
file, line, the limit, the count and the limit's value.

  <page>   a markdown page. None given: every tracked page a person reads, in the git
           repository holding the current directory (README.md, CLAUDE.md, docs/,
           bench/README.md, results/README.md, .claude/rules/)

The limits:
  words outside tables and code   $FRONT_PAGE_WORDS on README.md, named so
  words in a paragraph            $PARAGRAPH_WORDS; a list item is a paragraph
  sentences in a paragraph        $PARAGRAPH_SENTENCES; a bold label is a sentence
  figures in a sentence           $SENTENCE_FIGURES; a number that names a thing is not one
  columns in a table              $TABLE_COLUMNS
  subject page headings           the seven, in order, or the first alone (NN-*.md)
  bare upstream number            an issue or pull request number no link names in
                                  $LINK_WORDS words or more, or a bare #number
  em dash                         none

exit: 0 every page within the limits | 1 a page over a limit | 2 usage
      3 INVALID: no page was examined, or awk failed on one
EOT
}

say() { echo "check-prose.sh: $1"; }

pages=()
while [ $# -gt 0 ]; do
    case "$1" in
        --help) usage; exit 0 ;;
        -*) say "unknown option: $1" >&2; exit 2 ;;
        *) pages+=("$1"); shift ;;
    esac
done

if [ ${#pages[@]} -eq 0 ]; then
    command -v git > /dev/null || { say "INVALID: no page examined: git is not on the PATH"; exit 3; }
    top=$(git rev-parse --show-toplevel 2> /dev/null) || { say "INVALID: no page examined: not in a git repository"; exit 3; }
    cd "$top" || exit 3
    list=$(git ls-files -- README.md CLAUDE.md 'docs/*.md' bench/README.md results/README.md '.claude/rules/*.md') || { say "INVALID: git ls-files failed"; exit 3; }
    while IFS= read -r p; do
        [ -n "$p" ] && pages+=("$p")
    done <<< "$list"
fi
if [ ${#pages[@]} -eq 0 ]; then
    say "INVALID: no page examined: none is tracked here"
    exit 3
fi
for p in "${pages[@]}"; do
    [ -f "$p" ] && [ -r "$p" ] || { say "cannot read the page: $p" >&2; exit 2; }
done

read -r -d '' PROGRAM <<'AWK'
function is_fence(s) { return s ~ /^[ \t]*(```|~~~)/ }
function is_heading(s) { return s ~ /^##?#?#?#?#?[ \t]/ }
function is_item(s) { return s ~ /^[ \t]*([-*+]|[0-9]+\.)[ \t]+/ }
function is_row(s) { return s ~ /^[ \t]*\|/ }
function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }

function finding(at, what, found, limit) {
    printf "%s:%d: %s: %s (limit %s)\n", page, at, what, found, limit
    over++
}

# [label](target) becomes label.
function unlink(s,   out, m) {
    out = ""
    while (match(s, /\[[^]]*\]\([^)]*\)/)) {
        m = substr(s, RSTART, RLENGTH)
        sub(/\]\(.*$/, "", m)
        out = out substr(s, 1, RSTART - 1) substr(m, 2)
        s = substr(s, RSTART + RLENGTH)
    }
    return out s
}

function count_words(s,   n, w, i, c) {
    n = split(s, w, /[ \t\n]+/)
    c = 0
    for (i = 1; i <= n; i++) if (w[i] ~ /[A-Za-z0-9]/) c++
    return c
}

function columns(s,   n, f) {
    gsub(/\\\|/, "x", s)
    gsub(/`[^`]*`/, "x", s)
    s = trim(s)
    sub(/^\|+/, "", s)
    sub(/\|+$/, "", s)
    return split(s, f, /\|/)
}

# The numbers of a sentence that measure something. One names a thing and is no figure when it
# is a DOS or Windows version, 8.3, INT 21, or follows "issue", "pull request", "subject" or
# "rule", alone or in a list joined by "and", "or" or "to".
function figures(s,   n, off, st, m, len, p, ok, nx, before, refend) {
    n = 0; off = 0; refend = 0
    while (match(substr(s, off + 1), /[0-9][0-9,]*(\.[0-9]+)?/)) {
        st = off + RSTART
        m = substr(s, st, RLENGTH)
        if (st > 1 && substr(s, st - 1, 1) ~ /[A-Za-z0-9~]/) { off = st; continue }
        ok = 0
        for (len = length(m); len >= 1; len--) {
            p = substr(m, 1, len)
            if (p !~ /^[0-9][0-9,]*(\.[0-9]+)?$/) continue
            nx = substr(s, st + len, 1)
            if (nx ~ /[A-Za-z0-9]/) continue
            if (nx == "-" && substr(s, st + len + 1, 1) ~ /[a-z]/) continue
            ok = 1
            break
        }
        if (!ok) { off = st; continue }
        off = st + len - 1
        before = substr(s, 1, st - 1)
        # "21," is "21" before a comma.
        sub(/,+$/, "", p)
        len = length(p)
        if (p == "8.3") continue
        if (before ~ /MS-DOS $/ && (p == "7" || p == "7.10")) continue
        if (before ~ /Windows $/ && (p == "98" || p == "11")) continue
        if (before ~ /(INT|int) $/ && p == "21") continue
        if (p ~ /^[0-9]+$/) {
            if (before ~ /(pull requests?|issues?|subjects?|rules?) $/ ||
                (refend > 0 && substr(s, refend, st - refend) ~ /^,? (and|or|to) $/)) {
                refend = st + len
                continue
            }
        }
        refend = 0
        n++
    }
    return n
}

function measure(kind, at, text,   body, flat, q, parts, i, nparts, sent, held) {
    body = unlink(text)
    if (kind == "heading") sub(/^#+[ \t]+/, "", body)
    if (kind == "item") sub(/^[ \t]*([-*+]|[0-9]+\.)[ \t]+/, "", body)
    words = count_words(body)
    total += words
    if (kind == "heading") return
    if (words > PARAGRAPH_WORDS) finding(at, "words in a paragraph", words, PARAGRAPH_WORDS)
    flat = trim(body)
    gsub(/`[^`]*`/, "CODE", flat)
    gsub(SENTENCE_END, "\001", flat)
    nparts = split(flat, parts, "\001")
    sent = 0
    for (i = 1; i <= nparts; i++) {
        if (parts[i] !~ /[A-Za-z0-9]/) continue
        sent++
        held = figures(parts[i])
        if (held > SENTENCE_FIGURES) finding(at, "figures in a sentence", held, SENTENCE_FIGURES)
    }
    if (sent > PARAGRAPH_SENTENCES) finding(at, "sentences in a paragraph", sent, PARAGRAPH_SENTENCES)
}

function flush() {
    if (kind == "table" && cols > TABLE_COLUMNS) finding(start, "columns in a table", cols, TABLE_COLUMNS)
    if (kind == "paragraph" || kind == "item") measure(kind, start, held)
    kind = ""; held = ""
}

# Upstream numbers a link names: in a label of LINK_WORDS words or more, or in its target.
function collect_named(body,   m, label, target, t) {
    while (match(body, /\[[^]]*\]\([^)]*\)/)) {
        m = substr(body, RSTART, RLENGTH)
        body = substr(body, RSTART + RLENGTH)
        label = m; sub(/\]\(.*$/, "", label); label = substr(label, 2)
        target = m; sub(/^\[[^]]*\]\(/, "", target); sub(/\)$/, "", target)
        t = label; gsub(/`[^`]*`/, "x", t)
        if (count_words(t) < LINK_WORDS) continue
        while (match(label, /[0-9][0-9][0-9][0-9]/)) {
            named[substr(label, RSTART, 4)] = 1
            label = substr(label, RSTART + 4)
        }
        if (match(target, /\/(issues|pull)\/[0-9][0-9][0-9][0-9]/)) named[substr(target, RSTART + RLENGTH - 4, 4)] = 1
        if (match(target, /pr[0-9][0-9][0-9][0-9]\.md/)) named[substr(target, RSTART + 2, 4)] = 1
    }
}

function references(at, s,   m, n) {
    s = unlink(s)
    gsub(/`[^`]*`/, " ", s)
    while (match(s, /(issues?|pull requests?) [0-9][0-9][0-9][0-9]((, | and | or )[0-9][0-9][0-9][0-9])*/)) {
        m = substr(s, RSTART, RLENGTH)
        s = substr(s, RSTART + RLENGTH)
        while (match(m, /[0-9][0-9][0-9][0-9]/)) {
            n = substr(m, RSTART, 4)
            m = substr(m, RSTART + 4)
            if (!(n in named)) finding(at, "bare upstream number", n, "none outside a link that names it")
        }
    }
    while (match(s, /(^|[^A-Za-z0-9\/&])#[0-9]+/)) {
        m = substr(s, RSTART, RLENGTH)
        s = substr(s, RSTART + RLENGTH)
        sub(/^[^#]*/, "", m)
        finding(at, "bare upstream number", m, "none outside a link that names it")
    }
}

function subject_headings(   want, nwant, nh, i, expected) {
    nwant = split(SUBJECT_HEADINGS, want, "|")
    nh = 0
    for (i = 1; i <= NR; i++) {
        if (plain[i] ~ /^### /) finding(i, "subject page heading level", 3, 2)
        if (plain[i] ~ /^## /) { nh++; head[nh] = trim(substr(plain[i], 4)); headat[nh] = i }
    }
    if (nh == 1 && head[1] == want[1]) return
    for (i = 1; i <= nh; i++) {
        expected = (i <= nwant) ? "\"" want[i] "\"" : "no more than " nwant
        if (i > nwant || head[i] != want[i]) {
            finding(headat[i], "subject page heading " i, "\"" head[i] "\"", expected)
            return
        }
    }
    if (nh != nwant) finding(nh ? headat[nh] : 1, "subject page headings", nh, nwant " in order, or the first alone")
}

{ sub(/\r$/, ""); line[NR] = $0 }

END {
    SENTENCE_END = "[.?!][]\"" QUOTE ")*_]*[ \t]+"
    kind = ""; held = ""; incode = 0; total = 0; over = 0; body = ""
    for (i = 1; i <= NR; i++) {
        s = line[i]
        plain[i] = ""
        if (incode) { if (is_fence(s)) incode = 0; body = body "\n"; continue }
        if (is_fence(s)) { flush(); incode = 1; body = body "\n"; continue }
        plain[i] = s
        body = body s "\n"
        if (index(s, EMDASH)) { c = s; finding(i, "em dashes", gsub(EMDASH, "", c), 0) }
        if (s !~ /[^ \t]/) { flush(); continue }
        if (is_heading(s)) { flush(); measure("heading", i, s); continue }
        if (is_row(s)) {
            if (kind != "table") { flush(); kind = "table"; start = i; cols = 0 }
            c = columns(s)
            if (c > cols) cols = c
            continue
        }
        if (is_item(s)) { flush(); kind = "item"; start = i; held = trim(s); continue }
        if (kind == "table") flush()
        if (kind == "") { kind = "paragraph"; start = i; held = trim(s) } else held = held " " trim(s)
    }
    flush()
    if (FRONT && total > FRONT_PAGE_WORDS) finding(1, "words outside tables and code", total, FRONT_PAGE_WORDS)
    if (SUBJECT) subject_headings()
    collect_named(body)
    for (i = 1; i <= NR; i++) if (plain[i] != "") references(i, plain[i])
    exit over ? 1 : 0
}
AWK

emdash=$(printf '\342\200\224')
over=0
for p in "${pages[@]}"; do
    name=${p#./}
    front=0 subject=0
    [ "$name" = README.md ] && front=1
    case "${name##*/}" in [0-9][0-9]-*.md) subject=1 ;; esac
    LC_ALL=C awk -v page="$name" -v FRONT="$front" -v SUBJECT="$subject" -v EMDASH="$emdash" \
        -v QUOTE="'" -v FRONT_PAGE_WORDS="$FRONT_PAGE_WORDS" -v PARAGRAPH_WORDS="$PARAGRAPH_WORDS" \
        -v PARAGRAPH_SENTENCES="$PARAGRAPH_SENTENCES" -v SENTENCE_FIGURES="$SENTENCE_FIGURES" \
        -v TABLE_COLUMNS="$TABLE_COLUMNS" -v SUBJECT_HEADINGS="$SUBJECT_HEADINGS" \
        -v LINK_WORDS="$LINK_WORDS" "$PROGRAM" "$p"
    rc=$?
    case $rc in
        0) ;;
        1) over=$((over + 1)) ;;
        *) say "INVALID: awk failed on $p (exit $rc)"; exit 3 ;;
    esac
done

pages_said="${#pages[@]} pages"
[ ${#pages[@]} -eq 1 ] && pages_said="1 page"
if [ "$over" -gt 0 ]; then
    say "$pages_said, $over over a limit"
    exit 1
fi
say "$pages_said, every one within the limits"
