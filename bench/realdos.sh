#!/usr/bin/env bash
# Boots the DOS of a hard disk image inside DOSBox-X and runs one of the guest programs there, over
# a FAT disk made for the run: the answers are that DOS's, not the emulator's. See README.md
# beside this script.
set -u

usage() {
    cat <<'EOT'
usage: realdos.sh <build> <dos> <boot image> <id|findlife|exact|enumstat|drift|dtadump|patlist|
                     template|findpos|findpos-labelled|dosans|dosans-labelled|dosans-cd|memprobe|fc|
                     xcopy|dirgone|xcomsim|xcomsim-relay|nodrive>
       realdos.sh <build> <dos> <boot image> <junktest|dirtest> <folder>

  <build>       a DOSBox-X executable. It is only the machine here: its own DOS is shut down
                when the image boots
  <dos>         which DOS the image starts, and so how the run starts it:
                  msdos710  the system disk of a Windows 98, whose kernel is MS-DOS 7.10
                  msdos622  a hard disk MS-DOS 6.22 was installed on, its tools in C:\DOS
                  freedos   FreeDOS 1.4's USB Lite image, its tools in C:\FREEDOS\BIN and its
                            packages in C:\PACKAGES: LABEL is installed there from its own
                            package when the run needs it
  <boot image>  a hard disk image, raw or VHD, whose first partition starts that DOS. It is never
                written: the run boots a copy
  id            which DOS answers, and nothing else
  findlife      FINDLIFE over the two folders findlife.sh makes
  exact         EXACT over the folder exact.sh makes
  enumstat      ENUMSTAT in its modes s, x and n over 3,000 files with 8.3 names
  drift         DRIFT over the folder exact.sh makes
  dtadump       DTADUMP over the folder exact.sh makes
  patlist       PATLIST over the folder exact.sh makes
  template      TEMPLATE over the files template.sh makes, in the root of the run's disk, which
                is then labelled DISK1
  findpos       FINDPOS over the folder exact.sh makes, the run's disk as it is made: with no
                label
  findpos-labelled  the same once the image's own LABEL has named the disk FPLABEL
  dosans        DOSANS over the folder exact.sh makes, the run's disk with no label
  dosans-labelled  the same once the image's own LABEL has named the disk FPLABEL
  dosans-cd     DOSANS over a CD image, fixtures/cdans/game.iso.gz, attached to the booted DOS as an
                ATAPI drive and read through the DOS's own CD stack: MS-DOS 6.22 with its CD1.SYS and
                MSCDEX 2.23, MS-DOS 7.10 with MSCDEX 2.25 and the CD1.SYS in DIRCACHE_CD1_SYS (7.10
                ships no driver). FreeDOS: INVALID, none of its drivers leaves a drive MSCDEX opens
  memprobe      MEMPROBE in its mode e over 1,835 files with 8.3 names: each one looked up by
                a 4Eh that is never continued
  fc            the emulator's FC.EXE run 300 times from a batch file, as fc.sh runs it, in a
                folder of 700 files
  xcopy         the emulator's XCOPY.EXE over the tree xcopy.sh makes
  dirgone       DIRGONE over the folder dirgone.sh makes
  xcomsim       XCOMSIM over the drive xcomsim.sh makes, with X-COM Apocalypse's lookups
                (xcomsim/calls.txt) and its defaults: a model, not the game
  xcomsim-relay the same with --relay: the listing through the lookups' one DTA
  nodrive       the lines of nodrive.sh on Q:, a letter the DOS has no drive for: label q: X,
                label q:, label q:X, xcopy c:\A.TXT q:\ and the path commands copy, del, type,
                attrib, truename, cd, md, rd, dir, ren and a quoted path, each through REDIR,
                which keeps the error messages too
  junktest      the batch files of the archive of upstream issue 6827, unpacked in <folder>,
                in the run the issue describes: 300.BAT, JUNK.BAT, 300.BAT, each through
                COMMAND /C so that what it prints is kept, with the emulator's FC.EXE as
                junktest.sh runs them
  dirtest       DIRTEST.EXE of the archive of upstream issue 2485, unpacked in <folder>, as
                dirtest.sh runs it: the emulator, which is the machine, types Enter every few
                seconds from before the image boots, and the first one after the program's
                closing dialog ends it

the guest: C: is the copy of the image, with the programs in C:\RD and an AUTOEXEC.BAT that runs
them, never returns and turns the machine off, so no Windows starts; D: is a FAT16 image made
for the run that holds the folders under the names the emulator shows with long names off. For
junktest D:\JUNK holds the reporter's folder (a FAT16 root holds 512 entries, which JUNK.BAT
passes), for dirtest D:'s root; the program runs there.

