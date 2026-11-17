#!/usr/bin/env bash
# dirtest.sh's verdicts against one captured run, no emulator: bash dirtest.test.sh
# On a Mac only: the sampler reads ps and footprint. fixtures/dirtest is DIRTEST.EXE run to its
# end on an emulator: the guest's console and the program's find calls as the emulator logged
# them, and the line of the hold. The reporter's files are not in this repository: the folder
# handed to the script holds empty files, as many in DATA as the reporter's.
# fixtures/dirtest-windows holds what windows.ps1 wrote for DIRTEST on Windows, where the
# emulator exits 0xC0000409 with AUTOTYPE's keys still pending: its report and its words, with
# the figures of a real run of the unpatched base there; the guest's console and its hold line
# are the macOS run's, which the Windows run printed alike. The report's lines end in LF: Git
# Bash read the CR LF windows.ps1 writes as the scripts read LF, the figures of that run show.
set -u
# shellcheck source=testlib.sh
. "$(dirname "$0")/testlib.sh"
t_begin
f=$here/fixtures
folder=$work/dirtest
mkdir -p "$folder/DATA" || exit 3
: > "$folder/DIRTEST.EXE"
i=0
while [ "$i" -lt 1835 ]; do printf -v name 'F%04d.FRX' "$i"; : > "$folder/DATA/$name"; i=$((i + 1)); done
run() { "$here/dirtest.sh" "$build_a" "$folder" "$@"; }

