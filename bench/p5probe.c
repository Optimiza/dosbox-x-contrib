/* P5PROBE.EXE: a probe of the first read of a folder. One run per mode, every call a raw
 * INT 21h so that the same call is made with long names on and off.
 *
 *   usage: P5PROBE <mode> <folder> <name> <K> <output file> <ready file> <go file> <end file>
 *
 * With a ready file that is not "-": the program makes it and waits for the go file before its
 * first call, and waits for the end file after its output is written, so that a profile taken
 * from outside covers the calls and nothing else. The waits ask 4300h, which makes no search.
 *
 *   mode  f  one 4Eh for <folder>\<name>: the first touch of the folder
 *         b  the control: the 4Eh, then K more of it
 *         c  the 4Eh, then K times: a file created and closed (3Ch, 3Eh), then the 4Eh
 *         C  the 4Eh, then K creates with no search between them, then one 4Eh
 *         u  the 4Eh, then K times: 41h on a file the host made (ZZ5Pnnnn.TMP), then the 4Eh
 *         U  the 4Eh, then K deletes with no search between them, then one 4Eh
 *
 * Lines:  p5|mode=<m> k=<K> first=<0 when found> done=<calls that answered 0> found=<4Eh that answered 0>
 *         end|lines=1
 */
#include <dos.h>
#include <dpmi.h>
#include <go32.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/movedata.h>

#define ALL 0x37

static const char *g_folder;

static int int21(__dpmi_regs *r) { __dpmi_int(0x21, r); return (r->x.flags & 1) ? r->x.ax : 0; }

static void set_dta(void)
{
    __dpmi_regs r;
    memset(&r, 0, sizeof r);
    r.h.ah = 0x1A; r.x.ds = (unsigned short)((__tb + 1024) >> 4); r.x.dx = (unsigned short)((__tb + 1024) & 15);
    __dpmi_int(0x21, &r);
}

static int path_call(int ax, int cx, const char *name)
{
    char path[400];
    __dpmi_regs r;
    sprintf(path, "%s\\%s", g_folder, name);
    dosmemput(path, strlen(path) + 1, __tb);
    memset(&r, 0, sizeof r);
    r.x.ax = (unsigned short)ax; r.x.cx = (unsigned short)cx;
    r.x.ds = (unsigned short)(__tb >> 4); r.x.dx = (unsigned short)(__tb & 15);
    return int21(&r);
}

static int create(const char *name)
{
    __dpmi_regs r;
    char path[400];
    sprintf(path, "%s\\%s", g_folder, name);
    dosmemput(path, strlen(path) + 1, __tb);
    memset(&r, 0, sizeof r);
    r.h.ah = 0x3C; r.x.cx = 0x20;
    r.x.ds = (unsigned short)(__tb >> 4); r.x.dx = (unsigned short)(__tb & 15);
    if (int21(&r) != 0) return 1;
    r.x.bx = r.x.ax; r.h.ah = 0x3E;
    __dpmi_int(0x21, &r);
    return 0;
}

static void wait_for(const char *file)
{
    unsigned attr;
    while (_dos_getfileattr(file, &attr) != 0) delay(20);
}

int main(int argc, char **argv)
{
    char mode, made[13];
    const char *name;
    int k, i, first, done = 0, found = 0;
    FILE *out;

    if (argc != 9 || !strchr("fbcCuU", argv[1][0]) || argv[1][1]) {
        fprintf(stderr, "usage: P5PROBE <mode f|b|c|C|u|U> <folder> <name> <K> <output file> <ready file> <go file> <end file>\n");
        return 2;
    }
    mode = argv[1][0]; g_folder = argv[2]; name = argv[3]; k = atoi(argv[4]);
    if (k < 0 || k > 9999) { fprintf(stderr, "P5PROBE: K is 0 to 9999\n"); return 2; }
    out = fopen(argv[5], "w");
    if (!out) { fprintf(stderr, "P5PROBE: cannot write %s\n", argv[5]); return 3; }
    set_dta();
    if (strcmp(argv[6], "-") != 0) {
        FILE *ready = fopen(argv[6], "w");
        if (ready) { fputs("ready\n", ready); fclose(ready); }
        wait_for(argv[7]);
    }
    first = path_call(0x4E00, ALL, name);
    for (i = 0; mode != 'f' && i < k; i++) {
        sprintf(made, "ZZ5P%04d.TMP", i);
        if (mode == 'c' || mode == 'C') done += create(made) == 0;
        else if (mode == 'u' || mode == 'U') done += path_call(0x4100, 0, made) == 0;
        if (mode == 'b' || mode == 'c' || mode == 'u') found += path_call(0x4E00, ALL, name) == 0;
    }
    if (mode == 'C' || mode == 'U') found += path_call(0x4E00, ALL, name) == 0;
    fprintf(out, "p5|mode=%c k=%d first=%d done=%d found=%d\nend|lines=1\n", mode, k, first, done, found);
    fclose(out);
    if (strcmp(argv[6], "-") != 0) wait_for(argv[8]);
    return 0;
}
