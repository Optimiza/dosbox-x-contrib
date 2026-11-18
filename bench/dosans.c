/* DOSANS.EXE: what DOS answers around the names a search parses: a path that ends in a
 * backslash, a path that resolves to a directory itself, a name with a leading space, a
 * trailing dot or two dots, a name between quotes, the root listed, the volume label asked by
 * name, and a device found by a search. Each path shape is asked of 4Eh and of the calls that
 * parse the same path (open, get attributes, change directory), so a change to the parsing is
 * seen in every call it reaches. Written as text so the reports of two builds, or of a build
 * and a real DOS, can be compared line by line.
 *
 *   usage: DOSANS <folder> <output file>          e.g. DOSANS D:\X C:\DOSANS.TXT
 *
 * <folder> is the fixture exact.sh makes on D:, named for the usage line only. One line per case:
 *
 *   ans|<case>|<attr>|<path>|<cwd>|err=<first call's error>|n=<entries>|,<name>:<attr>:<size>...
 *   call|<3D, 43, 4301 or 3B>|<path>|err=<error>
 *   dta|<path>|err=<error>|<the 21 bytes a search keeps, hex>|<the 13 name bytes, hex>
 *   dev|<path>|err=<error>|size=<hex>|<the 21 bytes a search keeps, hex>
 *   chain|<n>|<the device's eight name bytes>|<attribute, hex>|<segment of its header, hex>
 *   end|lines=<n>
 *
 * The chain lines name where that DOS keeps each device's header: a DOS's own address, which
 * no other DOS shares. No long-name call is made.
 */
#include <dpmi.h>
#include <go32.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/movedata.h>

#define BLOCK_PARAS 256
#define DTA_OFF 0
#define PATH_OFF 2400
#define SHOWN 40
#define CHAIN_MAX 40

static unsigned long g_lin;
static unsigned short g_seg;
static FILE *g_out;
static int g_lines;
static const char *g_cwd = "D:\\";

static void put_path(const char *path) { dosmemput(path, strlen(path) + 1, g_lin + PATH_OFF); }

static void line(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    vfprintf(g_out, fmt, ap);
    va_end(ap);
    fputc('\n', g_out);
    g_lines++;
}

/* One call that takes DS:DX = a path; returns its error, 0 for none, and leaves AX in *ax. */
static int path_call(int ah, int cx, const char *path, int *ax)
{
    __dpmi_regs r;
    put_path(path);
    memset(&r, 0, sizeof r);
    r.h.ah = (unsigned char)ah; r.x.cx = (unsigned short)cx;
    r.x.ds = g_seg; r.x.dx = PATH_OFF;
    __dpmi_int(0x21, &r);
    if (ax) *ax = r.x.ax;
    return (r.x.flags & 1) ? r.x.ax : 0;
}

static void set_dta(void)
{
    __dpmi_regs r;
    memset(&r, 0, sizeof r);
    r.h.ah = 0x1A; r.x.ds = g_seg; r.x.dx = DTA_OFF;
    __dpmi_int(0x21, &r);
}

static void hex(char *text, unsigned long at, int len)
{
    unsigned char b[64];
    int i;
    dosmemget(at, len, b);
    for (i = 0; i < len; i++) sprintf(text + 2 * i, "%02X", b[i]);
}

static void entry(char *text)
{
    char name[13];
    unsigned char attr;
    unsigned long size;
    dosmemget(g_lin + DTA_OFF + 30, 13, name); name[12] = 0;
    dosmemget(g_lin + DTA_OFF + 21, 1, &attr);
    dosmemget(g_lin + DTA_OFF + 26, 4, &size);
    sprintf(text, "%s:%02X:%lu", name, attr, size);
}

static void ans(const char *name, int attr, const char *path)
{
    static char list[(SHOWN + 1) * 64];
    char text[64];
    __dpmi_regs r;
    int err, n = 0;
    list[0] = 0;
    set_dta();
    err = path_call(0x4E, attr, path, NULL);
    if (err == 0) {
        do {
            if (n < SHOWN) { entry(text); strcat(list, ","); strcat(list, text); }
            n++;
            memset(&r, 0, sizeof r);
            r.h.ah = 0x4F;
            __dpmi_int(0x21, &r);
        } while (!(r.x.flags & 1) && n < 200);
    }
    line("ans|%s|%02X|%s|%s|err=%d|n=%d|%s", name, attr, path, g_cwd, err, n, list);
}

