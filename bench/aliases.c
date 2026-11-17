/* ALIASES.EXE: lists a folder both ways, then reaches every entry by each name it was listed
 * under, so that the host, which knows each file's size, can tell whether a name leads to the
 * file it was listed for.
 *
 *   usage: ALIASES <folder> <output file> [list]
 *          with a third word, the listing alone: 714Eh/714Fh, or 4Eh/4Fh where the long-name
 *          call is refused
 *
 *   lfn|<long name>|<alias>|<attr>|<size>     every entry of 714Eh/714Fh; lfn|none|err=<n> when
 *                                             the call is refused (long names off)
 *   sfn|<name>|<attr>|<size>                  every entry of 4Eh/4Fh
 *   find|<short name>|n=<k>|<name:attr:size>,...
 *                                             4Eh/4Fh for each distinct short name listed
 *   open|<short name>|<size or err=<n>>       3Dh on it, the size by 4202h
 *   lopen|<long name>|<size or err=<n>>       716Ch on each long name listed that is a file
 *   end|lines=<n>                             the lines above it
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
#define PARK_OFF 128
#define FIND_OFF 2048
#define PATH_OFF 2400
#define ALL 0x37
#define MAX_ENTRIES 300

static unsigned long g_lin;
static unsigned short g_seg;
static FILE *g_out;
static long g_lines;
static char g_long[MAX_ENTRIES][80];
static char g_alias[MAX_ENTRIES][14];
static unsigned char g_lattr[MAX_ENTRIES];
static char g_short[MAX_ENTRIES][14];
static char g_names[2 * MAX_ENTRIES][14];

static void line(const char *fmt, ...) __attribute__((format(printf, 1, 2)));
static void line(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    vfprintf(g_out, fmt, ap);
    va_end(ap);
    fputc('\n', g_out);
    g_lines++;
}

static int int21(__dpmi_regs *r) { __dpmi_int(0x21, r); return (r->x.flags & 1) ? r->x.ax : 0; }

static void set_dta(int off)
{
    __dpmi_regs r;
    memset(&r, 0, sizeof r);
    r.h.ah = 0x1A; r.x.ds = g_seg; r.x.dx = (unsigned short)off;
    __dpmi_int(0x21, &r);
}

static int lfn_first(const char *path, int *handle)
{
    __dpmi_regs r;
    int err;
    dosmemput(path, strlen(path) + 1, g_lin + PATH_OFF);
    memset(&r, 0, sizeof r);
    r.x.ax = 0x714E; r.x.cx = ALL; r.x.si = 1;
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

/* A long-name entry whose alias field is empty has a long name that is its own 8.3 name. */
static void lfn_read(char *name, char *alias, unsigned long *attr, unsigned long *size)
{
    dosmemget(g_lin + FIND_OFF, 4, attr);
    dosmemget(g_lin + FIND_OFF + 32, 4, size);
    dosmemget(g_lin + FIND_OFF + 44, 260, name); name[260] = 0;
    dosmemget(g_lin + FIND_OFF + 304, 14, alias); alias[13] = 0;
    if (alias[0] == 0) { memcpy(alias, name, 13); alias[13] = 0; }
}

static int dos_find(int function, const char *path)
{
    __dpmi_regs r;
    int err;
    set_dta(DTA_OFF);
    memset(&r, 0, sizeof r);
    r.h.ah = (unsigned char)function;
    if (path) { dosmemput(path, strlen(path) + 1, g_lin + PATH_OFF); r.x.cx = ALL; r.x.ds = g_seg; r.x.dx = PATH_OFF; }
    err = int21(&r);
    set_dta(PARK_OFF);
    return err;
}

static void dta_read(char *name, unsigned char *attr, unsigned long *size)
{
    dosmemget(g_lin + DTA_OFF + 21, 1, attr);
    dosmemget(g_lin + DTA_OFF + 26, 4, size);
    dosmemget(g_lin + DTA_OFF + 30, 13, name); name[12] = 0;
}

/* The size of an open handle, or -1; the handle is closed. */
static long handle_size(int handle)
{
    __dpmi_regs r;
    long size = -1;
    memset(&r, 0, sizeof r);
    r.x.ax = 0x4202; r.x.bx = (unsigned short)handle;
    if (int21(&r) == 0) size = ((long)r.x.dx << 16) | r.x.ax;
    memset(&r, 0, sizeof r);
    r.h.ah = 0x3E; r.x.bx = (unsigned short)handle;
    __dpmi_int(0x21, &r);
    return size;
}

