/* FINDPOS.EXE: where a DOS keeps the place of a 4Eh search, and what a search for the volume
 * label alone leaves behind, written as text so the reports of two builds, or of a build and a
 * real DOS, can be compared line by line.
 *
 *   usage: FINDPOS <folder> <output file>          e.g. FINDPOS D:\X C:\FINDPOS.TXT
 *
 * <folder> is the fixture exact.sh makes; its parent must be the drive's root, which holds one
 * file and the folder. The place cases save a DTA, read on, put the saved bytes back (all 43, or
 * the 21 a DOS keeps for itself) or read a copy of it at another address; the label cases ask
 * for the label alone by three names, with everything else, and through the DTA of a search in
 * progress. One line per case:
 *
 *   pos|<case>|<what was counted>|,<name>:<attr>:<size>...
 *   end|lines=<n>
 *
 * No long-name call is made, so it runs whole on a DOS that has none. findpos.sh beside this
 * file runs it on two builds.
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
#define DTA_C 2
#define DTA_PARK 3
#define PATH_OFF 2400
#define DTA_BYTES 43
#define DTA_STATE 21        /* the bytes DOS reserves for the search itself */
#define ALL 0x37            /* everything but the volume label */
#define LABEL 0x08
#define SHOWN 40
#define LIST_BYTES ((SHOWN + 1) * 64)

static unsigned long g_lin;
static unsigned short g_seg;
static FILE *g_out;
static int g_lines;
static const char *g_folder;
static char g_root[400];

static int int21(__dpmi_regs *r) { __dpmi_int(0x21, r); return (r->x.flags & 1) ? r->x.ax : 0; }

static void set_dta(int dta)
{
    __dpmi_regs r;
    memset(&r, 0, sizeof r);
    r.h.ah = 0x1A; r.x.ds = g_seg; r.x.dx = (unsigned short)(dta * DTA_SIZE);
    __dpmi_int(0x21, &r);
}

static const char *in_folder(const char *name)
{
    static char path[4][400];
    static int turn;
    char *p = path[turn++ & 3];
    sprintf(p, "%s\\%s", g_folder, name);
    return p;
}

static const char *in_root(const char *name)
{
    static char path[4][400];
    static int turn;
    char *p = path[turn++ & 3];
    sprintf(p, "%s%s", g_root, name);
    return p;
}

