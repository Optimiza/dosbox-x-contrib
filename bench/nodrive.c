/* NODRIVE.EXE: makes A: the current drive and prints the current drive as DOS answers it, so
 * that the shell's next line runs with a current drive nothing is mounted on, and the run says
 * which drive that was.
 *
 *   usage: NODRIVE [/S]
 *
 *   /S  changes nothing: prints the current drive only
 *
 * INT 21h 0Eh takes A: and B: whether or not a drive is there, as a real DOS does for its two
 * floppy letters. A real DOS has a floppy drive behind them; the emulator, with none mounted,
 * then has no drive at all behind the current one. INT 21h 19h names the current drive without
 * reading it, so its answer holds with nothing behind it, where the shell's CD prints what the
 * drive's own state leaves.
 */
#include <dpmi.h>
#include <stdio.h>
#include <string.h>

int main(int argc, char **argv)
{
    __dpmi_regs r;

    if (argc > 2 || (argc == 2 && strcmp(argv[1], "/S") != 0)) {
        fputs("usage: NODRIVE [/S]\n", stderr);
        return 2;
    }
    if (argc == 1) {
        memset(&r, 0, sizeof r);
        r.h.ah = 0x0E;
        r.h.dl = 0;
        __dpmi_int(0x21, &r);
    }
    memset(&r, 0, sizeof r);
    r.h.ah = 0x19;
    __dpmi_int(0x21, &r);
    printf("%c:\n", 'A' + r.h.al);
    return 0;
}
