#!/usr/bin/env bash
# Stands in for every script battery.sh runs, in battery.test.sh: linked under each script's
# name, it plays the file of STUB_PLAY that battery.sh names in DIRCACHE_CALL, a file as
# battery.sh --raw keeps them. It prints what that call printed and exits with the code its first
# line records.
#   STUB_PLAY=<dir>     the files of one battery run
#   STUB_SLOW=<pattern> the calls whose names match it take a moment, so that calls which run
#                       side by side are seen to
set -u
name=$(basename "$0")
file=${STUB_PLAY:?set STUB_PLAY}/${DIRCACHE_CALL:?battery.sh names the call in DIRCACHE_CALL}.txt
if [ ! -f "$file" ]; then echo "stub-script: the recording has no call $DIRCACHE_CALL ($name)" >&2; exit 3; fi
# A file recorded for another script means the battery named a call for what it does not run.
said=$(sed -n '1s/^exit=[0-9]* :: \([^ ]*\).*/\1/p' "$file")
if [ "$said" != "$name" ]; then echo "stub-script: $DIRCACHE_CALL is recorded for $said, not $name" >&2; exit 3; fi
rc=$(sed -n '1s/^exit=\([0-9]*\) :: .*/\1/p' "$file")
case "$rc" in ''|*[!0-9]*) echo "stub-script: $file records no exit code" >&2; exit 3 ;; esac
# shellcheck disable=SC2254  # the pattern is the caller's, unquoted on purpose
case "$DIRCACHE_CALL" in ${STUB_SLOW:-}) sleep 0.3 ;; esac
sed 1d "$file"
exit "$rc"