/* The search's own bytes and the name bytes after one 4Eh. */
static void dta_case(const char *path)
{
    char search[64], name[64];
    int err;
    set_dta();
    dosmemput("\xEE\xEE\xEE\xEE\xEE\xEE\xEE\xEE\xEE\xEE\xEE\xEE\xEE", 13, g_lin + DTA_OFF + 30);
    err = path_call(0x4E, 0x37, path, NULL);
    hex(search, g_lin + DTA_OFF, 21);
    hex(name, g_lin + DTA_OFF + 30, 13);
    line("dta|%s|err=%d|%s|%s", path, err, search, name);
}

static void dev_case(const char *path)
{
    char search[64];
    unsigned long size = 0;
    int err;
    set_dta();
    err = path_call(0x4E, 0x37, path, NULL);
    if (err == 0) dosmemget(g_lin + DTA_OFF + 26, 4, &size);
    hex(search, g_lin + DTA_OFF, 21);
    line("dev|%s|err=%d|size=%lX|%s", path, err, size, search);
}

/* 3Dh opens and closes, 43h (AL=0) reads the attribute, 3Bh enters and comes back to the
 * current directory. */
static void call_case(int ah, const char *path)
{
    __dpmi_regs r;
    int ax, err = path_call(ah, 0, path, &ax);
    if (err == 0 && ah == 0x3D) {
        memset(&r, 0, sizeof r);
        r.h.ah = 0x3E; r.x.bx = (unsigned short)ax;
        __dpmi_int(0x21, &r);
    }
    if (err == 0 && ah == 0x3B) path_call(0x3B, 0, g_cwd, NULL);
    line("call|%02X|%s|err=%d", ah, path, err);
}

/* 43h with AL=1 writes back the attribute AL=0 read (read-only, hidden, system and archive
 * only), or archive alone where the read failed: the path is parsed as for a change, and a file
 * that exists keeps its attribute. */
static void setattr_case(const char *path)
{
    __dpmi_regs r;
    int ax, cx, err = path_call(0x43, 0, path, &ax);
    cx = err == 0 ? (ax & 0x27) : 0x20;
    put_path(path);
    memset(&r, 0, sizeof r);
    r.x.ax = 0x4301; r.x.cx = (unsigned short)cx;
    r.x.ds = g_seg; r.x.dx = PATH_OFF;
    __dpmi_int(0x21, &r);
    err = (r.x.flags & 1) ? r.x.ax : 0;
    line("call|4301|%s|err=%d", path, err);
}

/* Every call that parses a path, on one path */
static void calls(const char *path)
{
    call_case(0x3D, path);
    call_case(0x43, path);
    setattr_case(path);
    call_case(0x3B, path);
}

/* A device found through the DTA of a search in progress, then 4Fh: what that DTA goes on with */
static void devnext_case(const char *dev)
{
    __dpmi_regs r;
    char text[64];
    int first, err, next;
    set_dta();
    first = path_call(0x4E, 0x37, "D:\\X\\*.*", NULL);
    memset(&r, 0, sizeof r);
    r.h.ah = 0x4F;
    __dpmi_int(0x21, &r);
    err = path_call(0x4E, 0x37, dev, NULL);
    memset(&r, 0, sizeof r);
    r.h.ah = 0x4F;
    __dpmi_int(0x21, &r);
    next = (r.x.flags & 1) ? r.x.ax : 0;
    text[0] = 0;
    if (next == 0) entry(text);
    line("devnext|%s|first=%d dev=%d next=%d|%s", dev, first, err, next, text);
}

/* An FCB name with a space inside it: made by 16h, opened by 0Fh, sized by 23h, found by 11h
 * and by 4Eh, removed by 13h */