static void print_open(const char *tag, const char *name, const char *path, int lfn)
{
    __dpmi_regs r;
    int err;
    dosmemput(path, strlen(path) + 1, g_lin + PATH_OFF);
    memset(&r, 0, sizeof r);
    r.x.ds = g_seg;
    if (lfn) { r.x.ax = 0x716C; r.x.bx = 0; r.x.cx = 0; r.x.dx = 1; r.x.si = PATH_OFF; }
    else { r.x.ax = 0x3D00; r.x.dx = PATH_OFF; }
    r.x.flags = 1;
    err = int21(&r);
    if (err) line("%s|%s|err=%d", tag, name, err);
    else line("%s|%s|%ld", tag, name, handle_size(r.x.ax));
}

static int short_listing(const char *folder, int keep)
{
    char path[400], dta_name[13];
    unsigned long size;
    unsigned char battr;
    int ns = 0;
    snprintf(path, sizeof path, "%s\\*.*", folder);
    if (dos_find(0x4E, path) == 0) {
        do {
            dta_read(dta_name, &battr, &size);
            line("sfn|%s|%02x|%lu", dta_name, battr, size);
            if (keep && ns < MAX_ENTRIES) strcpy(g_short[ns++], dta_name);
        } while (dos_find(0x4F, NULL) == 0);
    }
    return ns;
}

int main(int argc, char **argv)
{
    char path[400], name[261], alias[14], dta_name[13];
    unsigned long attr, size;
    unsigned char battr;
    int sel, s, handle, nl = 0, ns, nn = 0, i, j, k, err, listing = argc == 4;

    if (argc != 3 && argc != 4) { fprintf(stderr, "usage: ALIASES <folder> <output file> [list]\n"); return 2; }
    s = __dpmi_allocate_dos_memory(BLOCK_PARAS, &sel);
    if (s == -1) return 3;
    g_seg = (unsigned short)s;
    g_lin = (unsigned long)g_seg << 4;
    set_dta(PARK_OFF);
    g_out = fopen(argv[2], "w");
    if (!g_out) return 3;

    snprintf(path, sizeof path, "%s\\*", argv[1]);
    err = lfn_first(path, &handle);
    if (err) line("lfn|none|err=%d", err);
    else {
        do {
            lfn_read(name, alias, &attr, &size);
            line("lfn|%s|%s|%02lx|%lu", name, alias, attr & 0xff, size);
            if (!listing && nl < MAX_ENTRIES && strlen(name) < sizeof g_long[0]) {
                strcpy(g_long[nl], name); strcpy(g_alias[nl], alias); g_lattr[nl] = (unsigned char)attr; nl++;
            }
        } while (lfn_next(handle) == 0);
        lfn_close(handle);
    }

    if (listing) {
        if (err) short_listing(argv[1], 0);
        line("end|lines=%ld", g_lines);
        fclose(g_out);
        return 0;
    }
    ns = short_listing(argv[1], 1);

    /* Every distinct short name either listing showed. */
    for (i = 0; i < nl + ns; i++) {
        const char *n = i < nl ? g_alias[i] : g_short[i - nl];
        if (strcmp(n, ".") == 0 || strcmp(n, "..") == 0) continue;
        for (j = 0; j < nn; j++) if (strcmp(g_names[j], n) == 0) break;
        if (j == nn) strcpy(g_names[nn++], n);
    }
    for (i = 0; i < nn; i++) {
        char found[2048];
        size_t used = 0;
        snprintf(path, sizeof path, "%s\\%.13s", argv[1], g_names[i]);
        k = 0;
        found[0] = 0;
        if (dos_find(0x4E, path) == 0) {
            do {
                dta_read(dta_name, &battr, &size);
                if (used < sizeof found - 40)
                    used += (size_t)snprintf(found + used, sizeof found - used, "%s%s:%02x:%lu", k ? "," : "", dta_name, battr, size);
                k++;
            } while (dos_find(0x4F, NULL) == 0);
        }
        line("find|%s|n=%d|%s", g_names[i], k, found);
        print_open("open", g_names[i], path, 0);
    }
    for (i = 0; i < nl; i++) {
        if (strcmp(g_long[i], ".") == 0 || strcmp(g_long[i], "..") == 0) continue;
        if (g_lattr[i] & 0x10) continue;
        snprintf(path, sizeof path, "%s\\%.79s", argv[1], g_long[i]);
        print_open("lopen", g_long[i], path, 1);
    }
    line("end|lines=%ld", g_lines);
    fclose(g_out);
    return 0;
}
