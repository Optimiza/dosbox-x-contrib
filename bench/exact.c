/* EXACT.EXE: what a DOSBox-X build answers to searches for one exact name, written as text so the
 * reports of two builds can be compared line by line.
 *
 *   usage: EXACT <folder> <output file>          e.g. EXACT D:\X C:\EXACT.TXT
 *
 * <folder> is the fixture exact.sh makes (its header lists the files). One line per search, every
 * entry the search returned to its end, in the order returned:
 *
 *   basic|4e|<attr>|<path>|err=<first call's error>|n=<entries>|<name>:<attr>:<size>,...
 *   basic|lfn|<attr>|<path>|err=...|n=...|<long name>:<alias>:<attr>:<size>,...
 *   basic|fcb|<plain or the extended FCB's attribute>|<the FCB's 11 characters>|n=...|<name>,...
 *   life|<case>|...     searches with an exact name that are saved, nested, abandoned or met by a
 *                       change of the folder: counts that must not move
 *   drift|<case>|...    a FindNext that arrives with another pattern than its FindFirst had: the
 *                       program edits the DTA, or the emulator itself rewrites it (a FindFirst that
 *                       fails after it set the search up, a long-name call made while the DTA is
 *                       current, the FCB calls sharing a DTA with the emulator's own lookups)
 *   end|lines=<n>
 *
 * Every call goes through __dpmi_int with its DTAs, find record, path and FCB in a block of
 * conventional memory of its own, and the current DTA is parked on a spare one between calls:
 * libc's own calls must not reach a search under test.
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
#define FIND_OFF 2048
#define PATH_OFF 2400
#define FCB_OFF 2720
#define DTA_BYTES 43
#define ALL 0x37            /* everything but the volume label */
#define SHOWN 40            /* entries written per search; the count is always whole */
#define SLOTS 2048

static unsigned long g_lin;
static unsigned short g_seg;
static FILE *g_out;
static int g_lines;
static const char *g_folder;

static int int21(__dpmi_regs *r) { __dpmi_int(0x21, r); return (r->x.flags & 1) ? r->x.ax : 0; }

static void set_dta(int dta)
{
    __dpmi_regs r;
    memset(&r, 0, sizeof r);
    r.h.ah = 0x1A; r.x.ds = g_seg; r.x.dx = (unsigned short)(dta * DTA_SIZE);
    __dpmi_int(0x21, &r);
}

static void put_path(const char *path) { dosmemput(path, strlen(path) + 1, g_lin + PATH_OFF); }

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
    put_path(path);
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

static int lfn_first(const char *path, int attr, int *handle)
{
    __dpmi_regs r;
    int err;
    put_path(path);
    memset(&r, 0, sizeof r);
    r.x.ax = 0x714E; r.x.cx = (unsigned short)attr; r.x.si = 1;
    r.x.ds = g_seg; r.x.dx = PATH_OFF; r.x.es = g_seg; r.x.di = FIND_OFF;
    r.x.flags = 1;
    err = int21(&r);
    *handle = r.x.ax;
    return err;
}

static int lfn_next(int handle)
{
    __dpmi_regs r;
    memset(&r, 0, sizeof r);
    r.x.ax = 0x714F; r.x.bx = (unsigned short)handle; r.x.si = 1;
    r.x.es = g_seg; r.x.di = FIND_OFF;
    r.x.flags = 1;
    return int21(&r);
}

