/* DRIFT.EXE: what a DOS answers when a FindNext reaches the search of one exact name with another
 * pattern than its FindFirst had, written as text so the reports of two builds, or of a build
 * and a real DOS, can be compared line by line.
 *
 *   usage: DRIFT <folder> <output file>          e.g. DRIFT D:\X C:\DRIFT.TXT
 *
 * <folder> is the fixture exact.sh makes; its parent must be the drive's root. Every case starts
 * a 4Eh search for one exact name, changes the 11 pattern bytes of the DTA (or its attribute
 * byte), and reads the search to its end with 4Fh:
 *
 *   drift|<case>|first=<FindFirst's error> more=<entries FindNext returned>|,<name>:<attr>:<size>...
 *   end|lines=<n>
 *
 * The cases in a folder renamed or removed add op=<error of the 56h or the 3Ah> before more=; the
 * one whose rename fails adds create=<error of the 3Ch that makes a file after it> after op=.
 *
 * No long-name call is made, so it runs whole on a DOS that has none.
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
#define NEW_OFF 2800
#define DTA_BYTES 43
#define DTA_PATTERN 1       /* the 11 characters of the search template */
#define DTA_ATTR 12         /* the search attribute */
#define ALL 0x37            /* everything but the volume label */
#define SHOWN 40
#define DTA_ID 13           /* where DOSBox-X keeps a search's number, among the DOS's own bytes */
#define FILL_PLACES 256     /* the DTAs of the searches that fill the emulator's search table */
#define FILL_PER_DTA 9      /* the searches a DTA holds there: its own and eight it replaced */
#define FILL_CALLS 4000
#define REUSE_CALLS 2100

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

static int drain(int dta, char *list)
{
    char text[64];
    int n = 0;
    while (next(dta) == 0) {
        if (n < SHOWN) { dta_entry(dta, text); strcat(list, ","); strcat(list, text); }
        n++;
    }
    return n;
}

/* The template as the DTA holds it: eight characters of name and three of extension. */
static void edit(int dta, const char *pattern11) { dosmemput(pattern11, 11, g_lin + dta * DTA_SIZE + DTA_PATTERN); }

static void touch(const char *name) { FILE *f = fopen(in_folder(name), "w"); if (f) { fputs("x", f); fclose(f); } }

/* 39h, 3Ah and 41h: a call on one path. */
static int path_call(int ah, const char *name)
{
    __dpmi_regs r;
    const char *path = in_folder(name);
    dosmemput(path, strlen(path) + 1, g_lin + PATH_OFF);
    memset(&r, 0, sizeof r);
    r.h.ah = (unsigned char)ah; r.x.ds = g_seg; r.x.dx = PATH_OFF;
    return int21(&r);
}

/* 56h: DS:DX the name, ES:DI the new name. */
static int rename_entry(const char *from, const char *to)
{
    __dpmi_regs r;
    const char *old_path = in_folder(from), *new_path = in_folder(to);
    dosmemput(old_path, strlen(old_path) + 1, g_lin + PATH_OFF);
    dosmemput(new_path, strlen(new_path) + 1, g_lin + NEW_OFF);
    memset(&r, 0, sizeof r);
    r.h.ah = 0x56; r.x.ds = g_seg; r.x.dx = PATH_OFF; r.x.es = g_seg; r.x.di = NEW_OFF;
    return int21(&r);
}

/* 3Ch, then 3Eh: a file made by the guest and its handle given back. */
static int create_entry(const char *name)
{
    __dpmi_regs r, c;
    const char *path = in_folder(name);
    int err;
    dosmemput(path, strlen(path) + 1, g_lin + PATH_OFF);
    memset(&r, 0, sizeof r);
    r.h.ah = 0x3C; r.x.cx = 0; r.x.ds = g_seg; r.x.dx = PATH_OFF;
    err = int21(&r);
    if (!err) {
        memset(&c, 0, sizeof c);
        c.h.ah = 0x3E; c.x.bx = r.x.ax;
        __dpmi_int(0x21, &c);
    }
    return err;
}

static void file_in(const char *dir, const char *name)
{
    char path[64];
    sprintf(path, "%s\\%s", dir, name);
    touch(path);
}

static int empty_and_rd(const char *dir)
{
    static const char *const names[] = { "AAA.TXT", "MMM.TXT", "NNN.TXT", "ZZZ.TXT" };
    char path[64];
    size_t i;
    for (i = 0; i < sizeof names / sizeof names[0]; i++) {
        sprintf(path, "%s\\%s", dir, names[i]);
        path_call(0x41, path);
    }
    return path_call(0x3A, dir);
}

