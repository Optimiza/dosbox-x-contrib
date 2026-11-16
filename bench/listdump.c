/* LISTDUMP.EXE: everything a DOSBox-X build answers about one folder, written as text, so the
 * dumps of two builds can be compared byte for byte.
 *
 *   usage: LISTDUMP <folder> <output file>        e.g. LISTDUMP D:\DIR C:\LIST.TXT
 *
 * The dump has three sections. Each enumeration closes with the guest's own count, and the last
 * line (end|...) carries the two counts again and the number of lookups:
 *   4e|...    every entry of a full 4Eh/4Fh enumeration of <folder>\*.*, in the order returned:
 *             attribute, time, date, size and the 8.3 name (what a DOS program sees);
 *   lfn|...   every entry of a full 714Eh/714Fh enumeration of <folder>\*, closed with 71A1h:
 *             attributes, the three times, size, the long name and the 8.3 alias. Without long
 *             names the first call fails and its error is the whole section;
 *   look|...  exact-name lookups of the first, middle and last entry of each enumeration, a name
 *             that is not there and the middle name in the other case, each through libc's
 *             `access` and `stat` (which reach DOS the way any DJGPP program does) and through
 *             raw 716Ch and 714Eh.
 *
 * The enumerations go through __dpmi_int with the DTA, the find record and the path in a block
 * of conventional memory of their own: libc's transfer buffer is overwritten by every write to
 * the output file, and 4Fh resumes from whatever the DTA holds.
 *
 * Left out on purpose: the DTA's first 21 bytes (the search state DOS keeps there) and the
 * handle 714Eh returns, which identify a search rather than describe a file, and the 8 reserved
 * bytes of the 714Eh record (24h to 2Bh), which describe nothing.
 */

#include <ctype.h>
#include <dpmi.h>
#include <errno.h>
#include <fcntl.h>
#include <go32.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/movedata.h>
#include <sys/stat.h>
#include <unistd.h>

#define BLOCK_PARAS 64
#define DTA_OFF 0
#define FIND_OFF 128
#define PATH_OFF 512
#define FIND_SIZE 318
#define PATH_MAX_DOS 300
#define SEARCH_ATTR 0x37    /* read-only, hidden, system, directory, archive: all but the label */
#define DOS_TIMES 1         /* 714Eh/714Fh SI: times as DOS date and time, not FILETIME */

static unsigned long g_block;
static unsigned short g_seg;
static FILE *g_out;
static int g_looks;

struct names {
    char **v;
    int n, cap;
};

static void names_add(struct names *l, const char *s)
{
    if (l->n == l->cap) {
        l->cap = l->cap ? l->cap * 2 : 1024;
        l->v = realloc(l->v, (size_t)l->cap * sizeof *l->v);
        if (!l->v) { fprintf(stderr, "out of memory\n"); exit(2); }
    }
    l->v[l->n] = strdup(s);
    if (!l->v[l->n]) { fprintf(stderr, "out of memory\n"); exit(2); }
    l->n++;
}

static int is_dot(const char *s)
{
    return strcmp(s, ".") == 0 || strcmp(s, "..") == 0;
}

static int put_path(const char *p)
{
    size_t len = strlen(p) + 1;
    if (len > PATH_MAX_DOS) return -1;
    dosmemput(p, len, g_block + PATH_OFF);
    return 0;
}

static void regs_init(__dpmi_regs *r)
{
    memset(r, 0, sizeof *r);
    r->x.ds = g_seg;
    r->x.es = g_seg;
}

static unsigned long le32(const unsigned char *p)
{
    return (unsigned long)p[0] | (unsigned long)p[1] << 8 | (unsigned long)p[2] << 16 |
           (unsigned long)p[3] << 24;
}

static void dump_dta(int idx, struct names *keep)
{
    unsigned char d[43];
    char name[14];
    dosmemget(g_block + DTA_OFF, sizeof d, d);
    memcpy(name, d + 0x1E, 13);
    name[13] = 0;
    fprintf(g_out, "4e|%d|attr=%02x|time=%04x|date=%04x|size=%lu|name=%s\n", idx, d[0x15],
            d[0x16] | d[0x17] << 8, d[0x18] | d[0x19] << 8, le32(d + 0x1A), name);
    if (keep && !is_dot(name)) names_add(keep, name);
}

