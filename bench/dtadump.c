/* DTADUMP.EXE: the bytes a DOS leaves in a DTA and in an FCB around the find calls, written as
 * text so the dump of a build and the dump of a real DOS can be compared line by line.
 *
 *   usage: DTADUMP <folder> <output file>          e.g. DTADUMP D:\X C:\DTADUMP.TXT
 *
 * <folder> is the fixture exact.sh makes; its parent must be the drive's root.
 *
 *   dump|<case>|<step>|<what the call answered>|<bytes in hex, in groups>
 *   list|<case>|<what was counted>|,<name>...
 *   end|lines=<n>
 *
 * The groups of a dump, by what the block is:
 *   a DTA around 4Eh and 4Fh, 43 bytes: drive, the 11 characters of the template, the search
 *     attribute, 8 bytes the DOS keeps for itself, then the entry found: attribute, time and
 *     date, size, name
 *   an FCB, 44 bytes from the start of its block: the header of an extended one, drive, name,
 *     the ten bytes at +0Ch where MS-DOS keeps the search, the rest
 *   an FCB 0Fh opened, 44 bytes: drive, name, block and record size, file size, date and time,
 *     the rest
 *   a DTA after 11h or 12h, 43 bytes: the header of an extended FCB, drive, then a directory
 *     entry: name, attribute, 10 reserved bytes, time and date, cluster, size; the rest
 * The DOS's own 8 bytes and every time and date are printed as dashes: they belong to one DOS
 * and to one run. Where a call must leave a DTA alone the answer says whether its 43 bytes are
 * unchanged, the dashed ones included. Every DTA is filled with EE before its first use: a
 * byte still EE was never written.
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
#define FCB1_OFF 1024
#define FCB2_OFF 1088
#define FIND_OFF 1280
#define PATH_OFF 2400
#define DTA_BYTES 43
#define FCB_BYTES 44
#define DTA_PATTERN 1
#define ALL 0x37
#define SHOWN 40

static unsigned long g_lin;
static unsigned short g_seg;
static FILE *g_out;
static int g_lines, g_rest;
static const char *g_folder;

static int int21(__dpmi_regs *r) { __dpmi_int(0x21, r); return (r->x.flags & 1) ? r->x.ax : 0; }

static void line(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    vfprintf(g_out, fmt, ap);
    va_end(ap);
    fputc('\n', g_out);
    g_lines++;
}

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

/* 714Eh with <dta> the current DTA, then 71A1h on the handle it gave. */
static int lfn_first_and_close(int dta, const char *path)
{
    __dpmi_regs r;
    int err;
    set_dta(dta);
    dosmemput(path, strlen(path) + 1, g_lin + PATH_OFF);
    memset(&r, 0, sizeof r);
    r.x.ax = 0x714E; r.x.cx = ALL; r.x.si = 1;
    r.x.ds = g_seg; r.x.dx = PATH_OFF; r.x.es = g_seg; r.x.di = FIND_OFF;
    r.x.flags = 1;
    err = int21(&r);
    /* A DOS with no long-name calls may clear the carry and leave AX at 7100h, as MS-DOS 6.22
     * does: that is the call refused, not a handle. */
    if (err == 0 && r.x.ax == 0x7100) err = 0x7100;
    if (err == 0) {
        unsigned short handle = r.x.ax;
        memset(&r, 0, sizeof r);
        r.x.ax = 0x71A1; r.x.bx = handle;
        __dpmi_int(0x21, &r);
    }
    set_dta(DTA_PARK);
    return err;
}

static void fill(int dta) { char ee[DTA_SIZE]; memset(ee, 0xEE, sizeof ee); dosmemput(ee, sizeof ee, g_lin + dta * DTA_SIZE); }

/* The lengths of a dump's groups, 0 at the end; a negative one is printed as dashes. */
static const int DTA_FIND[] = {1, 11, 1, -8, 1, -4, 4, 13, 0};
static const int FCB_PLAIN[] = {1, 11, 10, 22, 0};
static const int FCB_EXTENDED[] = {7, 1, 11, 10, 15, 0};
static const int FCB_OPENED[] = {1, 11, 4, 4, -4, 20, 0};
static const int FOUND_PLAIN[] = {1, 11, 1, 10, -4, 2, 4, 10, 0};
static const int FOUND_EXTENDED[] = {7, 1, 11, 1, 10, -4, 2, 4, 3, 0};

