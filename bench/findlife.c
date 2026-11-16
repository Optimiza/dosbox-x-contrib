/* FINDLIFE.EXE: what happens to a directory search that is not simply run to its end. Each case
 * starts a search, does something else in the middle (another search, a child process, a
 * remount, a rescan) and then asks the first search for its next entries, the way DOS allows:
 * the whole state of a 4Eh search is the 21 bytes DOS keeps in the DTA, so a program may copy
 * them away, reuse the DTA and put them back.
 *
 *   usage: FINDLIFE <folder A> <folder B> <output file> <root file>
 *                   e.g. FINDLIFE D:\A D:\B C:\LIFE.TXT C:\ROOT.TXT
 *
 * <folder A> holds files whose names start with A, <folder B> with B, so an entry handed back
 * from the wrong folder shows in its name. Both sit on one drive, which the remount case
 * unmounts and mounts again from the host path written in <root file> (a host path is too long
 * for a DOS command line). The output is one line per case:
 *
 *   case|<name>|<what was counted>|<ok, or DIFFERS from what a search whose whole state is
 *                                    its DTA would answer, or "not judged" when the case
 *                                    could not be set up>
 *
 * and a trailer with the number of cases. findlife.sh beside this file runs it on two builds.
 *
 * The current DTA is parked on a spare one between calls. DOS leaves the DTA alone outside the
 * find calls, but the emulator's long-name calls write their pattern and drive into whichever
 * DTA is current, and libc makes such calls on its own (to open a file, to find a program to
 * run): a search whose DTA were still current would lose its pattern to them on any build. The
 * case lfn-writes-current-dta shows that on purpose.
 */

#include <dir.h>
#include <dpmi.h>
#include <go32.h>
#include <process.h>
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
#define DTA_C 2
#define DTA_PARK 3          /* the current DTA whenever no 4Eh, 4Fh or FCB call is being made */
#define DTA_LIVE 8          /* the first of LIVE_COUNT DTAs that each hold a live search */
#define LIVE_COUNT 16
#define FIND_OFF 2048
#define PATH_OFF 2400
#define FCB_OFF 2720
#define RESULT_OFF 2800
#define DTA_BYTES 43
#define SEARCH_ATTR 0x37    /* everything but the volume label */
/* The size of the emulator's search table per drive, mirrored: the reuse cases walk it once.
 * slot-reused-live proves in its own line that the walk landed, from the slot number the
 * emulator keeps in the DTA, and is not judged when it did not. */
#define SLOTS 2048
#define DTA_SLOT_OFF 13
#define PAST_SLOTS (SLOTS + 52)     /* more searches than the table holds at once */
#define HANDLES_MOST 64             /* more file handles than a process has by default */
/* Lookups before each turn of two searches read turn about: folder B is listed in 32 turns. */
#define LOOKUPS_A_TURN (PAST_SLOTS / 30)

_Static_assert((DTA_LIVE + LIVE_COUNT) * DTA_SIZE <= FIND_OFF, "the DTAs overlap the find record");
_Static_assert(RESULT_OFF + 1 + 2 * 13 <= BLOCK_PARAS * 16, "the child's results overflow the block");

static unsigned long g_lin;
static unsigned short g_seg;
static FILE *g_out;
static int g_cases;

static int int21(__dpmi_regs *r)
{
    __dpmi_int(0x21, r);
    return (r->x.flags & 1) ? r->x.ax : 0;
}

static void set_dta(unsigned short seg, unsigned short off)
{
    __dpmi_regs r;
    memset(&r, 0, sizeof r);
    r.h.ah = 0x1A; r.x.ds = seg; r.x.dx = off;
    __dpmi_int(0x21, &r);
}

static void park(void) { set_dta(g_seg, DTA_PARK * DTA_SIZE); }

static void put_path(const char *path)
{
    dosmemput(path, strlen(path) + 1, g_lin + PATH_OFF);
}

static int first(int dta, const char *path)
{
    __dpmi_regs r;
    int err;
    set_dta(g_seg, dta * DTA_SIZE);
    put_path(path);
    memset(&r, 0, sizeof r);
    r.h.ah = 0x4E; r.x.cx = SEARCH_ATTR; r.x.ds = g_seg; r.x.dx = PATH_OFF;
    err = int21(&r);
    park();
    return err;
}

