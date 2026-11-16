/* TIES.EXE: finds the 8.3 names that two entries of a folder share and writes what an exact-name
 * search for each returns, in the order returned.
 *
 *   usage: TIES <folder> <output file>
 *
 *   all|<n>|<long name>:<alias>:<size>,...      the folder whole, through 714Eh/714Fh
 *   tie|<alias>|lfn|<long name>:<size>,...      714Eh/714Fh for an alias two entries share
 *   tie|<alias>|4e|<name>:<size>,...            4Eh/4Fh for the same
 *   end|ties=<n>
 */
#include <dpmi.h>
#include <go32.h>
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
#define MAX_ENTRIES 400

static unsigned long g_lin;
static unsigned short g_seg;
static char g_alias[MAX_ENTRIES][14];

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

static void lfn_read(char *name, char *alias, unsigned long *size)
{
    dosmemget(g_lin + FIND_OFF + 32, 4, size);
    dosmemget(g_lin + FIND_OFF + 44, 260, name); name[260] = 0;
    dosmemget(g_lin + FIND_OFF + 304, 14, alias); alias[13] = 0;
    if (alias[0] == 0) { strncpy(alias, name, 13); alias[13] = 0; }
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

int main(int argc, char **argv)
{
    char path[400], name[261], alias[14], dta_name[13];
    unsigned long size;
    int sel, s, handle, n = 0, i, j, ties = 0;
    FILE *out;

    if (argc != 3) { fprintf(stderr, "usage: TIES <folder> <output file>\n"); return 2; }
    s = __dpmi_allocate_dos_memory(BLOCK_PARAS, &sel);
    if (s == -1) return 3;
    g_seg = (unsigned short)s;
    g_lin = (unsigned long)g_seg << 4;
    set_dta(PARK_OFF);
    out = fopen(argv[2], "w");
    if (!out) return 3;

    sprintf(path, "%s\\*", argv[1]);
    fprintf(out, "all|");
    if (lfn_first(path, &handle) == 0) {
        do {
            lfn_read(name, alias, &size);
            if (n < MAX_ENTRIES) strcpy(g_alias[n], alias);
            fprintf(out, "%s%s:%s:%lu", n ? "," : "", name, alias, size);
            n++;
        } while (lfn_next(handle) == 0);
        lfn_close(handle);
    }
    fprintf(out, "|n=%d\n", n);
    if (n > MAX_ENTRIES) n = MAX_ENTRIES;

    for (i = 0; i < n; i++) {
        for (j = 0; j < i; j++) if (strcmp(g_alias[i], g_alias[j]) == 0) break;
        if (j == i) continue;                       /* the first holder of this alias */
        for (j = j + 1; j < i; j++) if (strcmp(g_alias[i], g_alias[j]) == 0) break;
        if (j < i) continue;                        /* reported at its second holder already */
        ties++;
        sprintf(path, "%s\\%s", argv[1], g_alias[i]);
        fprintf(out, "tie|%s|lfn|", g_alias[i]);
        if (lfn_first(path, &handle) == 0) {
            j = 0;
            do { lfn_read(name, alias, &size); fprintf(out, "%s%s:%lu", j++ ? "," : "", name, size); } while (lfn_next(handle) == 0);
            lfn_close(handle);
        }
        fprintf(out, "\ntie|%s|4e|", g_alias[i]);
        if (dos_find(0x4E, path) == 0) {
            j = 0;
            do {
                dosmemget(g_lin + DTA_OFF + 30, 13, dta_name); dta_name[12] = 0;
                dosmemget(g_lin + DTA_OFF + 26, 4, &size);
                fprintf(out, "%s%s:%lu", j++ ? "," : "", dta_name, size);
            } while (dos_find(0x4F, NULL) == 0);
        }
        fprintf(out, "\n");
    }
    fprintf(out, "end|ties=%d\n", ties);
    fclose(out);
    return 0;
}
