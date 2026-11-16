/* DOSID.EXE: which DOS answers INT 21h, written as text so a run can say whose answers it holds.
 *
 *   usage: DOSID <output file>
 *
 *   dos|version=<major>.<minor> oem=<hex>          AX=3000h, what the DOS reports
 *   dos|true_version=<major>.<minor> flags=<hex>   AX=3306h, what SETVER cannot change
 *   dos|int21=<seg>:<off> code=<8 bytes>           the real-mode vector and the code it points at:
 *                                                  DOSBox-X's own DOS is a callback in the ROM
 *                                                  segment F000, a DOS loaded from disk is code
 *                                                  in low memory
 *   dos|lfn_714e=<error>                           7100 where there is no long-name API
 *   dos|windows_1600=<al>                          00 when no Windows is running
 *   dos|drive_z=<error of a search on Z:\*.*>      0 only where the emulator's own drive exists
 *   end
 */
#include <dpmi.h>
#include <go32.h>
#include <stdio.h>
#include <string.h>
#include <sys/movedata.h>

int main(int argc, char **argv)
{
    __dpmi_regs r;
    unsigned char code[8];
    unsigned short vector[2];
    const char *z = "Z:\\*.*";
    FILE *out;
    int i;

    if (argc != 2) { fprintf(stderr, "usage: DOSID <output file>\n"); return 2; }
    out = fopen(argv[1], "w");
    if (!out) return 3;

    memset(&r, 0, sizeof r);
    r.x.ax = 0x3000;
    __dpmi_int(0x21, &r);
    fprintf(out, "dos|version=%d.%02d oem=%02X\n", r.h.al, r.h.ah, r.h.bh);

    memset(&r, 0, sizeof r);
    r.x.ax = 0x3306;
    __dpmi_int(0x21, &r);
    fprintf(out, "dos|true_version=%d.%02d flags=%02X\n", r.h.bl, r.h.bh, r.h.dh);

    dosmemget(0x21 * 4, 4, vector);
    dosmemget(((unsigned long)vector[1] << 4) + vector[0], sizeof code, code);
    fprintf(out, "dos|int21=%04X:%04X code=", vector[1], vector[0]);
    for (i = 0; i < (int)sizeof code; i++) fprintf(out, "%02X", code[i]);
    fputc('\n', out);

    dosmemput(z, strlen(z) + 1, __tb);
    memset(&r, 0, sizeof r);
    r.x.ax = 0x714E; r.x.cx = 0x37; r.x.si = 1;
    r.x.ds = __tb >> 4; r.x.dx = __tb & 15;
    r.x.es = __tb >> 4; r.x.di = (__tb & 15) + 512;
    r.x.flags = 1;
    __dpmi_int(0x21, &r);
    fprintf(out, "dos|lfn_714e=%04X\n", (r.x.flags & 1) ? r.x.ax : 0);
    if (!(r.x.flags & 1)) {
        r.x.bx = r.x.ax; r.x.ax = 0x71A1;
        __dpmi_int(0x21, &r);
    }

    memset(&r, 0, sizeof r);
    r.x.ax = 0x1600;
    __dpmi_int(0x2F, &r);
    fprintf(out, "dos|windows_1600=%02X\n", r.h.al);

    memset(&r, 0, sizeof r);
    r.h.ah = 0x4E; r.x.cx = 0x37;
    r.x.ds = __tb >> 4; r.x.dx = __tb & 15;
    __dpmi_int(0x21, &r);
    fprintf(out, "dos|drive_z=%d\n", (r.x.flags & 1) ? r.x.ax : 0);

    fprintf(out, "end\n");
    fclose(out);
    return 0;
}
