#!/usr/bin/env bash
# Stands in for every script battery.sh runs, in battery.test.sh: linked under each script's
# name, its n-th call plays the n-th file of STUB_PLAY, a file as battery.sh --raw keeps them.
# It prints what that call printed and exits with the code its first line records.
#   STUB_PLAY=<dir>    the files of one battery run
#   STUB_STATE=<dir>   the call counter
set -u
n=$(($(cat "$STUB_STATE/count" 2>/dev/null || echo 0) + 1))
echo "$n" > "$STUB_STATE/count"
name=$(basename "$0")
file=$(printf '%s/%03d-%s.txt' "${STUB_PLAY:?set STUB_PLAY}" "$n" "${name%.sh}")
# A call that is not the recorded one means the battery's order moved and the recording did not.
if [ ! -f "$file" ]; then echo "stub-script: call $n is $name, and the recording has no $file" >&2; exit 3; fi
rc=$(sed -n '1s/^exit=\([0-9]*\) :: .*/\1/p' "$file")
case "$rc" in ''|*[!0-9]*) echo "stub-script: $file records no exit code" >&2; exit 3 ;; esac
sed 1d "$file"
exit "$rc"