static unsigned short dta_id(unsigned long lin) { unsigned short id; dosmemget(lin + DTA_ID, 2, &id); return id; }

/* A search of the whole folder abandoned after its first entry, then enough searches, never
 * continued, to fill the search table DOSBox-X keeps, which it empties when it is full: its
 * numbers wrap past the free ones once, and drop again when it is emptied. A search
 * for *.TXT then repeated until DOSBox-X gives it the number of the abandoned one, and read to
 * its end. A DOS that keeps no table answers it as any search for *.TXT. */
static void reused_number(void)
{
    static char list[(SHOWN + 1) * 64];
    unsigned long fill_lin;
    unsigned short abandoned, id, last = 0;
    __dpmi_regs r;
    int fill_sel, fill_seg, err, c, n, drops = 0;
    list[0] = 0;
    fill_seg = __dpmi_allocate_dos_memory(FILL_PLACES * DTA_SIZE / 16, &fill_sel);
    if (fill_seg == -1) { line("drift|after-the-search-table-emptied|no conventional memory|"); return; }
    fill_lin = (unsigned long)fill_seg << 4;
    first(DTA_A, in_folder("*.*"), ALL);
    abandoned = dta_id(g_lin + DTA_A * DTA_SIZE);
    dosmemput(in_folder("*.*"), strlen(in_folder("*.*")) + 1, g_lin + PATH_OFF);
    for (c = 0; c < FILL_CALLS; c++) {
        memset(&r, 0, sizeof r);
        r.h.ah = 0x1A; r.x.ds = (unsigned short)fill_seg; r.x.dx = (unsigned short)((c / FILL_PER_DTA % FILL_PLACES) * DTA_SIZE);
        __dpmi_int(0x21, &r);
        memset(&r, 0, sizeof r);
        r.h.ah = 0x4E; r.x.cx = ALL; r.x.ds = g_seg; r.x.dx = PATH_OFF;
        if (int21(&r)) break;
        id = dta_id(fill_lin + (unsigned long)(c / FILL_PER_DTA % FILL_PLACES) * DTA_SIZE);
        if (c && id < last && ++drops == 2) break;
        last = id;
    }
    set_dta(DTA_PARK);
    for (c = 0; c < REUSE_CALLS; c++) {
        err = first(DTA_B, in_folder("*.TXT"), ALL);
        if (err || dta_id(g_lin + DTA_B * DTA_SIZE) == abandoned) break;
    }
    n = err ? 0 : drain(DTA_B, list);
    __dpmi_free_dos_memory(fill_sel);
    line("drift|after-the-search-table-emptied|first=%d more=%d|%s", err, n, list);
}

enum moved_how { MOVED_NOT, MOVED_REN, MOVED_REN_REMADE, MOVED_REN_FAILED, MOVED_RD, MOVED_RD_REMADE };

/* A folder of its own made with AAA.TXT and MMM.TXT (and ZZZ.TXT), a search for MMM.TXT in it,
 * the folder renamed or removed (and a folder made again under its old name, holding NNN.TXT),
 * then the template edited to every name. op is the error of the 56h or of the 3Ah. A rename
 * into the folder itself fails on the host: ZZZ.TXT is made after it, and create is the error
 * of the 3Ch that makes it. */
static void moved(const char *label, const char *dir, enum moved_how how)
{
    static char list[(SHOWN + 1) * 64];
    char path[64], other[16], inner[16];
    int err, op = 0, create = 0, n;
    list[0] = 0;
    sprintf(other, "%.6s_R", dir);
    path_call(0x39, dir);
    file_in(dir, "AAA.TXT"); file_in(dir, "MMM.TXT");
    if (how != MOVED_REN_FAILED) file_in(dir, "ZZZ.TXT");
    sprintf(path, "%s\\MMM.TXT", dir);
    err = first(DTA_A, in_folder(path), ALL);
    if (how == MOVED_REN || how == MOVED_REN_REMADE) op = rename_entry(dir, other);
    if (how == MOVED_REN_FAILED) {
        sprintf(inner, "%s\\SUB", dir);
        op = rename_entry(dir, inner);
        sprintf(inner, "%s\\ZZZ.TXT", dir);
        create = create_entry(inner);
    }
    if (how == MOVED_RD || how == MOVED_RD_REMADE) op = empty_and_rd(dir);
    if (how == MOVED_REN_REMADE || how == MOVED_RD_REMADE) { path_call(0x39, dir); file_in(dir, "NNN.TXT"); }
    edit(DTA_A, "???????????");
    n = drain(DTA_A, list);
    empty_and_rd(dir); empty_and_rd(other);
    if (how == MOVED_REN_FAILED)
        line("drift|%s|first=%d op=%d create=%d more=%d|%s", label, err, op, create, n, list);
    else
        line("drift|%s|first=%d op=%d more=%d|%s", label, err, op, n, list);
}