static void fcbspace_case(const char *name11, const char *pattern)
{
    __dpmi_regs r;
    unsigned char fcb[37];
    char found[12], list[256], text[64];
    int made, opened, sized, search, err, n = 0;
    memset(fcb, 0, sizeof fcb);
    memcpy(fcb + 1, name11, 11);
    dosmemput(fcb, sizeof fcb, g_lin + PATH_OFF);
    memset(&r, 0, sizeof r);
    r.h.ah = 0x16; r.x.ds = g_seg; r.x.dx = PATH_OFF;
    __dpmi_int(0x21, &r);
    made = r.h.al;
    if (made == 0) {
        memset(&r, 0, sizeof r);
        r.h.ah = 0x10; r.x.ds = g_seg; r.x.dx = PATH_OFF;
        __dpmi_int(0x21, &r);
    }
    dosmemput(fcb, sizeof fcb, g_lin + PATH_OFF);
    memset(&r, 0, sizeof r);
    r.h.ah = 0x0F; r.x.ds = g_seg; r.x.dx = PATH_OFF;
    __dpmi_int(0x21, &r);
    opened = r.h.al;
    if (opened == 0) {
        memset(&r, 0, sizeof r);
        r.h.ah = 0x10; r.x.ds = g_seg; r.x.dx = PATH_OFF;
        __dpmi_int(0x21, &r);
    }
    dosmemput(fcb, sizeof fcb, g_lin + PATH_OFF);
    memset(&r, 0, sizeof r);
    r.h.ah = 0x23; r.x.ds = g_seg; r.x.dx = PATH_OFF;
    __dpmi_int(0x21, &r);
    sized = r.h.al;
    set_dta();
    dosmemput(fcb, sizeof fcb, g_lin + PATH_OFF);
    memset(&r, 0, sizeof r);
    r.h.ah = 0x11; r.x.ds = g_seg; r.x.dx = PATH_OFF;
    __dpmi_int(0x21, &r);
    search = r.h.al;
    found[0] = 0;
    if (search == 0) { dosmemget(g_lin + DTA_OFF + 1, 11, found); found[11] = 0; }
    list[0] = 0;
    set_dta();
    err = path_call(0x4E, 0x37, pattern, NULL);
    if (err == 0) {
        do {
            entry(text); strcat(list, ","); strcat(list, text);
            n++;
            memset(&r, 0, sizeof r);
            r.h.ah = 0x4F;
            __dpmi_int(0x21, &r);
        } while (!(r.x.flags & 1) && n < 8);
    }
    dosmemput(fcb, sizeof fcb, g_lin + PATH_OFF);
    memset(&r, 0, sizeof r);
    r.h.ah = 0x13; r.x.ds = g_seg; r.x.dx = PATH_OFF;
    __dpmi_int(0x21, &r);
    line("fcbspace|%s|made=%d opened=%d sized=%d found=%d|%s|4e=%d n=%d|%s|deleted=%d", name11, made,
         opened, sized, search, found, err, n, list, r.h.al);
}

static void cd(const char *dir)
{
    path_call(0x3B, 0, dir, NULL);
    g_cwd = dir;
}

/* The device chain from NUL, which sits in the list of lists at +22h. */
static void chain(void)
{
    __dpmi_regs r;
    unsigned short seg, off;
    unsigned char header[18];
    char name[9];
    int n;
    memset(&r, 0, sizeof r);
    r.h.ah = 0x52;
    __dpmi_int(0x21, &r);
    seg = r.x.es; off = (unsigned short)(r.x.bx + 0x22);
    for (n = 0; n < CHAIN_MAX && off != 0xFFFF; n++) {
        dosmemget(((unsigned long)seg << 4) + off, sizeof header, header);
        memcpy(name, header + 10, 8); name[8] = 0;
        line("chain|%d|%s|%04X|%04X", n, name, header[4] | (header[5] << 8), seg);
        off = (unsigned short)(header[0] | (header[1] << 8));
        seg = (unsigned short)(header[2] | (header[3] << 8));
    }
}

