/* ENUMSTAT.EXE: lists a folder while looking each entry up by its exact name, the way a program
 * that shows sizes or opens every file does, and counts what the listing returned.
 *
 *   usage: ENUMSTAT <mode> <folder> <output file>
 *
 *   mode  l  714Eh/714Fh enumeration of <folder>\*, libc stat() on every entry
 *         s  4Eh/4Fh enumeration of <folder>\*.*, libc stat() on every entry
 *         x  4Eh/4Fh enumeration, a raw 4Eh exact-name search on every entry (never continued)
 *         n  4Eh/4Fh enumeration alone: the count the others are judged against
 *
 * The enumeration goes through __dpmi_int with its own DTA and find record in a block of
 * conventional memory, parked between calls, so libc's own calls cannot touch it.
 */
#include <dpmi.h>
#include <go32.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/movedata.h>
#include <sys/stat.h>

#define BLOCK_PARAS 256
#define DTA_SIZE 64
#define DTA_ENUM 0
#define DTA_LOOK 1
#define DTA_PARK 3
#define FIND_OFF 2048
#define PATH_OFF 2400
#define SEARCH_ATTR 0x37

static unsigned long g_lin;
static unsigned short g_seg;

static int int21(__dpmi_regs *r) { __dpmi_int(0x21, r); return (r->x.flags & 1) ? r->x.ax : 0; }

static void set_dta(int dta)
{
    __dpmi_regs r;
    memset(&r, 0, sizeof r);
    r.h.ah = 0x1A; r.x.ds = g_seg; r.x.dx = (unsigned short)(dta * DTA_SIZE);
    __dpmi_int(0x21, &r);
}

static int first(int dta, const char *path)
{
    __dpmi_regs r;
    int err;
    set_dta(dta);
    dosmemput(path, strlen(path) + 1, g_lin + PATH_OFF);
    memset(&r, 0, sizeof r);
    r.h.ah = 0x4E; r.x.cx = SEARCH_ATTR; r.x.ds = g_seg; r.x.dx = PATH_OFF;
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

static int lfn_first(const char *path, int *handle)
{
    __dpmi_regs r;
    int err;
    dosmemput(path, strlen(path) + 1, g_lin + PATH_OFF);
    memset(&r, 0, sizeof r);
    r.x.ax = 0x714E; r.x.cx = SEARCH_ATTR; r.x.si = 1;
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

int main(int argc, char **argv)
{
    char pattern[300], full[600], name[261], last[261];
    struct stat st;
    int sel, s, err, handle = 0, listed = 0, found = 0;
    char mode;
    FILE *out;

    if (argc != 4) { fprintf(stderr, "usage: ENUMSTAT <l|s|x|n> <folder> <output file>\n"); return 2; }
    mode = argv[1][0];
    s = __dpmi_allocate_dos_memory(BLOCK_PARAS, &sel);
    if (s == -1) return 3;
    g_seg = (unsigned short)s;
    g_lin = (unsigned long)g_seg << 4;
    set_dta(DTA_PARK);
    last[0] = 0;

    if (mode == 'l') {
        sprintf(pattern, "%s\\*", argv[2]);
        err = lfn_first(pattern, &handle);
    } else {
        sprintf(pattern, "%s\\*.*", argv[2]);
        err = first(DTA_ENUM, pattern);
    }
    while (err == 0) {
        if (mode == 'l') dosmemget(g_lin + FIND_OFF + 44, 260, name);
        else dosmemget(g_lin + DTA_ENUM * DTA_SIZE + 30, 13, name);
        name[260] = 0;
        listed++;
        strcpy(last, name);
        if (name[0] != '.') {
            sprintf(full, "%s\\%s", argv[2], name);
            if (mode == 'l' || mode == 's') { if (stat(full, &st) == 0) found++; }
            else if (mode == 'x') { if (first(DTA_LOOK, full) == 0) found++; }
        }
        err = (mode == 'l') ? lfn_next(handle) : next(DTA_ENUM);
    }
    if (mode == 'l' && listed > 0) lfn_close(handle);

    out = fopen(argv[3], "w");
    if (!out) return 3;
    fprintf(out, "enumstat|mode=%c|listed=%d|looked_up_ok=%d|last=%s\nend\n", mode, listed, found, last);
    fclose(out);
    return 0;
}