/* FindFirst for <name>, the template rewritten to <pattern11>, then the search to its end. */
static void edited(const char *label, const char *name, const char *pattern11)
{
    static char list[(SHOWN + 1) * 64];
    int err, n;
    list[0] = 0;
    err = first(DTA_A, in_folder(name), ALL);
    edit(DTA_A, pattern11);
    n = drain(DTA_A, list);
    line("drift|%s|first=%d more=%d|%s", label, err, n, list);
}

int main(int argc, char **argv)
{
    static char list[(SHOWN + 1) * 64], inner[(SHOWN + 1) * 64], root[400];
    char saved[DTA_BYTES], text[64];
    unsigned char attr = ALL;
    int sel, s, err, n, m;
    char *slash;

    if (argc != 3) { fprintf(stderr, "usage: DRIFT <folder> <output file>\n"); return 2; }
    g_folder = argv[1];
    s = __dpmi_allocate_dos_memory(BLOCK_PARAS, &sel);
    if (s == -1) { fprintf(stderr, "DRIFT: no conventional memory\n"); return 3; }
    g_seg = (unsigned short)s;
    g_lin = (unsigned long)g_seg << 4;
    set_dta(DTA_PARK);
    g_out = fopen(argv[2], "w");
    if (!g_out) { fprintf(stderr, "DRIFT: cannot write %s\n", argv[2]); return 3; }

    /* The folder as a whole-folder search returns it: the order the cases below are read against. */
    list[0] = 0;
    err = first(DTA_A, in_folder("*.*"), ALL);
    n = 0;
    if (err == 0) { dta_entry(DTA_A, list); n = 1 + drain(DTA_A, list); }
    line("drift|whole-folder|first=%d n=%d|%s", err, n, list);

    edited("to-every-name", "BAR.TXT", "???????????");
    edited("to-wildcard-that-matches-the-entry", "BAR.TXT", "????????TXT");
    edited("to-wildcard-that-does-not", "BAR.TXT", "????????MID");
    edited("to-a-later-exact-name", "BAR.TXT", "ZED     TXT");
    edited("to-an-earlier-exact-name", "FOO.TXT", "BAR     TXT");
    edited("to-a-missing-exact-name", "BAR.TXT", "NOSUCH  TXT");
    edited("to-its-own-name-in-lower-case", "BAR.TXT", "bar     txt");
    /* DOS compares the template with its directory byte for byte, and the directory holds upper
     * case: a later name in small letters or in mixed case, shorter than its fields and filling
     * them. */
    edited("to-a-later-exact-name-in-lower-case", "BAR.TXT", "zed     txt");
    edited("to-a-later-exact-name-in-mixed-case", "BAR.TXT", "Zed     Txt");
    edited("to-a-later-full-length-name-in-lower-case", "A.B", "alphat~2mid");
    edited("to-a-later-full-length-name-in-mixed-case", "A.B", "Alphat~2Mid");
    /* A DOS that keeps the template padded with zeros, where MS-DOS pads it with spaces, matches
     * a name padded its own way and not the one above: the same three edits in that form. */
    edited("to-a-later-exact-name-zero-padded", "BAR.TXT", "ZED\0\0\0\0\0TXT");
    edited("to-an-earlier-exact-name-zero-padded", "FOO.TXT", "BAR\0\0\0\0\0TXT");
    edited("to-its-own-name-zero-padded", "BAR.TXT", "BAR\0\0\0\0\0TXT");
    /* No directory entry holds a '*', so a template that has one matches nothing: the program
     * writes the eleven bytes itself, and a DOS reads them byte for byte. */
    edited("to-a-later-name-with-a-star", "BAR.TXT", "Z*      TXT");
    edited("to-a-star-for-the-name", "BAR.TXT", "*       TXT");
    edited("from-a-directory", "SUBDIR", "???????????");
    edited("from-the-last-entry", "ZED.TXT", "???????????");
    edited("from-a-missing-name", "NOSUCH.TXT", "???????????");

    /* The template edited twice: to every name for one entry, then to one exact name. */
    list[0] = 0;
    err = first(DTA_A, in_folder("BAR.TXT"), ALL);
    edit(DTA_A, "???????????");
    n = 0;
    if (next(DTA_A) == 0) { dta_entry(DTA_A, text); strcat(list, ","); strcat(list, text); n = 1; }
    edit(DTA_A, "ZED     TXT");
    n += drain(DTA_A, list);
    line("drift|edited-twice|first=%d more=%d|%s", err, n, list);

    /* The DTA saved, a whole-folder search run through it to its end, the bytes put back, then
     * the template edited. */
    list[0] = 0; inner[0] = 0;
    err = first(DTA_A, in_folder("BAR.TXT"), ALL);
    dosmemget(g_lin + DTA_A * DTA_SIZE, DTA_BYTES, saved);
    m = (first(DTA_A, in_folder("*.*"), ALL) == 0);
    m += drain(DTA_A, inner);
    dosmemput(saved, DTA_BYTES, g_lin + DTA_A * DTA_SIZE);
    edit(DTA_A, "???????????");
    n = drain(DTA_A, list);
    line("drift|saved-and-restored-then-edited|first=%d inner=%d more=%d|%s", err, m, n, list);

    /* The same exact name searched through a second DTA in between. */
    list[0] = 0;
    err = first(DTA_A, in_folder("BAR.TXT"), ALL);
    m = first(DTA_B, in_folder("BAR.TXT"), ALL);
    edit(DTA_A, "???????????");
    n = drain(DTA_A, list);
    inner[0] = 0;
    m += drain(DTA_B, inner);
    line("drift|two-searches-one-edited|first=%d more=%d other=%d|%s", err, n, m, list);

    /* The folder gains two files between the FindFirst and the edited FindNext: one whose name
     * sorts before the entry found and one after. */
    list[0] = 0;
    err = first(DTA_A, in_folder("BAR.TXT"), ALL);
    touch("AAANEW.TXT"); touch("BARNEW.TXT");
    edit(DTA_A, "???????????");
    n = drain(DTA_A, list);
    remove(in_folder("AAANEW.TXT")); remove(in_folder("BARNEW.TXT"));
    line("drift|folder-gained-files|first=%d more=%d|%s", err, n, list);

    /* The folder loses the entry found. */
    list[0] = 0;
    touch("KILL.TXT");
    err = first(DTA_A, in_folder("KILL.TXT"), ALL);
    remove(in_folder("KILL.TXT"));
    edit(DTA_A, "???????????");
    n = drain(DTA_A, list);
    line("drift|folder-lost-the-entry|first=%d more=%d|%s", err, n, list);

    /* The folder loses an entry that sorts after the one found. */
    list[0] = 0;
    touch("MMM.TXT");
    err = first(DTA_A, in_folder("BAR.TXT"), ALL);
    remove(in_folder("MMM.TXT"));
    edit(DTA_A, "???????????");
    n = drain(DTA_A, list);
    line("drift|folder-lost-a-later-entry|first=%d more=%d|%s", err, n, list);

    /* A search for the volume label alone, by an exact name, in the root: whether or not it
     * answers, the template and the attribute are then edited to everything. */
    strcpy(root, g_folder);
    slash = strrchr(root, '\\');
    if (slash) strcpy(slash + 1, "FOO.TXT");
    list[0] = 0;
    err = first(DTA_A, root, 0x08);
    edit(DTA_A, "???????????");
    dosmemput(&attr, 1, g_lin + DTA_A * DTA_SIZE + DTA_ATTR);
    n = drain(DTA_A, list);
    line("drift|label-search-then-edited|first=%d more=%d|%s", err, n, list);

    /* A search for one name in a folder that is then renamed or removed: DOS reads on in the
     * directory it was searching, under its new name, and finds nothing in a removed one. */
    moved("in-a-folder-kept", "MV0", MOVED_NOT);
    moved("in-a-folder-renamed", "MV1", MOVED_REN);
    moved("in-a-folder-renamed-and-remade", "MV2", MOVED_REN_REMADE);
    moved("in-a-folder-removed", "MV3", MOVED_RD);
    moved("in-a-folder-removed-and-remade", "MV4", MOVED_RD_REMADE);
    moved("in-a-folder-renamed-and-failed", "MV5", MOVED_REN_FAILED);
    reused_number();

    fprintf(g_out, "end|lines=%d\n", g_lines);
    fclose(g_out);
    return 0;
}
