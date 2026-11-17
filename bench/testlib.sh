# shellcheck shell=bash
# Sourced by the *.test.sh here: a script runs against the stub launcher and its exit code
# and one phrase are checked. The "builds" are links to bash: a process can carry their name.

t_begin() {
    here=$(cd "$(dirname "$0")" && pwd) || exit 3
    work=$(mktemp -d "${TMPDIR:-/tmp}/dircache-test.XXXXXX") || exit 3
    work=$(cd "$work" && pwd -P) || exit 3
    trap 'rm -rf "$work"' EXIT
    mkdir -p "$work/state" "$work/prebuilt" "$work/tmp" || exit 3
    ln -s /bin/bash "$work/build-A" && ln -s /bin/bash "$work/build-B" || exit 3
    for p in LISTDUMP MEMPROBE FINDLIFE EXACT DRIFT DTADUMP PATLIST TEMPLATE FINDPOS ATTRPRB ATTRSEM ATTRCOST RESPRB DELPRB ALIASES P5PROBE P5REP TIES ENUMSTAT DOSID; do : > "$work/prebuilt/$p.EXE"; done
    # shellcheck disable=SC2034  # the two builds a test hands to its script
    build_a=$work/build-A build_b=$work/build-B
    export DIRCACHE_LAUNCHER="$here/fixtures/stub-launcher.sh" STUB_STATE="$work/state" DIRCACHE_PREBUILT="$work/prebuilt" TMPDIR="$work/tmp"
    t_cases=0 t_failed=0
}

t_play() {
    export STUB_PLAY=$1
    rm -f "$STUB_STATE/count"
}

t_derive() {
    derived=$work/derived-$t_cases
    rm -rf "$derived"
    cp -R "$1" "$derived" || exit 3
}

# t_case <what it shows> <exit code wanted> <phrase wanted> <command>...
t_case() {
    local what=$1 want_rc=$2 want_text=$3 out rc
    shift 3
    rm -f "$STUB_STATE/count"
    out=$("$@" 2>&1)
    rc=$?
    t_cases=$((t_cases + 1))
    if [ "$rc" -ne "$want_rc" ]; then
        t_failed=$((t_failed + 1))
        printf 'FAIL %s: exit %s, wanted %s\n%s\n' "$what" "$rc" "$want_rc" "$out"
        return
    fi
    case "$out" in
        *"$want_text"*) echo "ok   $what" ;;
        *) t_failed=$((t_failed + 1)); printf 'FAIL %s: no "%s" in:\n%s\n' "$what" "$want_text" "$out" ;;
    esac
}

t_end() {
    if [ "$t_cases" -eq 0 ]; then echo "INVALID: no case ran"; exit 3; fi
    echo "$t_cases cases, $t_failed failed"
    [ "$t_failed" -eq 0 ]
}