static void lfn_close(int handle)
{
    __dpmi_regs r;
    memset(&r, 0, sizeof r);
    r.x.ax = 0x71A1; r.x.bx = (unsigned short)handle;
    __dpmi_int(0x21, &r);
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

/* Appends what is left of a 4Eh search to `list` and returns how many entries that was. */
static int drain(int dta, char *list)
{
    char text[64];
    int n = 0;
    while (next(dta) == 0) {
        if (list && n < SHOWN) { dta_entry(dta, text); strcat(list, ","); strcat(list, text); }
        n++;
    }
    return n;
}

static int list4e(int dta, const char *path, int attr, char *list)
{
    list[0] = 0;
    if (first(dta, path, attr) != 0) return 0;
    dta_entry(dta, list);
    return 1 + drain(dta, list);
}

static void basic4e(const char *path, int attr)
{
    static char list[(SHOWN + 1) * 64];
    int err, n = 0;
    list[0] = 0;
    err = first(DTA_A, path, attr);
    if (err == 0) { dta_entry(DTA_A, list); n = 1 + drain(DTA_A, list); }
    line("basic|4e|%02X|%s|err=%d|n=%d|%s", attr, path, err, n, list);
}

static void lfn_entry(char *text)
{
    char name[261], alias[15];
    unsigned long attr, size;
    dosmemget(g_lin + FIND_OFF, 4, &attr);
    dosmemget(g_lin + FIND_OFF + 32, 4, &size);
    dosmemget(g_lin + FIND_OFF + 44, 260, name); name[260] = 0;
    dosmemget(g_lin + FIND_OFF + 304, 14, alias); alias[14] = 0;
    sprintf(text, "%s:%s:%02lX:%lu", name, alias, attr, size);
}

static void basiclfn(const char *path, int attr)
{
    static char list[(SHOWN + 1) * 300];
    char text[300];
    int err, handle, n = 0;
    list[0] = 0;
    err = lfn_first(path, attr, &handle);
    if (err == 0) {
        lfn_entry(list);
        n = 1;
        while (lfn_next(handle) == 0) {
            if (n < SHOWN) { lfn_entry(text); strcat(list, ","); strcat(list, text); }
            n++;
        }
        lfn_close(handle);
    }
    line("basic|lfn|%02X|%s|err=%d|n=%d|%s", attr, path, err, n, list);
}

/* An unopened FCB for the default drive: plain when attr < 0, extended with that attribute. */
static void fcb_put(const char *name11, int attr)
{
    unsigned char fcb[44];
    memset(fcb, 0, sizeof fcb);
    if (attr < 0) memcpy(fcb + 1, name11, 11);
    else { fcb[0] = 0xFF; fcb[6] = (unsigned char)attr; memcpy(fcb + 8, name11, 11); }
    dosmemput(fcb, sizeof fcb, g_lin + FCB_OFF);
}

static int fcb_call(int function, int dta)
{
    __dpmi_regs r;
    set_dta(dta);
    memset(&r, 0, sizeof r);
    r.h.ah = (unsigned char)function; r.x.ds = g_seg; r.x.dx = FCB_OFF;
    __dpmi_int(0x21, &r);
    set_dta(DTA_PARK);
    return r.h.al == 0 ? 0 : 1;
}

static void fcb_entry(int dta, int extended, char *text)
{
    dosmemget(g_lin + dta * DTA_SIZE + (extended ? 8 : 1), 11, text);
    text[11] = 0;
}

static int fcb_drain(int dta, int extended, char *list)
{
    char text[12];
    int n = 0;
    while (fcb_call(0x12, dta) == 0) {
        if (list && n < SHOWN) { fcb_entry(dta, extended, text); strcat(list, ","); strcat(list, text); }
        n++;
    }
    return n;
}

static void basicfcb(const char *name11, int attr)
{
    static char list[(SHOWN + 1) * 12];
    int n = 0;
    list[0] = 0;
    fcb_put(name11, attr);
    if (fcb_call(0x11, DTA_A) == 0) { fcb_entry(DTA_A, attr >= 0, list); n = 1 + fcb_drain(DTA_A, attr >= 0, list); }
    if (attr < 0) line("basic|fcb|plain|%s|n=%d|%s", name11, n, list);
    else line("basic|fcb|%02X|%s|n=%d|%s", attr, name11, n, list);
}

static void dta_save(int dta, char *bytes) { dosmemget(g_lin + dta * DTA_SIZE, DTA_BYTES, bytes); }
static void dta_load(int dta, const char *bytes) { dosmemput(bytes, DTA_BYTES, g_lin + dta * DTA_SIZE); }

static const char *const NAMES[] = {
    "FOO.TXT", "foo.txt", "Foo.Txt", "FOO.TXT.", "FOO.", "FOO", "FOO.TX", "FOO.TXTX", "FOOO.TXT", "FO.TXT",
    " FOO.TXT", "FOO.TXT ", "FOO .TXT", "NOSUCH.TXT", "NOEXT", "NOEXT.", "noext.", "A.B", "A.B.",
    "SUBDIR", "subdir", "SUBDIR.", "Long Sub Directory", "LONGSU~1", "LONGSU~1.", "ALPHAT~1.MID",
    "alphat~1.mid", "ALPHAT~2.MID", "ALPHAT~3.MID", "ALPHAT~4.MID", "Alpha track 000000.mid",
    "ALPHA TRACK 000000.MID", "Alpha track 000001.mid", "Alpha tr.mid", "ALPHA TR.MID", "MixCase.Txt",
    "MIXCASE.TXT", "Two.dots.name.txt", "TWODOT~1.TXT", "No extension long name", "NOEXTE~1",
    "NUL", "NUL.TXT", "CON", "PRN.TXT", ".", "..", "X", "SUBDIR\\INNER.TXT", "SUBDIR\\NOSUCH.TXT",
    "NOSUCH\\FOO.TXT", "Long Sub Directory\\Inner long name.dat", "LONGSU~1\\INNERL~1.DAT",
};

static const char *const WILD[] = {
    "*.*", "*.TXT", "FOO.T?T", "F*.TXT", "????????.???", "FOO.*", "*.MID", "ALPHAT~?.MID", "*", "Alpha*", "*.mid",
};

static const char *const ROOT[] = {
    "D:\\X", "D:\\x", "D:\\X\\", "D:\\FOO.TXT", "D:\\NOSUCH", "D:\\X\\FOO.TXT\\", "D:FOO.TXT", "D:\\.\\X\\FOO.TXT",
    "D:\\X\\..\\FOO.TXT", "D:\\X\\SUBDIR\\..\\BAR.TXT",
};

static const char *const LABEL[] = { "D:\\*.*", "D:\\FOO.TXT", "D:\\X\\FOO.TXT", "D:\\NOSUCH.TXT", "D:\\X\\*.*" };

static const char *const FCBS[] = {
    "FOO     TXT", "NOSUCH  TXT", "NOEXT      ", "A       B  ", "SUBDIR     ", "ALPHAT~1MID", "ALPHAT~2MID",
    "MIXCASE TXT", "????????TXT", "FOO     T?T", "FOO     ???", "???????????",
};

#define COUNT(a) ((int)(sizeof(a) / sizeof(a)[0]))

int main(int argc, char **argv)
{
    static char list[(SHOWN + 1) * 64], list2[(SHOWN + 1) * 64];
    char saved[DTA_BYTES], text[64], cwd[300];
    int sel, s, i, n, m, t, total, handle, err, err2;
    FILE *f;

    if (argc != 3) { fprintf(stderr, "usage: EXACT <folder> <output file>\n"); return 2; }
    g_folder = argv[1];
    s = __dpmi_allocate_dos_memory(BLOCK_PARAS, &sel);
    if (s == -1) { fprintf(stderr, "EXACT: no conventional memory\n"); return 3; }
    g_seg = (unsigned short)s;
    g_lin = (unsigned long)g_seg << 4;
    set_dta(DTA_PARK);
    g_out = fopen(argv[2], "w");
    if (!g_out) { fprintf(stderr, "EXACT: cannot write %s\n", argv[2]); return 3; }

    for (i = 0; i < COUNT(NAMES); i++) {
        basic4e(in_folder(NAMES[i]), ALL);
        basic4e(in_folder(NAMES[i]), 0x00);
        basic4e(in_folder(NAMES[i]), 0x10);
        basiclfn(in_folder(NAMES[i]), ALL);
        basiclfn(in_folder(NAMES[i]), 0x00);
    }
    for (i = 0; i < COUNT(WILD); i++) { basic4e(in_folder(WILD[i]), ALL); basiclfn(in_folder(WILD[i]), ALL); }
    for (i = 0; i < COUNT(ROOT); i++) { basic4e(ROOT[i], ALL); basiclfn(ROOT[i], ALL); }
    for (i = 0; i < COUNT(LABEL); i++) { basic4e(LABEL[i], 0x08); basic4e(LABEL[i], 0x3F); basiclfn(LABEL[i], 0x08); }

    getcwd(cwd, sizeof cwd);
    if (chdir(g_folder) == 0) {
        for (i = 0; i < COUNT(FCBS); i++) { basicfcb(FCBS[i], -1); basicfcb(FCBS[i], 0x10); basicfcb(FCBS[i], 0x16); }
        /* the same exact names with no drive and no directory, from inside the folder */
        basic4e("FOO.TXT", ALL); basic4e("NOSUCH.TXT", ALL); basic4e("SUBDIR", ALL);
        basiclfn("Alpha track 000000.mid", ALL);
    } else {
        line("basic|fcb|could not enter %s", g_folder);
    }

    total = list4e(DTA_A, in_folder("*.*"), ALL, list);
    line("life|whole-folder|n=%d", total);

    /* Two exact-name searches through one DTA, the first one's bytes saved and put back. */
    n = (first(DTA_A, in_folder("FOO.TXT"), ALL) == 0);
    dta_save(DTA_A, saved);
    m = list4e(DTA_A, in_folder("BAR.TXT"), ALL, list2);
    dta_load(DTA_A, saved);
    n += drain(DTA_A, NULL);
    line("life|exact-nested-same-dta|outer=%d inner=%d", n, m);

    /* A whole-folder search with exact-name searches inside it: through its own DTA with its
     * bytes saved and put back, then through another DTA and never continued. */
    n = (first(DTA_A, in_folder("*.*"), ALL) == 0);
    for (i = 0; i < 2 && next(DTA_A) == 0; i++) n++;
    dta_save(DTA_A, saved);
    m = list4e(DTA_A, in_folder("ZED.TXT"), ALL, list2);
    dta_load(DTA_A, saved);
    for (i = 0; i < 50; i++) first(DTA_B, in_folder("BAR.TXT"), ALL);
    n += drain(DTA_A, NULL);
    line("life|exact-inside-whole-folder|outer=%d of %d inner=%d", n, total, m);

    /* An exact-name search that matches more than one entry, read one entry at a time with a
     * whole-folder search of another DTA between the two. */
    list[0] = 0; n = 0; m = -1;
    if (first(DTA_A, in_folder("ALPHAT~1.MID"), ALL) == 0) {
        dta_entry(DTA_A, list); n = 1;
        m = list4e(DTA_B, in_folder("*.*"), ALL, list2);
        n += drain(DTA_A, list);
    }
    line("life|exact-two-entries|n=%d inner=%d of %d|%s", n, m, total, list);

    /* The folder changes between exact-name searches for the name that changes. */
    err = first(DTA_A, in_folder("NEWFILE.TXT"), ALL);
    f = fopen(in_folder("NEWFILE.TXT"), "w");
    if (f) { fputs("new", f); fclose(f); }
    n = list4e(DTA_A, in_folder("NEWFILE.TXT"), ALL, list);
    t = list4e(DTA_B, in_folder("newfile.txt"), ALL, list2);
    remove(in_folder("NEWFILE.TXT"));
    err2 = first(DTA_A, in_folder("NEWFILE.TXT"), ALL);
    line("life|exact-after-create-and-delete|before=%d created=%d found=%d other_case=%d after=%d|%s", err, f != NULL, n, t, err2, list);

    /* An exact-name search started before the folder changes, continued after. */
    err = first(DTA_A, in_folder("BAR.TXT"), ALL);
    f = fopen(in_folder("BARNEW.TXT"), "w");
    if (f) fclose(f);
    n = drain(DTA_A, NULL);
    remove(in_folder("BARNEW.TXT"));
    line("life|exact-across-create|first=%d more=%d", err, n);

    /* Long-name searches for one exact name, opened and closed 300 times, then the folder whole. */
    m = 0;
    for (i = 0; i < 300; i++) {
        if (lfn_first(in_folder("Alpha track 000000.mid"), ALL, &handle) == 0) { m++; lfn_close(handle); }
    }
    n = list4e(DTA_A, in_folder("*.*"), ALL, list);
    line("life|lfn-exact-300-then-folder|found=%d folder=%d of %d", m, n, total);

    /* More abandoned exact-name searches than the cache has slots, then the folder whole and one
     * exact name again. */
    m = 0;
    for (i = 0; i < SLOTS + 60; i++) if (first(DTA_B, in_folder("BAR.TXT"), ALL) == 0) m++;
    n = list4e(DTA_A, in_folder("*.*"), ALL, list);
    t = list4e(DTA_C, in_folder("ZED.TXT"), ALL, list2);
    line("life|exact-abandoned-past-the-slots|found=%d folder=%d of %d then=%d|%s", m, n, total, t, list2);

    /* drift: the program rewrites the DTA's pattern to eleven question marks after an exact-name
     * FindFirst. */
    list[0] = 0;
    err = first(DTA_A, in_folder("BAR.TXT"), ALL);
    memset(text, '?', 11);
    dosmemput(text, 11, g_lin + DTA_A * DTA_SIZE + 1);
    n = drain(DTA_A, list);
    line("drift|dta-pattern-edited|first=%d more=%d|%s", err, n, list);

    /* drift: a FindFirst that fails after the emulator set its search up in the DTA (the
     * directory does not exist), through the DTA of an exact-name search. */
    list[0] = 0;
    err = first(DTA_A, in_folder("BAR.TXT"), ALL);
    err2 = first(DTA_A, "D:\\NOSUCH\\*.*", ALL);
    n = drain(DTA_A, list);
    line("drift|failed-findfirst-other-pattern|first=%d failed=%d more=%d|%s", err, err2, n, list);

    /* drift: a long-name search made while the DTA of an exact-name 4Eh search is current. */
    list[0] = 0;
    err = first(DTA_A, in_folder("BAR.TXT"), ALL);
    set_dta(DTA_A);
    err2 = lfn_first(in_folder("*"), ALL, &handle);
    if (err2 == 0) lfn_close(handle);
    set_dta(DTA_PARK);
    n = drain(DTA_A, list);
    line("drift|lfn-wildcard-writes-exact-dta|first=%d lfn=%d more=%d|%s", err, err2, n, list);

    /* drift: the same with a whole-folder 4Eh search and an exact long-name search. */
    list[0] = 0;
    n = (first(DTA_A, in_folder("*.*"), ALL) == 0);
    for (i = 0; i < 2 && next(DTA_A) == 0; i++) n++;
    set_dta(DTA_A);
    err2 = lfn_first(in_folder("FOO.TXT"), ALL, &handle);
    if (err2 == 0) lfn_close(handle);
    set_dta(DTA_PARK);
    n += drain(DTA_A, list);
    line("drift|lfn-exact-writes-wildcard-dta|lfn=%d outer=%d of %d|%s", err2, n, total, list);

    /* drift: a device name through the DTA of an exact-name search. */
    list[0] = 0;
    err = first(DTA_A, in_folder("BAR.TXT"), ALL);
    err2 = first(DTA_A, "NUL", ALL);
    n = drain(DTA_A, list);
    line("drift|device-through-exact-dta|first=%d device=%d more=%d|%s", err, err2, n, list);

    /* The FCB calls share one DTA with the emulator's own lookups, so a long-name call between
     * 11h and 12h reaches the FCB search: an exact FCB name, then a whole-folder one, each with
     * an exact long-name search in the middle; and a whole-folder one around an exact 4Eh. */
    if (chdir(g_folder) == 0) {
        list[0] = 0; n = 0;
        fcb_put("BAR     TXT", -1);
        if (fcb_call(0x11, DTA_A) == 0) n = 1;
        err2 = lfn_first(in_folder("ZED.TXT"), ALL, &handle);
        if (err2 == 0) lfn_close(handle);
        n += fcb_drain(DTA_A, 0, list);
        line("drift|fcb-exact-around-lfn-exact|lfn=%d files=%d|%s", err2, n, list);

        list[0] = 0; n = 0;
        fcb_put("???????????", -1);
        if (fcb_call(0x11, DTA_A) == 0) n = 1;
        if (fcb_call(0x12, DTA_A) == 0) n++;
        err2 = lfn_first(in_folder("Alpha track 000000.mid"), ALL, &handle);
        if (err2 == 0) lfn_close(handle);
        n += fcb_drain(DTA_A, 0, list);
        line("drift|fcb-wildcard-around-lfn-exact|lfn=%d files=%d|%s", err2, n, list);

        n = 0;
        fcb_put("???????????", -1);
        if (fcb_call(0x11, DTA_A) == 0) n = 1;
        if (fcb_call(0x12, DTA_A) == 0) n++;
        err2 = first(DTA_B, in_folder("ZED.TXT"), ALL);
        n += fcb_drain(DTA_A, 0, NULL);
        line("life|fcb-wildcard-around-4e-exact|inner=%d files=%d", err2, n);
    }
    chdir(cwd);

    fprintf(g_out, "end|lines=%d\n", g_lines);
    fclose(g_out);
    return 0;
}
