/* ATTRSEM.EXE: what a search and the attribute calls answer around a change of the hidden,
 * system and read-only attributes, so that a build that empties its directory cache after the
 * change can be compared with one that does not.
 *
 *   usage: ATTRSEM <folder> <output file>      e.g. ATTRSEM D:\X C:\SEM.TXT
 *
 * The folder holds F0000.TXT to F0009.TXT and the directory SUB. Lines:
 *   sem|<case>|<what the calls answered>
 *   end|lines=<n>
 */
#include <dpmi.h>
#include <go32.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/movedata.h>

static const char *g_folder;
static FILE *g_out;
static int g_lines;

static int int21(__dpmi_regs *r) { __dpmi_int(0x21, r); return (r->x.flags & 1) ? r->x.ax : 0; }

static void set_dta(void)
{
    __dpmi_regs r;
    memset(&r, 0, sizeof r);
    r.h.ah = 0x1A; r.x.ds = (unsigned short)((__tb + 1024) >> 4); r.x.dx = (unsigned short)((__tb + 1024) & 15);
    __dpmi_int(0x21, &r);
}

static int path_call(int ax, int cx, const char *name, int *cx_out)
{
    char path[400];
    __dpmi_regs r;
    int err;
    sprintf(path, "%s\\%s", g_folder, name);
    dosmemput(path, strlen(path) + 1, __tb);
    memset(&r, 0, sizeof r);
    r.x.ax = (unsigned short)ax; r.x.cx = (unsigned short)cx;
    r.x.ds = (unsigned short)(__tb >> 4); r.x.dx = (unsigned short)(__tb & 15);
    err = int21(&r);
    if (cx_out) *cx_out = r.x.cx;
    if (!err && (ax >> 8) == 0x3D) { r.x.bx = r.x.ax; r.h.ah = 0x3E; __dpmi_int(0x21, &r); }
    return err;
}

static int next(void)
{
    __dpmi_regs r;
    memset(&r, 0, sizeof r);
    r.h.ah = 0x4F;
    return int21(&r);
}

static void line(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    vfprintf(g_out, fmt, ap);
    va_end(ap);
    fputc('\n', g_out);
    g_lines++;
}

/* A whole search with <mask>: how many entries, and the attribute <watch> came back with. */
static void list(const char *label, int mask, const char *watch)
{
    unsigned char dta[43];
    char name[13];
    int n = 0, seen = -1;
    if (path_call(0x4E00, mask, "*.*", NULL) == 0) {
        do {
            dosmemget(__tb + 1024, 43, dta);
            memcpy(name, dta + 30, 13); name[12] = 0;
            n++;
            if (strcmp(name, watch) == 0) seen = dta[21];
        } while (next() == 0);
    }
    line("sem|%s list mask=%02X|n=%d %s=%d", label, mask, n, watch, seen);
}

static void around(const char *label, const char *name, int attr)
{
    int got = -1, set, get, e20, e27, wr;
    set = path_call(0x4301, attr, name, NULL);
    get = path_call(0x4300, 0, name, &got);
    e20 = path_call(0x4E00, 0x20, name, NULL);
    e27 = path_call(0x4E00, 0x27, name, NULL);
    wr = path_call(0x3D02, 0, name, NULL);
    line("sem|%s|set=%d get=%d attr=%02X exact20=%d exact27=%d openrw=%d", label, set, get, got & 0xFF, e20, e27, wr);
    list(label, 0x20, name);
    list(label, 0x37, name);
}

int main(int argc, char **argv)
{
    unsigned char dta[43];
    char name[13];
    int i, n, seen;

    if (argc != 3) { fprintf(stderr, "usage: ATTRSEM <folder> <output file>\n"); return 2; }
    g_folder = argv[1];
    g_out = fopen(argv[2], "w");
    if (!g_out) { fprintf(stderr, "ATTRSEM: cannot write %s\n", argv[2]); return 3; }
    set_dta();

    list("before", 0x20, "F0003.TXT");
    list("before", 0x37, "F0003.TXT");
    around("hidden", "F0003.TXT", 0x22);
    around("system", "F0003.TXT", 0x24);
    around("hidden-system", "F0003.TXT", 0x26);
    around("read-only", "F0003.TXT", 0x21);
    around("archive-again", "F0003.TXT", 0x20);
    around("no-archive", "F0003.TXT", 0x00);
    around("archive-back", "F0003.TXT", 0x20);

    /* The directory hidden: listed only when the mask asks for hidden entries. */
    i = path_call(0x4301, 0x12, "SUB", NULL);
    line("sem|dir-hidden|set=%d", i);
    list("dir-hidden", 0x10, "SUB");
    list("dir-hidden", 0x12, "SUB");
    i = path_call(0x4301, 0x10, "SUB", NULL);
    line("sem|dir-shown|set=%d", i);
    list("dir-shown", 0x10, "SUB");

    /* A search in progress: three entries read, then a file it has not reached is hidden. */
    n = 0; seen = 0;
    if (path_call(0x4E00, 0x20, "*.*", NULL) == 0) {
        n = 1;
        if (next() == 0) n++;
        if (next() == 0) n++;
        i = path_call(0x4301, 0x22, "F0007.TXT", NULL);
        while (next() == 0) {
            dosmemget(__tb + 1024, 43, dta);
            memcpy(name, dta + 30, 13); name[12] = 0;
            n++;
            if (strcmp(name, "F0007.TXT") == 0) seen = 1;
        }
        line("sem|hidden-mid-search|set=%d n=%d returned=%d", i, n, seen);
    }
    list("after-mid-search", 0x20, "F0007.TXT");
    i = path_call(0x4301, 0x20, "F0007.TXT", NULL);
    line("sem|shown-again|set=%d", i);
    list("shown-again", 0x20, "F0007.TXT");

    fprintf(g_out, "end|lines=%d\n", g_lines);
    fclose(g_out);
    return 0;
}