t_play "$f/dirtest"
t_case "the program's lookups, read while held" 0 "files=1835 calls_4f=1835 calls_4e=1865 peak_rss_kb=" run off
t_case "the line carries the figures" 0 "dirtest.sh: lfn=off files=1835 calls_4f=1835 calls_4e=1865 peak_rss_kb=" run off
t_derive "$f/dirtest"; LC_ALL=C awk '/ ah=4f, / && !cut { cut = 1; next } { print }' "$f/dirtest/1/dosbox.log" > "$derived/1/dosbox.log"; t_play "$derived"
t_case "a listing one call short" 3 "1835 files, calls_4f=1834 calls_4e=1865" run off
t_derive "$f/dirtest"; LC_ALL=C awk '/ ah=4e, / && n++ >= 1000 { next } { print }' "$f/dirtest/1/dosbox.log" > "$derived/1/dosbox.log"; t_play "$derived"
t_case "lookups that stop part way" 3 "did not look every file of DATA up" run off
t_derive "$f/dirtest"; LC_ALL=C awk '/>DIRTEST\.EXE$/ { on = 1 } on && / ah=4e, / && cut < 30 { cut++; next } { print }' "$f/dirtest/1/dosbox.log" > "$derived/1/dosbox.log"; t_play "$derived"
t_case "no more 4Eh calls than files: the listing's own first is missing" 3 "1835 files, calls_4f=1835 calls_4e=1835" run off
t_derive "$f/dirtest"; LC_ALL=C awk '/^DOS CON: D:\\>DIRTEST\.EXE/ { on = 1; print; next } on && /^DOS CON: / { next } { print }' "$f/dirtest/1/dosbox.log" > "$derived/1/dosbox.log"; t_play "$derived"
t_case "a program that never returned to the shell" 3 "DIRTEST.EXE never returned to the shell" run off
t_derive "$f/dirtest"; LC_ALL=C sed -i '' '/^DOS CON: D:\\>DIRTEST\.EXE/d' "$derived/1/dosbox.log"; t_play "$derived"
t_case "a shell that never started it" 3 "the shell never started DIRTEST.EXE" run off
t_derive "$f/dirtest"; rm "$derived/1/HOLD"; t_play "$derived"
t_case "a guest that never held" 3 "was not read while the guest held" run off
t_play "$f/dirtest"
: > "$folder/DATA/EXTRA.FRX"
t_case "a DATA with a file more than the program looked up" 3 "1836 files, calls_4f=1835" run off
STUB_RC=3 t_case "the launcher refuses the run" 3 "did not run to its end" run off
t_case "no folder of the reporter's files" 3 "INVALID: no folder of the reporter's files" "$here/dirtest.sh" "$build_a" "$work/none" off
mkdir "$work/empty" && : > "$work/empty/DIRTEST.EXE" && mkdir "$work/empty/DATA"
t_case "a DATA with no file" 3 "the reporter's DATA holds no file" "$here/dirtest.sh" "$build_a" "$work/empty" off
rm -r "$folder/DATA"
t_case "a folder with no DATA" 3 "the reporter's folder holds no DATA" run off
# Windows: a uname that says MINGW, a cygpath that hands paths back, windows.ps1 played.
mkdir -p "$folder/DATA" "$work/winbin" || exit 3
i=0
while [ "$i" -lt 1835 ]; do printf -v name 'F%04d.FRX' "$i"; : > "$folder/DATA/$name"; i=$((i + 1)); done
printf '#!/bin/sh\necho MINGW64_NT-10.0-26100\n' > "$work/winbin/uname"
cat > "$work/winbin/cygpath" <<'EOT'
#!/bin/sh
echo "$2"
EOT
chmod +x "$work/winbin/uname" "$work/winbin/cygpath" && ln -s "$f/stub-powershell.sh" "$work/winbin/powershell" || exit 3
# windows_play <launcher's words> <exit code>: the Windows run, the macOS run's guest beside it.
windows_play() {
    t_derive "$f/dirtest-windows"
    cp "$f/dirtest/1/dosbox.log" "$derived/1/" && cp "$f/dirtest/1/PRB.TXT" "$derived/1/GUEST.TXT" || exit 3
    sed -i '' "s/^windows\.ps1: exit code: .*/windows.ps1: exit code: $2/" "$derived/1/report.txt"
    printf '%s\n' "$1" > "$derived/1/launcher.err"
    t_play "$derived"
}
win() { PATH="$work/winbin:$PATH" "$here/dirtest.sh" "$build_a" "$folder" off; }
windows_play "windows.ps1: INVALID: the emulator exited -1073740791" -1073740791
t_case "Windows: the exit with keys pending, after the guest's last line" 0 "the emulator exited -1073740791 (0xC0000409) with AUTOTYPE's keys still pending" win
t_case "Windows: the figures the launcher read" 0 "calls_4e=1865 peak_ws_kb=2221708 held_ws_kb=2221684 held_private_kb=2274052 samples=199" win
rm "$derived/1/GUEST.TXT"
t_case "Windows: that exit with no last line of the guest" 3 "the guest did not hold, or was not let go" win
windows_play "windows.ps1: INVALID: the emulator exited -1073741819" -1073741819
t_case "Windows: another exit code" 3 "did not run to its end" win
windows_play "windows.ps1: INVALID: the emulator passed the bound of 1800 s and was killed" -1
t_case "Windows: a run cut at its bound" 3 "did not run to its end" win
windows_play "windows.ps1: INVALID: the emulator exited -1073740791" -1073740791
printf '0\n' > "$derived/1/launcher.rc"; sed -i '' '/exit code/s/-1073740791/0/' "$derived/1/report.txt"; : > "$derived/1/launcher.err"
# said_0xc0000409: 0 when a measured run names that exit, 1 when it does not.
said_0xc0000409() {
    local out
    out=$(win 2>&1)
    case "$out" in *0xC0000409*) return 0 ;; *"dirtest.sh: lfn=off"*) return 1 ;; *) return 3 ;; esac
}
t_case "Windows: a clean exit says nothing of it" 1 "" said_0xc0000409
t_case "neither on nor off" 2 "on or off" run maybe
t_case "two arguments" 2 "usage:" "$here/dirtest.sh" "$build_a" "$folder"
t_end
