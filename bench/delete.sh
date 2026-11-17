#!/usr/bin/env bash
# Runs DELPRB.EXE headless on two DOSBox-X builds, each over a drive of its own, after the shell's
# DEL over a folder of long names, and compares what each build deleted, which file each short
# name opens before and after a delete, what a search open across a delete or a create
# returns, and which directory each short name reaches before and after an RD, an MD and a
# rename. See README.md beside this script.
set -u

usage() {
    cat <<'EOT'
usage: delete.sh <build A> <build B> <on|off>

  <build A>, <build B>  two DOSBox-X executables (the same one twice is the A/A control)
  <on|off>              the guest's long file names ([dos] lfn)

each build's drive holds the folders S, L, W, A, P and C, each with the eight files
"Alpha track 000000.mid" to "Alpha track 000007.mid" (A with PLAIN.TXT too), every file holding
its own name, and the folder R with the eight directories "Alpha track 000000" to "...000007",
each holding an ID.TXT with its own name. The shell runs DEL D:\S\*.MID, then DELPRB deletes L
through 41h on each name a search returns and W through 7141h with a wildcard, deletes one file
of A, creates one, renames A's first long name RENAMED.TXT (56h) and one long name to the same
name in capitals (7156h, where it answers), keeps a search of P open
across two deletes and one of C across an 8.3 create and a long-name create (C is listed before
and after), removes R's ALPHAT~1 with RD, makes R\NEWDIR (39h) and R\Alpha track new (7139h,
where it answers), removes NEWDIR again (3Ah), renames the first directory R lists with an
ID.TXT RENAMED (56h), and makes the old long names of the renamed file and directory again
(716Ch, 7139h, where they answer).

prints each build's path, version line and report whole, the files the host holds in each folder
at the end, and for each build: A's short names that open another file after one delete than
before it; the short names C's search returned that open another file than before the creates;
what C lists after the creates (how many, of how many before and how many creates answered, the
short names listed twice, the earlier short names that open another file); A after the rename
(how many it lists, of how many before, the short names listed twice, the earlier short names
that open another file, whether RENAMED.TXT opens the renamed file); A's short names that open
another file, or were not listed, after a case-only 7156h rename; after the renamed file's old
long name is made again (716Ch), the earlier short names that open another file and the short
name the new file takes beside the renamed file's old one; R's short names that reach
another directory after the RD than before it, and how many R lists after it; R after the MD and
after the rename, each against the listing before it (how many listed, of how many, made or
renamed, listed twice, earlier short names reaching another directory, and for the rename whether
RENAMED reaches the renamed directory); the directories of R whose own search lists other entries
than their ID.TXT (none for a new one) after the MD and after the rename; after the renamed
directory's old long name is made again (7139h), the earlier short names that reach another
directory and the short name it takes beside the renamed one's old one; R after NEWDIR is removed
again (how many listed, of how many, earlier short names reaching another directory); then the
verdict and the lines that differ.

environment:
  DJDIR                the DJGPP cross toolchain (default: $HOME/djgpp)
  DIRCACHE_PREBUILT     a folder holding DELPRB.EXE built on another host, instead of DJGPP

exit: 0 alike | 1 different | 2 usage
      3 INVALID: a run collected nothing, a folder did not list its eight files before the
        deletes or is gone after them, or a report has no line or no trailer; the run's
        directory is kept and named
EOT
}

SECONDS_BOUND=300
FILES=8
FOLDERS=(S L W A P C)
DIRS=R

