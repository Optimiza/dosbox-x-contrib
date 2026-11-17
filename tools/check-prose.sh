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
# The front page: its sections in order, the most list items in the one on measuring, the words
# that mark the sentence on AI assistance, and how the credits line, its last, starts.
# A table column headed so names things: its numbers are no figures.
NAME_COLUMNS='#|Exit code'
FRONT_SECTIONS='The subjects|The problem, and the case that showed it|How it is measured|Running it'
FRONT_MEASURE_LINES=5
FRONT_AI_MARK='AI assistance'
FRONT_CREDITS_START='Developed by Optimiza'

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
  a table of figures              a line starting Source: under it; a column headed
                                  $NAME_COLUMNS names things and holds no figure
  relative link                   a file that exists, and a heading that exists
                                  when it names one
  front page contents             its sections, in order: $FRONT_SECTIONS;
                                  one opening paragraph; a subjects table whose rows link
                                  to docs/NN-*.md; one table in the problem; at most
                                  $FRONT_MEASURE_LINES list items and a link in how it is measured;
                                  one code block and a link in running it; one paragraph
                                  with "$FRONT_AI_MARK"; the last line starts "$FRONT_CREDITS_START"

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

function cells(s, out) {
    gsub(/\\\|/, "x", s)
    gsub(/`[^`]*`/, "x", s)
    s = trim(s)
    sub(/^\|+/, "", s)
    sub(/\|+$/, "", s)
    return split(s, out, /\|/)
}

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

function columns(s,   f) { return cells(s, f) }

# The numbers of a sentence that measure something. One names a thing and is no figure when it
# is a DOS or Windows version, 8.3, INT 21, or follows "issue", "pull request", "subject" or
# "rule", alone or in a list joined by commas, "and", "or" or "to".
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
        if (before ~ /(MS-DOS|FreeDOS) $/) continue
        if (before ~ /Windows $/ && (p == "98" || p == "11")) continue
        if (before ~ /(INT|int) $/ && p == "21") continue
        if (p ~ /^[0-9]+$/) {
            if (before ~ /([Pp]ull requests?|[Ii]ssues?|[Ss]ubjects?|[Rr]ules?) $/ ||
                (refend > 0 && substr(s, refend, st - refend) ~ /^(, |,? (and|or|to) )$/)) {
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
    if (kind == "table") {
        if (cols > TABLE_COLUMNS) finding(start, "columns in a table", cols, TABLE_COLUMNS)
        if (tfig) source_wanted = start
        tables[sec]++
        if (tables[sec] == 2) second_table[sec] = start
    }
    if (kind == "paragraph" || kind == "item") {
        measure(kind, start, held)
        if (kind == "item") items[sec]++
        nb++; bsec[nb] = sec; bstart[nb] = start; btext[nb] = trim(held)
    }
    kind = ""; held = ""
}

# The figures of a table's body row, leaving out the columns whose numbers name things.
function row_figures(s,   n, c, r, f) {
    n = cells(s, r)
    f = 0
    for (c = 1; c <= n; c++) if (!(hdr[c] in named_column)) f += figures(trim(unlink(r[c])))
    return f
}

# A table of figures is followed by a line starting Source:.
function source_due(at, s) {
    if (!source_wanted) return
    if (s !~ /^Source:/) finding(source_wanted, "source of a table of figures", "none", "a Source: line under it")
    source_wanted = 0
}

function read_slugs(file,   l, t, fenced, n) {
    slugs_read[file] = 1
    fenced = 0
    while ((getline l < file) > 0) {
        sub(/\r$/, "", l)
        if (is_fence(l)) { fenced = !fenced; continue }
        if (fenced || l !~ /^#+[ \t]/) continue
        t = l
        sub(/^#+[ \t]+/, "", t)
        t = tolower(trim(t))
        gsub(/[^a-z0-9 _-]/, "", t)
        gsub(/ /, "-", t)
        n = slug_seen[file, t]++
        slug[file, n ? t "-" n : t] = 1
    }
    close(file)
}

# A relative link names a file that exists, and a heading of it when it names one.
function check_link(at, target,   k, path, anchor, file) {
    if (target ~ /^[A-Za-z][A-Za-z0-9+.-]*:/) return
    sub(/[ \t].*$/, "", target)
    k = index(target, "#")
    path = k ? substr(target, 1, k - 1) : target
    anchor = k ? substr(target, k + 1) : ""
    file = path == "" ? page : DIR path
    if (file ~ /'/ || system("test -e '" file "'") != 0) {
        finding(at, "relative link", target, "a file that exists")
        return
    }
    if (anchor == "" || file !~ /\.md$/) return
    if (!(file in slugs_read)) read_slugs(file)
    if (!((file, anchor) in slug)) finding(at, "relative link", target, "a heading that exists")
}

function check_links(   i, s, target) {
    for (i = 1; i <= NR; i++) {
        if (plain[i] == "") continue
        s = plain[i]
        gsub(/`[^`]*`/, "", s)
        while (match(s, /\]\([^)]*\)/)) {
            target = substr(s, RSTART + 2, RLENGTH - 3)
            s = substr(s, RSTART + RLENGTH)
            check_link(i, target)
        }
    }
}