static const char *hex(unsigned long lin, const int *groups)
{
    static char text[3 * 64 + 1];
    unsigned char b[64];
    char *p = text;
    int at = 0, g, i, n;
    for (g = 0, n = 0; groups[g]; g++) n += abs(groups[g]);
    dosmemget(lin, n, b);
    for (g = 0; groups[g]; g++) {
        if (g) *p++ = ' ';
        for (i = 0; i < abs(groups[g]); i++, at++) {
            if (groups[g] < 0) { *p++ = '-'; *p++ = '-'; }
            else p += sprintf(p, "%02X", b[at]);
        }
    }
    *p = 0;
    return text;
}

static void dump_dta(const char *label, const char *step, const char *answer, int dta)
{
    line("dump|%s|%s|%s|%s", label, step, answer, hex(g_lin + dta * DTA_SIZE, DTA_FIND));
}

static void dump_fcb(const char *label, const char *step, const char *answer, int off, int extended)
{
    line("dump|%s|%s|%s|%s", label, step, answer, hex(g_lin + off, extended ? FCB_EXTENDED : FCB_PLAIN));
}

static void dump_opened(const char *label, const char *step, const char *answer, int off)
{
    line("dump|%s|%s|%s|%s", label, step, answer, hex(g_lin + off, FCB_OPENED));
}

static void dump_found(const char *label, const char *step, int dta, int extended)
{
    line("dump|%s|%s|-|%s", label, step, hex(g_lin + dta * DTA_SIZE, extended ? FOUND_EXTENDED : FOUND_PLAIN));
}

/* Whether the 43 bytes of <dta> are those kept in <before>. */
static const char *untouched(int dta, const char *before)
{
    char now[DTA_BYTES];
    dosmemget(g_lin + dta * DTA_SIZE, DTA_BYTES, now);
    return memcmp(now, before, DTA_BYTES) == 0 ? "unchanged" : "changed";
}

static const char *answered(const char *what, int err)
{
    static char text[4][40];
    static int turn;
    char *p = text[turn++ & 3];
    sprintf(p, "%s=%d", what, err);
    return p;
}

static const char *answered_dta(const char *what, int err, const char *dta)
{
    static char text[60];
    sprintf(text, "%s=%d dta=%s", what, err, dta);
    return text;
}

static void dta_name(int dta, char *text)
{
    dosmemget(g_lin + dta * DTA_SIZE + 30, 13, text);
    text[12] = 0;
}

static int drain(int dta, char *list)
{
    char text[16];
    int n = 0;
    while (next(dta) == 0) {
        if (n < SHOWN) { dta_name(dta, text); strcat(list, ","); strcat(list, text); }
        n++;
    }
    return n;
}

/* The template a FindFirst leaves for one pattern, in a DTA that held only EE. */
static void template_of(const char *pattern)
{
    char label[80];
    int err;
    fill(DTA_A);
    err = first(DTA_A, in_folder(pattern), ALL);
    sprintf(label, "template %s", pattern);
    dump_dta(label, "after", answered("first", err), DTA_A);
}

/* A whole-folder search read for three entries, then a FindFirst that fails through the same
 * DTA, then the first search read to its end: the rest of the folder, g_rest entries. */
static void failed_first(const char *label, const char *path, int attr)
{
    static char list[(SHOWN + 1) * 16];
    char before[DTA_BYTES];
    int err, n;
    fill(DTA_A);
    first(DTA_A, in_folder("*.*"), ALL);
    next(DTA_A); next(DTA_A);
    dosmemget(g_lin + DTA_A * DTA_SIZE, DTA_BYTES, before);
    dump_dta(label, "before", "-", DTA_A);
    err = first(DTA_A, path, attr);
    dump_dta(label, "after", answered_dta("first", err, untouched(DTA_A, before)), DTA_A);
    list[0] = 0;
    n = drain(DTA_A, list);
    line("list|%s|failed=%d then more=%d of %d|%s", label, err, n, g_rest, list);
}