every line it prints names the DOS: its own lines start "realdos.sh: <dos>: ", the program's
report lines "<dos>|". It prints the machine's path and version line, the image, the DOS's own
VER line, what DOSID read of the DOS that answered, then the program's report whole (for
enumstat, one line per mode; for dtadump, the figures dtadump.sh prints come first; for
memprobe, the guest's line; for nodrive, a line per command: its name, the command and what the
DOS answered, its lines joined by " / "; for fc, how
many runs said the two files do not differ; for xcopy, how many files and folders the tree
holds, how many of each that DOS's own DIR lists under the copy, and the count XCOPY printed; for
junktest, the entries that DOS's DIR lists in D:\JUNK at the end, how many of them are .TMP
files, and the lines the batch files printed, counted as junktest.sh counts them; for dirtest,
the files that DOS's DIR lists in D:\DATA and that the program returned: it draws on the
screen and leaves nothing a batch file can read).

environment:
  DJDIR                 the DJGPP cross toolchain (default: $HOME/djgpp)
  DIRCACHE_PREBUILT     a folder holding the guest programs built on another host

exit: 0 the report is the image's DOS's | 2 usage
      3 INVALID: the folders did not reach the disk whole, the image did not boot or its DOS
        did not reach the end of the batch, the emulator's own DOS answered, or the report is
        cut short; for junktest and dirtest also a folder of the reporter's files that is absent
        or lacks one of them, and an FC that did not compare them; the run's directory is kept
        and named
EOT
}

STAGE_SECONDS=900
BOOT_SECONDS=1800
ENUM_FILES=3000
ENUM_MODES="s x n"
EACH_FILES=1835
FC_FILES=700
FC_RUNS=300
JUNKTEST_BATCHES="300 JUNK 300"
# DIRTEST's FILE() reads the FAT folder from its start for every file, so on this DOS the loop
# grows with the square of the folder, each read paid at the emulated disk's rate: Enter for 100
# minutes, and the boot bounded by the same.
DIRTEST_KEYS=600
DIRTEST_BOOT_SECONDS=6000
DISK_MB=64
# name|line: nodrive.sh's lines on a drive that is not mounted, under its names. The XCOPY line
# and the path commands read A.TXT off C:, where the batch copies it before the lines run.
NODRIVE_LINES='label-q-x|label q: X
label-q|label q:
label-qx|label q:X'
NODRIVE_LINES+=$'\n'"xcopy-q|xcopy c:\\A.TXT q:\\
copy-q|copy c:\\A.TXT q:\\
del-q|del q:\\A.TXT
type-q|type q:\\A.TXT
attrib-q|attrib q:\\A.TXT
truename-q|truename q:\\A.TXT
cd-q|cd q:
cd-q-root|cd q:\\
md-q|md q:\\X
dir-q|dir q:\\ /B
ren-q|ren q:\\A.TXT B.TXT
rd-q|rd q:\\X
quoted-q|type \"q:\\A.TXT\""

if [ $# -eq 1 ] && [ "$1" = "--help" ]; then usage; exit 0; fi
if [ $# -ne 4 ] && [ $# -ne 5 ]; then usage >&2; exit 2; fi
build=$1 dos=$2 image=$3 what=$4 folder=${5:-}

tool=realdos.sh
here=$(cd "$(dirname "$0")" && pwd) || exit 2
if [ ! -f "$here/common.sh" ]; then echo "realdos.sh: common.sh is missing beside the script" >&2; exit 3; fi
# shellcheck source=common.sh
. "$here/common.sh"
need_builds "$build"
# What each DOS needs from the run: the folders of its tools, and the file its kernel reads its
# configuration from. FreeDOS reads FDCONFIG.SYS, whose SHELL line names the batch file to start.
case "$dos" in
    msdos710) dos_path='C:\WINDOWS;C:\WINDOWS\COMMAND' config=CONFIG.SYS config_lines=("FILES=40") ;;
    msdos622) dos_path='C:\DOS' config=CONFIG.SYS config_lines=("FILES=40") ;;
    freedos)
        dos_path='C:\FREEDOS\BIN' config=FDCONFIG.SYS
        config_lines=("FILES=40" 'SHELL=C:\FREEDOS\BIN\COMMAND.COM C:\FREEDOS\BIN /E:1024 /P=C:\AUTOEXEC.BAT')
        ;;
    *) fail_usage "the DOS is msdos710, msdos622 or freedos, not: $dos" ;;