static int next(int dta)
{
    __dpmi_regs r;
    int err;
    set_dta(g_seg, dta * DTA_SIZE);
    memset(&r, 0, sizeof r);
    r.h.ah = 0x4F;
    err = int21(&r);
    park();
    return err;
}

static void dta_name(int dta, char *name)
{
    dosmemget(g_lin + dta * DTA_SIZE + 30, 13, name);
    name[12] = 0;
}

static int slot_of(const char *bytes)
{
    return (unsigned char)bytes[DTA_SLOT_OFF] | (unsigned char)bytes[DTA_SLOT_OFF + 1] << 8;
}

static void dta_save(int dta, char *bytes) { dosmemget(g_lin + dta * DTA_SIZE, DTA_BYTES, bytes); }
static void dta_load(int dta, const char *bytes) { dosmemput(bytes, DTA_BYTES, g_lin + dta * DTA_SIZE); }

static int is_foreign(const char *name, char want)
{
    return name[0] != want && name[0] != '.';
}

/* Runs a started search to its end. Returns how many more entries it gave and adds to *foreign
 * the ones whose name does not start with `want`. */
static int drain(int dta, char want, int *foreign)
{
    char name[13];
    int n = 0;
    while (next(dta) == 0) {
        dta_name(dta, name);
        if (is_foreign(name, want)) (*foreign)++;
        n++;
    }
    return n;
}

/* Starts a search and reads `count` entries in all (the first included). Returns how many it got. */
static int start(int dta, const char *pattern, int count)
{
    int n = 0;
    if (first(dta, pattern) != 0) return 0;
    for (n = 1; n < count; n++)
        if (next(dta) != 0) break;
    return n;
}

