#!/usr/bin/env bash
# Runs three DOS sessions headless on each DOSBox-X build given, each over a host or archive path
# longer than the arrays the emulator builds it in, and says whether the emulator survives them.
# See README.md beside this script.
set -u

usage() {
    cat <<'EOT'
usage: longpath.sh <on|off> <build>...

  <on|off>  the guest's long file names ([dos] lfn)
  <build>   one or more DOSBox-X executables

Four cases, each in a run of its own so that one that ends the emulator hides no other, each
beside a control that does the same over a short path and must list its file:

  mount    MOUNT of a host folder whose path is 369 bytes, then DIR of the drive
  nested   DIR, TYPE and CD of three nested host folders of 200 characters each, reached by their
           8.3 names
  zip      MOUNT of a zip holding nested folders of 200, 200 and 95 characters, then DIR /S
  overlay  an overlay drive whose folder is 404 bytes long over a base with a name of 101
           characters (DIR must list it), then one over a base folder that holds an entry too
           long to list (RD of the folder must fail with "directory not empty")

prints, for each build, one line: the four cases, survived or crashed with the emulator's exit
code, and the controls, ok. A case survives when the guest reaches its last line and the emulator
exits 0; the answer the guest gets for a path the emulator cannot hold is not judged, except in
the overlay case, which is wrong when its DIR lists nothing or its RD does not fail.

environment:
  DIRCACHE_LONGPATH_BYTES   the host path of the mount case, in bytes (default 369, at least 250)
  DIRCACHE_LONGPATH_ZIPS    a folder holding long.zip and short.zip made on another host, instead
                            of python3 (a host whose python cannot start)

exit: 0 every case survived on every build
      1 a case ended the emulator on some build
      2 usage
      3 INVALID: the emulator did not start, a run left no first line, or a control did not
        list its file; the run's directory is kept and named
EOT
}

SECONDS_BOUND=120
MOUNT_BYTES=${DIRCACHE_LONGPATH_BYTES:-369}

if [ $# -eq 1 ] && [ "$1" = "--help" ]; then usage; exit 0; fi
if [ $# -lt 2 ]; then usage >&2; exit 2; fi
lfn=$1
shift
case "${1:-}" in -*) echo "longpath.sh: unknown option: $1" >&2; exit 2 ;; esac
case "$MOUNT_BYTES" in ''|*[!0-9]*) echo "longpath.sh: DIRCACHE_LONGPATH_BYTES is a number of bytes" >&2; exit 2 ;; esac
if [ "$MOUNT_BYTES" -lt 250 ]; then echo "longpath.sh: DIRCACHE_LONGPATH_BYTES is at least 250, the path of a case that must not fit" >&2; exit 2; fi

tool=longpath.sh
here=$(cd "$(dirname "$0")" && pwd) || exit 2
if [ ! -f "$here/common.sh" ]; then echo "longpath.sh: common.sh is missing beside the script" >&2; exit 3; fi
# shellcheck source=common.sh
. "$here/common.sh"
need_builds "$@"
lfn_parse "$lfn"
# No guest program is built here: the cases are shell commands, so no compiler is needed.
need_tools() {
    if [ "$HOST_KIND" = windows ]; then
        [ -f "$here/windows.ps1" ] || fail_usage "windows.ps1 is missing beside the script"
    else
        [ -x "$launcher" ] || fail_usage "the launcher is not an executable: $launcher"
    fi
    if [ -n "${DIRCACHE_LONGPATH_ZIPS:-}" ]; then
        [ -f "$DIRCACHE_LONGPATH_ZIPS/long.zip" ] && [ -f "$DIRCACHE_LONGPATH_ZIPS/short.zip" ] ||
            fail_usage "DIRCACHE_LONGPATH_ZIPS holds no long.zip and short.zip: $DIRCACHE_LONGPATH_ZIPS"
    else
        command -v python3 > /dev/null || fail_usage "python3 is not on the PATH: it makes the zip"
    fi
}
need_tools

run_begin longpath
mkdir -p "$tmp/c" || invalid "could not make the guest's C:"

# fill <character> <count>: that many of the character.
fill() { head -c "$2" /dev/zero | tr '\0' "$1"; }