/* One 714Eh/714Fh record, the fields in their order in the record. */
static void dump_find(const char *tag, int idx, unsigned cx, struct names *keep)
{
    unsigned char f[FIND_SIZE];
    char lname[261], sname[15];
    dosmemget(g_block + FIND_OFF, sizeof f, f);
    memcpy(lname, f + 0x2C, 260);
    lname[260] = 0;
    memcpy(sname, f + 0x130, 14);
    sname[14] = 0;
    fprintf(g_out,
            "%s|%d|attr=%08lx|ctime=%08lx%08lx|atime=%08lx%08lx|mtime=%08lx%08lx"
            "|size=%08lx%08lx|cx=%04x|long=%s|short=%s\n",
            tag, idx, le32(f), le32(f + 0x08), le32(f + 0x04), le32(f + 0x10), le32(f + 0x0C),
            le32(f + 0x18), le32(f + 0x14), le32(f + 0x1C), le32(f + 0x20), cx, lname, sname);
    if (keep && !is_dot(lname)) names_add(keep, lname);
}

static int enum_4e(const char *folder, struct names *keep)
{
    char spec[PATH_MAX_DOS];
    __dpmi_regs r;
    int count = 0;

    snprintf(spec, sizeof spec, "%s\\*.*", folder);
    put_path(spec);
    regs_init(&r);
    r.h.ah = 0x1A;
    r.x.dx = DTA_OFF;
    __dpmi_int(0x21, &r);

    regs_init(&r);
    r.h.ah = 0x4E;
    r.x.cx = SEARCH_ATTR;
    r.x.dx = PATH_OFF;
    __dpmi_int(0x21, &r);
    while (!(r.x.flags & 1)) {
        dump_dta(count++, keep);
        regs_init(&r);
        r.h.ah = 0x4F;
        __dpmi_int(0x21, &r);
    }
    fprintf(g_out, "4e-end|err=%04x|count=%d\n", r.x.ax, count);
    return count;
}

static int enum_lfn(const char *folder, struct names *keep)
{
    char spec[PATH_MAX_DOS];
    __dpmi_regs r;
    unsigned short handle;
    int count = 0;

    snprintf(spec, sizeof spec, "%s\\*", folder);
    put_path(spec);
    regs_init(&r);
    r.x.ax = 0x714E;
    r.h.cl = SEARCH_ATTR;
    r.x.si = DOS_TIMES;
    r.x.dx = PATH_OFF;
    r.x.di = FIND_OFF;
    __dpmi_int(0x21, &r);
    if (r.x.flags & 1) {
        fprintf(g_out, "lfn-end|err=%04x|count=0\n", r.x.ax);
        return 0;
    }
    handle = r.x.ax;
    for (;;) {
        dump_find("lfn", count++, r.x.cx, keep);
        regs_init(&r);
        r.x.ax = 0x714F;
        r.x.bx = handle;
        r.x.si = DOS_TIMES;
        r.x.di = FIND_OFF;
        __dpmi_int(0x21, &r);
        if (r.x.flags & 1) break;
    }
    fprintf(g_out, "lfn-end|err=%04x|count=%d\n", r.x.ax, count);
    regs_init(&r);
    r.x.ax = 0x71A1;
    r.x.bx = handle;
    __dpmi_int(0x21, &r);
    fprintf(g_out, "lfn-close|cf=%d|ax=%04x\n", r.x.flags & 1, (r.x.flags & 1) ? r.x.ax : 0);
    return count;
}

static void look_access(const char *path)
{
    int rc;
    errno = 0;
    rc = access(path, F_OK);
    fprintf(g_out, "look-access|rc=%d|errno=%d\n", rc, rc ? errno : 0);
}

static void look_stat(const char *path)
{
    struct stat st;
    int rc;
    errno = 0;
    rc = stat(path, &st);
    if (rc)
        fprintf(g_out, "look-stat|rc=%d|errno=%d\n", rc, errno);
    else
        fprintf(g_out, "look-stat|rc=0|size=%ld|mode=%o|mtime=%ld\n", (long)st.st_size,
                (unsigned)st.st_mode, (long)st.st_mtime);
}

static void look_716c(const char *path)
{
    __dpmi_regs r;
    unsigned short handle;
    if (put_path(path)) { fprintf(g_out, "look-716c|too-long\n"); return; }
    regs_init(&r);
    r.x.ax = 0x716C;
    r.x.bx = 0;     /* read-only */
    r.x.dx = 1;     /* open an existing file, fail otherwise */
    r.x.si = PATH_OFF;
    __dpmi_int(0x21, &r);
    if (r.x.flags & 1) {
        fprintf(g_out, "look-716c|cf=1|err=%04x\n", r.x.ax);
        return;
    }
    handle = r.x.ax;
    fprintf(g_out, "look-716c|cf=0|action=%04x\n", r.x.cx);
    regs_init(&r);
    r.h.ah = 0x3E;
    r.x.bx = handle;
    __dpmi_int(0x21, &r);
}