esac
tool="realdos.sh: $dos"
if [ ! -f "$image" ]; then fail_usage "not a disk image: $image"; fi
case "$what" in
    id) programs="" ;;
    findlife) programs=FINDLIFE ;;
    exact) programs=EXACT ;;
    enumstat) programs=ENUMSTAT ;;
    drift) programs=DRIFT ;;
    dtadump) programs=DTADUMP ;;
    patlist) programs=PATLIST ;;
    template) programs=TEMPLATE ;;
    findpos|findpos-labelled) programs=FINDPOS ;;
    memprobe) programs=MEMPROBE ;;
    dirgone) programs=DIRGONE ;;
    dosans|dosans-labelled|dosans-cd) programs=DOSANS ;;
    xcomsim|xcomsim-relay) programs=XCOMSIM ;;
    nodrive) programs=REDIR ;;
    fc|xcopy|junktest|dirtest) programs="" ;;
    *) fail_usage "the program is id, findlife, exact, enumstat, drift, dtadump, patlist, template, findpos, findpos-labelled, dosans, dosans-labelled, dosans-cd, memprobe, fc, xcopy, dirgone, xcomsim, xcomsim-relay, nodrive, junktest or dirtest, not: $what" ;;
esac
case "$what" in
    junktest|dirtest) if [ $# -ne 5 ]; then fail_usage "$what takes the folder of the reporter's files"; fi ;;
    *) if [ $# -ne 4 ]; then fail_usage "$what takes no folder"; fi ;;
esac
need_tools
cd_driver=""
if [ "$what" = dosans-cd ]; then
    case "$dos" in
        msdos622) cd_driver='C:\DOS\CD1.SYS' ;;
        msdos710)
            if [ ! -f "${DIRCACHE_CD1_SYS:-}" ]; then fail_usage "MS-DOS 7.10 ships no CD driver: DIRCACHE_CD1_SYS names the CD1.SYS of an MS-DOS 6.22 disk"; fi
            cd_driver='C:\RD\CD1.SYS'
            ;;
        *) echo "$tool: INVALID: no CD driver of $dos leaves a drive that MSCDEX opens" >&2; exit 3 ;;
    esac
    config_lines+=("DEVICE=$cd_driver /D:banana")
fi
# shellcheck disable=SC2086  # the names, split on purpose
case "$what" in
    junktest) reporter_folder "$folder" $JUNKTEST_FILES ;;
    dirtest) reporter_folder "$folder" $DIRTEST_FILES ;;
esac

