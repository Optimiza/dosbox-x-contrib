#!/usr/bin/env bash
# Runs ALIASES.EXE headless on each DOSBox-X build given and says, from the host's side, whether
# two entries of a folder share a short name and whether each short name opens its own file.
# See README.md beside this script.
set -u

usage() {
    cat <<'EOT'
usage: aliases.sh cases <on|off> [--parent <dir>] <build>...
       aliases.sh folder <on|off> <folder> <build>...

  cases     a folder made for the run, every file a size of its own: names that already are
            8.3 names beside long names whose alias the emulator could make the same (the 12
            pairs of ties.sh, a real SIBLIN~2.DAT among three long names, a real TENTH~10.DAT
            among eleven, one with no extension, one in lower case, a directory and a real file
            named like its alias), two families of long names alone that the numbering loses
            count of, eight real files named as the Wine-style short names of eight long names,
            and controls. Made under --parent when given: on a volume that tells case apart
            the folder also gets names that differ only in case.
  folder    a host directory, mounted read-only and listed only (714Eh, or 4Eh with long
            names off), or synthetic:<count>:<style> as run.sh makes it
  <on|off>  the guest's long file names ([dos] lfn)
  <build>   one or more DOSBox-X executables

prints, for each build, one line of figures. cases:
  entries                      the entries 4Eh listed, host the entries the host holds
  names_shared                 short names more than one entry is listed under (4Eh, and
                               714Eh's aliases with long names on)
  exact_search_not_one         short names whose 4Eh search returns other than one entry
  real_name_not_its_own        files whose own name is 8.3 and does not open them
  files_no_short_name_opens    files that no listed short name opens
  with long names on, from 714Eh, whose rows carry each entry's long name:
  listed_with_another_size     entries listed with another file's size, or a directory
                               listed as a file
  name_opens_another_file      aliases that open another file than the one listed
  long_name_opens_another_file long names that open another file through 716Ch
every figure 0 says that no two entries share a short name and that each short name opens the
file it was listed for. folder: entries, host, names_shared, entries_sharing (the entries
those names carry), and with long names on matched (entries whose long name the host holds)
and listed_with_another_size. No file name of a folder is printed.

environment:
  DJDIR                 the DJGPP cross toolchain (default: $HOME/djgpp)
  DIRCACHE_PREBUILT     a folder holding ALIASES.EXE built on another host, instead of DJGPP

exit: 0 every build measured, and the figures alike where several were given
      1 two builds' figures differ
      2 usage
      3 INVALID: a run collected nothing, its report has no trailer or not the lines it
        counts, a listing came back empty, or the folder did not come out whole; the run's
        directory is kept and named
EOT
}

SECONDS_BOUND=300
FOLDER_SECONDS_BOUND=1800

if [ $# -eq 1 ] && [ "$1" = "--help" ]; then usage; exit 0; fi
if [ $# -lt 3 ]; then usage >&2; exit 2; fi
what=$1 lfn=$2
shift 2
parent_dir="" folder=""
case "$what" in
    cases)
        if [ "$1" = "--parent" ]; then
            if [ $# -lt 3 ]; then usage >&2; exit 2; fi
            parent_dir=$2
            shift 2
        fi
        ;;
    folder)
        folder=$1
        shift
        if [ $# -lt 1 ]; then usage >&2; exit 2; fi
        ;;
    *) echo "aliases.sh: cases or folder, not: $what" >&2; exit 2 ;;
esac
case "${1:-}" in -*) echo "aliases.sh: unknown option: $1" >&2; exit 2 ;; esac

tool=aliases.sh
here=$(cd "$(dirname "$0")" && pwd) || exit 2
if [ ! -f "$here/common.sh" ]; then echo "aliases.sh: common.sh is missing beside the script" >&2; exit 3; fi
# shellcheck source=common.sh
. "$here/common.sh"
need_builds "$@"
lfn_parse "$lfn"
need_tools
if [ -n "$parent_dir" ] && [ ! -d "$parent_dir" ]; then fail_usage "not a directory: $parent_dir"; fi
if [ "$what" = folder ]; then folder_parse "$folder"; fi

run_begin aliases
# A folder made under --parent is outside the run's directory: it goes whatever way the run ends.
outside=""
trap 'if [ -n "$outside" ]; then rm -rf "$outside"; fi; run_end' EXIT
guest_build ALIASES "$tmp/c" || invalid "ALIASES did not build"

# The Wine-style short name the emulator computes for each "wine long name <n>.txt"
# (wine_hash_short_file_name in drive_cache.cpp), written here so the folder needs no hash.
WINE_NAMES=(WINE~B2P.TXT WINE~F2P.TXT WINE~J2O.TXT WINE~N2O.TXT WINE~RON.TXT WINE~VON.TXT WINE~ZOM.TXT WINE~3OM.TXT)

# cases_folder <dir> <manifest>: the folder of the cases, every file of a size of its own, and
# its manifest: name, size (or dir), and whether the name is the file's own 8.3 name (given),
# needs an alias (made), or differs from another only in case (dup). A real name shaped like an
# alias is written before its long names: where the file system names the aliases, a long name
# made first takes that name, and the write of the real file then lands on it.
cases_folder() {
    local d=$1 manifest=$2 size=0 stem upper i n
    mkdir -p "$d" || return
    : > "$manifest" || return
    put() {
        size=$((size + 1))
        head -c "$size" /dev/zero > "$d/$1" || return
        printf '%s\t%s\t%s\n' "$1" "$size" "$2" >> "$manifest"
    }
    for stem in a b c d e f g h j k m n; do
        upper=$(printf '%s' "$stem$stem$stem$stem$stem$stem" | tr '[:lower:]' '[:upper:]')
        put "$upper~1.TXT" given
        put "$stem$stem$stem $stem$stem$stem.txt" made
    done
    put "SIBLIN~2.DAT" given
    put "sibling one.dat" made; put "sibling two.dat" made; put "sibling six.dat" made
    put "TENTH~10.DAT" given
    i=1
    while [ "$i" -le 11 ]; do printf -v n 'tenth file %02d.dat' "$i"; put "$n" made; i=$((i + 1)); done
    put "NOEXTL~1" given; put "noext long name" made
    put "lowerc~1.txt" given; put "lowercase name.txt" made
    put "PLAIN.TXT" given; put "unique long name.txt" made; put "TILDE~9.TXT" given
    for n in first second third fourth fifth sixth; do put "01.$n song.mid" made; done
    put "01aaaa long.mid" made
    i=1
    while [ "$i" -le 14 ]; do printf -v n 'americ tune %02d.mid' "$i"; put "$n" made; i=$((i + 1)); done
    put "amerik tune.mid" made
    i=0
    while [ "$i" -lt "${#WINE_NAMES[@]}" ]; do
        put "wine long name $i.txt" made
        put "${WINE_NAMES[$i]}" given
        i=$((i + 1))
    done
    put "DIRLON~1" given
    mkdir "$d/dirlong name" || return
    printf '%s\t%s\t%s\n' "dirlong name" dir made >> "$manifest"
    : > "$d/case-probe" || return
    if [ ! -e "$d/CASE-PROBE" ]; then
        put "readme.txt" dup; put "README.TXT" dup
        put "Mixed.Dat" dup; put "MIXED.DAT" dup; put "mixed.dat" dup
    fi
    rm "$d/case-probe"
}

# cases_judge <manifest> <report> <on|off>: the figures of one report, or nothing when a listing
# is empty.
cases_judge() {
    LC_ALL=C awk -F'|' -v lfn="$3" '
        FNR == NR {
            split($0, m, "\t"); size[m[1]] = m[2]; kind[m[1]] = m[3]; host++
            if (m[2] != "dir") files[m[2]] = 1
            next
        }
        $1 == "sfn" && $2 != "." && $2 != ".." { sfn[$2]++; entries++; next }
        $1 == "lfn" && $2 != "none" && $2 != "." && $2 != ".." {
            n = NF; name = $2; for (i = 3; i <= n - 3; i++) name = name "|" $i
            alias = $(n - 2); lsize = $n
            lrows++; aliases[alias]++; lname[lrows] = name; lalias[lrows] = alias; lsz[lrows] = lsize
            # the directory bit, 10h, of the attribute byte in hex
            ldir[lrows] = index("13579bdfBDF", substr($(n - 1), 1, 1)) > 0
            next
        }
        $1 == "find" { sub(/^n=/, "", $3); if ($3 + 0 != 1) { notone++; detail["exact_search_not_one|" $2 "|n=" $3] = 1 }; next }
        $1 == "open" { opened[$2] = $3; if ($3 !~ /^err=/) reached[$3] = 1; next }
        $1 == "lopen" { n = NF; name = $2; for (i = 3; i < n; i++) name = name "|" $i; lopened[name] = $n; next }
        END {
            if (entries == 0 || (lfn == "on" && lrows == 0)) exit 3
            for (s in sfn) if (sfn[s] > 1) shared[s] = 1
            for (a in aliases) if (aliases[a] > 1) shared[a] = 1
            for (s in shared) nshared++
            for (f in kind) {
                if (kind[f] == "given") { u = toupper(f); if (opened[u] != size[f]) lost++ }
                if (size[f] != "dir" && !(size[f] in reached)) unreached++
            }
            printf "entries=%d host=%d names_shared=%d exact_search_not_one=%d real_name_not_its_own=%d files_no_short_name_opens=%d",
                entries, host, nshared, notone, lost, unreached
            if (lfn == "on") {
                for (r = 1; r <= lrows; r++) {
                    name = lname[r]
                    if (!(name in size)) { wrong++; detail["listed_with_another_size|" name "|not on the host"] = 1; continue }
                    if (size[name] == "dir") { if (!ldir[r]) { wrong++; detail["listed_with_another_size|" name "|a directory listed as a file"] = 1 }; continue }
                    if (lsz[r] != size[name]) { wrong++; detail["listed_with_another_size|" name "|" lsz[r] ", is " size[name]] = 1 }
                    if (opened[lalias[r]] != size[name]) { other++; detail["name_opens_another_file|" lalias[r] "|of " name ", opens " opened[lalias[r]]] = 1 }
                    if (lopened[name] != size[name]) { longother++; detail["long_name_opens_another_file|" name "|opens " lopened[name] ", is " size[name]] = 1 }
                }
                printf " listed_with_another_size=%d name_opens_another_file=%d long_name_opens_another_file=%d", wrong, other, longother
            }
            printf "\n"
            fflush()
            sorted = "LC_ALL=C sort"
            for (d in detail) print "  " d | sorted
            for (s in shared) print "  shared|" s | sorted
            for (f in kind) if (size[f] != "dir" && !(size[f] in reached)) print "  no_short_name_opens|" f | sorted
            for (f in kind) if (kind[f] == "given" && opened[toupper(f)] != size[f]) print "  real_name_not_its_own|" f "|opens " opened[toupper(f)] | sorted
            close(sorted)
        }' "$1" "$2"
}

# folder_judge <host sizes> <report> <on|off>: the figures of one listing of a host folder.
folder_judge() {
    LC_ALL=C awk -F'|' -v lfn="$3" '
        FNR == NR { t = index($0, "\t"); size[substr($0, t + 3)] = substr($0, 1, t - 1); host++; next }
        $1 == "lfn" && $2 != "none" && $2 != "." && $2 != ".." {
            n = NF; name = $2; for (i = 3; i <= n - 3; i++) name = name "|" $i
            entries++; lrows++; count[$(n - 2)]++
            if (name in size) { matched++; if (size[name] != "dir" && size[name] != $n) wrong++ }
            next
        }
        $1 == "sfn" && $2 != "." && $2 != ".." { entries++; count[$2]++; next }
        END {
            if (entries == 0 || (lfn == "on" && lrows == 0)) exit 3
            for (c in count) if (count[c] > 1) { nshared++; sharing += count[c] }
            printf "entries=%d host=%d names_shared=%d entries_sharing=%d", entries, host, nshared, sharing
            if (lfn == "on") printf " matched=%d listed_with_another_size=%d", matched, wrong
            printf "\n"
        }' "$1" "$2"
}

# host_sizes <dir> <out>: each entry of the folder as <size or dir><tab>./<name>.
host_sizes() {
    local out=$2 format
    if stat -c '%s' . > /dev/null 2>&1; then format=(-c $'%s\t%n'); else format=(-f $'%z\t%N'); fi
    (
        cd "$1" || exit
        find . -mindepth 1 -maxdepth 1 -type f -exec stat "${format[@]}" {} + &&
            find . -mindepth 1 -maxdepth 1 -type d -exec printf 'dir\t%s\n' {} +
    ) > "$out"
}

if [ "$what" = cases ]; then
    if [ -n "$parent_dir" ]; then fx=$parent_dir/aliases-$$ outside=$parent_dir/aliases-$$; else fx=$tmp/fx; fi
    cases_folder "$fx/T" "$tmp/manifest.txt" || invalid "could not make the folder"
    made=$(wc -l < "$tmp/manifest.txt" | tr -d ' ')
    host_count=$(find "$fx/T" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')
    [ "$made" = "$host_count" ] || invalid "the folder came out with $host_count entries, not $made"
    echo "aliases.sh: cases, long names $lfn, $host_count entries"
else
    folder_resolve "$folder" "$lfn"
    host_sizes "$parent/$base" "$tmp/host.txt" || invalid "the host's sizes could not be read"
    echo "aliases.sh: folder $folder, long names $lfn, $host_count entries"
fi

n=0 first="" differ=0
for build in "$@"; do
    n=$((n + 1))
    if [ "$what" = cases ]; then
        guest_run "$n" "$build" "$fx" "" ALIASES.TXT "$SECONDS_BOUND" "c:" 'ALIASES.EXE D:\T C:\ALIASES.TXT'
    else
        guest_run "$n" "$build" "$parent" " -ro" ALIASES.TXT "$FOLDER_SECONDS_BOUND" "c:" "ALIASES.EXE D:\\$base C:\\ALIASES.TXT list"
    fi
    LC_ALL=C tr -d '\r' < "$guest_out" > "$tmp/report-$n.txt" || invalid "build $n's report could not be read"
    exact_whole "$tmp/report-$n.txt" || invalid "build $n's report has no line or no trailer"
    if [ "$what" = cases ]; then
        judged=$(cases_judge "$tmp/manifest.txt" "$tmp/report-$n.txt" "$lfn") || invalid "build $n listed nothing"
    else
        judged=$(folder_judge "$tmp/host.txt" "$tmp/report-$n.txt" "$lfn") || invalid "build $n listed nothing"
    fi
    figures=${judged%%$'\n'*}
    case "$figures" in entries=*) ;; *) invalid "build $n's report gave no figures" ;; esac
    echo "aliases.sh: $what lfn=$lfn $figures build=\"$emu_version\" binary=$build"
    if [ "$judged" != "$figures" ]; then printf '%s\n' "${judged#*$'\n'}"; fi
    if [ -z "$first" ]; then first=$judged; elif [ "$judged" != "$first" ]; then differ=1; fi
done
if [ "$#" -gt 1 ]; then
    if [ "$differ" -eq 1 ]; then echo "aliases.sh: DIFFERENT"; exit 1; fi
    echo "aliases.sh: ALIKE"
fi
exit 0