static int lfn_first(const char *path, int *handle)
{
    __dpmi_regs r;
    int err;
    put_path(path);
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

/* A handle on the NUL device, or -1 when the process has none left. */
static int nul_open(void)
{
    __dpmi_regs r;
    put_path("NUL");
    memset(&r, 0, sizeof r);
    r.x.ax = 0x3D00; r.x.ds = g_seg; r.x.dx = PATH_OFF;
    return int21(&r) ? -1 : r.x.ax;
}

static void handle_close(int handle)
{
    __dpmi_regs r;
    memset(&r, 0, sizeof r);
    r.h.ah = 0x3E; r.x.bx = (unsigned short)handle;
    __dpmi_int(0x21, &r);
}

static int lfn_drain(int handle, char want, int *foreign)
{
    char name[2];
    int n = 0;
    while (lfn_next(handle) == 0) {
        dosmemget(g_lin + FIND_OFF + 44, 1, name);
        name[1] = 0;
        if (is_foreign(name, want)) (*foreign)++;
        n++;
    }
    return n;
}

/* An unopened FCB for every file of the default drive's current directory. */
static void fcb_put(void)
{
    char fcb[37];
    memset(fcb, 0, sizeof fcb);
    memset(fcb + 1, '?', 11);
    dosmemput(fcb, sizeof fcb, g_lin + FCB_OFF);
}

static int fcb_call(int function, int dta)
{
    __dpmi_regs r;
    set_dta(g_seg, dta * DTA_SIZE);
    memset(&r, 0, sizeof r);
    r.h.ah = (unsigned char)function; r.x.ds = g_seg; r.x.dx = FCB_OFF;
    __dpmi_int(0x21, &r);
    park();
    return r.h.al == 0 ? 0 : 1;
}

static int fcb_drain(int dta)
{
    int n = 0;
    while (fcb_call(0x12, dta) == 0) n++;
    return n;
}

static void emit(const char *name, int ok, const char *fmt, ...)
{
    va_list ap;
    fprintf(g_out, "case|%s|", name);
    va_start(ap, fmt);
    vfprintf(g_out, fmt, ap);
    va_end(ap);
    fprintf(g_out, "|%s\n", ok ? "ok" : "DIFFERS");
    g_cases++;
}

static void note(const char *name, const char *fmt, ...)
{
    va_list ap;
    fprintf(g_out, "case|%s|", name);
    va_start(ap, fmt);
    vfprintf(g_out, fmt, ap);
    va_end(ap);
    fprintf(g_out, "|not judged\n");
    g_cases++;
}

static int run_child(const char *self, const char *mode, const char *a, const char *b, const char *c)
{
    return spawnl(P_WAIT, self, self, mode, a, b, c, (char *)NULL);
}

/* The child's side of the three cases that need a second process. */
static int child_main(int argc, char **argv)
{
    __dpmi_regs r;
    char name[13];
    int i, n, handle, sel;
    unsigned short seg, off;

    if (argc != 5) return 2;
    if (strcmp(argv[1], "@abandon") == 0) {
        /* one 4Eh search and one 714Eh search of its own, left open when it exits */
        int s = __dpmi_allocate_dos_memory(BLOCK_PARAS, &sel);
        if (s == -1) return 3;
        g_seg = (unsigned short)s;
        g_lin = (unsigned long)g_seg << 4;
        if (first(DTA_A, argv[2]) != 0) return 4;
        lfn_first(argv[3], &handle);
        return 0;
    }
    seg = (unsigned short)strtoul(argv[2], NULL, 16);
    off = (unsigned short)strtoul(argv[3], NULL, 16);
    g_seg = seg;
    g_lin = (unsigned long)seg << 4;
    if (strcmp(argv[1], "@next") == 0) {
        /* continues the parent's search through the parent's DTA */
        n = atoi(argv[4]);
        for (i = 0; i < n; i++) {
            set_dta(seg, off);
            memset(&r, 0, sizeof r);
            r.h.ah = 0x4F;
            if (int21(&r) != 0) break;
            dosmemget(g_lin + off + 30, 13, name);
            dosmemput(name, 13, g_lin + RESULT_OFF + 1 + i * 13);
        }
        name[0] = (char)i;
        dosmemput(name, 1, g_lin + RESULT_OFF);
        return 0;
    }
    if (strcmp(argv[1], "@start") == 0) {
        /* starts a search in the parent's DTA and leaves it there */
        set_dta(seg, off);
        put_path(argv[4]);
        memset(&r, 0, sizeof r);
        r.h.ah = 0x4E; r.x.cx = SEARCH_ATTR; r.x.ds = seg; r.x.dx = PATH_OFF;
        return int21(&r) == 0 ? 0 : 5;
    }
    return 2;
}

int main(int argc, char **argv)
{
    char pat_a[300], pat_b[300], lfn_a[300], lfn_b[300], lfn_root[300], refused[300], newfile[300], pat_b_longer[300];
    char saved[DTA_BYTES], live[DTA_BYTES], name[13], hex_seg[8], hex_off[8], drive[3], drive_spec[3], root[300], lookup[300];
    int sel, s, i, t, n, m, foreign, got, handle, handle2, err, rc, old_slot, reused, created;
    int n_a, n_b, remount_before, remount_after, remount_rc, remount_foreign;
    int handles[HANDLES_MOST], opened, turned_away;
    char *slash, device[8];
    struct ffblk ff_a, ff_b;
    FILE *f;

    if (argc >= 2 && argv[1][0] == '@') return child_main(argc, argv);
    if (argc != 5) {
        fprintf(stderr, "usage: FINDLIFE <folder A> <folder B> <output file> <root file>\n");
        return 2;
    }
    f = fopen(argv[4], "r");
    if (!f || !fgets(root, sizeof root, f)) { fprintf(stderr, "FINDLIFE: cannot read %s\n", argv[4]); return 3; }
    fclose(f);
    root[strcspn(root, "\r\n")] = 0;
    s = __dpmi_allocate_dos_memory(BLOCK_PARAS, &sel);
    if (s == -1) { fprintf(stderr, "FINDLIFE: no conventional memory\n"); return 3; }
    g_seg = (unsigned short)s;
    g_lin = (unsigned long)g_seg << 4;
    sprintf(pat_a, "%s\\*.*", argv[1]);
    sprintf(pat_b, "%s\\*.*", argv[2]);
    sprintf(lfn_a, "%s\\*", argv[1]);
    sprintf(lfn_b, "%s\\*", argv[2]);
    /* Folder A itself, searched for in the root: its name alone and a star, which no name of
     * folder B matches. */
    strcpy(lfn_root, argv[1]);
    slash = strrchr(lfn_root, '\\');
    if (slash) strcpy(slash + 2, "*");
    sprintf(hex_seg, "%04X", g_seg);
    drive[0] = argv[1][0]; drive[1] = 0;
    sprintf(drive_spec, "%c:", argv[1][0]);

    /* remount: runs first, so the search it leaves open is the drive's first, and the first
     * search of the drive mounted in its place gets the same place in the new cache. */
    remount_before = start(DTA_A, pat_a, 3);
    remount_rc = spawnlp(P_WAIT, "MOUNT", "MOUNT", "-u", drive, (char *)NULL);
    if (remount_rc == 0) remount_rc = spawnlp(P_WAIT, "MOUNT", "MOUNT", drive, root, (char *)NULL);
    remount_foreign = 0;
    remount_after = start(DTA_B, pat_b, 3);
    first(DTA_A, pat_a);
    remount_after += drain(DTA_B, 'B', &remount_foreign);
    drain(DTA_A, 'A', &remount_foreign);

    foreign = 0;
    n_a = start(DTA_A, pat_a, 1); n_a += drain(DTA_A, 'A', &foreign);
    n_b = start(DTA_B, pat_b, 1); n_b += drain(DTA_B, 'B', &foreign);

    g_out = fopen(argv[3], "w");
    if (!g_out) { fprintf(stderr, "FINDLIFE: cannot write %s\n", argv[3]); return 3; }
    fprintf(g_out, "folders|a=%d b=%d foreign=%d\n", n_a, n_b, foreign);
    if (n_a < 8 || n_b < 8 || foreign != 0) { fprintf(g_out, "end|cases=0\n"); fclose(g_out); return 3; }
    emit("remount", remount_rc == 0 && remount_before == 3 && remount_after == n_b && remount_foreign == 0,
         "mount_rc=%d before=%d search_on_new_drive=%d of %d foreign=%d", remount_rc, remount_before, remount_after, n_b, remount_foreign);

    /* A long-name search read to its end and then asked once more through its handle, which is
     * still open: the call finds no more files and reaches no other search. The search it
     * could reach is the one in the first slot of the emulator's table, so that table is
     * walked until a 4Eh search of folder B holds that slot. The long-name search is for
     * folder A in the root, a name no entry of folder B matches: a build that does reach the
     * slot passes over its entries and ends that search. */
    err = lfn_first("C:\\FINDLIFE.EXE", &handle);
    if (err == 0) {
        lfn_close(handle);
        foreign = 0; got = 0; n = 0; rc = 0;
        for (i = 0; i <= SLOTS && !got; i++) {
            start(DTA_B, pat_b, 1);
            dta_save(DTA_B, saved);
            if (slot_of(saved) == 0) got = 1; else drain(DTA_B, 'B', &foreign);
        }
        if (lfn_first(lfn_root, &handle) == 0) {
            n = 1 + lfn_drain(handle, 'A', &foreign);
            rc = lfn_next(handle);
            lfn_close(handle);
        }
        m = got ? 1 + drain(DTA_B, 'B', &foreign) : 0;
        if (got) emit("lfn-next-after-its-end", n == 1 && rc != 0 && m == n_b && foreign == 0, "lfn=%d of 1 again=%04X search_in_first_slot=%d of %d foreign=%d", n, rc, m, n_b, foreign);
        else note("lfn-next-after-its-end", "no search got the first slot: the table is not %d slots or other searches hold it", SLOTS);
    } else {
        note("lfn-next-after-its-end", "714Eh failed, error %04X", err);
    }

    /* A second search through the same DTA, the first one's bytes saved and put back. */
    foreign = 0;
    n = start(DTA_A, pat_a, 3);
    dta_save(DTA_A, saved);
    m = start(DTA_A, pat_b, 1); m += drain(DTA_A, 'B', &foreign);
    dta_load(DTA_A, saved);
    n += drain(DTA_A, 'A', &foreign);
    emit("nested-same-dta", n == n_a && m == n_b && foreign == 0, "outer=%d of %d inner=%d of %d foreign=%d", n, n_a, m, n_b, foreign);

    /* The same nesting with a DTA of its own for the inner search. */
    foreign = 0;
    n = start(DTA_A, pat_a, 3);
    m = start(DTA_B, pat_b, 1); m += drain(DTA_B, 'B', &foreign);
    n += drain(DTA_A, 'A', &foreign);
    emit("nested-other-dta", n == n_a && m == n_b && foreign == 0, "outer=%d of %d inner=%d of %d foreign=%d", n, n_a, m, n_b, foreign);

    /* A FindFirst refused for its trailing backslash never reaches the DTA: the search in it
     * goes on. */
    foreign = 0;
    n = start(DTA_A, pat_a, 3);
    sprintf(refused, "%s\\", argv[1]);
    err = first(DTA_A, refused);
    n += drain(DTA_A, 'A', &foreign);
    emit("failed-findfirst", err != 0 && n == n_a && foreign == 0, "error=%d outer=%d of %d foreign=%d", err, n, n_a, foreign);

    /* A long-name search made while a 4Eh search's DTA is the current one. */
    foreign = 0;
    n = start(DTA_A, pat_a, 3);
    set_dta(g_seg, DTA_A * DTA_SIZE);
    err = lfn_first("C:\\FINDLIFE.EXE", &handle);
    if (err == 0) lfn_close(handle);
    park();
    n += drain(DTA_A, 'A', &foreign);
    if (err == 0) emit("lfn-writes-current-dta", n == n_a && foreign == 0, "outer=%d of %d foreign=%d", n, n_a, foreign);
    else note("lfn-writes-current-dta", "714Eh failed, error %04X", err);

    /* Two long-name searches at once, and a long-name search inside a 4Eh one. */
    foreign = 0; n = 0; m = 0;
    err = lfn_first(lfn_a, &handle);
    if (err == 0) {
        n = 1;
        if (lfn_next(handle) == 0) n++;
        if (lfn_first(lfn_b, &handle2) == 0) { m = 1 + lfn_drain(handle2, 'B', &foreign); lfn_close(handle2); }
        n += lfn_drain(handle, 'A', &foreign);
        lfn_close(handle);
        emit("nested-lfn", n == n_a && m == n_b && foreign == 0, "outer=%d of %d inner=%d of %d foreign=%d", n, n_a, m, n_b, foreign);
        foreign = 0; m = 0;
        n = start(DTA_A, pat_a, 3);
        if (lfn_first(lfn_b, &handle2) == 0) { m = 1 + lfn_drain(handle2, 'B', &foreign); lfn_close(handle2); }
        n += drain(DTA_A, 'A', &foreign);
        emit("lfn-inside-4e", n == n_a && m == n_b && foreign == 0, "outer=%d of %d inner=%d of %d foreign=%d", n, n_a, m, n_b, foreign);
    } else {
        note("nested-lfn", "714Eh failed, error %04X", err);
        note("lfn-inside-4e", "714Eh failed, error %04X", err);
    }

    /* A search that ends through another DTA address (the bytes copied there, as DJGPP's
     * findnext does) leaves its first DTA behind. LIVE_COUNT live searches then take the slots
     * around the one it had, and a new search from the first DTA must not close any of them. */
    foreign = 0; reused = 0;
    start(DTA_A, pat_a, 1);
    dta_save(DTA_A, saved);
    old_slot = slot_of(saved);
    dta_load(DTA_C, saved);
    drain(DTA_C, 'A', &foreign);
    for (i = 0; i < SLOTS - LIVE_COUNT / 2 - 2; i++) { start(DTA_B, pat_b, 1); drain(DTA_B, 'B', &foreign); }
    for (t = 0; t < LIVE_COUNT; t++) {
        start(DTA_LIVE + t, pat_b, 1);
        dta_save(DTA_LIVE + t, live);
        if (slot_of(live) == old_slot) reused = 1;
    }
    start(DTA_A, pat_a, 1);
    m = n_b;
    for (t = 0; t < LIVE_COUNT; t++) { n = 1 + drain(DTA_LIVE + t, 'B', &foreign); if (n < m) m = n; }
    drain(DTA_A, 'A', &foreign);
    if (reused) emit("slot-reused-live", m == n_b && foreign == 0, "old_slot_held_by_a_live_search=1 shortest_live_search=%d of %d foreign=%d", m, n_b, foreign);
    else note("slot-reused-live", "no live search got the old slot: the table is not %d slots or other searches hold some", SLOTS);

    /* The outer search of a same-DTA nesting, asked again once the cache has gone round all its
     * slots and live searches of the other folder hold the ones around its own. */
    foreign = 0; got = 0; name[0] = 0;
    n = start(DTA_A, pat_a, 3);
    dta_save(DTA_A, saved);
    start(DTA_A, pat_b, 1); drain(DTA_A, 'B', &foreign);
    for (i = 0; i < SLOTS - LIVE_COUNT / 2 - 2; i++) { start(DTA_B, pat_b, 1); drain(DTA_B, 'B', &foreign); }
    reused = 0;
    for (t = 0; t < LIVE_COUNT; t++) {
        start(DTA_LIVE + t, pat_b, 3);
        dta_save(DTA_LIVE + t, live);
        if (slot_of(live) == slot_of(saved)) reused = 1;
    }
    dta_load(DTA_C, saved);
    if (next(DTA_C) == 0) { got = 1; dta_name(DTA_C, name); if (is_foreign(name, 'A')) foreign++; }
    for (t = 0; t < LIVE_COUNT; t++) drain(DTA_LIVE + t, 'B', &i);
    emit("stale-dta-after-reuse", got == 1 && foreign == 0, "its_slot_held_by_a_search_of_the_other_folder=%d next=%s name=%s from_other_folder=%d", reused, got ? "entry" : "none", got ? name : "-", foreign);

    /* A child process leaves a 4Eh and a 714Eh search open when it ends; the parent's two go on. */
    foreign = 0; m = 0;
    n = start(DTA_A, pat_a, 3);
    err = lfn_first(lfn_b, &handle);
    rc = run_child(argv[0], "@abandon", pat_b, lfn_a, "-");
    if (err == 0) { m = 1 + lfn_drain(handle, 'B', &foreign); lfn_close(handle); }
    n += drain(DTA_A, 'A', &foreign);
    if (err == 0) emit("child-ends-mid-search", rc == 0 && n == n_a && m == n_b && foreign == 0, "child_rc=%d parent_4e=%d of %d parent_lfn=%d of %d foreign=%d", rc, n, n_a, m, n_b, foreign);
    else emit("child-ends-mid-search", rc == 0 && n == n_a && foreign == 0, "child_rc=%d parent_4e=%d of %d parent_lfn=not run, 714Eh failed foreign=%d", rc, n, n_a, foreign);

    /* A child continues the parent's search through the parent's DTA, then the parent goes on. */
    foreign = 0;
    n = start(DTA_A, pat_a, 3);
    sprintf(hex_off, "%04X", DTA_A * DTA_SIZE);
    rc = run_child(argv[0], "@next", hex_seg, hex_off, "2");
    dosmemget(g_lin + RESULT_OFF, 1, name);
    m = name[0];
    for (i = 0; i < m; i++) { dosmemget(g_lin + RESULT_OFF + 1 + i * 13, 13, name); name[12] = 0; if (is_foreign(name, 'A')) foreign++; }
    n += m + drain(DTA_A, 'A', &foreign);
    emit("child-continues-parent", rc == 0 && m == 2 && n == n_a && foreign == 0, "child_rc=%d child_got=%d total=%d of %d foreign=%d", rc, m, n, n_a, foreign);

    /* A child starts a search in the parent's DTA and ends; the parent runs it. */
    foreign = 0;
    sprintf(hex_off, "%04X", DTA_B * DTA_SIZE);
    rc = run_child(argv[0], "@start", hex_seg, hex_off, pat_b);
    n = 1 + drain(DTA_B, 'B', &foreign);
    emit("child-starts-parent-continues", rc == 0 && n == n_b && foreign == 0, "child_rc=%d total=%d of %d foreign=%d", rc, n, n_b, foreign);

    /* The directory changes and the drive is rescanned under a live search: the search goes on,
     * over what it saw when it started or over that and the file created meanwhile. */
    foreign = 0;
    n = start(DTA_A, pat_a, 3);
    sprintf(newfile, "%s\\ANEW.TXT", argv[1]);
    f = fopen(newfile, "w");
    created = f != NULL;
    if (f) fclose(f);
    remove(newfile);
    rc = spawnlp(P_WAIT, "RESCAN", "RESCAN", drive_spec, (char *)NULL);
    n += drain(DTA_A, 'A', &foreign);
    m = start(DTA_B, pat_a, 1); m += drain(DTA_B, 'A', &foreign);
    emit("rescan-mid-search", rc == 0 && created && (n == n_a || n == n_a + 1) && m == n_a && foreign == 0, "rescan_rc=%d created=%d live=%d of %d after=%d of %d foreign=%d", rc, created, n, n_a, m, n_a, foreign);

    /* Two enumerations at once through libc's findfirst and findnext, which opendir and readdir
     * are made of. Without long names libc places the DTA after the path in its transfer
     * buffer, so two paths of one length share its address and two of different lengths do
     * not: the second pair is the control. */
    n = findfirst(pat_a, &ff_a, SEARCH_ATTR) == 0;
    m = findfirst(pat_b, &ff_b, SEARCH_ATTR) == 0;
    while (n && findnext(&ff_a) == 0) n++;
    while (m && findnext(&ff_b) == 0) m++;
    park();
    emit("libc-two-searches", n == n_a && m == n_b, "first=%d of %d second=%d of %d", n, n_a, m, n_b);
    sprintf(pat_b_longer, "%s\\.\\*.*", argv[2]);
    n = findfirst(pat_a, &ff_a, SEARCH_ATTR) == 0;
    m = findfirst(pat_b_longer, &ff_b, SEARCH_ATTR) == 0;
    while (n && findnext(&ff_a) == 0) n++;
    while (m && findnext(&ff_b) == 0) m++;
    park();
    emit("libc-two-searches-other-length", n == n_a && m == n_b, "first=%d of %d second=%d of %d", n, n_a, m, n_b);

    /* The FCB calls: a whole enumeration, one abandoned and started again, one with a 4Eh
     * search in the middle, one with a long-name search in the middle, and one with a
     * long-name search for a device in the middle. */
    if (chdir(argv[1]) == 0) {
        fcb_put();
        n = (fcb_call(0x11, DTA_A) == 0) ? 1 + fcb_drain(DTA_A) : 0;
        fcb_call(0x11, DTA_A); fcb_call(0x12, DTA_A);
        m = (fcb_call(0x11, DTA_A) == 0) ? 1 + fcb_drain(DTA_A) : 0;
        emit("fcb", n == n_a - 2 && m == n, "files=%d of %d again=%d", n, n_a - 2, m);
        foreign = 0;
        fcb_call(0x11, DTA_A); fcb_call(0x12, DTA_A);
        t = start(DTA_B, pat_b, 1); t += drain(DTA_B, 'B', &foreign);
        m = 2 + fcb_drain(DTA_A);
        emit("fcb-around-4e", m == n && t == n_b && foreign == 0, "files=%d of %d inner=%d of %d", m, n, t, n_b);
        foreign = 0;
        fcb_call(0x11, DTA_A); fcb_call(0x12, DTA_A);
        t = 0;
        if (lfn_first(lfn_b, &handle) == 0) { t = 1 + lfn_drain(handle, 'B', &foreign); lfn_close(handle); }
        m = 2 + fcb_drain(DTA_A);
        /* With no long-name search in the middle the case was not set up. */
        if (t) emit("fcb-around-lfn", m == n && t == n_b && foreign == 0, "files=%d of %d inner=%d of %d", m, n, t, n_b);
        else note("fcb-around-lfn", "files=%d of %d inner=%d of %d", m, n, t, n_b);
        /* The same around a long-name search for a device in the drive's root: the path of that
         * call is looked up without the drive being searched. */
        fcb_call(0x11, DTA_A); fcb_call(0x12, DTA_A);
        sprintf(device, "%c:\\NUL", argv[1][0]);
        err = lfn_first(device, &handle);
        if (err == 0) lfn_close(handle);
        m = 2 + fcb_drain(DTA_A);
        if (err == 0) emit("fcb-around-lfn-of-a-device", m == n, "files=%d of %d", m, n);
        else note("fcb-around-lfn-of-a-device", "files=%d of %d, 714Eh failed, error %04X", m, n, err);
        chdir("C:\\");
    } else {
        note("fcb", "could not enter %s", argv[1]);
    }

    /* The folder listed again while an earlier listing of it is still open, a file created in
     * between: the second listing has the new file, and the first goes on over what it saw when
     * it started or over that and the new file. */
    foreign = 0; got = 0; m = 0;
    n = start(DTA_A, pat_a, 3);
    sprintf(newfile, "%s\\ANEW.TXT", argv[1]);
    f = fopen(newfile, "w");
    created = f != NULL;
    if (f) fclose(f);
    if (first(DTA_B, pat_a) == 0) {
        do {
            dta_name(DTA_B, name);
            if (strcmp(name, "ANEW.TXT") == 0) got = 1;
            if (is_foreign(name, 'A')) foreign++;
            m++;
        } while (next(DTA_B) == 0);
    }
    n += drain(DTA_A, 'A', &foreign);
    remove(newfile);
    emit("listed-again-after-a-new-file", created && got == 1 && m == n_a + 1 && (n == n_a || n == n_a + 1) && foreign == 0,
         "created=%d first_listing=%d of %d second_listing=%d of %d new_file_in_second=%d foreign=%d", created, n, n_a, m, n_a + 1, got, foreign);

    /* 714Eh finds an entry while the process has no handle left to return the search through:
     * the call fails and the search it started is over. Made more times than the emulator's
     * table has slots, it leaves a 4Eh search started before it to go on to its end. */
    foreign = 0; opened = 0; turned_away = 0; err = 0;
    n = start(DTA_A, pat_a, 3);
    while (opened < HANDLES_MOST && (handles[opened] = nul_open()) >= 0) opened++;
    for (i = 0; i < PAST_SLOTS; i++) {
        err = lfn_first(lfn_root, &handle);
        if (err == 0) lfn_close(handle);
        if (err != 4) break;
        turned_away++;
    }
    while (opened > 0) handle_close(handles[--opened]);
    n += drain(DTA_A, 'A', &foreign);
    if (turned_away == PAST_SLOTS) emit("lfn-first-with-no-handle-left", n == n_a && foreign == 0, "turned_away=%d outer=%d of %d foreign=%d", turned_away, n, n_a, foreign);
    else note("lfn-first-with-no-handle-left", "714Eh was not turned away for want of a handle: error %04X after %d calls", err, turned_away);

    /* More searches of a whole folder left open than the emulator's search table holds: the one
     * started before them, read for three entries, goes on to its end. Last, because it leaves
     * that table full. */
    foreign = 0;
    n = start(DTA_A, pat_a, 3);
    for (i = 0; i < PAST_SLOTS; i++) first(DTA_B, pat_b);
    n += drain(DTA_A, 'A', &foreign);
    emit("left-open-past-the-slots", n == n_a && foreign == 0, "left_open=%d outer=%d of %d foreign=%d", PAST_SLOTS, n, n_a, foreign);

    /* Two searches, each through its own DTA, read turn about, while the program looks a file
     * up by its name before every turn and never continues that search: more lookups in all
     * than the emulator's search table has slots. Both searches go on to their ends. */
    foreign = 0; t = 0; got = 0;
    sprintf(lookup, "%s\\A0000.TXT", argv[1]);
    n = start(DTA_A, pat_a, 1);
    m = start(DTA_B, pat_b, 1);
    for (i = 1; n == i || m == i; i++) {
        for (rc = 0; rc < LOOKUPS_A_TURN; rc++, t++) if (first(DTA_C, lookup) == 0) got++;
        if (n == i && next(DTA_A) == 0) { n++; dta_name(DTA_A, name); if (is_foreign(name, 'A')) foreign++; }
        if (m == i && next(DTA_B) == 0) { m++; dta_name(DTA_B, name); if (is_foreign(name, 'B')) foreign++; }
    }
    emit("turn-about-past-the-slots", t > SLOTS && got == t && n == n_a && m == n_b && foreign == 0,
         "lookups=%d found=%d first=%d of %d second=%d of %d foreign=%d", t, got, n, n_a, m, n_b, foreign);

    fprintf(g_out, "end|cases=%d\n", g_cases);
    fclose(g_out);
    return 0;
}
