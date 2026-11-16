/* TEMPLATE.EXE: the searches whose answer hangs on how a DOS keeps the eleven bytes of its search
 * template: a search for the volume label alone, a 4Eh for a quoted name whose name or
 * extension ends in a space, and the name an FCB holds after 11h.
 *
 *   usage: TEMPLATE <drive letter> <output file>          e.g. TEMPLATE D C:\TEMPLATE.TXT
 *
 * The volume is labelled DISK1 and its root holds the files template.sh's --help lists. In the
 * report V: stands for the drive, so that two volumes under two letters give lines to compare.
 *
 *   label|<path>|first=<4Eh's error, attribute 08h> <name found>|more=<entries 4Fh then returned>|,<name>...
 *   fcblabel|<11 characters>|al=<11h on an extended FCB, attribute 08h: 0 found>|more=<entries 12h then returned>
 *   quoted|<path>|first=<4Eh's error, attribute 37h> n=<entries>|,<name>...
 *   fcbname|<11 characters>|al=<11h on a plain FCB>|name=<the FCB's name bytes after it, in hex>|more=<entries 12h then returned>
 *   end|lines=<n>
 */
#include <dpmi.h>
#include <go32.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>
#include <sys/movedata.h>

#define BLOCK_PARAS 64
#define PATH_OFF 256
#define FCB_OFF 512
#define FOUND_NAME 30       /* where a DTA holds the name of the entry found */
#define MOST 20             /* no list here is longer; a search that never ends stops there */
#define COUNT(a) (sizeof (a) / sizeof (a)[0])

static unsigned long g_lin;
static unsigned short g_seg;
static char g_drive;
static FILE *g_out;
static int g_lines;

static void line(const char *format, ...)
{
    va_list ap;
    va_start(ap, format);
    vfprintf(g_out, format, ap);
    va_end(ap);
    fputc('\n', g_out);
    g_lines++;
}

/* The C library moves the DTA when it writes a file with long names off. */
static void set_dta(void)
{
    __dpmi_regs r;
    memset(&r, 0, sizeof r);
    r.h.ah = 0x1A; r.x.ds = g_seg; r.x.dx = 0;
    __dpmi_int(0x21, &r);
}

static int find_first(const char *path, int attr)
{
    __dpmi_regs r;
    char real[80];
    char *v;

    strcpy(real, path);
    v = strchr(real, 'V');
    if (v) *v = g_drive;
    set_dta();
    dosmemput(real, strlen(real) + 1, g_lin + PATH_OFF);
    memset(&r, 0, sizeof r);
    r.h.ah = 0x4E; r.x.cx = attr; r.x.ds = g_seg; r.x.dx = PATH_OFF;
    __dpmi_int(0x21, &r);
    return (r.x.flags & 1) ? r.x.ax : 0;
}

static int find_next(void)
{
    __dpmi_regs r;
    set_dta();
    memset(&r, 0, sizeof r);
    r.h.ah = 0x4F;
    __dpmi_int(0x21, &r);
    return (r.x.flags & 1) ? r.x.ax : 0;
}

static void found(char *name)
{
    dosmemget(g_lin + FOUND_NAME, 13, name);
    name[13] = 0;
}

/* 11h or 12h on the FCB at FCB_OFF: 0 when an entry was found. */
static int fcb_call(int ah)
{
    __dpmi_regs r;
    set_dta();
    memset(&r, 0, sizeof r);
    r.h.ah = ah; r.x.ds = g_seg; r.x.dx = FCB_OFF;
    __dpmi_int(0x21, &r);
    return r.h.al == 0 ? 0 : 1;
}

static int fcb_rest(void)
{
    int n = 0;
    while (n < MOST && fcb_call(0x12) == 0) n++;
    return n;
}

