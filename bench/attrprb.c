/* ATTRPRB.EXE: what a 4Eh search in progress returns when another file of the drive is removed
 * or has its attribute changed in the middle, and whether a DTA saved from an ended search reaches
 * a later one once those calls have run.
 *
 *   usage: ATTRPRB <folder X> <folder Y> <output file>      e.g. ATTRPRB D:\X D:\Y C:\A.TXT
 *
 * X holds F0000.TXT to F0039.TXT, Y holds G0000.TXT to G0019.TXT. Every whole-folder search uses
 * attribute 37h, so X lists 42 entries and Y 22 with the dot entries. A line:
 *
 *   attr|<case>|total=<entries the search returned> of <what it held at FindFirst> foreign=<entries
 *       of the other folder> gone=<the removed file returned: 1 or 0>
 *   end|lines=<n>
 *
 * A folder that lists nothing ends the report before its trailer: no case would mean anything.
 * No long-name call is made. attrprobe.sh beside this file runs it on two builds.
 */
#include <dpmi.h>
#include <go32.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/movedata.h>
#include <unistd.h>

#define BLOCK_PARAS 256
#define DTA_SIZE 64
#define DTA_A 0
#define DTA_B 1
#define DTA_PARK 3
#define PATH_OFF 2400
#define DTA_BYTES 43
#define ALL 0x37

static unsigned long g_lin;
static unsigned short g_seg;
static FILE *g_out;
static int g_lines;
static const char *g_x, *g_y;

static int int21(__dpmi_regs *r) { __dpmi_int(0x21, r); return (r->x.flags & 1) ? r->x.ax : 0; }

static void set_dta(int dta)
{
    __dpmi_regs r;
    memset(&r, 0, sizeof r);
    r.h.ah = 0x1A; r.x.ds = g_seg; r.x.dx = (unsigned short)(dta * DTA_SIZE);
    __dpmi_int(0x21, &r);
}

static const char *in(const char *folder, const char *name)
{
    static char path[4][400];
    static int turn;
    char *p = path[turn++ & 3];
    sprintf(p, "%s\\%s", folder, name);
    return p;
}

static int path_call(int ax, int cx, const char *path)
{
    __dpmi_regs r;
    dosmemput(path, strlen(path) + 1, g_lin + PATH_OFF);
    memset(&r, 0, sizeof r);
    r.x.ax = (unsigned short)ax; r.x.cx = (unsigned short)cx; r.x.ds = g_seg; r.x.dx = PATH_OFF;
    return int21(&r);
}

static int first(int dta, const char *path)
{
    int err;
    set_dta(dta);
    err = path_call(0x4E00, ALL, path);
    set_dta(DTA_PARK);
    return err;
}

