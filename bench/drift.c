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
#define DTA_BYTES 43
#define DTA_PATTERN 1       /* the 11 characters of the search template */
#define DTA_ATTR 12         /* the search attribute */
#define ALL 0x37            /* everything but the volume label */
#define SHOWN 40

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

    fprintf(g_out, "end|lines=%d\n", g_lines);
    fclose(g_out);
    return 0;
}