# deep_path <base> <bytes>: <base> and folders under it, the whole path exactly <bytes> long.
deep_path() {
    local p=$1 left room
    left=$(($2 - ${#1}))
    while [ "$left" -gt 1 ]; do
        room=$((left - 1))
        if [ "$room" -gt 200 ]; then room=200; fi
        p=$p/$(fill m "$room")
        left=$((left - room - 1))
    done
    printf '%s\n' "$p"
}

# nested_tree <dir> <len>: <dir>/D1<x...>/D2<x...>/D3<x...>/CTRL.TXT, each folder <len> long
nested_tree() {
    local d=$1 len=$2 n
    for n in 1 2 3; do d=$d/D$n$(fill x $((len - 2))); done
    mkdir -p "$d" && printf 'control' > "$d/CTRL.TXT"
}

# zip_make <file> <len1> <len2> <len3>: a zip holding D1<x...>/D2<x...>/D3<x...>/CTRL.TXT
zip_make() {
    python3 -I - "$@" <<'PYEND'
import sys, zipfile
out, *lens = sys.argv[1], *[int(a) for a in sys.argv[2:]]
path = "/".join(("D%d" % (i + 1)) + "x" * (n - 2) for i, n in enumerate(lens))
with zipfile.ZipFile(out, "w") as z:
    z.writestr(path + "/CTRL.TXT", "control")
PYEND
}

# alias_path <suffix>: D:\D1XXXX<suffix>\D2XXXX<suffix>\D3XXXX<suffix>, the names nested_tree's
# folders go by: the 8.3 alias of a folder of 200 characters ends in ~1, a folder of 6 has none.
alias_path() {
    local p=D: n=1
    while [ "$n" -le 3 ]; do p=$p\\D${n}XXXX$1; n=$((n + 1)); done
    printf '%s\n' "$p"
}

# run_one <label> <build> <host dir for D:> <guest line>...: one run whose guest writes
# "start" first and "end" last into OUT.TXT. Sets outcome (survived or crashed<code>) and
# out_file. A run that leaves no "start" is INVALID: nothing was judged.
run_one() {
    local label=$1 binary=$2 d=$3 run=$tmp/run-$1 code
    shift 3
    if ! mkdir -p "$run" || ! cp -R "$tmp/c/." "$run/"; then invalid "could not make the run directory of $label"; fi
    conf_write "$run" "$d" "" 'echo start> C:\OUT.TXT' "$@" 'echo end>> C:\OUT.TXT'
    emu_start "$binary" "$run" OUT.TXT "$SECONDS_BOUND"
    wait "$emu_job"
    emu_job=""
    emu_version=$(sed -n 's/^[^ ]*: version: //p' "$run/report.txt" 2> /dev/null)
    [ -n "$emu_version" ] || { echo "$tool: $label: no version line; the launcher said:" >&2; cat "$run/launcher.txt" >&2; invalid "$label did not start"; }
    out_file=$run/OUT.TXT
    if [ "$HOST_KIND" = windows ]; then
        code=$(sed -n 's/^windows\.ps1: exit code: //p' "$run/report.txt" | tr -d '\r')
    else
        code=$(sed -n 's/^launch\.sh: exit code: //p' "$run/report.txt")
    fi
    if [ ! -f "$out_file" ] || ! LC_ALL=C tr -d '\r' < "$out_file" | command grep -a -q '^start *$'; then invalid "$label left no first line"; fi
    if LC_ALL=C tr -d '\r' < "$out_file" | command grep -a -q '^end *$' && [ "$code" = 0 ]; then
        outcome=survived
    else
        outcome=crashed${code:+:$code}
    fi
}

# control_listed <file>: the control's guest listed its file.
control_listed() { LC_ALL=C command grep -a -q -E 'CTRL( +|\.)TXT' "$1"; }

n=0 any_crashed=0
for build in "$@"; do
    n=$((n + 1))
    fx=$tmp/fx-$n
    mkdir -p "$fx/short" || invalid "could not make the folders"
    printf 'control' > "$fx/short/CTRL.TXT"

    deep=$(deep_path "$fx/m" "$MOUNT_BYTES")
    mkdir -p "$deep" || invalid "the host cannot hold a path of $MOUNT_BYTES bytes"
    printf 'control' > "$deep/CTRL.TXT"
    nested_tree "$fx/nest-long" 200 || invalid "could not make the nested folders"
    nested_tree "$fx/nest-short" 6 || invalid "could not make the short nested folders"
    if [ -n "${DIRCACHE_LONGPATH_ZIPS:-}" ]; then
        cp "$DIRCACHE_LONGPATH_ZIPS/long.zip" "$DIRCACHE_LONGPATH_ZIPS/short.zip" "$fx/" || invalid "could not copy the zips"
    else
        zip_make "$fx/long.zip" 200 200 95 || invalid "could not make the long zip"
        zip_make "$fx/short.zip" 6 6 6 || invalid "could not make the short zip"
    fi

    mount_host=$(host_path "$deep")
    short_host=$(host_path "$fx/short")
    run_one "$n-mount-control" "$build" "$fx" "mount e \"$short_host\"" 'DIR E:\ >> C:\OUT.TXT'
    control_listed "$out_file" || invalid "the mount control did not list its file"
    run_one "$n-mount" "$build" "$fx" "mount e \"$mount_host\"" 'DIR E:\ >> C:\OUT.TXT'
    r_mount=$outcome

    short_chain=$(alias_path "")
    run_one "$n-nested-control" "$build" "$fx/nest-short" "DIR $short_chain >> C:\OUT.TXT"
    control_listed "$out_file" || invalid "the nested control did not list its file"
    long_chain=$(alias_path "~1")
    run_one "$n-nested" "$build" "$fx/nest-long" "DIR $long_chain >> C:\\OUT.TXT" "TYPE $long_chain\\CTRL.TXT >> C:\\OUT.TXT" "CD $long_chain"
    r_nested=$outcome

    zip_short=$(host_path "$fx/short.zip")
    zip_long=$(host_path "$fx/long.zip")
    run_one "$n-zip-control" "$build" "$fx" "mount e \"$zip_short\"" 'DIR E:\ /S >> C:\OUT.TXT'
    control_listed "$out_file" || invalid "the zip control did not list its file"
    run_one "$n-zip" "$build" "$fx" "mount e \"$zip_long\"" 'DIR E:\ /S >> C:\OUT.TXT'
    r_zip=$outcome

    # The overlay case, in two runs. A base file of 201 characters under an overlay folder of 300
    # bytes must list; a folder that holds an entry too long to list must survive its RD, over a
    # short overlay folder. The control is the same two over short names, in one run.
    mkdir -p "$fx/ovb-short/D1/D2" "$fx/ovo-short" || invalid "could not make the overlay control"
    printf 'control' > "$fx/ovb-short/CTRL.TXT"
    printf 'control' > "$fx/ovb-short/D1/D2/CTRL.TXT"
    mkdir -p "$fx/ovb-file" "$fx/ovb-rd/N1$(fill x 78)/N2$(fill x 78)" || invalid "could not make the overlay's base"
    printf 'control' > "$fx/ovb-file/F$(fill x 100)" || invalid "could not make the overlay's long file"
    printf 'control' > "$fx/ovb-rd/N1$(fill x 78)/N2$(fill x 78)/F$(fill y 254)" || invalid "could not make the overlay's long entry"
    ovo=$(deep_path "$fx/ovo-long" 404)
    mkdir -p "$ovo" || invalid "the host cannot hold the overlay's folder"
    run_one "$n-overlay-control" "$build" "$fx" "mount e \"$(host_path "$fx/ovb-short")\"" "mount e \"$(host_path "$fx/ovo-short")\" -t overlay" 'DIR E:\ >> C:\OUT.TXT' 'RD E:\D1 >> C:\OUT.TXT' 'DIR E:\D1 >> C:\OUT.TXT'
    control_listed "$out_file" || invalid "the overlay control did not list its file"
    LC_ALL=C tr -d '\r' < "$out_file" | command grep -a -q '^D2 ' || invalid "the overlay control lost a folder it holds"
    run_one "$n-overlay" "$build" "$fx" "mount e \"$(host_path "$fx/ovb-file")\"" "mount e \"$(host_path "$ovo")\" -t overlay" 'DIR E:\ >> C:\OUT.TXT'
    r_overlay=$outcome
    if [ "$r_overlay" = survived ] && ! LC_ALL=C tr -d '\r' < "$out_file" | command grep -a -q '^FXXXXX'; then r_overlay=wrong:unlisted; fi
    if [ "$HOST_KIND" = windows ] || [ "$lfn" = off ]; then
        # Windows stops its paths at 260, so the entry too long to list cannot be made there. With
        # long names off the overlay's RD does not list the folder it removes, on any build.
        :
    else
        run_one "$n-overlay-rd" "$build" "$fx" "mount e \"$(host_path "$fx/ovb-rd")\"" "mount e \"$(host_path "$fx/ovo-short")\" -t overlay" 'RD E:\N1XXXX~1\N2XXXX~1 >> C:\OUT.TXT' 'DIR E:\N1XXXX~1 >> C:\OUT.TXT'
        if [ "$outcome" != survived ]; then r_overlay=$outcome
        elif [ "$r_overlay" = survived ] && ! LC_ALL=C tr -d '\r' < "$out_file" | command grep -a -q 'directory not empty'; then r_overlay=wrong:rd-succeeded; fi
    fi

    echo "longpath.sh: lfn=$lfn mount=$r_mount nested=$r_nested zip=$r_zip overlay=$r_overlay controls=ok build=\"$emu_version\" binary=$build"
    case "$r_mount$r_nested$r_zip$r_overlay" in *crashed*|*wrong*) any_crashed=1 ;; esac
done
if [ "$any_crashed" -eq 1 ]; then echo "longpath.sh: CRASHED"; exit 1; fi
echo "longpath.sh: SURVIVED"
exit 0