run_begin realdos
stage=$tmp/stage boot=$tmp/boot collect=$tmp/collect
mkdir -p "$stage/RD" "$stage/BOOT" "$stage/D" "$boot" "$collect" || invalid "could not make the run's directories"
# A clone where the file system has them, a copy elsewhere. The copy keeps the image's extension:
# the emulator tells a VHD by it. A copy of a read-only image is read-only too, and the guest
# writes the copy.
image_name=c.${image##*.}
cp -c "$image" "$boot/$image_name" 2> /dev/null || cp "$image" "$boot/$image_name" || invalid "could not copy the image"
chmod u+w "$boot/$image_name" || invalid "could not make the copy of the image writable"

for p in DOSID $programs; do
    guest_build "$p" "$stage/RD" || invalid "$p did not build"
done
if [ "$what" = nodrive ]; then printf 'x' > "$stage/RD/A.TXT" || invalid "could not write A.TXT"; fi
if [ "$what" = dosans-cd ]; then
    gzip -dc "$here/fixtures/cdans/game.iso.gz" > "$tmp/game.iso" || invalid "the CD image could not be unpacked"
    if [ "$dos" = msdos710 ]; then cp "$DIRCACHE_CD1_SYS" "$stage/RD/CD1.SYS" || invalid "could not copy the CD driver"; fi
fi

# The batch files are DOS's: CR LF.
dos_lines() { printf '%s\r\n' "$@"; }

# Connects to the BIOS's power management and turns the machine off: how the run ends once the
# DOS is the image's and no shell of the emulator is left to say exit.
#   mov ax,5301h / xor bx,bx / int 15h              connect, real mode
#   mov ax,530Eh / xor bx,bx / mov cx,0102h / int 15h   version 1.2
#   mov ax,5307h / mov bx,1 / mov cx,3 / int 15h    all devices: off
#   mov ax,4C01h / int 21h                          still here
printf '\xB8\x01\x53\x31\xDB\xCD\x15\xB8\x0E\x53\x31\xDB\xB9\x02\x01\xCD\x15\xB8\x07\x53\xBB\x01\x00\xB9\x03\x00\xCD\x15\xB8\x01\x4C\xCD\x21' \
    > "$stage/RD/APMOFF.COM" || invalid "could not write APMOFF.COM"

# One result file, a section per answer. Each program writes OUT.TXT, removed before the next:
# a program that left nothing leaves its section empty, never the one before it. Every path is
# whole: a program may leave another current directory behind.
result='C:\RD\RESULT.TXT' out='C:\RD\OUT.TXT'
batch=("@ECHO OFF" "PATH C:\\RD;$dos_path" "C:" "CD \\RD" "ECHO section ver> $result" "VER >> $result")
report() {
    batch+=("ECHO section $1>> $result" "$2" "TYPE $out >> $result" "DEL $out")
}
report dos "DOSID.EXE $out"
case "$what" in
    findlife)
        findlife_tree "$stage/D" || invalid "could not make the folders"
        # FINDLIFE reads the host path of its remount case here: there is none under this DOS.
        dos_lines "D:\\" > "$stage/RD/ROOT.TXT"
        report findlife "FINDLIFE.EXE D:\\A D:\\B $out C:\\RD\\ROOT.TXT"
        ;;
    dosans-cd)
        # The CD is the disk the program reads: no folder is made for D:. MSCDEX gives the driver's
        # unit the letter D: and says so, which the run keeps and checks.
        batch+=("ECHO section mscdex>> $result" "MSCDEX.EXE /D:banana /L:D >> $result")
        report dosans-cd "DOSANS.EXE D:\\X $out"
        ;;
    exact|drift|dtadump|patlist|findpos|findpos-labelled|dosans|dosans-labelled)
        exact_tree "$stage/D" || invalid "could not make the folder"
        # The label is the image's DOS's own work: an entry as that DOS writes one. FreeDOS's
        # USB Lite image carries LABEL only as a package, which its own installer puts in place;
        # the installer will not start without a folder in TEMP to unpack into.
        if [ "$what" = findpos-labelled ] || [ "$what" = dosans-labelled ]; then
            if [ "$dos" = freedos ]; then batch+=("SET DOSDIR=C:\\FREEDOS" "SET TEMP=C:\\RD" "FDINST INSTALL C:\\PACKAGES\\BASE\\LABEL.ZIP > NUL"); fi
            batch+=("LABEL D:$FINDPOS_LABEL")
        fi
        report "$what" "$programs.EXE D:\\X $out"
        ;;
    enumstat)
        folder_make "$stage/D/DIR" "$ENUM_FILES" 83 || invalid "could not make the folder"
        for mode in $ENUM_MODES; do report "enumstat-$mode" "ENUMSTAT.EXE $mode D:\\DIR $out"; done
        ;;
    template)
        template_tree "$stage/D" || invalid "could not make the volume's files"
        report template "TEMPLATE.EXE D $out"
        ;;
    dirgone)
        dirgone_tree "$stage/D" || invalid "could not make the folder"
        report dirgone "DIRGONE.EXE D:\\G $out"
        ;;
    xcomsim|xcomsim-relay)
        xcomsim_tree "$stage/D" "$here/xcomsim/calls.txt" || invalid "could not make the drive"
        cp "$here/xcomsim/calls.txt" "$stage/RD/CALLS.TXT" || invalid "could not copy the calls file"
        relay=""
        if [ "$what" = xcomsim-relay ]; then relay=" --relay"; fi
        report xcomsim "XCOMSIM.EXE C:\\RD\\CALLS.TXT D:\\XCOMA D:\\LISTA D:\\LISTB $out$relay"
        ;;
    memprobe)
        folder_make "$stage/D/DIR" "$EACH_FILES" 83 || invalid "could not make the folder"
        synth_name 83 0
        report memprobe "MEMPROBE.EXE e D:\\DIR\\$synth_name_out $EACH_FILES - - > $out"
        ;;
    fc)
        fc_folder "$stage/D/DIR" "$FC_FILES" "$FC_RUNS" "$out" || invalid "could not make the folder"
        batch+=("ECHO section fc>> $result" "D:" "CD \\DIR" "CALL RUNS.BAT" "C:" "CD \\RD" "TYPE $out >> $result" "DEL $out")
        ;;
    xcopy)
        xcopy_tree "$stage/D/TREE" || invalid "could not make the tree"
        # What arrived is listed by the DOS itself, not taken from XCOPY's own count.
        batch+=("ECHO section xcopy>> $result" "MD D:\\COPY" "XCOPY D:\\TREE\\*.* D:\\COPY /S /E /Y > $out"
            "ECHO files>> $out" "DIR D:\\COPY /S /B /A-D >> $out" "ECHO folders>> $out" "DIR D:\\COPY /S /B /AD >> $out"
            "TYPE $out >> $result" "DEL $out")
        ;;
    nodrive)
        # A.TXT goes to C:'s root, where the XCOPY line names it. A blank line after each answer:
        # a message that ends with no line break would join the next section's name.
        batch+=("COPY /Y C:\\RD\\A.TXT C:\\A.TXT > NUL")
        while IFS='|' read -r name line; do
            batch+=("ECHO section nodrive-$name>> $result" "REDIR.EXE $out $line" "TYPE $out >> $result" "ECHO.>> $result" "DEL $out")
        done <<< "$NODRIVE_LINES"
        ;;
    junktest)
        # In a folder of D:, not its root: a FAT16 root holds 512 entries, and the folder the
        # reporter mounted as a drive has no such limit. A batch file prints through a COMMAND /C
        # of its own, because CALL keeps no redirection.
        if ! mkdir "$stage/D/JUNK" || ! cp -R "$folder/." "$stage/D/JUNK/"; then invalid "could not copy the reporter's folder"; fi
        batch+=("ECHO section junktest>> $result" "D:" "CD \\JUNK" "FC /B E001.EXP RESULT.TXT >> $result")
        for b in $JUNKTEST_BATCHES; do batch+=("COMMAND /C $b.BAT >> $result"); done
        batch+=("ECHO section entries>> $result" "DIR D:\\JUNK /B >> $result" "C:" "CD \\RD")
        ;;
    dirtest)
        cp -R "$folder/." "$stage/D/" || invalid "could not copy the reporter's folder"
        batch+=("ECHO section dirtest>> $result" "D:" "CD \\" "DIRTEST.EXE"
            "ECHO section entries>> $result" "DIR D:\\DATA /B /A-D >> $result" "C:" "CD \\RD")
        ;;