/* An unopened FCB for the default drive: plain when attr < 0, extended with that attribute. */
static void fcb_put(int off, const char *name11, int attr)
{
    unsigned char fcb[FCB_BYTES];
    memset(fcb, 0, sizeof fcb);
    if (attr < 0) memcpy(fcb + 1, name11, 11);
    else { fcb[0] = 0xFF; fcb[6] = (unsigned char)attr; memcpy(fcb + 8, name11, 11); }
    dosmemput(fcb, sizeof fcb, g_lin + off);
}

/* 11h or 12h on the FCB at <off>, the entry going to <dta>. 0 found, 1 not. */
static int fcb_call(int function, int off, int dta)
{
    __dpmi_regs r;
    set_dta(dta);
    memset(&r, 0, sizeof r);
    r.h.ah = (unsigned char)function; r.x.ds = g_seg; r.x.dx = (unsigned short)off;
    __dpmi_int(0x21, &r);
    set_dta(DTA_PARK);
    return r.h.al == 0 ? 0 : 1;
}

/* The name an FCB find call left in <dta>, behind the drive byte of a plain FCB. */
static void fcb_name(int dta, int found, char *list)
{
    char name[12];
    if (found != 0) { strcat(list, ",-"); return; }
    dosmemget(g_lin + dta * DTA_SIZE + 1, 11, name);
    name[11] = 0;
    strcat(list, ",");
    strcat(list, name);
}

