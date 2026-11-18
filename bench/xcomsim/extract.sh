#!/usr/bin/env bash
# Writes calls.txt from a raw INT 21h trace of X-COM Apocalypse (the `dos_calls` log a build with
# that trace writes): every FindFirst (AH=4Eh) the game made, in order, with the name as it
# passed it and what DOS answered. Only the calls are kept; nothing of the game's files.
set -u

usage() {
    cat <<'EOT'
usage: extract.sh <trace> > calls.txt

  <trace>  lines "E N=<n> ... CS=<seg> IP=<off> ... AX=<ax> ... CX=<cx> ... NAME=<path>" for each
           entry to INT 21h and "R N=<n> ... AX=<ax> ... CF=<0|1> ..." for each return

prints one line per FindFirst, in the trace's order:
  <n>|<CS:IP of the caller>|<CX>|<c or cd>|<found or err=<AX>>|<the name, trailing spaces kept>
"cd" is a name on drive D:, the game's CD; every other name is on C:, relative to the game's
folder. A line opens with "#" for the header.

exit: 0 the lines are written | 2 usage
      3 INVALID: the trace holds no FindFirst, or one without its return
EOT
}

if [ $# -eq 1 ] && [ "$1" = "--help" ]; then usage; exit 0; fi
if [ $# -ne 1 ] || [ ! -f "$1" ]; then usage >&2; exit 2; fi

LC_ALL=C awk '
    function field(line, key) {
        if (match(line, " " key "=[^ ]*")) return substr(line, RSTART + length(key) + 2, RLENGTH - length(key) - 2)
        return ""
    }
    $1 == "E" && substr(field($0, "AX"), 1, 2) == "4E" {
        n = field($0, "N"); order[++count] = n
        name = $0; sub(/^.* NAME=/, "", name)
        caller[n] = field($0, "CS") ":" field($0, "IP"); cx[n] = field($0, "CX"); path[n] = name
    }
    $1 == "R" { n = field($0, "N"); if (n in path) { cf[n] = field($0, "CF"); ax[n] = field($0, "AX") } }
    END {
        if (count == 0) { print "extract.sh: INVALID: the trace holds no FindFirst" > "/dev/stderr"; exit 3 }
        print "# n|caller|cx|drive|answer|name: the FindFirst calls of X-COM Apocalypse, from its INT 21h trace"
        for (i = 1; i <= count; i++) {
            n = order[i]
            if (!(n in cf)) { print "extract.sh: INVALID: FindFirst " n " has no return" > "/dev/stderr"; exit 3 }
            drive = (toupper(substr(path[n], 1, 2)) == "D:") ? "cd" : "c"
            answer = (cf[n] == "0") ? "found" : "err=" ax[n]
            print n "|" caller[n] "|" cx[n] "|" drive "|" answer "|" path[n]
        }
    }' "$1"