esac
# The loop holds the machine if the power-off is refused: AUTOEXEC.BAT must not return, or the
# image goes on to start its Windows.
batch+=("ECHO section done>> $result" "APMOFF.COM" ":HOLD" "GOTO HOLD")
dos_lines "${batch[@]}" > "$stage/BOOT/AUTOEXEC.BAT"
dos_lines "${config_lines[@]}" > "$stage/BOOT/$config"
host_files=$(find "$stage/D" -type f | wc -l | tr -d ' ')
host_dirs=$(find "$stage/D" -mindepth 2 -type d | wc -l | tr -d ' ')

# conf <run dir> <core> <autoexec line>...
# ver=7.1 on every conf that mounts the image: under a lower reported version DOSBox-X answers a
# FAT32 volume with a native dialog and waits for a click, headless too. No line may end in a
# backslash: the conf reader joins it with the next one.
conf() {
    local run=$1 core=$2
    shift 2
    {
        printf '[dosbox]\nmemsize=64\n\n[cpu]\ncore=%s\ncycles=max\n\n[dos]\nver=7.1\nlfn=false\n\n[autoexec]\n' "$core"
        printf '%s\n' "$@"
    } > "$run/run.conf"
}
c_img=$(host_path "$boot/$image_name") d_img=$(host_path "$boot/d.img")