function front_page(   want, nwant, i, n, at, ai, last) {
    nwant = split(FRONT_SECTIONS, want, "|")
    for (i = 1; i <= h2 && i <= nwant; i++)
        if (h2name[i] != want[i]) finding(h2at[i], "front page section " i, "\"" h2name[i] "\"", "\"" want[i] "\"")
    if (h2 != nwant) finding(h2 ? h2at[h2] : 1, "front page sections", h2, nwant)
    n = 0
    for (i = 1; i <= nb; i++) if (bsec[i] == 0) { n++; if (n == 2) at = bstart[i] }
    if (n != 1) finding(n > 1 ? at : 1, "front page opening paragraphs", n, 1)
    if (tables[1] < 1) finding(h2at[1] ? h2at[1] : 1, "front page tables in the subjects", 0, 1)
    if (tables[2] > 1) finding(second_table[2], "front page tables in the problem", tables[2], 1)
    if (items[3] > FRONT_MEASURE_LINES) finding(h2at[3], "front page lines in how it is measured", items[3], FRONT_MEASURE_LINES)
    if (!links[3]) finding(h2at[3] ? h2at[3] : 1, "front page links in how it is measured", 0, 1)
    if (codes[4] != 1) finding(h2at[4] ? h2at[4] : 1, "front page code blocks in running it", codes[4] + 0, 1)
    if (!links[4]) finding(h2at[4] ? h2at[4] : 1, "front page links in running it", 0, 1)
    ai = 0
    for (i = 1; i <= nb; i++) if (index(btext[i], FRONT_AI_MARK)) { ai++; if (ai == 2) at = bstart[i] }
    if (ai != 1) finding(ai > 1 ? at : 1, "front page AI line", ai, 1)
    for (last = NR; last > 1 && line[last] !~ /[^ \t]/; last--) ;
    if (index(line[last], FRONT_CREDITS_START) != 1)
        finding(last, "front page last line", "not the credits line", "the line starting \"" FRONT_CREDITS_START "\"")
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
    while (match(s, /([Ii]ssues?|[Pp]ull requests?) [0-9][0-9][0-9][0-9]((, | and | or )[0-9][0-9][0-9][0-9])*/)) {
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
    n = split(NAME_COLUMNS, hcell, "|"); for (k = 1; k <= n; k++) named_column[hcell[k]] = 1
    kind = ""; held = ""; incode = 0; total = 0; over = 0; body = ""; sec = 0; h2 = 0; nb = 0; source_wanted = 0
    for (i = 1; i <= NR; i++) {
        s = line[i]
        plain[i] = ""
        if (incode) { if (is_fence(s)) incode = 0; body = body "\n"; continue }
        if (is_fence(s)) { flush(); source_due(i, s); codes[sec]++; incode = 1; body = body "\n"; continue }
        plain[i] = s
        body = body s "\n"
        if (index(s, EMDASH)) { c = s; finding(i, "em dashes", gsub(EMDASH, "", c), 0) }
        if (s !~ /[^ \t]/) { flush(); continue }
        if (s ~ /\]\([^)]*\)/) links[sec]++
        if (!is_row(s)) { if (kind == "table") flush(); source_due(i, s) }
        if (is_heading(s)) {
            flush()
            measure("heading", i, s)
            if (s ~ /^## /) { h2++; sec = h2; h2name[h2] = trim(substr(s, 4)); h2at[h2] = i }
            if (FRONT && s ~ /^###/) finding(i, "front page heading level", 3, 2)
            continue
        }
        if (is_row(s)) {
            if (kind != "table") { flush(); kind = "table"; start = i; cols = 0; trow = 0; tfig = 0; delete hdr }
            trow++
            c = columns(s)
            if (c > cols) cols = c
            if (trow == 1) { n = cells(s, hcell); for (k = 1; k <= n; k++) hdr[k] = trim(unlink(hcell[k])) }
            else if (trow > 2) tfig += row_figures(s)
            if (FRONT && sec == 1 && trow > 2 && s !~ /\]\(docs\/[0-9][0-9]-[^)]*\.md\)/)
                finding(i, "front page subject row", "no page link", "a link to docs/NN-*.md")
            continue
        }
        if (is_item(s)) { flush(); kind = "item"; start = i; held = trim(s); continue }
        if (kind == "table") flush()
        if (kind == "") { kind = "paragraph"; start = i; held = trim(s) } else held = held " " trim(s)
    }
    flush()
    source_due(NR + 1, "")
    if (FRONT && total > FRONT_PAGE_WORDS) finding(1, "words outside tables and code", total, FRONT_PAGE_WORDS)
    if (FRONT) front_page()
    if (SUBJECT) subject_headings()
    check_links()
    collect_named(body)
    for (i = 1; i <= NR; i++) if (plain[i] != "") references(i, plain[i])
    exit over ? 1 : 0
}
AWK

emdash=$(printf '\342\200\224')
over=0
for p in "${pages[@]}"; do
    name=${p#./}
    front=0 subject=0 dir=
    [ "$name" = README.md ] && front=1
    case $name in */*) dir=${name%/*}/ ;; esac
    case "${name##*/}" in [0-9][0-9]-*.md) subject=1 ;; esac
    LC_ALL=C awk -v page="$name" -v FRONT="$front" -v SUBJECT="$subject" -v EMDASH="$emdash" \
        -v QUOTE="'" -v FRONT_PAGE_WORDS="$FRONT_PAGE_WORDS" -v PARAGRAPH_WORDS="$PARAGRAPH_WORDS" \
        -v PARAGRAPH_SENTENCES="$PARAGRAPH_SENTENCES" -v SENTENCE_FIGURES="$SENTENCE_FIGURES" \
        -v TABLE_COLUMNS="$TABLE_COLUMNS" -v SUBJECT_HEADINGS="$SUBJECT_HEADINGS" \
        -v LINK_WORDS="$LINK_WORDS" -v DIR="$dir" -v NAME_COLUMNS="$NAME_COLUMNS" -v FRONT_SECTIONS="$FRONT_SECTIONS" \
        -v FRONT_MEASURE_LINES="$FRONT_MEASURE_LINES" -v FRONT_AI_MARK="$FRONT_AI_MARK" \
        -v FRONT_CREDITS_START="$FRONT_CREDITS_START" "$PROGRAM" "$p"
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