static const char *const SHAPES[] = {
    "D:\\X\\", "D:\\X\\FOO.TXT\\", "D:\\X\\SUBDIR\\", "D:\\NOSUCH\\", "D:\\",
    "D:\\X\\..", "D:\\X\\.", "D:\\X\\SUBDIR\\..", "D:\\X\\...", "D:\\X\\....\\FOO.TXT",
    "D:\\X\\FOO.TXT", "D:\\X\\FOO.TXT.", "D:\\X\\FOO.", "D:\\X\\NOEXT.", "D:\\X\\A.B.", "D:\\X\\A.B..",
    "D:\\X\\Two.dots.name.txt", "D:\\X.Y.Z\\FOO.TXT", "D:\\X\\SUBDIR.\\INNER.TXT", "D:\\X\\.TXT",
    "D:\\X\\ FOO.TXT", "D:\\ X\\FOO.TXT", "D:\\X\\FOO .TXT", "D:\\X\\FOO.TXT ", "D:\\X\\FOO. TXT",
    "\"D:\\X\\FOO.TXT\"", "D:\\X\\\"FOO.TXT\"", "D:\\X\\FOO.TXT\\..",
    "D:\\X\\NOEXT. ", "D:\\X\\SUBDIR. \\INNER.TXT", "D:\\X\\FOO.T X", "D:\\X\\..\\", "D:\\.\\",
    "D:/X/FOO.TXT", "D:\\X/SUBDIR/INNER.TXT",
};

/* A space inside a name, a character no 8.3 name holds, a wildcard, a name longer than its
 * field, a device, an empty name and a climb, asked of the path calls only */
static const char *const CALL_SHAPES[] = {
    "", "D:", "D:.", ".", "..", "D:\\..", "D:\\X\\..\\..", "D:\\X\\\\FOO.TXT", "\\",
    "D:\\X\\F OO.TXT", "D:\\X\\FOO.T XT", "D:\\X\\FOO.TX T", "D:\\X\\SUB DIR\\INNER.TXT",
    "D:\\X\\SUBDIR \\INNER.TXT", "D:\\X\\SUBDIR\\ INNER.TXT", "D:\\X\\SUBDIR ", "D:\\X\\SUBDIR.",
    "D:\\X\\A+B.TXT", "D:\\X\\A,B.TXT", "D:\\X\\A;B.TXT", "D:\\X\\A=B.TXT", "D:\\X\\A[B.TXT",
    "D:\\X\\A]B.TXT", "D:\\X\\A|B.TXT", "D:\\X\\A<B.TXT", "D:\\X\\A>B.TXT", "D:\\X\\A:B.TXT",
    "D:\\X+\\FOO.TXT", "D:\\X;\\FOO.TXT", "D:\\X\\FOO.T+T",
    "D:\\X\\*.TXT", "D:\\X\\FOO.T?T", "D:\\X?\\FOO.TXT", "D:\\*\\FOO.TXT",
    "D:\\X\\ALPHAT~1XYZ.MID", "D:\\X\\FOO.TXTX", "D:\\X\\SUBDIR.XYZW\\INNER.TXT",
    "NUL", "D:\\X\\NUL", "NUL.TXT", "NUL:", "CON:", "D:\\NOSUCH\\NUL", "D:\\X\\NUL\\FOO",
    "D:\\X\\NUL\\", "D:\\X\\FOO.TXT\\.", "D:\\X\\SUBDIR\\.", "D:\\X\\SUBDIR\\..\\FOO.TXT",
    "D:\\X\\.\\FOO.TXT", "D:\\X\\..\\X\\FOO.TXT", "D:\\NOSUCH\\FOO.TXT", "D:\\X\\NOSUCH\\FOO.TXT",
    "D:\\X\\FOO.TXT\\BAR.TXT", "Q:\\FOO.TXT", "Q:",
    " D:\\X\\FOO.TXT", "D: \\X\\FOO.TXT", "D:\\X\\.\\", "D:\\X\\FOO     X.TXT", "D:\\X\\FOO.TXT  X",
    "D:\\X\\SUBDIR\\..\\..\\..", "D:\\X\\FOO.TXT\\..\\BAR.TXT", "D:\\X\\NUL.TXT\\", "D:\\X\\CON\\FOO",
    "D:\\NOSUCH\\CON", "D:\\X\\FOO..TXT", "D:\\X\\SUBDIR\\...\\", "D:\\X\\FOO.TXT:", "\\X\\FOO.TXT",
    "D:X\\FOO.TXT", "d:\\x\\foo.txt", "D:\\X\\SUBDIR\\INNER.TXT\\.", "D:\\X\\ \\FOO.TXT",
    "D:\\X\\NOSUCH\\.", "D:\\X\\NOSUCH\\SUB\\..", "D:\\X\\MISSING.TXT\\.", "D:/NOSUCH/FOO.TXT",
    "D:\\NOSUCH/FOO.TXT", "\\DEV\\NUL", "\\DEV\\CON", "D:\\DEV\\CON", "D:\\X\\SUBDIR\\. ",
    "D:\\X\\SUBDIR\\.. ", "D:\\X\\. \\FOO.TXT", "D:\\X\\.. \\FOO.TXT",
    "D:\\NOSUCH\\F OO.TXT", "D:\\X\\FOO.TXT\\F OO.TXT", "D:\\NOSUCH\\A+B.TXT", "D:\\NOSUCH\\FOO.T?T",
    "D:\\X\\NUL\\.", "D:\\X\\CON\\.", "D:\\X\\..\\DEV\\NUL", "DEV\\NUL", "D:\\X\\..\\DEV\\CON",
};

