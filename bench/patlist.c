/* PATLIST.EXE: every entry a 4Eh search returns for a list of patterns that hold a '*' followed
 * by more characters, or that a long name could match where its 8.3 name does not.
 *
 *   usage: PATLIST <folder> <output file>          e.g. PATLIST D:\X C:\PATLIST.TXT
 *
 *   pat|<pattern>|first=<FindFirst's error> n=<entries>|,<name>...
 *   end|lines=<n>
 */
#include <dpmi.h>
#include <go32.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/movedata.h>

#define BLOCK_PARAS 256
#define PATH_OFF 2400
#define ALL 0x37

static unsigned long g_lin;
static unsigned short g_seg;

static int int21(__dpmi_regs *r) { __dpmi_int(0x21, r); return (r->x.flags & 1) ? r->x.ax : 0; }

int main(int argc, char **argv)
{
    static const char *patterns[] = {
        "*R.TXT", "B*R.TXT", "*O.TXT", "ZED.T*T", "*.T*T", "*.*D", "TWO.*", "ALPHA*.MID", "A*~1.MID",
        "*~1.*", "NOEXT*.*", "N*", "MIXCASE.TXT", "????????.???", "*.*",
    };
    static char list[4096], path[400];
    __dpmi_regs r;
    FILE *out;
    char name[13];
    int sel, s, err, n, lines = 0;
    unsigned i;

    if (argc != 3) { fprintf(stderr, "usage: PATLIST <folder> <output file>\n"); return 2; }
    s = __dpmi_allocate_dos_memory(BLOCK_PARAS, &sel);
    if (s == -1) { fprintf(stderr, "PATLIST: no conventional memory\n"); return 3; }
    g_seg = (unsigned short)s;
    g_lin = (unsigned long)g_seg << 4;
    out = fopen(argv[2], "w");
    if (!out) { fprintf(stderr, "PATLIST: cannot write %s\n", argv[2]); return 3; }

    for (i = 0; i < sizeof patterns / sizeof patterns[0]; i++) {
        sprintf(path, "%s\\%s", argv[1], patterns[i]);
        dosmemput(path, strlen(path) + 1, g_lin + PATH_OFF);
        /* The C library moves the DTA when it opens a file with long names off. */
        memset(&r, 0, sizeof r);
        r.h.ah = 0x1A; r.x.ds = g_seg; r.x.dx = 0;
        __dpmi_int(0x21, &r);
        memset(&r, 0, sizeof r);
        r.h.ah = 0x4E; r.x.cx = ALL; r.x.ds = g_seg; r.x.dx = PATH_OFF;
        err = int21(&r);
        list[0] = 0;
        n = 0;
        if (err == 0) {
            do {
                dosmemget(g_lin + 30, 13, name); name[12] = 0;
                strcat(list, ","); strcat(list, name);
                n++;
                memset(&r, 0, sizeof r);
                r.h.ah = 0x4F;
            } while (int21(&r) == 0);
        }
        fprintf(out, "pat|%s|first=%d n=%d|%s\n", patterns[i], err, n, list);
        lines++;
    }
    fprintf(out, "end|lines=%d\n", lines);
    fclose(out);
    return 0;
}
