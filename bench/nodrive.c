/* NODRIVE [/S]: makes A: current, which 0Eh takes with no drive behind it, then prints the
 * current drive as 19h names it, without reading it. /S only prints it. */
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
