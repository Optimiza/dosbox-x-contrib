#!/usr/bin/env bash
# Samples the host while the timers' batch runs; macOS's top. See README.md beside this script.
set -u

usage() {
    cat <<'EOT'
usage: loadwatch.sh <out file> <seconds>

every <seconds>, appends to <out file> the load average, the CPU's user, system and idle shares
and the ten processes using the most CPU, read from top's second sample (the first has no
interval to measure a share over), until it is killed:

  load|<epoch>|<1 5 15 min>
  cpu|<epoch>|<user>|<sys>|<idle>
  top|<epoch>|<pid>|<ppid>|<cpu %>|<command>

exit: 2 usage; otherwise it runs until it is killed
EOT
}

if [ $# -eq 1 ] && [ "$1" = "--help" ]; then usage; exit 0; fi
if [ $# -ne 2 ]; then usage >&2; exit 2; fi
out=$1 every=$2
while :; do
    now=$(date +%s)
    echo "load|$now|$(sysctl -n vm.loadavg | tr -d '{}' | sed 's/^ *//; s/ *$//')" >> "$out"
    top -l 2 -s 1 -n 10 -o cpu -stats pid,ppid,cpu,command 2> /dev/null | awk -v t="$now" '
        /^Processes:/ { n++ }
        n == 2 && /^CPU usage:/ { gsub(/%/, ""); printf "cpu|%s|%s|%s|%s\n", t, $3, $5, $7 }
        n == 2 && /^PID/ { body = 1; next }
        n == 2 && body && NF >= 4 { cmd = $4; for (i = 5; i <= NF; i++) cmd = cmd " " $i; printf "top|%s|%s|%s|%s|%s\n", t, $1, $2, $3, cmd }
    ' >> "$out"
    sleep "$every"
done