int main(int argc, char **argv)
{
    static const char *labels[] = { "V:\\", "V:", "V:\\*.*", "V:\\DISK1", "V:\\DISK", "V:\\DIS", "V:\\DISK1.*", "V:\\DISK*", "V:\\DISK1XYZ",
                                    "V:\\D?SK1", "V:\\DISK2", "V:\\disk1", "V:\\FOO.TXT", "V:\\FOO", "V:\\.TXT" };
    static const char *fcb_labels[] = { "???????????", "DISK1      ", "DISK       ", "DIS        ", "DISK1   XYZ", "D?SK1      ", "DISK2      ",
                                        "           ", "        TXT", "FOO     TXT" };
    static const char *quoted[] = { "\"V:\\FOO .TXT\"", "V:\\FOO.TXT", "\"V:\\PROGRAM FILES\"", "V:\\PROGRAM", "\"V:\\PROGRAM .TXT\"",
                                    "V:\\PROGRAM.TXT", "V:\\*.*" };
    static const char *fcb_names[] = { "FOO     TXT", "FOO        ", "foo     txt", "????????TXT", "NOSUCH  TXT" };
    static char list[1024];
    char name[14], hex[23];
    unsigned char fcb[44], after[11];
    int sel, s, n, err, al;
    unsigned i, k;

    if (argc != 3 || !argv[1][0] || argv[1][1]) { fprintf(stderr, "usage: TEMPLATE <drive letter> <output file>\n"); return 2; }
    g_drive = argv[1][0];
    if (g_drive >= 'a' && g_drive <= 'z') g_drive -= 32;
    if (g_drive < 'A' || g_drive > 'Z') { fprintf(stderr, "TEMPLATE: not a drive letter: %s\n", argv[1]); return 2; }
    s = __dpmi_allocate_dos_memory(BLOCK_PARAS, &sel);
    if (s == -1) { fprintf(stderr, "TEMPLATE: no conventional memory\n"); return 3; }
    g_seg = (unsigned short)s;
    g_lin = (unsigned long)g_seg << 4;
    g_out = fopen(argv[2], "w");
    if (!g_out) { fprintf(stderr, "TEMPLATE: cannot write %s\n", argv[2]); return 3; }

    for (i = 0; i < COUNT(labels); i++) {
        err = find_first(labels[i], 0x08);
        name[0] = 0; list[0] = 0; n = 0;
        if (!err) {
            found(name);
            while (n < MOST && find_next() == 0) {
                char more[14];
                found(more);
                strcat(list, ","); strcat(list, more);
                n++;
            }
        }
        line("label|%s|first=%d %s|more=%d|%s", labels[i], err, name, n, list);
    }
    for (i = 0; i < COUNT(fcb_labels); i++) {
        memset(fcb, 0, sizeof fcb);
        fcb[0] = 0xFF; fcb[6] = 0x08; fcb[7] = (unsigned char)(g_drive - 'A' + 1); memcpy(fcb + 8, fcb_labels[i], 11);
        dosmemput(fcb, sizeof fcb, g_lin + FCB_OFF);
        al = fcb_call(0x11);
        line("fcblabel|%s|al=%d|more=%d", fcb_labels[i], al, al == 0 ? fcb_rest() : 0);
    }
    for (i = 0; i < COUNT(quoted); i++) {
        err = find_first(quoted[i], 0x37);
        list[0] = 0; n = 0;
        while (!err && n < MOST) {
            found(name);
            strcat(list, ","); strcat(list, name);
            n++;
            err = find_next();
        }
        line("quoted|%s|first=%d n=%d|%s", quoted[i], n ? 0 : err, n, list);
    }
    for (i = 0; i < COUNT(fcb_names); i++) {
        memset(fcb, 0, sizeof fcb);
        fcb[0] = (unsigned char)(g_drive - 'A' + 1); memcpy(fcb + 1, fcb_names[i], 11);
        dosmemput(fcb, sizeof fcb, g_lin + FCB_OFF);
        al = fcb_call(0x11);
        dosmemget(g_lin + FCB_OFF + 1, sizeof after, after);
        for (k = 0; k < sizeof after; k++) sprintf(hex + 2 * k, "%02X", after[k]);
        line("fcbname|%s|al=%d|name=%s|more=%d", fcb_names[i], al, hex, al == 0 ? fcb_rest() : 0);
    }
    fprintf(g_out, "end|lines=%d\n", g_lines);
    fclose(g_out);
    return 0;
}