if [ $# -eq 1 ] && [ "$1" = "--help" ]; then usage; exit 0; fi
if [ $# -ne 3 ]; then usage >&2; exit 2; fi
build_a=$1 build_b=$2 lfn=$3

tool=delete.sh
here=$(cd "$(dirname "$0")" && pwd) || exit 2
if [ ! -f "$here/common.sh" ]; then echo "delete.sh: common.sh is missing beside the script" >&2; exit 3; fi
# shellcheck source=common.sh
. "$here/common.sh"
need_builds "$build_a" "$build_b"
lfn_parse "$lfn"
need_tools

run_begin delete
guest_build DELPRB "$tmp/c" || invalid "DELPRB did not build"

# delete_tree <dir>: the six folders, a copy per build, because the run deletes and makes files.
delete_tree() {
    local folder i name
    for folder in "${FOLDERS[@]}"; do
        mkdir -p "$1/$folder" || return
        i=0
        while [ "$i" -lt "$FILES" ]; do
            printf -v name 'Alpha track %06d.mid' "$i"
            printf '%s' "$name" > "$1/$folder/$name" || return
            i=$((i + 1))
        done
    done
    printf '%s' PLAIN.TXT > "$1/A/PLAIN.TXT"
    i=0
    while [ "$i" -lt "$FILES" ]; do
        printf -v name 'Alpha track %06d' "$i"
        mkdir -p "$1/$DIRS/$name" && printf '%s' "$name" > "$1/$DIRS/$name/ID.TXT" || return
        i=$((i + 1))
    done
}

echo "delete.sh: long names $lfn"
for label in A B; do
    if [ "$label" = A ]; then binary=$build_a; else binary=$build_b; fi
    delete_tree "$tmp/fx-$label" || invalid "could not make build $label's folders"
    guest_run "$label" "$binary" "$tmp/fx-$label" "" DELPRB.TXT "$SECONDS_BOUND" "c:" \
        'DEL D:\S\*.MID' 'DELPRB.EXE D: C:\DELPRB.TXT'
    LC_ALL=C tr -d '\r' < "$guest_out" > "$tmp/report-$label.txt" || invalid "build $label's report could not be read"
    echo "delete.sh: build $label: $binary ($emu_version)"
    cat "$tmp/report-$label.txt"
    exact_whole "$tmp/report-$label.txt" || invalid "build $label's report has no line or no trailer"
    left=""
    for folder in "${FOLDERS[@]}"; do
        [ -d "$tmp/fx-$label/$folder" ] || invalid "build $label's folder $folder is gone"
        n=$(find "$tmp/fx-$label/$folder" -mindepth 1 -maxdepth 1 -type f | wc -l | tr -d ' ')
        echo "host|$folder|files=$n" >> "$tmp/report-$label.txt"
        left="$left $folder=$n"
    done
    [ -d "$tmp/fx-$label/$DIRS" ] || invalid "build $label's folder $DIRS is gone"
    n=$(find "$tmp/fx-$label/$DIRS" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
    echo "host|$DIRS|dirs=$n" >> "$tmp/report-$label.txt"
    left="$left $DIRS=$n directories"
    echo "delete.sh: build $label: files the host holds at the end:$left"
    # A short name read after the change that opens another file (or directory) than before it,
    # or a name that was not listed before, has moved.
    awk -F'|' 'function key(f) { split(f, kv, "="); return kv[1] }
        function val(f) { split(f, kv, "="); return substr(f, length(kv[1]) + 2) }
        function moved(group, f) { n[group]++; if (!((group, key(f)) in was) || was[group, key(f)] != val(f)) m[group]++ }
        $1 == "alias" && $2 == "before" { was["delete", key($3)] = val($3) }
        $1 == "alias" && $2 == "after-delete" { moved("delete", $3) }
        $1 == "search" && $2 == "create" && $3 == "before" { was["create", key($4)] = val($4) }
        $1 == "search" && $2 == "create" && $3 ~ /^[0-9]+$/ { moved("create", $4) }
        $1 == "search" && $2 == "create" && $3 == "after" { listed["create"]++; if (seen[key($4)]++) twice["create"]++; if ((("create", key($4)) in was) && was["create", key($4)] != val($4)) m["after"]++ }
        $1 == "search" && $2 == "create" && $3 ~ /^3ch=/ { split($3, codes, " "); made = (codes[1] == "3ch=0000") + (codes[2] == "716ch=0000") }
        $1 == "rmdir" && $2 == "before" { was["rd", key($3)] = val($3); before["rd"]++ }
        $1 == "rmdir" && $2 == "after-rd" { moved("rd", $3); listed["rd"]++; prior_to("md", $3) }
        # prior_to(g, f): f is listed before step g; after(g, f): f is listed after it.
        function prior_to(g, f) { was[g, key(f)] = val(f); prior[g]++ }
        function after(g, f) { listed[g]++; if (seen[g, key(f)]++) twice[g]++; if (((g, key(f)) in was) && was[g, key(f)] != val(f)) m[g]++; if (key(f) ~ /^RENAMED/) to[g] = val(f) }
        $1 == "alias" && $2 == "after-create" { prior_to("fren", $3) }
        $1 == "alias" && $2 == "after-ren" { after("fren", $3); was["case", key($3)] = val($3) }
        $1 == "alias" && $2 == "after-case" { moved("case", $3); prior_to("fremake", $3) }
        $1 == "alias" && $2 == "after-remake" { remade("fremake", $3) }
        # remade(g, f): f listed after an old name was made again; the name not listed before is the new entry.
        function remade(g, f) { if ((g, key(f)) in was) { if (was[g, key(f)] != val(f)) m[g]++ } else made_as[g] = key(f) }
        function inside_wrong(g, f) { if ((cur[g, key(f)] == "none") ? (val(f) != 0) : (val(f) != 1)) wrong[g]++ }
        $1 == "rename" && $2 == "file" { split($3, w, " "); sub(/^from=/, "", w[1]); from["fren"] = w[1]; done["fren"] = (w[2] == "56h=0000") }
        $1 == "mkdir" && $2 == "made" { split($3, codes, " "); made_dirs = (codes[1] == "39h=0000") + (codes[2] == "7139h=0000") }
        $1 == "mkdir" && $2 == "after-md" { after("md", $3); prior_to("rdnew", $3); cur["md", key($3)] = val($3) }
        $1 == "mkdir" && $2 == "after-rd-new" { after("rdnew", $3); prior_to("dren", $3) }
        $1 == "mkdir" && $2 == "inside" { inside_wrong("md", $3) }
        $1 == "rename" && $2 == "inside" { inside_wrong("dren", $3) }
        $1 == "rename" && $2 == "after-remake" { remade("dremake", $3) }
        $1 == "rename" && $2 == "dir" { split($3, w, " "); sub(/^from=/, "", w[1]); from["dren"] = w[1]; done["dren"] = (w[2] == "56h=0000") }
        $1 == "rename" && $2 == "after-ren" { after("dren", $3); prior_to("dremake", $3); cur["dren", key($3)] = val($3) }
        END {
            for (k in was) { split(k, part, SUBSEP); if (part[1] == "create") before["create"]++ }
            printf "delete.sh: build %s: short names moved by one delete: %d of %d\n", label, m["delete"], n["delete"]
            printf "delete.sh: build %s: short names a search returned that open another file after the creates: %d of %d\n", label, m["create"], n["create"]
            printf "delete.sh: build %s: C after the creates: listed=%d before=%d created=%d listed twice=%d earlier short names opening another file=%d\n", label, listed["create"], before["create"], made, twice["create"], m["after"]
            printf "delete.sh: build %s: short names of directories moved by one RD: %d of %d\n", label, m["rd"], n["rd"]
            printf "delete.sh: build %s: R after the RD: listed=%d before=%d\n", label, listed["rd"], before["rd"]
            printf "delete.sh: build %s: A after one rename: listed=%d before=%d renamed=%d listed twice=%d earlier short names opening another file=%d RENAMED.TXT opens the renamed file=%s\n", label, listed["fren"], prior["fren"], done["fren"], twice["fren"], m["fren"], (to["fren"] != "" && to["fren"] != "none" && to["fren"] == was["fren", from["fren"]]) ? "yes" : "no"
            printf "delete.sh: build %s: A after a case-only rename: short names that moved: %d of %d\n", label, m["case"], n["case"]
            printf "delete.sh: build %s: A after the old long name of the renamed file is made again: earlier short names opening another file=%d its short name=%s the old short name of the renamed file=%s\n", label, m["fremake"], (made_as["fremake"] != "") ? made_as["fremake"] : "-", (from["fren"] != "") ? from["fren"] : "-"
            printf "delete.sh: build %s: R after the MD: listed=%d before=%d made=%d listed twice=%d earlier short names reaching another directory=%d\n", label, listed["md"], prior["md"], made_dirs, twice["md"], m["md"]
            printf "delete.sh: build %s: R after NEWDIR is removed again: listed=%d before=%d earlier short names reaching another directory=%d\n", label, listed["rdnew"], prior["rdnew"], m["rdnew"]
            printf "delete.sh: build %s: R directories whose search lists other entries than their own: after the MD=%d after the rename=%d\n", label, wrong["md"], wrong["dren"]
            printf "delete.sh: build %s: R after the old long name of the renamed directory is made again: earlier short names reaching another directory=%d its short name=%s the old short name of the renamed directory=%s\n", label, m["dremake"], (made_as["dremake"] != "") ? made_as["dremake"] : "-", (from["dren"] != "") ? from["dren"] : "-"
            printf "delete.sh: build %s: R after one rename: listed=%d before=%d renamed=%d listed twice=%d earlier short names reaching another directory=%d RENAMED reaches the renamed directory=%s\n", label, listed["dren"], prior["dren"], done["dren"], twice["dren"], m["dren"], (to["dren"] != "" && to["dren"] != "none" && to["dren"] == was["dren", from["dren"]]) ? "yes" : "no"
        }' label="$label" "$tmp/report-$label.txt" || invalid "build $label's counts could not be read"
done
reports_verdict