static const char *const CALL_SHAPES_X[] = {
    "..", "..\\", "..\\..", "..\\FOO.TXT", ".\\FOO.TXT", "FOO.TXT", "FOO.TXT\\", "SUBDIR\\",
    "SUBDIR", "SUBDIR\\..\\FOO.TXT", "...\\FOO.TXT", "D:FOO.TXT", "D:..\\FOO.TXT", "D:SUBDIR",
    " FOO.TXT", "\"FOO.TXT\"",
};

int main(int argc, char **argv)
{
    __dpmi_regs r;
    int s, sel, i;

    if (argc != 3) { fprintf(stderr, "usage: DOSANS <folder> <output file>\n"); return 2; }
    s = __dpmi_allocate_dos_memory(BLOCK_PARAS, &sel);
    if (s == -1) { fprintf(stderr, "DOSANS: no conventional memory\n"); return 3; }
    g_seg = (unsigned short)s;
    g_lin = (unsigned long)g_seg << 4;
    g_out = fopen(argv[2], "w");
    if (!g_out) { fprintf(stderr, "DOSANS: cannot write %s\n", argv[2]); return 3; }

    /* D: is the default drive from here on, its current directory the root. */
    memset(&r, 0, sizeof r);
    r.h.ah = 0x0E; r.h.dl = 3;
    __dpmi_int(0x21, &r);
    cd("D:\\");

    /* Every path shape through each call that parses it */
    for (i = 0; i < (int)(sizeof SHAPES / sizeof SHAPES[0]); i++) {
        ans("shape", 0x37, SHAPES[i]);
        ans("shape", 0x00, SHAPES[i]);
        calls(SHAPES[i]);
    }

    /* Shapes asked of the path calls only, from the root and from D:\X */
    for (i = 0; i < (int)(sizeof CALL_SHAPES / sizeof CALL_SHAPES[0]); i++) calls(CALL_SHAPES[i]);
    cd("D:\\X");
    for (i = 0; i < (int)(sizeof CALL_SHAPES_X / sizeof CALL_SHAPES_X[0]); i++) calls(CALL_SHAPES_X[i]);
    cd("D:\\");

    /* A path that ends in a backslash, by attribute */
    ans("trail", 0x10, "D:\\X\\");
    ans("trail", 0x08, "D:\\X\\");
    ans("trail", 0x37, "X\\");
    ans("trail", 0x37, "D:\\X\\*.*\\");
    ans("trail", 0x10, "D:\\");
    ans("trail", 0x08, "D:\\");
    ans("trail", 0x3F, "D:\\");
    ans("trail", 0x37, "\\");
    ans("trail", 0x37, "D:\\\\");
    ans("trail", 0x37, "D:\\X\\\\FOO.TXT");

    /* A path that resolves to a directory itself, the root above all */
    ans("dots", 0x10, "D:\\X\\..");
    ans("dots", 0x08, "D:\\X\\..");
    ans("dots", 0x3F, "D:\\X\\..");
    ans("dots", 0x37, "D:\\.");
    ans("dots", 0x37, "D:\\..");
    ans("dots", 0x37, "D:\\X\\SUBDIR\\..\\..");
    ans("dots", 0x37, "D:\\X\\.\\..");
    ans("dots", 0x37, "D:");
    ans("dots", 0x37, "D:.");
    ans("dots", 0x37, ".");
    ans("dots", 0x37, "..");
    cd("D:\\X");
    ans("dots", 0x37, "D:");
    ans("dots", 0x37, ".");
    ans("dots", 0x37, "..");
    ans("dots", 0x37, "SUBDIR\\..");
    ans("dots", 0x37, "..\\X\\FOO.TXT");
    ans("dots", 0x37, "..\\");
    cd("D:\\");

    /* The root listed */
    ans("root", 0x37, "D:\\*.*");
    ans("root", 0x10, "D:\\*.*");
    ans("root", 0x3F, "D:\\????????.???");
    ans("root", 0x3F, "D:\\*");
    ans("root", 0x37, "\\*.*");
    ans("root", 0x37, "D:*.*");
    ans("root", 0x3F, "D:\\X\\*.*");

    /* The label asked by name */
    ans("label", 0x08, "D:\\*.*");
    ans("label", 0x08, "D:\\FPLABEL");
    ans("label", 0x08, "D:\\FPLAB*");
    ans("label", 0x08, "D:\\FPLABEL.*");
    ans("label", 0x08, "D:\\FPL");
    ans("label", 0x08, "D:\\FPLABELX");
    ans("label", 0x08, "D:\\FOO.TXT");
    ans("label", 0x08, "D:\\X\\*.*");
    ans("label", 0x08, "D:\\X\\FPLABEL");
    ans("label", 0x08, "D:\\NOSUCH\\*.*");
    ans("label", 0x08, "D:*.*");
    ans("label", 0x08, "D:");
    ans("label", 0x08, "D:\\.TXT");
    ans("label", 0x08, "D:\\.");
    ans("label", 0x3F, "D:\\FPLABEL");
    ans("label", 0x3F, "D:\\FPL*");
    ans("label", 0x08, "D:\\X\\.");
    ans("label", 0x08, "D:\\X\\SUBDIR\\.");
    ans("label", 0x08, "D:\\X\\..");
    ans("label", 0x08, "D:/X/FPLABEL");
    ans("label", 0x08, "D:/FPLABEL");
    ans("label", 0x08, "D:\\X\\..\\FPLABEL");
    ans("label", 0x18, "D:\\*.*");
    ans("label", 0x09, "D:\\*.*");

    /* What a search keeps in the DTA, and the name bytes it writes */
    dta_case("D:\\X\\*.*");
    dta_case("D:\\X\\NOEXT");
    dta_case("D:\\X\\A.B");
    dta_case("D:\\X\\FOO.TXT");
    dta_case("D:\\X\\SUBDIR");
    dta_case("D:\\*.*");

    /* A device found by a search, and where each device's header lies */
    dev_case("D:\\X\\NUL");
    dev_case("NUL");
    dev_case("D:\\X\\CON");
    dev_case("CON.TXT");
    dev_case("D:\\X\\PRN.TXT");
    dev_case("AUX");
    dev_case("CLOCK$");
    dev_case("D:\\NOSUCH\\NUL");
    dev_case("D:\\X\\NUL\\FOO");
    devnext_case("D:\\X\\NUL");
    devnext_case("D:\\X\\CON");

    /* A name with a space inside, which only an FCB call can make */
    fcbspace_case("A B     TXT", "D:\\A?B.TXT");
    fcbspace_case("AB CDEFGTXT", "D:\\AB?CDEFG.TXT");
    fcbspace_case("ABC     T X", "D:\\ABC.T?X");
    chain();

    line("end|lines=%d", g_lines);
    fclose(g_out);
    return 0;
}