# The emulator's own shell puts everything on the two disks, long names off: the folders reach D:
# under the 8.3 names a program sees through the emulator's host-folder drive.
# A large folder goes through the shell's own COPY, a folder at a time: XCOPY looks every file up
# while it lists the folder, and the emulator's search table gives out before the listing ends.
# FC.EXE and XCOPY.EXE are the emulator's own, taken from its Z: drive like the DPMI host.
case "$what" in
    id|dosans-cd|nodrive) folders=("echo 0 file(s) copied > e:\\STAGED.TXT") ;;
    enumstat|memprobe) folders=("md d:\\DIR" "copy /y e:\\D\\DIR\\*.* d:\\DIR > e:\\STAGED.TXT") ;;
    fc) folders=("copy /y z:\\dos\\fc.exe c:\\RD > nul" "md d:\\DIR" "copy /y e:\\D\\DIR\\*.* d:\\DIR > e:\\STAGED.TXT") ;;
    xcopy)
        folders=("copy /y z:\\dos\\xcopy.exe c:\\RD > nul" "echo the tree, a folder at a time > e:\\STAGED.TXT")
        while IFS= read -r dir; do
            dir=${dir//\//\\}
            folders+=("md d:\\$dir" "copy /y e:\\D\\$dir\\*.* d:\\$dir >> e:\\STAGED.TXT")
        done < <(cd "$stage/D" && find TREE -type d | LC_ALL=C sort)
        ;;
    template) folders=("label d: $TEMPLATE_LABEL" "xcopy e:\\D\\*.* d:\\ /s /e /y > e:\\STAGED.TXT" "vol d: >> e:\\STAGED.TXT") ;;
    junktest) folders=("copy /y z:\\dos\\fc.exe c:\\RD > nul" "md d:\\JUNK" "copy /y e:\\D\\JUNK\\*.* d:\\JUNK > e:\\STAGED.TXT") ;;
    dirtest) folders=("copy /y e:\\D\\*.* d:\\ > e:\\STAGED.TXT" "md d:\\DATA" "copy /y e:\\D\\DATA\\*.* d:\\DATA >> e:\\STAGED.TXT") ;;
    *) folders=("xcopy e:\\D\\*.* d:\\ /s /e /y > e:\\STAGED.TXT") ;;
esac
conf "$stage" dynamic \
    "mount e \"$(host_path "$stage")\"" \
    "imgmount c \"$c_img\"" \
    "imgmake \"$d_img\" -t hd -size $DISK_MB" \
    "imgmount d \"$d_img\"" \
    "md c:\\RD" \
    "if exist c:\\RD\\RESULT.TXT del c:\\RD\\RESULT.TXT" \
    "copy /y e:\\RD\\*.* c:\\RD > nul" \
    "copy /y z:\\bin\\cwsdpmi.exe c:\\RD > nul" \
    "copy /y e:\\BOOT\\*.* c:\\ > nul" \
    "${folders[@]}" \
    "exit"
emu_run stage "$build" "$stage" STAGED.TXT "$STAGE_SECONDS" || invalid "the disks could not be made"
# One count per COPY, or XCOPY's one count: their sum.
staged=$(LC_ALL=C tr -d '\r' < "$stage/STAGED.TXT" | sed -n 's/^ *\([0-9][0-9]*\) [Ff]ile(s) copied.*/\1/p' | awk '{ n += $1 } END { if (NR) print n }')
if [ "$staged" != "$host_files" ]; then
    invalid "the folders did not reach the disk whole: $host_files files made, ${staged:-no count} copied"
fi
if [ "$what" = template ] && ! LC_ALL=C tr -d '\r' < "$stage/STAGED.TXT" | command grep -a -q "^ *Volume in drive D is $TEMPLATE_LABEL *\$"; then
    invalid "the emulator's shell does not say the disk is labelled $TEMPLATE_LABEL"
fi

