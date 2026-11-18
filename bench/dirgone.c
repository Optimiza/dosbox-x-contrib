/* DIRGONE.EXE: what a search left open inside a directory answers once that directory is removed
 * or renamed, with 8.3 names and the calls every DOS has, so that each DOS in reach can answer.
 *
 *   usage: DIRGONE <folder> <output file>                   e.g. DIRGONE D:\G C:\DIRGONE.TXT
 *
 * dirgone.sh beside this file makes the folder: KEEP, RD0, RD1, REN0 and REN1, each holding
 * ID.TXT and TWO.TXT. The program makes the rest itself before the first case: RDL with ID.TXT
 * and TWO.TXT, P1\X, P2\X, P3\X with ID.TXT, T with ID.TXT, and U. Each case opens a search of
 * <directory>\*.* with attribute 10h, reads its first entry, does one thing to the directory,
 * then continues the search with 4Fh until it fails. A line:
 *
 *   gone|<case>|first=<error of the 4Eh> entry=<its name> op=<error of what the case does>
 *       made=<error of what it does next, or -> next=<error of the 4Fh that ended the search>
 *       rest=<the names the 4Fh calls returned, in order, or ->
 *
 *   kept            KEEP, nothing done to it
 *   rd              RD0 emptied by 41h and removed by 3Ah (op is the 3Ah's; the 41h runs before
 *                   the search opens)
 *   rd-remade       RD1 the same, then made again empty by 39h under its old name
 *   ren             REN0 renamed RENA by 56h
 *   ren-remade      REN1 renamed RENB by 56h, then a new empty REN1 made by 39h
 *   rd-late-remade  RDL emptied after the search opens and removed, then made again by 39h with
 *                   an ID.TXT: what a DOS reads is the removed directory, not the new one
 *   rd-parent-ren   P1\X removed, then P1 renamed P1R
 *   rd-parent-rd    P2\X removed, then P2 removed
 *   ren-parent      P3 renamed P3R, the search being in P3\X
 *   ren-twice       T renamed T1, then T1 renamed T2
 *   ren-then-rd     U renamed U1, then U1 removed
 *   end|lines=<n>
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
#define MAX_REST 16

static unsigned long g_lin;
static unsigned short g_seg;
static FILE *g_out;
static const char *g_folder;
static int g_lines;

static int int21(__dpmi_regs *r) { __dpmi_int(0x21, r); return (r->x.flags & 1) ? r->x.ax : 0; }

static const char *in(const char *name)
{
    static char path[4][160];
    static int turn;
    char *p = path[turn++ & 3];
    sprintf(p, "%s\\%s", g_folder, name);
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

/* 3Ch then 3Eh: an empty file. */
static int make_file(const char *path)
{
    __dpmi_regs r;
    int rc;
    dosmemput(path, strlen(path) + 1, g_lin + PATH_OFF);
    memset(&r, 0, sizeof r);
    r.x.ax = 0x3C00; r.x.cx = 0; r.x.ds = g_seg; r.x.dx = PATH_OFF;
    rc = int21(&r);
    if (rc) return rc;
    {
        unsigned short h = r.x.ax;
        memset(&r, 0, sizeof r);
        r.x.ax = 0x3E00; r.x.bx = h;
        return int21(&r);
    }
}

/* 56h: DS:DX the name, ES:DI the new name. */
static int rename_entry(const char *from, const char *to)
{
    __dpmi_regs r;
    dosmemput(to, strlen(to) + 1, g_lin + NEW_OFF);
    dosmemput(from, strlen(from) + 1, g_lin + PATH_OFF);
    memset(&r, 0, sizeof r);
    r.x.ax = 0x5600; r.x.ds = g_seg; r.x.dx = PATH_OFF; r.x.es = g_seg; r.x.di = NEW_OFF;
    return int21(&r);
}

static void dta_name(char *name)
{
    dosmemget(g_lin + DTA_OFF + 30, 13, name);
    name[12] = 0;
}

static int find_next(void)
{
    __dpmi_regs r;
    memset(&r, 0, sizeof r);
    r.h.ah = 0x4F;
    return int21(&r);
}

/* The steps of a case. Each returns the error of its last call, or of the first that failed; the
 * calls are statements of their own, since C leaves the order of a function's arguments open. */
static int rename_to(const char *from, const char *to) { char t[64]; strcpy(t, in(to)); return rename_entry(in(from), t); }
static int rd(const char *name) { return path_call(0x3A00, 0, in(name)); }
static int md(const char *name) { return path_call(0x3900, 0, in(name)); }

static int empty(const char *dir)
{
    char file[64];
    int rc;
    sprintf(file, "%s\\ID.TXT", dir);
    rc = path_call(0x4100, 0, in(file));
    sprintf(file, "%s\\TWO.TXT", dir);
    if (rc) { path_call(0x4100, 0, in(file)); return rc; }
    return path_call(0x4100, 0, in(file));
}

