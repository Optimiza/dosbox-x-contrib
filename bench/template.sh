#!/usr/bin/env bash
# Runs TEMPLATE.EXE headless on two DOSBox-X builds, each over a volume labelled DISK1 made for
# the run, and compares what they answer to the searches that hang on how the search template is
# kept. See README.md beside this script.
set -u

usage() {
    cat <<'EOT'
usage: template.sh <build A> <build B> <fat|host> <on|off>

  <build A>, <build B>  two DOSBox-X executables (the same one twice is the A/A control)
  <fat|host>            the volume searched: a FAT16 disk image each build makes, labels and
                        fills with its own shell, or a host folder mounted with that label
  <on|off>              the guest's long file names ([dos] lfn)

the volume is labelled DISK1 and its root holds eight files: FOO.TXT, FOO, BAR.TXT, PROGRAM,
PROGRAM.TXT, "foo .txt", "program .txt" and "Program Files". On the image they arrive through
the shell's COPY, so with long names off they are there under their 8.3 names.

prints each build's path, version line and report whole, then the verdict and the lines that
differ. On the image the report ends with one line of the shell's own: the free space its DIR
gives for the volume while it is still empty, asked right after a DIR of another drive.

environment:
  DJDIR                 the DJGPP cross toolchain (default: $HOME/djgpp)
  DIRCACHE_PREBUILT     a folder holding TEMPLATE.EXE built on another host, instead of DJGPP

exit: 0 alike | 1 different | 2 usage
      3 INVALID: a run collected nothing, the volume did not come out labelled or whole, or a
        report has no line or no trailer; the run's directory is kept and named
EOT
}

SECONDS_BOUND=300
DISK_MB=64

if [ $# -eq 1 ] && [ "$1" = "--help" ]; then usage; exit 0; fi
if [ $# -ne 4 ]; then usage >&2; exit 2; fi
build_a=$1 build_b=$2 kind=$3 lfn=$4

tool=template.sh
here=$(cd "$(dirname "$0")" && pwd) || exit 2
if [ ! -f "$here/common.sh" ]; then echo "template.sh: common.sh is missing beside the script" >&2; exit 3; fi
# shellcheck source=common.sh
. "$here/common.sh"
need_builds "$build_a" "$build_b"
case "$kind" in fat|host) ;; *) fail_usage "the volume is fat or host, not: $kind" ;; esac
lfn_parse "$lfn"
need_tools

run_begin template
guest_build TEMPLATE "$tmp/c" || invalid "TEMPLATE did not build"
template_tree "$tmp/fx" || invalid "could not make the volume's files"
# The image is mounted under the version a FAT32 or LBA volume asks for: under a lower one the
# emulator answers such a mount with a native dialog. Both volumes run on the one machine.
# shellcheck disable=SC2034  # read by conf_write
conf_dos='ver=7.1'

echo "template.sh: volume $kind, long names $lfn"
for label in A B; do
    if [ "$label" = A ]; then binary=$build_a; else binary=$build_b; fi
    if [ "$kind" = host ]; then
        guest_run "$label" "$binary" "$tmp/fx" " -label $TEMPLATE_LABEL" TEMPLATE.TXT "$SECONDS_BOUND" \
            'vol d: > c:\TEMPLATE.TXT' "c:" 'TEMPLATE.EXE D C:\REPORT.TXT' 'type c:\REPORT.TXT >> c:\TEMPLATE.TXT'
    else
        image=$(host_path "$tmp/run-$label/v.img")
        guest_run "$label" "$binary" "$tmp/fx" "" TEMPLATE.TXT "$SECONDS_BOUND" \
            "imgmake \"$image\" -t hd -size $DISK_MB" "imgmount e \"$image\"" "label e: $TEMPLATE_LABEL" \
            'dir c:\ > c:\DIRC.TXT' 'dir e:\ > c:\DIRE.TXT' \
            'copy d:\*.* e:\ > c:\TEMPLATE.TXT' 'vol e: >> c:\TEMPLATE.TXT' 'type c:\DIRE.TXT >> c:\TEMPLATE.TXT' \
            "c:" 'TEMPLATE.EXE E C:\REPORT.TXT' 'type c:\REPORT.TXT >> c:\TEMPLATE.TXT'
    fi
    LC_ALL=C tr -d '\r' < "$guest_out" > "$tmp/out-$label.txt" || invalid "build $label's output could not be read"
    template_report "$tmp/out-$label.txt" "$kind" > "$tmp/report-$label.txt" || invalid "build $label's volume did not come out labelled and whole"
    echo "template.sh: build $label: $binary ($emu_version)"
    cat "$tmp/report-$label.txt"
    exact_whole "$tmp/report-$label.txt" || invalid "build $label's report has no line or no trailer"
    if [ "$kind" = fat ]; then
        free=$(sed -n 's/^ *[0-9][0-9]* Dir(s) *\([0-9,][0-9,]*\) Bytes free.*/\1/p' "$tmp/out-$label.txt" | head -n 1)
        if [ -z "$free" ]; then invalid "build $label's DIR of the empty volume printed no free space"; fi
        echo "shell|DIR of the volume while empty, after a DIR of another drive|free=$free" | tee -a "$tmp/report-$label.txt"
    fi
done
reports_verdict
