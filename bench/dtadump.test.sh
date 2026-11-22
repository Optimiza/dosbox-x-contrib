#!/usr/bin/env bash
# dtadump.sh's verdicts against captured reports, no emulator: bash dtadump.test.sh
# fixtures/dtadump holds DTADUMP's report of a build whose failed FindFirst rewrites the DTA (1)
# and of a build that leaves it alone (2). fixtures/dtadump-open-wild holds one build twice, with the
# case of an open by wildcards that writes into the DTA.
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
f=$here/fixtures
run() { "$here/dtadump.sh" "$build_a" "$build_b" "$@"; }
# A report without its template dumps, its trailer counting what is left.
no_templates() {
    awk -F'|' '$1 == "end" { printf "end|lines=%d\r\n", n; next } $2 !~ /^template / { print; n++ }' "$1" > "$1.cut" && mv "$1.cut" "$1"
}

t_play "$f/dtadump"
t_case "two reports that differ, the lines counted" 1 "dtadump.sh: DIFFERENT, 41 lines differ" run off
t_case "a build that rewrites the DTA" 1 "dtadump.sh: figures A: template=1c5027e13814 untouched=3/6 resumed=3/6 fcb=ce9cdd5c399c" run off
t_case "a build that leaves it alone" 1 "dtadump.sh: figures B: template=8044d2aed1bc untouched=6/6 resumed=6/6 fcb=f9c92156e849" run off
t_case "each report printed whole" 1 "list|fcb-copied-then-12h|11h TXT, copy, 11h MID, 12h on the copy three times|,BAR     TXT,ALPHAT~1MID,FOO     TXT" run off
t_play "$f/dtadump-open-wild"
t_case "an open by wildcards that writes the program's DTA" 0 "dump|fcb-open-wild|dta-after-0Fh|al=0 dta=changed|04 5A45442020202020545854" run off
t_case "the open counts among the calls that must leave a DTA alone" 0 "dtadump.sh: figures A: template=1c5027e13814 untouched=3/7 resumed=3/6 fcb=ce9cdd5c399c" run off
t_derive "$f/dtadump"; cp "$derived/1/DTADUMP.TXT" "$derived/2/DTADUMP.TXT"; t_play "$derived"
t_case "the same report twice" 0 "dtadump.sh: ALIKE" run off
t_derive "$f/dtadump"; sed -i '' '$d' "$derived/1/DTADUMP.TXT"; t_play "$derived"
t_case "a report cut before its trailer" 3 "build A's report has no line or no trailer" run off
t_derive "$f/dtadump"; no_templates "$derived/2/DTADUMP.TXT"; t_play "$derived"
t_case "a report with no template dumped" 3 "build B's report lacks the lines its figures are read from" run off
t_derive "$f/dtadump"; sed -i '' 's/ dta=[a-z]*|/|/' "$derived/1/DTADUMP.TXT"; t_play "$derived"
t_case "a report that says of no DTA whether it changed" 3 "build A's report lacks the lines its figures are read from" run off
t_play "$f/dtadump"
STUB_RC=3 t_case "the launcher refuses the run" 3 "did not run to its end" run off
t_case "neither on nor off" 2 "on or off" run maybe
t_case "two arguments" 2 "usage:" "$here/dtadump.sh" "$build_a" "$build_b"
t_end