static int next(int dta)
{
    __dpmi_regs r;
    int err;
    set_dta(dta);
    memset(&r, 0, sizeof r);
    r.h.ah = 0x4F;
    err = int21(&r);
    set_dta(DTA_PARK);
    return err;
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

struct tally { int n, foreign, gone; };

static void count(int dta, char own, const char *gone, struct tally *t)
{
    char name[13];
    dosmemget(g_lin + dta * DTA_SIZE + 30, 13, name); name[12] = 0;
    t->n++;
    if (name[0] != '.' && name[0] != own) t->foreign++;
    if (gone && strcmp(name, gone) == 0) t->gone = 1;
}

/* FindFirst and two FindNext: three entries read before anything else happens. */
static void start(int dta, const char *folder, char own, struct tally *t)
{
    memset(t, 0, sizeof *t);
    if (first(dta, in(folder, "*.*")) != 0) return;
    count(dta, own, NULL, t);
    if (next(dta) == 0) count(dta, own, NULL, t);
    if (next(dta) == 0) count(dta, own, NULL, t);
}

static void drain(int dta, char own, const char *gone, struct tally *t)
{
    while (next(dta) == 0) count(dta, own, gone, t);
}

static void touch(const char *path) { FILE *f = fopen(path, "w"); if (f) fclose(f); }

static void emit(const char *label, const struct tally *t, int held)
{
    line("attr|%s|total=%d of %d foreign=%d gone=%d", label, t->n, held, t->foreign, t->gone);
}

int main(int argc, char **argv)
{
    struct tally a, b;
    char saved[DTA_BYTES];
    int s, sel, err;

    if (argc != 4) { fprintf(stderr, "usage: ATTRPRB <folder X> <folder Y> <output file>\n"); return 2; }
    g_x = argv[1]; g_y = argv[2];
    s = __dpmi_allocate_dos_memory(BLOCK_PARAS, &sel);
    if (s == -1) { fprintf(stderr, "ATTRPRB: no conventional memory\n"); return 3; }
    g_seg = (unsigned short)s;
    g_lin = (unsigned long)g_seg << 4;
    set_dta(DTA_PARK);
    g_out = fopen(argv[3], "w");
    if (!g_out) { fprintf(stderr, "ATTRPRB: cannot write %s\n", argv[3]); return 3; }

    start(DTA_A, g_x, 'F', &a); drain(DTA_A, 'F', NULL, &a);
    if (a.n == 0) { fprintf(stderr, "ATTRPRB: %s lists nothing\n", g_x); fclose(g_out); return 3; }
    emit("nothing-in-between", &a, 42);

    /* libc's remove(), which sets the file's attributes before it deletes it. */
    start(DTA_A, g_x, 'F', &a);
    remove(in(g_x, "F0039.TXT"));
    drain(DTA_A, 'F', "F0039.TXT", &a);
    emit("remove-a-later-file", &a, 42);
    touch(in(g_x, "F0039.TXT"));

    /* 41h alone: the delete with no attribute call before it. */
    start(DTA_A, g_x, 'F', &a);
    err = path_call(0x4100, 0, in(g_x, "F0038.TXT"));
    drain(DTA_A, 'F', "F0038.TXT", &a);
    line("attr|delete-41h-a-later-file|rc=%d total=%d of 42 foreign=%d gone=%d", err, a.n, a.foreign, a.gone);
    touch(in(g_x, "F0038.TXT"));

    /* 4301h on another file of the folder: read-only, then back. */
    start(DTA_A, g_x, 'F', &a);
    err = path_call(0x4301, 0x01, in(g_x, "F0030.TXT"));
    drain(DTA_A, 'F', NULL, &a);
    path_call(0x4301, 0x20, in(g_x, "F0030.TXT"));
    line("attr|setattr-another-file|rc=%d total=%d of 42 foreign=%d", err, a.n, a.foreign);

    /* 4301h on a file of X while a search of Y is open. */
    start(DTA_A, g_y, 'G', &a);
    err = path_call(0x4301, 0x01, in(g_x, "F0030.TXT"));
    drain(DTA_A, 'G', NULL, &a);
    path_call(0x4301, 0x20, in(g_x, "F0030.TXT"));
    if (a.n == 0) { fprintf(stderr, "ATTRPRB: %s lists nothing\n", g_y); fclose(g_out); return 3; }
    line("attr|setattr-in-another-folder|rc=%d total=%d of 22 foreign=%d", err, a.n, a.foreign);

    /* A search of X and one of Y open together across one 4301h. */
    start(DTA_A, g_x, 'F', &a);
    start(DTA_B, g_y, 'G', &b);
    path_call(0x4301, 0x01, in(g_x, "F0030.TXT"));
    drain(DTA_A, 'F', NULL, &a);
    drain(DTA_B, 'G', NULL, &b);
    path_call(0x4301, 0x20, in(g_x, "F0030.TXT"));
    line("attr|two-searches-one-setattr|x=%d of 42 y=%d of 22 foreign=%d", a.n, b.n, a.foreign + b.foreign);

    /* A DTA saved from a search of X that then ran to its end; a 4301h; a search of Y started;
     * the saved bytes put back and FindNext asked through them. A DOS that keeps a search's place
     * in its DTA goes on with X; one whose saved DTA names a slot now Y's returns Y's files. */
    path_call(0x4301, 0x20, in(g_x, "F0030.TXT"));
    start(DTA_A, g_x, 'F', &a);
    dosmemget(g_lin + DTA_A * DTA_SIZE, DTA_BYTES, saved);
    drain(DTA_A, 'F', NULL, &a);
    path_call(0x4301, 0x20, in(g_x, "F0030.TXT"));
    start(DTA_B, g_y, 'G', &b);
    dosmemput(saved, DTA_BYTES, g_lin + DTA_A * DTA_SIZE);
    memset(&a, 0, sizeof a);
    drain(DTA_A, 'F', NULL, &a);
    drain(DTA_B, 'G', NULL, &b);
    line("attr|saved-dta-after-setattr|more=%d of 39 foreign=%d y=%d of 22", a.n, a.foreign, b.n);

    /* The same with no 4301h in between: the control. */
    start(DTA_A, g_x, 'F', &a);
    dosmemget(g_lin + DTA_A * DTA_SIZE, DTA_BYTES, saved);
    drain(DTA_A, 'F', NULL, &a);
    start(DTA_B, g_y, 'G', &b);
    dosmemput(saved, DTA_BYTES, g_lin + DTA_A * DTA_SIZE);
    memset(&a, 0, sizeof a);
    drain(DTA_A, 'F', NULL, &a);
    drain(DTA_B, 'G', NULL, &b);
    line("attr|saved-dta-no-setattr|more=%d of 39 foreign=%d y=%d of 22", a.n, a.foreign, b.n);

    fprintf(g_out, "end|lines=%d\n", g_lines);
    fclose(g_out);
    return 0;
}