int main(int argc, char **argv)
{
    static char list[(SHOWN + 1) * 16], root[400], refused[400];
    unsigned char copy[FCB_BYTES];
    char before[DTA_BYTES];
    int sel, s, err, n, i;
    char *slash;

    if (argc != 3) { fprintf(stderr, "usage: DTADUMP <folder> <output file>\n"); return 2; }
    g_folder = argv[1];
    s = __dpmi_allocate_dos_memory(BLOCK_PARAS, &sel);
    if (s == -1) { fprintf(stderr, "DTADUMP: no conventional memory\n"); return 3; }
    g_seg = (unsigned short)s;
    g_lin = (unsigned long)g_seg << 4;
    set_dta(DTA_PARK);
    g_out = fopen(argv[2], "w");
    if (!g_out) { fprintf(stderr, "DTADUMP: cannot write %s\n", argv[2]); return 3; }

    /* The folder as a whole-folder search returns it. */
    list[0] = 0;
    fill(DTA_A);
    err = first(DTA_A, in_folder("*.*"), ALL);
    n = 0;
    if (err == 0) { dta_name(DTA_A, list); n = 1 + drain(DTA_A, list); }
    line("list|whole-folder|first=%d n=%d|%s", err, n, list);
    g_rest = n - 3;

    /* What a FindFirst writes as the template. */
    template_of("*.*");
    template_of("BAR.TXT");
    template_of("bar.txt");
    template_of("B*.TXT");
    template_of("B*R.TXT");
    template_of("*R.TXT");
    template_of("B*");
    template_of("NOEXT");
    template_of("*");
    template_of("*.");
    template_of("A.B");
    template_of("?OO.T?T");
    template_of("ZED.*");
    template_of("ZED.T*T");
    template_of("ALPHAT~1.MID");
    template_of("NOSUCH.TXT");

    /* What a FindNext moves, and what a FindNext that finds nothing leaves. */
    fill(DTA_A);
    err = first(DTA_A, in_folder("B*.TXT"), ALL);
    dump_dta("next", "after-first", answered("first", err), DTA_A);
    err = next(DTA_A);
    dump_dta("next", "after-failed-next", answered("next", err), DTA_A);
    err = next(DTA_A);
    dump_dta("next", "after-second-failed-next", answered("next", err), DTA_A);
    fill(DTA_A);
    err = first(DTA_A, in_folder("*.TXT"), ALL);
    dump_dta("next", "wild-after-first", answered("first", err), DTA_A);
    err = next(DTA_A);
    dump_dta("next", "wild-after-next", answered("next", err), DTA_A);

    /* A FindFirst that fails through the DTA of a search in progress. */
    failed_first("failed-first no-such-file", in_folder("NOSUCH.TXT"), ALL);
    failed_first("failed-first no-such-directory", in_folder("NOSUCH\\*.*"), ALL);
    sprintf(refused, "%s\\", g_folder);
    failed_first("failed-first trailing-backslash", refused, ALL);
    strcpy(root, g_folder);
    slash = strrchr(root, '\\');
    if (slash) strcpy(slash + 1, "NOLABEL.XYZ");
    failed_first("failed-first label-by-name", root, 0x08);
    if (slash) strcpy(slash + 1, "*.*");
    failed_first("failed-first label-any", root, 0x08);

    /* A long-name FindFirst made while the DTA of a 4Eh search is the current one. */
    fill(DTA_A);
    first(DTA_A, in_folder("*.*"), ALL);
    next(DTA_A); next(DTA_A);
    dosmemget(g_lin + DTA_A * DTA_SIZE, DTA_BYTES, before);
    dump_dta("lfn-first", "before", "-", DTA_A);
    err = lfn_first_and_close(DTA_A, in_folder("ZED.TXT"));
    dump_dta("lfn-first", "after", answered_dta("714E", err, untouched(DTA_A, before)), DTA_A);
    list[0] = 0;
    n = drain(DTA_A, list);
    line("list|lfn-first|714E=%d then more=%d of %d|%s", err, n, g_rest, list);

    /* The FCB calls search the default drive's current directory. */
    if (chdir(g_folder) != 0) {
        line("list|fcb|could not enter the folder|");
    } else {
        /* A plain FCB: the block before 11h, after it, after 12h, and the DTA each time. */
        fill(DTA_A);
        fcb_put(FCB1_OFF, "????????TXT", -1);
        dump_fcb("fcb-plain", "fcb-before", "-", FCB1_OFF, 0);
        err = fcb_call(0x11, FCB1_OFF, DTA_A);
        dump_fcb("fcb-plain", "fcb-after-11h", answered("al", err), FCB1_OFF, 0);
        dump_found("fcb-plain", "dta-after-11h", DTA_A, 0);
        err = fcb_call(0x12, FCB1_OFF, DTA_A);
        dump_fcb("fcb-plain", "fcb-after-12h", answered("al", err), FCB1_OFF, 0);
        dump_found("fcb-plain", "dta-after-12h", DTA_A, 0);

        /* An extended FCB that asks for directories too. */
        fill(DTA_A);
        fcb_put(FCB1_OFF, "???????????", 0x10);
        dump_fcb("fcb-extended", "fcb-before", "-", FCB1_OFF, 1);
        err = fcb_call(0x11, FCB1_OFF, DTA_A);
        dump_fcb("fcb-extended", "fcb-after-11h", answered("al", err), FCB1_OFF, 1);
        dump_found("fcb-extended", "dta-after-11h", DTA_A, 1);

        /* An 11h that finds nothing. */
        fcb_put(FCB1_OFF, "NOSUCH  XYZ", -1);
        err = fcb_call(0x11, FCB1_OFF, DTA_A);
        dump_fcb("fcb-not-found", "fcb-after-11h", answered("al", err), FCB1_OFF, 0);

        /* Two FCB searches at once, each with its own FCB: 11h, 11h, then 12h turn about. */
        list[0] = 0;
        fcb_put(FCB1_OFF, "????????TXT", -1);
        fcb_put(FCB2_OFF, "????????MID", -1);
        fcb_name(DTA_A, fcb_call(0x11, FCB1_OFF, DTA_A), list);
        fcb_name(DTA_B, fcb_call(0x11, FCB2_OFF, DTA_B), list);
        for (i = 0; i < 3; i++) {
            fcb_name(DTA_A, fcb_call(0x12, FCB1_OFF, DTA_A), list);
            fcb_name(DTA_B, fcb_call(0x12, FCB2_OFF, DTA_B), list);
        }
        line("list|fcb-two-searches|TXT and MID turn about|%s", list);

        /* A 4Eh search in the middle of an FCB search. */
        list[0] = 0;
        fcb_put(FCB1_OFF, "????????TXT", -1);
        fcb_name(DTA_A, fcb_call(0x11, FCB1_OFF, DTA_A), list);
        err = first(DTA_B, in_folder("*.MID"), ALL);
        while (fcb_call(0x12, FCB1_OFF, DTA_A) == 0) fcb_name(DTA_A, 0, list);
        line("list|fcb-around-4e|inner first=%d|%s", err, list);

        /* The FCB put back as it was before 11h, then 12h. */
        list[0] = 0;
        fcb_put(FCB1_OFF, "????????TXT", -1);
        fcb_name(DTA_A, fcb_call(0x11, FCB1_OFF, DTA_A), list);
        fcb_name(DTA_A, fcb_call(0x12, FCB1_OFF, DTA_A), list);
        fcb_put(FCB1_OFF, "????????TXT", -1);
        for (i = 0; i < 3; i++) fcb_name(DTA_A, fcb_call(0x12, FCB1_OFF, DTA_A), list);
        line("list|fcb-rewritten-then-12h|11h 12h, the FCB rewritten, 12h 12h 12h|%s", list);

        /* The FCB copied elsewhere after 11h, a second search started with the first FCB, then
         * 12h on the copy. */
        list[0] = 0;
        fcb_put(FCB1_OFF, "????????TXT", -1);
        fcb_name(DTA_A, fcb_call(0x11, FCB1_OFF, DTA_A), list);
        dosmemget(g_lin + FCB1_OFF, FCB_BYTES, copy);
        dosmemput(copy, FCB_BYTES, g_lin + FCB2_OFF);
        fcb_put(FCB1_OFF, "????????MID", -1);
        fcb_name(DTA_B, fcb_call(0x11, FCB1_OFF, DTA_B), list);
        for (i = 0; i < 3; i++) fcb_name(DTA_A, fcb_call(0x12, FCB2_OFF, DTA_A), list);
        line("list|fcb-copied-then-12h|11h TXT, copy, 11h MID, 12h on the copy three times|%s", list);

        /* An open by wildcards is no search: it leaves the DTA and the name in the FCB as the
         * program had them. */
        fill(DTA_A);
        dosmemget(g_lin + DTA_A * DTA_SIZE, DTA_BYTES, before);
        fcb_put(FCB1_OFF, "ZED?????TXT", -1);
        err = fcb_call(0x0F, FCB1_OFF, DTA_A);
        dump_dta("fcb-open-wild", "dta-after-0Fh", answered_dta("al", err, untouched(DTA_A, before)), DTA_A);
        dump_opened("fcb-open-wild", "fcb-after-0Fh", answered("al", err), FCB1_OFF);
        if (err == 0) fcb_call(0x10, FCB1_OFF, DTA_A);
        /* The same open, the name written in small letters: MS-DOS leaves it so. */
        fcb_put(FCB1_OFF, "zed?????txt", -1);
        err = fcb_call(0x0F, FCB1_OFF, DTA_A);
        dump_opened("fcb-open-wild-small", "fcb-after-0Fh", answered("al", err), FCB1_OFF);
        if (err == 0) fcb_call(0x10, FCB1_OFF, DTA_A);
        chdir("C:\\");
    }

    /* The folder loses an entry in the middle of it, the one the search found. */
    list[0] = 0;
    err = first(DTA_A, in_folder("FOO.TXT"), ALL);
    remove(in_folder("FOO.TXT"));
    dosmemput("???????????", 11, g_lin + DTA_A * DTA_SIZE + DTA_PATTERN);
    n = drain(DTA_A, list);
    line("list|folder-lost-a-middle-entry|first=%d more=%d|%s", err, n, list);

    fprintf(g_out, "end|lines=%d\n", g_lines);
    fclose(g_out);
    return 0;
}