static void look_714e(const char *path)
{
    __dpmi_regs r;
    unsigned short handle;
    if (put_path(path)) { fprintf(g_out, "look-714e|too-long\n"); return; }
    regs_init(&r);
    r.x.ax = 0x714E;
    r.h.cl = SEARCH_ATTR;
    r.x.si = DOS_TIMES;
    r.x.dx = PATH_OFF;
    r.x.di = FIND_OFF;
    __dpmi_int(0x21, &r);
    if (r.x.flags & 1) {
        fprintf(g_out, "look-714e|cf=1|err=%04x\n", r.x.ax);
        return;
    }
    handle = r.x.ax;
    dump_find("look-714e", 0, r.x.cx, NULL);
    regs_init(&r);
    r.x.ax = 0x714F;
    r.x.bx = handle;
    r.x.si = DOS_TIMES;
    r.x.di = FIND_OFF;
    __dpmi_int(0x21, &r);
    fprintf(g_out, "look-714f|cf=%d|err=%04x\n", r.x.flags & 1, (r.x.flags & 1) ? r.x.ax : 0);
    regs_init(&r);
    r.x.ax = 0x71A1;
    r.x.bx = handle;
    __dpmi_int(0x21, &r);
}

static void look_one(const char *folder, const char *source, const char *which, const char *name)
{
    char path[PATH_MAX_DOS];
    g_looks++;
    fprintf(g_out, "look|%s|%s|%s\n", source, which, name);
    if (snprintf(path, sizeof path, "%s\\%s", folder, name) >= (int)sizeof path) {
        fprintf(g_out, "look-skipped|too-long\n");
        return;
    }
    look_access(path);
    look_stat(path);
    look_716c(path);
    look_714e(path);
}

static void flip_case(char *s)
{
    for (; *s; s++)
        *s = (char)(islower((unsigned char)*s) ? toupper((unsigned char)*s)
                                               : tolower((unsigned char)*s));
}

static void look_all(const char *folder, const char *source, const struct names *l,
                     const char *missing)
{
    char flipped[261];
    if (l->n == 0) return;
    look_one(folder, source, "first", l->v[0]);
    look_one(folder, source, "middle", l->v[l->n / 2]);
    look_one(folder, source, "last", l->v[l->n - 1]);
    look_one(folder, source, "missing", missing);
    snprintf(flipped, sizeof flipped, "%s", l->v[l->n / 2]);
    flip_case(flipped);
    look_one(folder, source, "case", flipped);
}

int main(int argc, char **argv)
{
    struct names n83 = {0}, nlong = {0};
    int sel, c4e, clfn;
    static char buf[1 << 16];

    if (argc != 3) {
        fprintf(stderr, "usage: LISTDUMP <folder> <output file>\n");
        return 2;
    }
    if (strlen(argv[1]) > 200) {
        fprintf(stderr, "folder path too long\n");
        return 2;
    }
    g_seg = (unsigned short)__dpmi_allocate_dos_memory(BLOCK_PARAS, &sel);
    if (g_seg == 0xFFFF) {
        fprintf(stderr, "no conventional memory\n");
        return 2;
    }
    g_block = (unsigned long)g_seg << 4;
    g_out = fopen(argv[2], "wb");
    if (!g_out) {
        perror(argv[2]);
        return 2;
    }
    setvbuf(g_out, buf, _IOFBF, sizeof buf);

    fprintf(g_out, "listdump|folder=%s|use_lfn=%d\n", argv[1], _use_lfn(argv[1]) ? 1 : 0);
    c4e = enum_4e(argv[1], &n83);
    clfn = enum_lfn(argv[1], &nlong);
    look_all(argv[1], "4e", &n83, "ZZNOFILE.ZZZ");
    look_all(argv[1], "lfn", &nlong, "no such file here.zzz");
    fprintf(g_out, "end|4e=%d|lfn=%d|look=%d\n", c4e, clfn, g_looks);
    if (fclose(g_out)) {
        perror(argv[2]);
        return 2;
    }
    return 0;
}
