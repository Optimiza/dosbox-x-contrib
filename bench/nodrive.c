/* NODRIVE.EXE: makes A: the current drive and ends, so that the shell's next line runs with a
 * current drive nothing is mounted on.
 *
 *   usage: NODRIVE
 *
 * INT 21h 0Eh takes A: and B: whether or not a drive is there, as a real DOS does for its two
 * floppy letters. A real DOS has a floppy drive behind them; the emulator, with none mounted,
 * then has no drive at all behind the current one. The program prints nothing: the shell's
 * next line is what is judged.
 */
#include <dpmi.h>
#include <string.h>

int main(void)
{
    __dpmi_regs r;

    memset(&r, 0, sizeof r);
    r.h.ah = 0x0E;
    r.h.dl = 0;
    __dpmi_int(0x21, &r);
    return 0;
}
