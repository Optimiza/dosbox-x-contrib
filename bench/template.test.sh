#!/usr/bin/env bash
# template.sh's verdicts against captured runs, no emulator: bash template.test.sh
# fixtures/template-fat holds what two builds that answer differently left over the disk image,
# long names off: what the shell said of the volume and of its free space, then TEMPLATE's
# report.
# fixtures/template-host holds the same over the host folder, long names on.
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
f=$here/fixtures
run() { "$here/template.sh" "$build_a" "$build_b" "$@"; }

t_play "$f/template-fat"
t_case "two reports that differ" 1 "template.sh: DIFFERENT, 3 lines differ" run fat off
t_case "each report printed whole" 1 'fcblabel|DISK1      |al=0|more=0' run fat off
t_case "a line that differs, of the second build" 1 '> label|V:\DISK|first=18 |more=0|' run fat off
t_case "of what the shell said, the report takes the free space alone" 1 "end|lines=37
shell|DIR of the volume while empty, after a DIR of another drive|free=66,781,184
template.sh: build B: " run fat off
t_derive "$f/template-fat"; sed -i '' 's/^    0 Dir(s)         66,781,184 Bytes free/    0 Dir(s)      2,013,265,920 Bytes free/' "$derived/2/TEMPLATE.TXT"; t_play "$derived"
t_case "a DIR that gives another drive's free space" 1 "> shell|DIR of the volume while empty, after a DIR of another drive|free=2,013,265,920" run fat off
t_derive "$f/template-fat"; sed -i '' '/Dir(s) .* Bytes free/d' "$derived/1/TEMPLATE.TXT"; t_play "$derived"
t_case "a DIR that printed no free space" 3 "build A's DIR of the empty volume printed no free space" run fat off
t_derive "$f/template-fat"; cp "$derived/1/TEMPLATE.TXT" "$derived/2/TEMPLATE.TXT"; t_play "$derived"
t_case "two reports alike" 0 "template.sh: ALIKE" run fat off
t_derive "$f/template-fat"; sed -i '' 's/^   8 File(s) copied/   7 File(s) copied/' "$derived/1/TEMPLATE.TXT"; t_play "$derived"
t_case "an image that did not get every file" 3 "7 copied of 8" run fat off
t_derive "$f/template-fat"; sed -i '' '/File(s) copied/d' "$derived/2/TEMPLATE.TXT"; t_play "$derived"
t_case "a copy that printed no count" 3 "no count copied of 8" run fat off
t_derive "$f/template-fat"; sed -i '' 's/^ Volume in drive E is DISK1/ Volume in drive E has no label/' "$derived/1/TEMPLATE.TXT"; t_play "$derived"
t_case "a volume the shell does not call DISK1" 3 "does not say the volume is labelled DISK1" run fat off
t_derive "$f/template-fat"; sed -i '' '/^end|lines/d' "$derived/2/TEMPLATE.TXT"; t_play "$derived"
t_case "a report cut before its trailer" 3 "build B's report has no line or no trailer" run fat off
t_derive "$f/template-fat"; sed -i '' '/^quoted|/d' "$derived/1/TEMPLATE.TXT"; t_play "$derived"
t_case "a report whose count disagrees" 3 "build A's report has no line or no trailer" run fat off
t_play "$f/template-host"
t_case "the host folder: the line that differs" 1 '> fcbname|foo     txt|al=0|name=464F4F2020202020545854|more=0' run host on
t_case "the host folder: counted" 1 "template.sh: DIFFERENT, 1 lines differ" run host on
t_derive "$f/template-host"; sed -i '' '/Volume in drive/d' "$derived/1/TEMPLATE.TXT"; t_play "$derived"
t_case "a host folder mounted with no label" 3 "build A's volume did not come out labelled and whole" run host on
t_play "$f/template-fat"
STUB_RC=3 t_case "the launcher refuses the run" 3 "did not run to its end" run fat off
# A run that judged nothing keeps its directory: the conf it booted is read there.
conf_of() {
    local out
    out=$(STUB_RC=3 run "$@" 2>&1)
    cat "$(printf '%s\n' "$out" | sed -n 's/.*the run is kept in //p')/run-A/run.conf"
}
t_case "a folder mounted with no label named gets an empty one" 0 '/fx" -label ""' conf_of fat off
t_case "and so does the run's own drive" 0 '/run-A" -label ""' conf_of fat off
t_case "the host volume is mounted with its label, and only that one" 0 '/fx" -label DISK1
' conf_of host off
t_case "the image is mounted under the version it asks for" 0 "ver=7.1" conf_of fat off
t_case "neither fat nor host" 2 "fat or host" run iso off
t_case "neither on nor off" 2 "on or off" run fat maybe
t_case "three arguments" 2 "usage:" "$here/template.sh" "$build_a" "$build_b" fat
t_end