static int first(int dta, const char *path, int attr)
{
    __dpmi_regs r;
    int err;
    set_dta(dta);
    dosmemput(path, strlen(path) + 1, g_lin + PATH_OFF);
    memset(&r, 0, sizeof r);
    r.h.ah = 0x4E; r.x.cx = (unsigned short)attr; r.x.ds = g_seg; r.x.dx = PATH_OFF;
    err = int21(&r);
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

static void dta_entry(int dta, char *text)
{
    char name[13];
    unsigned char attr;
    unsigned long size;
    dosmemget(g_lin + dta * DTA_SIZE + 30, 13, name); name[12] = 0;
    dosmemget(g_lin + dta * DTA_SIZE + 21, 1, &attr);
    dosmemget(g_lin + dta * DTA_SIZE + 26, 4, &size);
    sprintf(text, "%s:%02X:%lu", name, attr, size);
}

static void add_entry(int dta, char *list, int n)
{
    char text[64];
    if (n >= SHOWN) return;
    dta_entry(dta, text);
    strcat(list, ",");
    strcat(list, text);
}

/* Reads at most <most> entries; returns how many came. */
static int read_some(int dta, int most, char *list)
{
    int n = 0;
    while (n < most && next(dta) == 0) { add_entry(dta, list, n); n++; }
    return n;
}

static int drain(int dta, char *list) { return read_some(dta, 1 << 30, list); }

static void save(int dta, char *bytes) { dosmemget(g_lin + dta * DTA_SIZE, DTA_BYTES, bytes); }
static void put(int dta, const char *bytes, int n) { dosmemput(bytes, n, g_lin + dta * DTA_SIZE); }

/* A whole-folder search read for three more entries, its DTA saved, read for five more, the first
 * <bytes> of the saved DTA put back, then the search read to its end. */
static void rewound(const char *label, int bytes)
{
    static char list[LIST_BYTES], skipped[LIST_BYTES];
    char saved[DTA_BYTES];
    int err, a, b, n;
    list[0] = 0; skipped[0] = 0;
    err = first(DTA_A, in_folder("*.*"), ALL);
    a = read_some(DTA_A, 3, skipped);
    save(DTA_A, saved);
    b = read_some(DTA_A, 5, skipped);
    put(DTA_A, saved, bytes);
    n = drain(DTA_A, list);
    line("pos|%s|first=%d read=%d then=%d more=%d|%s", label, err, a, b, n, list);
}

/* A search for the volume label alone, then the same DTA read on. */
static void label_alone(const char *label, const char *path)
{
    static char list[LIST_BYTES];
    char entry[64];
    int err, e, n = 0;
    list[0] = 0;
    strcpy(entry, "-");
    err = first(DTA_A, path, LABEL);
    if (err == 0) dta_entry(DTA_A, entry);
    e = next(DTA_A);
    if (e == 0) { add_entry(DTA_A, list, 0); n = 1 + drain(DTA_A, list); }
    line("pos|%s|first=%d entry=%s next=%d more=%d|%s", label, err, entry, e, n, list);
}

int main(int argc, char **argv)
{
    static char list[LIST_BYTES], other[LIST_BYTES];
    char saved[DTA_BYTES], wrecked[DTA_BYTES], entry[64], name[13];
    int sel, s, err, e1, e2, n, m, a, b, live_a, live_b;
    char *slash;

    if (argc != 3) { fprintf(stderr, "usage: FINDPOS <folder> <output file>\n"); return 2; }
    g_folder = argv[1];
    strcpy(g_root, g_folder);
    slash = strrchr(g_root, '\\');
    if (!slash) { fprintf(stderr, "FINDPOS: the folder has no parent: %s\n", g_folder); return 2; }
    slash[1] = 0;
    s = __dpmi_allocate_dos_memory(BLOCK_PARAS, &sel);
    if (s == -1) { fprintf(stderr, "FINDPOS: no conventional memory\n"); return 3; }
    g_seg = (unsigned short)s;
    g_lin = (unsigned long)g_seg << 4;
    set_dta(DTA_PARK);
    g_out = fopen(argv[2], "w");
    if (!g_out) { fprintf(stderr, "FINDPOS: cannot write %s\n", argv[2]); return 3; }

    /* The folder as a whole-folder search returns it: the order the cases below are read against. */
    list[0] = 0;
    err = first(DTA_A, in_folder("*.*"), ALL);
    n = 0;
    if (err == 0) { add_entry(DTA_A, list, 0); n = 1 + drain(DTA_A, list); }
    line("pos|whole-folder|first=%d n=%d|%s", err, n, list);

    rewound("rewound-by-restored-dta", DTA_BYTES);
    rewound("rewound-by-its-first-21-bytes", DTA_STATE);

    /* The DTA copied to a second address after three more entries; the two read turn about. */
    list[0] = 0; other[0] = 0;
    err = first(DTA_A, in_folder("*.*"), ALL);
    read_some(DTA_A, 3, other);
    other[0] = 0;
    save(DTA_A, saved);
    put(DTA_B, saved, DTA_BYTES);
    a = b = 0; live_a = live_b = 1;
    while (live_a || live_b) {
        if (live_a) { if (next(DTA_A) == 0) { add_entry(DTA_A, list, a); a++; } else live_a = 0; }
        if (live_b) { if (next(DTA_B) == 0) { add_entry(DTA_B, other, b); b++; } else live_b = 0; }
    }
    line("pos|copy-read-beside-the-original|first=%d original=%d copy=%d|%s|copy%s", err, a, b, list, other);

    /* The DTA copied to another address after three more entries, the first one overwritten, and
     * the search read to its end through the copy. */
    list[0] = 0; other[0] = 0;
    err = first(DTA_A, in_folder("*.*"), ALL);
    read_some(DTA_A, 3, other);
    save(DTA_A, saved);
    put(DTA_C, saved, DTA_BYTES);
    memset(wrecked, 0xEE, sizeof wrecked);
    put(DTA_A, wrecked, DTA_BYTES);
    n = drain(DTA_C, list);
    line("pos|read-on-from-another-address|first=%d more=%d|%s", err, n, list);

    /* The DTA saved right after FindFirst; the search read to its end, asked twice more, then the
     * saved bytes put back and the search read again. */
    list[0] = 0; other[0] = 0;
    err = first(DTA_A, in_folder("*.*"), ALL);
    save(DTA_A, saved);
    n = drain(DTA_A, other);
    e1 = next(DTA_A);
    e2 = next(DTA_A);
    put(DTA_A, saved, DTA_BYTES);
    m = drain(DTA_A, list);
    line("pos|after-the-end|first=%d more=%d again=%d,%d rewound=%d|%s", err, n, e1, e2, m, list);

    /* A search run to its end; a second one started and read for two more; the ended DTA asked
     * again; the second one read to its end. */
    list[0] = 0; other[0] = 0;
    err = first(DTA_A, in_folder("*.*"), ALL);
    drain(DTA_A, other);
    other[0] = 0;
    m = first(DTA_B, in_folder("*.*"), ALL);
    read_some(DTA_B, 2, other);
    e1 = next(DTA_A);
    n = drain(DTA_B, list);
    line("pos|ended-dta-beside-a-live-search|first=%d,%d ended_next=%d more=%d|%s", err, m, e1, n, list);

    /* The volume label alone: by every name, by a name it does not have, by its own name. */
    label_alone("label-alone", in_root("*.*"));
    label_alone("label-alone-by-another-name", in_root("NOLABEL.XYZ"));
    strcpy(name, "-");
    if (first(DTA_A, in_root("*.*"), LABEL) == 0) { dosmemget(g_lin + DTA_A * DTA_SIZE + 30, 13, name); name[12] = 0; }
    if (strcmp(name, "-")) label_alone("label-alone-by-its-own-name", in_root(name));
    else line("pos|label-alone-by-its-own-name|no label|");

    /* The label asked for with everything else, in the root. */
    list[0] = 0;
    strcpy(entry, "-");
    err = first(DTA_A, in_root("*.*"), ALL | LABEL);
    n = 0;
    if (err == 0) { dta_entry(DTA_A, entry); n = 1 + drain(DTA_A, list); }
    line("pos|label-with-everything|first=%d entry=%s n=%d|%s", err, entry, n, list);

    /* A whole-folder search read for three more entries, then a search for the label alone
     * through the same DTA, then FindNext to the end. */
    list[0] = 0; other[0] = 0;
    err = first(DTA_A, in_folder("*.*"), ALL);
    read_some(DTA_A, 3, other);
    m = first(DTA_A, in_root("*.*"), LABEL);
    n = drain(DTA_A, list);
    line("pos|label-alone-through-a-live-search|first=%d label=%d more=%d|%s", err, m, n, list);

    fprintf(g_out, "end|lines=%d\n", g_lines);
    fclose(g_out);
    return 0;
}