static int empty_and_rd(const char *dir)
{
    int rc = empty(dir);
    if (rc) { rd(dir); return rc; }
    return rd(dir);
}

static int md_with_id(const char *dir)
{
    char file[64];
    int rc = md(dir);
    sprintf(file, "%s\\ID.TXT", dir);
    if (rc) { make_file(in(file)); return rc; }
    return make_file(in(file));
}

static int ren0(const char *dir) { return rename_to(dir, "RENA"); }
static int ren1(const char *dir) { return rename_to(dir, "RENB"); }
static int rd_parent_ren(const char *dir) { (void)dir; return rename_to("P1", "P1R"); }
static int rd_parent_rd(const char *dir) { (void)dir; return rd("P2"); }
static int ren_parent(const char *dir) { (void)dir; return rename_to("P3", "P3R"); }
static int ren_t1(const char *dir) { return rename_to(dir, "T1"); }
static int ren_t2(const char *dir) { (void)dir; return rename_to("T1", "T2"); }
static int ren_u1(const char *dir) { return rename_to(dir, "U1"); }
static int rd_u1(const char *dir) { (void)dir; return rd("U1"); }

typedef int (*step)(const char *dir);

struct gone_case {
    const char *label, *dir;
    step before, op, made;      /* before the search opens; once its first entry is read; after */
};

static const struct gone_case CASES[] = {
    { "kept",           "KEEP",  NULL,  NULL,          NULL },
    { "rd",             "RD0",   empty, rd,            NULL },
    { "rd-remade",      "RD1",   empty, rd,            md },
    { "ren",            "REN0",  NULL,  ren0,          NULL },
    { "ren-remade",     "REN1",  NULL,  ren1,          md },
    { "rd-late-remade", "RDL",   NULL,  empty_and_rd,  md_with_id },
    { "rd-parent-ren",  "P1\\X", NULL,  rd,            rd_parent_ren },
    { "rd-parent-rd",   "P2\\X", NULL,  rd,            rd_parent_rd },
    { "ren-parent",     "P3\\X", NULL,  ren_parent,    NULL },
    { "ren-twice",      "T",     NULL,  ren_t1,        ren_t2 },
    { "ren-then-rd",    "U",     NULL,  ren_u1,        rd_u1 },
};

static void one(const struct gone_case *c)
{
    char pattern[64], name[13], rest[MAX_REST * 13 + 1] = "";
    int first, op = 0, made = 0, next, n = 0;
    sprintf(pattern, "%s\\*.*", c->dir);
    if (c->before) c->before(c->dir);
    first = path_call(0x4E00, 0x10, in(pattern));
    if (first == 0) dta_name(name); else strcpy(name, "-");
    if (c->op) op = c->op(c->dir);
    if (c->made) made = c->made(c->dir);
    while ((next = find_next()) == 0 && n < MAX_REST) {
        char got[13];
        dta_name(got);
        if (n) strcat(rest, ",");
        strcat(rest, got);
        n++;
    }
    fprintf(g_out, "gone|%s|first=%04X entry=%s op=", c->label, first, name);
    if (c->op) fprintf(g_out, "%04X", op); else fputc('-', g_out);
    if (c->made) fprintf(g_out, " made=%04X", made); else fprintf(g_out, " made=-");
    fprintf(g_out, " next=%04X rest=%s\n", next, n ? rest : "-");
    g_lines++;
}

/* The directories the later cases need, made by the guest so that every DOS makes them alike. */
static void make_dirs(void)
{
    md_with_id("RDL"); make_file(in("RDL\\TWO.TXT"));
    md("P1"); md("P1\\X");
    md("P2"); md("P2\\X");
    md("P3"); md_with_id("P3\\X");
    md_with_id("T");
    md("U");
}

int main(int argc, char **argv)
{
    int sel;
    size_t i;
    __dpmi_regs r;

    if (argc != 3) { fprintf(stderr, "usage: DIRGONE <folder> <output file>\n"); return 2; }
    g_folder = argv[1];
    g_out = fopen(argv[2], "w");
    if (!g_out) { fprintf(stderr, "DIRGONE: cannot write %s\n", argv[2]); return 2; }
    /* A block of its own: the C library writes its files through the transfer buffer. */
    g_seg = (unsigned short)__dpmi_allocate_dos_memory(BLOCK_PARAS, &sel);
    if (g_seg == 0xFFFF) { fprintf(stderr, "DIRGONE: no DOS memory\n"); return 3; }
    g_lin = (unsigned long)g_seg * 16;
    memset(&r, 0, sizeof r);
    r.h.ah = 0x1A; r.x.ds = g_seg; r.x.dx = DTA_OFF;
    __dpmi_int(0x21, &r);
    make_dirs();
    for (i = 0; i < sizeof CASES / sizeof CASES[0]; i++) one(&CASES[i]);
    fprintf(g_out, "end|lines=%d\n", g_lines);
    fclose(g_out);
    __dpmi_free_dos_memory(sel);
    return 0;
}
