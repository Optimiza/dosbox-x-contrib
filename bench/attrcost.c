/* ATTRCOST.EXE: what a program pays after it changes a file's attribute, deletes or creates a
 * file: the probe makes the calls, and the emulator's own count of its host reads says the cost.
 *
 *   usage: ATTRCOST <mode> <folder> <K> <output file>       e.g. ATTRCOST s D:\MIDI 10 C:\COST.TXT
 *
 *   mode  b  the baseline every mode starts with: the folder searched (4Eh *.*, K+2 entries read)
 *            and searched again
 *         s  then K times: 4301h on one file of the folder (its attribute set to what it is,
 *            archive), then a 4Eh for another file's exact name
 *         m  then K times: libc remove() of a file made for it (4301h, then 41h), then the 4Eh
 *         u  then K times: 41h alone on a file made for it, then the 4Eh
 *         c  then K times: a file created and closed (3Ch, 3Eh), then the 4Eh; removed at the end
 *
 * The K files of m and u are made before the baseline. Lines:
 *   cost|baseline|names=<n>
 *   cost|loop|mode=<m> k=<K> done=<calls that answered 0> found=<4Eh that answered 0> guest_us=<n>
 *   end|lines=<n>
 */
#include <dpmi.h>
#include <go32.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/movedata.h>
#include <time.h>
#include <unistd.h>

#define MAX_K 2000
#define ALL 0x37

static char g_names[MAX_K + 2][13];
static const char *g_folder;

static int int21(__dpmi_regs *r) { __dpmi_int(0x21, r); return (r->x.flags & 1) ? r->x.ax : 0; }

static void set_dta(void)
{
    __dpmi_regs r;
    memset(&r, 0, sizeof r);
    r.h.ah = 0x1A; r.x.ds = (unsigned short)((__tb + 1024) >> 4); r.x.dx = (unsigned short)((__tb + 1024) & 15);
    __dpmi_int(0x21, &r);
}

static int path_call(int ax, int cx, const char *name)
{
    char path[400];
    __dpmi_regs r;
    sprintf(path, "%s\\%s", g_folder, name);
    dosmemput(path, strlen(path) + 1, __tb);
    memset(&r, 0, sizeof r);
    r.x.ax = (unsigned short)ax; r.x.cx = (unsigned short)cx;
    r.x.ds = (unsigned short)(__tb >> 4); r.x.dx = (unsigned short)(__tb & 15);
    return int21(&r);
}

static int next(void)
{
    __dpmi_regs r;
    memset(&r, 0, sizeof r);
    r.h.ah = 0x4F;
    return int21(&r);
}

static void dta_entry(char *name, int *attr)
{
    unsigned char dta[43];
    dosmemget(__tb + 1024, 43, dta);
    *attr = dta[21];
    memcpy(name, dta + 30, 13); name[12] = 0;
}

/* The folder searched, the first <want> plain files' names kept; the search is left there. */
static int baseline(int want)
{
    int n = 0, attr;
    char name[13];
    if (path_call(0x4E00, ALL, "*.*") != 0) return 0;
    do {
        dta_entry(name, &attr);
        if (!(attr & 0x18) && strncmp(name, "ZZ4R", 4) != 0) strcpy(g_names[n++], name);
    } while (n < want && next() == 0);
    return n;
}

static void made_name(char *out, int i) { sprintf(out, "ZZ4R%04d.TMP", i); }

static int create(const char *name)
{
    char path[400];
    __dpmi_regs r;
    sprintf(path, "%s\\%s", g_folder, name);
    dosmemput(path, strlen(path) + 1, __tb);
    memset(&r, 0, sizeof r);
    r.h.ah = 0x3C; r.x.cx = 0x20;
    r.x.ds = (unsigned short)(__tb >> 4); r.x.dx = (unsigned short)(__tb & 15);
    if (int21(&r) != 0) return 1;
    r.x.bx = r.x.ax; r.h.ah = 0x3E;
    __dpmi_int(0x21, &r);
    return 0;
}

int main(int argc, char **argv)
{
    char mode, made[13], path[400];
    int k, i, names, done = 0, found = 0, lines = 0;
    uclock_t t0;
    FILE *out;

    if (argc != 5 || !strchr("bsmuc", argv[1][0]) || argv[1][1]) {
        fprintf(stderr, "usage: ATTRCOST <mode b|s|m|u|c> <folder> <K> <output file>\n");
        return 2;
    }
    mode = argv[1][0]; g_folder = argv[2]; k = atoi(argv[3]);
    if (k < 1 || k > MAX_K) { fprintf(stderr, "ATTRCOST: K is 1 to %d\n", MAX_K); return 2; }
    out = fopen(argv[4], "w");
    if (!out) { fprintf(stderr, "ATTRCOST: cannot write %s\n", argv[4]); return 3; }
    set_dta();
    if (mode == 'm' || mode == 'u')
        for (i = 0; i < k; i++) { made_name(made, i); if (create(made) != 0) { fprintf(stderr, "ATTRCOST: cannot make %s\n", made); return 3; } }

    names = baseline(k + 2);
    baseline(k + 2);
    fprintf(out, "cost|baseline|names=%d\n", names); lines++;
    if (names < k + 2) { fprintf(stderr, "ATTRCOST: the folder holds %d plain files, %d needed\n", names, k + 2); return 3; }

    t0 = uclock();
    for (i = 0; mode != 'b' && i < k; i++) {
        made_name(made, i);
        if (mode == 's') done += path_call(0x4301, 0x20, g_names[i]) == 0;
        else if (mode == 'm') { sprintf(path, "%s\\%s", g_folder, made); done += remove(path) == 0; }
        else if (mode == 'u') done += path_call(0x4100, 0, made) == 0;
        else done += create(made) == 0;
        found += path_call(0x4E00, ALL, g_names[i + 1]) == 0;
    }
    t0 = uclock() - t0;
    if (mode != 'b') {
        fprintf(out, "cost|loop|mode=%c k=%d done=%d found=%d guest_us=%lu\n", mode, k, done, found, (unsigned long)(t0 * 1000000UL / UCLOCKS_PER_SEC));
        lines++;
    }
    if (mode == 'c') for (i = 0; i < k; i++) { made_name(made, i); path_call(0x4100, 0, made); }
    fprintf(out, "end|lines=%d\n", lines);
    fclose(out);
    return 0;
}