# The image's own DOS. What the guest must leave is the image itself, written.
keys=() bound=$BOOT_SECONDS
if [ "$what" = dirtest ]; then keys=("$(dirtest_autotype "$DIRTEST_KEYS")") bound=$DIRTEST_BOOT_SECONDS; fi
d_boot="imgmount d \"$d_img\""
if [ "$what" = dosans-cd ]; then d_boot="imgmount d \"$(host_path "$tmp/game.iso")\" -t iso -ide 2m"; fi
conf "$boot" normal "imgmount c \"$c_img\"" "$d_boot" ${keys[@]+"${keys[@]}"} "boot c:"
# The emulator can die in its AUTOTYPE thread when the DOS turns the machine off with keys still
# to type (SIGSEGV in Typer::Callback on macOS). That exit is taken here, and the run is then
# trusted only if the DOS's batch reached its last section, which the power-off follows.
if [ "$what" = dirtest ] && [ "$HOST_KIND" != windows ]; then accept_exit=139; fi
emu_run boot "$build" "$boot" "$image_name" "$bound" || invalid "the image did not boot, or its DOS wrote nothing"
accept_exit="" off_exit=$emu_exit_accepted
machine=$emu_version
booted=$(log_count 'DOS kernel shutdown, booting a guest OS') || invalid "the emulator's log could not be read"
if [ "$booted" -ne 1 ]; then invalid "the emulator's log does not say it shut its own DOS down to boot the image"; fi

conf "$collect" dynamic \
    "mount e \"$(host_path "$collect")\"" \
    "imgmount c \"$c_img\"" \
    "copy /y c:\\RD\\RESULT.TXT e:\\RESULT.TXT > nul" \
    "exit"
emu_run collect "$build" "$collect" RESULT.TXT 300 || invalid "the image's DOS left no result file"
LC_ALL=C tr -d '\r' < "$collect/RESULT.TXT" > "$tmp/result.txt" || invalid "the result file could not be read"

section() {
    LC_ALL=C awk -v s="section $1" '$0 == s { on = 1; next } /^section / { on = 0 } on' "$tmp/result.txt"
}
if [ "$(tail -n 1 "$tmp/result.txt")" != "section done" ]; then invalid "the image's DOS did not reach the end of its batch"; fi

# Whose DOS: the emulator's own answers INT 21h from its ROM segment and has its Z: drive.
section dos > "$tmp/dos.txt"
if [ "$(tail -n 1 "$tmp/dos.txt")" != "end" ]; then invalid "DOSID left no report"; fi
if command grep -q -E '^dos\|(int21=F000:|drive_z=0$)' "$tmp/dos.txt"; then
    invalid "the emulator's own DOS answered, not the image's"
fi
ver=$(section ver | command grep -a . | head -n 1)
if [ -z "$ver" ]; then invalid "the DOS printed no VER line"; fi

