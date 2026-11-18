/* LFNREN.EXE: whether the short names a directory gave before a rename still open the same files
 * under its new name, long names on. Each directory holds three files made by 716Ch, each holding
 * a word of its long name; the first is deleted by its short name before anything else, so the two
 * left keep the numbers ~2 and ~3, which a fresh read of the folder would not give them.
 *
 *   usage: LFNREN <folder> <output file>                     e.g. LFNREN D:\L C:\LFNREN.TXT
 *
 *   listed  A listed whole by 4Eh/4Fh, renamed AR by 56h, each name it listed opened as AR\<name>
 *   search  C searched (4Eh C\*.*, its "." read), renamed CR by 56h, the search read to its end
 *           by 4Fh, each name it returned opened as CR\<name>
 *
 * A line per name: lfnren|<case>|<name>=<error of 3Dh>:<what the file holds, or ->, beside a line
 * per directory made (lfnren|setup|<dir> del=<error of the 41h>), the rename's error and the count
 * the search returned. end|lines=<n>
 */
#include <dpmi.h>
#include <go32.h>
#include <stdio.h>
#include <string.h>
#include <sys/movedata.h>

#define BLOCK_PARAS 64
#define DTA_OFF 0
#define PATH_OFF 128
#define NEW_OFF 512
#define BUF_OFF 768

static unsigned long g_lin;
static unsigned short g_seg;
static FILE *g_out;
static const char *g_folder;
static int g_lines;
#define LINE(...) (g_lines++, fprintf(g_out, __VA_ARGS__))

static int int21(__dpmi_regs *r) { __dpmi_int(0x21, r); return (r->x.flags & 1) ? r->x.ax : 0; }

static const char *in(const char *name)
{
    static char path[4][200];
    static int turn;
    char *p = path[turn++ & 3];
    sprintf(p, "%s\\%s", g_folder, name);
    return p;
}

static int path_call(int ax, int cx, const char *path, __dpmi_regs *r)
{
    dosmemput(path, strlen(path) + 1, g_lin + PATH_OFF);
    memset(r, 0, sizeof *r);
    r->x.ax = (unsigned short)ax; r->x.cx = (unsigned short)cx; r->x.ds = g_seg; r->x.dx = PATH_OFF;
    return int21(r);
}

static int close_handle(unsigned short h)
{
    __dpmi_regs r;
    memset(&r, 0, sizeof r);
    r.x.ax = 0x3E00; r.x.bx = h;
    return int21(&r);
}

/* 716Ch create, the file holding its long name. */
static int make_long(const char *path, const char *text)
{
    __dpmi_regs r;
    int rc;
    unsigned short h;
    dosmemput(path, strlen(path) + 1, g_lin + PATH_OFF);
    memset(&r, 0, sizeof r);
    r.x.ax = 0x716C; r.x.bx = 0x0002; r.x.cx = 0; r.x.dx = 0x0012; r.x.ds = g_seg; r.x.si = PATH_OFF;
    rc = int21(&r);
    if (rc) return rc;
    if (r.x.ax == 0x7100) return 0x7100;
    h = r.x.ax;
    dosmemput(text, strlen(text), g_lin + BUF_OFF);
    memset(&r, 0, sizeof r);
    r.x.ax = 0x4000; r.x.bx = h; r.x.cx = (unsigned short)strlen(text); r.x.ds = g_seg; r.x.dx = BUF_OFF;
    int21(&r);
    return close_handle(h);
}

static void open_read(const char *label, const char *dir, const char *name)
{
    __dpmi_regs r;
    char path[64], text[64] = "-";
    int rc;
    sprintf(path, "%s\\%s", dir, name);
    rc = path_call(0x3D00, 0, in(path), &r);
    if (!rc) {
        unsigned short h = r.x.ax;
        memset(&r, 0, sizeof r);
        r.x.ax = 0x3F00; r.x.bx = h; r.x.cx = 63; r.x.ds = g_seg; r.x.dx = BUF_OFF;
        if (!int21(&r)) { dosmemget(g_lin + BUF_OFF, r.x.ax, text); text[r.x.ax] = 0; }
        close_handle(h);
    }
    LINE("lfnren|%s|%s=%04X:%s\n", label, name, rc, text);
}

static int rename_entry(const char *from, const char *to)
{
    __dpmi_regs r;
    dosmemput(to, strlen(to) + 1, g_lin + NEW_OFF);
    dosmemput(from, strlen(from) + 1, g_lin + PATH_OFF);
    memset(&r, 0, sizeof r);
    r.x.ax = 0x5600; r.x.ds = g_seg; r.x.dx = PATH_OFF; r.x.es = g_seg; r.x.di = NEW_OFF;
    return int21(&r);
}

static int find_next(void)
{
    __dpmi_regs r;
    memset(&r, 0, sizeof r);
    r.h.ah = 0x4F;
    return int21(&r);
}

static void dta_name(char *name) { dosmemget(g_lin + DTA_OFF + 30, 13, name); name[12] = 0; }

static void setup(const char *dir)
{
    __dpmi_regs r;
    char p[64];
    path_call(0x3900, 0, in(dir), &r);
    sprintf(p, "%s\\Long Name One.txt", dir); make_long(in(p), "one");
    sprintf(p, "%s\\Long Name Two.txt", dir); make_long(in(p), "two");
    sprintf(p, "%s\\Long Name Six.txt", dir); make_long(in(p), "six");
    sprintf(p, "%s\\LONGNA~1.TXT", dir);
    LINE("lfnren|setup|%s del=%04X\n", dir, path_call(0x4100, 0, in(p), &r));
}

int main(int argc, char **argv)
{
    int sel, n, i, rc;
    char names[16][13], pattern[64], to[64];
    __dpmi_regs r;

    if (argc != 3) return 2;
    g_folder = argv[1];
    g_out = fopen(argv[2], "w");
    if (!g_out) return 2;
    g_seg = (unsigned short)__dpmi_allocate_dos_memory(BLOCK_PARAS, &sel);
    if (g_seg == 0xFFFF) return 3;
    g_lin = (unsigned long)g_seg * 16;
    memset(&r, 0, sizeof r);
    r.h.ah = 0x1A; r.x.ds = g_seg; r.x.dx = DTA_OFF;
    __dpmi_int(0x21, &r);

    setup("A");
    n = 0;
    sprintf(pattern, "A\\*.*");
    for (rc = path_call(0x4E00, 0, in(pattern), &r); !rc && n < 16; rc = find_next()) dta_name(names[n++]);
    strcpy(to, in("AR"));
    LINE("lfnren|listed|56h=%04X\n", rename_entry(in("A"), to));
    for (i = 0; i < n; i++) open_read("listed", "AR", names[i]);

    setup("C");
    n = 0;
    sprintf(pattern, "C\\*.*");
    rc = path_call(0x4E00, 0x10, in(pattern), &r);
    strcpy(to, in("CR"));
    LINE("lfnren|search|first=%04X 56h=%04X\n", rc, rename_entry(in("C"), to));
    while (!find_next() && n < 16) {
        dta_name(names[n]);
        if (names[n][0] != '.') open_read("search", "CR", names[n]);
        n++;
    }
    LINE("lfnren|search|returned=%d\n", n);
    fprintf(g_out, "end|lines=%d\n", g_lines);
    fclose(g_out);
    __dpmi_free_dos_memory(sel);
    return 0;
}