say() { printf '%s: %s\n' "$tool" "$*"; }
# A line of the program's report, named by the DOS that gave it.
named() { sed "s/^/$dos|/" "$@"; }
say "machine: $build ($machine)"
say "image: $image"
say "ver: $ver"
command grep -a '^dos|' "$tmp/dos.txt" | sed "s/^/$tool: /"
case "$what" in
    findlife)
        section findlife > "$tmp/report.txt"
        findlife_whole "$tmp/report.txt" || invalid "FINDLIFE's report has no case or no trailer"
        named "$tmp/report.txt"
        ;;
    exact|drift|dtadump|patlist|template|findpos|findpos-labelled|dirgone|dosans|dosans-labelled|dosans-cd)
        if [ "$what" = dosans-cd ]; then
            section mscdex > "$tmp/mscdex.txt"
            command grep -a -q 'Drive D: = Driver BANANA unit 0' "$tmp/mscdex.txt" || invalid "MSCDEX did not give the CD the letter D:"
            say "mscdex: $(command grep -a -m1 '^MSCDEX Version' "$tmp/mscdex.txt")"
        fi
        section "$what" > "$tmp/report.txt"
        exact_whole "$tmp/report.txt" || invalid "$programs's report has no trailer or its count disagrees"
        if [ "$what" = findpos-labelled ] && ! command grep -a -q "^pos|label-alone|first=0 entry=$FINDPOS_LABEL:" "$tmp/report.txt"; then
            invalid "the image's DOS did not label the disk $FINDPOS_LABEL"
        fi
        if [ "$what" = dtadump ]; then
            figures=$(dtadump_figures "$tmp/report.txt") || invalid "DTADUMP's report lacks the lines its figures are read from"
            say "figures: $figures"
        fi
        named "$tmp/report.txt"
        ;;
    xcomsim|xcomsim-relay)
        section xcomsim > "$tmp/report.txt"
        exact_whole "$tmp/report.txt" || invalid "XCOMSIM's report has no trailer or its count disagrees"
        verdict=$(command grep -a '^listing=' "$tmp/report.txt")
        case "$verdict" in listing=*/*' '*/*' lost='*) ;; *) invalid "XCOMSIM's report has no verdict line" ;; esac
        named "$tmp/report.txt"
        say "$verdict"
        ;;
    enumstat)
        for mode in $ENUM_MODES; do
            line=$(section "enumstat-$mode" | command grep -a '^enumstat|')
            case "$line" in "enumstat|mode=$mode|listed="*) ;; *) invalid "not ENUMSTAT's line for mode $mode: $line" ;; esac
            say "names=83 files=$ENUM_FILES $line"
        done
        ;;
    memprobe)
        line=$(section memprobe | sed -n 's/^\(mode=e k=[0-9]* ok=[0-9]*\) .*/\1/p')
        case "$line" in "mode=e k=$EACH_FILES ok="*) ;; *) invalid "not MEMPROBE's line for $EACH_FILES calls in mode e: $line" ;; esac
        say "names=83 files=$EACH_FILES $line"
        ;;
    fc)
        section fc > "$tmp/report.txt"
        compared=$(fc_compared "$tmp/report.txt")
        if [ "$compared" != "$FC_RUNS" ]; then invalid "FC compared the two files ${compared:-0} times of $FC_RUNS"; fi
        say "files=$FC_FILES runs=$FC_RUNS compared=$compared"
        ;;
    xcopy)
        section xcopy > "$tmp/report.txt"
        if [ "$(command grep -a -c -E '^(files|folders)$' "$tmp/report.txt")" != 2 ]; then invalid "the batch did not list what XCOPY left"; fi
        said=$(xcopy_said "$tmp/report.txt")
        # shellcheck disable=SC2046  # two counts, split on purpose
        set -- $(awk '$0 == "files" || $0 == "folders" { kind = $0; next } index($0, "D:\\COPY\\") == 1 { n[kind]++ } END { print n["files"] + 0, n["folders"] + 0 }' "$tmp/report.txt")
        say "made=$host_files copied=$1 dirs_made=$host_dirs dirs_copied=$2 said=${said:--}"
        ;;
    nodrive)
        while IFS='|' read -r name line; do
            answer=$(section "nodrive-$name" | awk 'NF { printf "%s%s", sep, $0; sep = " / " } END { print "" }')
            if [ -z "$answer" ]; then invalid "the DOS printed nothing for \"$line\""; fi
            echo "$dos|$name|$line|$answer"
        done <<< "$NODRIVE_LINES"
        ;;
    junktest)
        section junktest > "$tmp/report.txt"
        fc_answered "$tmp/report.txt" || invalid "FC did not compare the reporter's two files"
        said=$(junktest_said "$tmp/report.txt")
        # shellcheck disable=SC2086  # the batch files, split on purpose
        junktest_batches $JUNKTEST_BATCHES
        # shellcheck disable=SC2086
        set -- $JUNKTEST_BATCHES
        if [ "$said" != "counted=$((junktest_runs * 300)) done=$#" ]; then
            invalid "the batch files did not reach their end: $said for $JUNKTEST_BATCHES"
        fi
        section entries > "$tmp/entries.txt"
        entries=$(command grep -a -c . "$tmp/entries.txt")
        junk=$(command grep -a -c -i '\.TMP$' "$tmp/entries.txt")
        batches=$JUNKTEST_BATCHES
        say "batches=${batches// /,} entries=$entries junk=$junk $said"
        ;;
    dirtest)
        files=$(section entries | command grep -a -c .)
        staged_data=$(find "$stage/D/DATA" -type f | wc -l | tr -d ' ')
        if [ "$files" != "$staged_data" ]; then invalid "that DOS lists $files files in D:\\DATA, of $staged_data staged"; fi
        if [ -n "$off_exit" ]; then say "the emulator exited $off_exit with AUTOTYPE's keys still pending, after the DOS's batch reached its end"; fi
        say "files=$files returned=1"
        ;;
esac
exit 0
