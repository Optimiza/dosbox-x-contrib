/* MEMPROBE.EXE: one DOS call repeated K times on one path, so that the host can read what
 * each call costs the emulator in memory.
 *
 *   usage: MEMPROBE <mode> <path> <K> <held file> <go file>
 *
 *   mode  a  access()                  s  stat()               d  findfirst(), never continued
 *         o  open() + read() + close() f  fopen() + fread() + fclose()
 *         r  raw 716Ch open, 3Fh read, 3Eh close: no libc path handling
 *         v  raw 4Eh for the volume label (attribute 08h) of <path>
 *         c  K child processes, each one findfirst() and then its exit
 *         e  raw 4Eh for one file of <path>'s folder after another, by its 8.3 name, never
 *            continued: the folder is listed first, files only, and K past its size starts over
 *         k  K child processes, each nine raw 4Eh for <path> through one DTA and then its exit,
 *            every child's DTA at another place: mode n, its K the place
 *
 * With long names libc closes its own 714Eh handle for a name without wildcards, so d and c
 * leave no search open. Without them the 4Eh search stays open in the DTA, which libc puts
 * right after the path: each child of c gets a path of another length, so that only its end
 * can release its search.
 *
 * It prints how many calls reached the file (ok=) and exits 1 when one did not: a failed call
 * costs the emulator nothing. Before that it creates <held file> and waits for <go file>, so
 * the host reads the emulator with the process alive; "-" skips the hold.
 *
 * DJGPP's start-up passes every argument through glob() before main, and for a path that asks
 * the file's attributes: the first read of a folder the emulator has not read, before the
 * first call the mode makes. The program turns it off, so its own calls are the ones measured.
 */

#include <crt0.h>
#include <dir.h>
#include <dos.h>
#include <dpmi.h>
#include <fcntl.h>
#include <go32.h>
#include <process.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/movedata.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

#define WAIT_SECONDS 60
#define CHILD_PATHS 16      /* path lengths mode c cycles through */
#define DTA_OFF 1024        /* the DTA of the raw find calls, in the transfer buffer */
#define NAME_SIZE 13
#define FOLDER_SIZE 300
#define LABEL_ATTR 0x08
#define FILES_ATTR 0x27     /* every file, no directory: no "." and no ".." */
#define CHILD_FINDS 9       /* the 4Eh calls of a child of mode k: one more than a DTA keeps */
#define DTA_STRIDE 48       /* mode n's DTA places, from DTA_OFF on in the transfer buffer */

static int g_place;

char **__crt0_glob_function(char *arg)
{
    (void)arg;
    return 0;
}

static int raw_open(const char *path)
{
    __dpmi_regs r;
    dosmemput(path, strlen(path) + 1, __tb);
    memset(&r, 0, sizeof r);
    r.x.ax = 0x716C; r.x.bx = 0; r.x.cx = 0; r.x.dx = 1;
    r.x.ds = (unsigned short)(__tb >> 4); r.x.si = (unsigned short)(__tb & 15);
    __dpmi_int(0x21, &r);
    return (r.x.flags & 1) ? -1 : r.x.ax;
}

static int raw_read(int h, char *buf, int n)
{
    __dpmi_regs r;
    memset(&r, 0, sizeof r);
    r.h.ah = 0x3F; r.x.bx = (unsigned short)h; r.x.cx = (unsigned short)n;
    r.x.ds = (unsigned short)((__tb + 1024) >> 4); r.x.dx = (unsigned short)((__tb + 1024) & 15);
    __dpmi_int(0x21, &r);
    if (r.x.flags & 1) return -1;
    dosmemget(__tb + 1024, r.x.ax, buf);
    return r.x.ax;
}

static void raw_close(int h)
{
    __dpmi_regs r;
    memset(&r, 0, sizeof r);
    r.h.ah = 0x3E; r.x.bx = (unsigned short)h;
    __dpmi_int(0x21, &r);
}

/* 4Eh for <path>, or 4Fh when <path> is NULL, through a DTA in the transfer buffer. Returns 0
 * when an entry was found, with its 8.3 name in name[] when that is not NULL. */
static int raw_find(const char *path, int attr, char *name)
{
    const unsigned long dta = __tb + DTA_OFF + (unsigned long)g_place * DTA_STRIDE;
    __dpmi_regs r;
    memset(&r, 0, sizeof r);
    r.h.ah = 0x1A;
    r.x.ds = (unsigned short)(dta >> 4); r.x.dx = (unsigned short)(dta & 15);
    __dpmi_int(0x21, &r);
    memset(&r, 0, sizeof r);
    if (path) {
        dosmemput(path, strlen(path) + 1, __tb);
        r.h.ah = 0x4E; r.x.cx = (unsigned short)attr;
        r.x.ds = (unsigned short)(__tb >> 4); r.x.dx = (unsigned short)(__tb & 15);
    } else {
        r.h.ah = 0x4F;
    }
    __dpmi_int(0x21, &r);
    if (r.x.flags & 1) return -1;
    if (name) dosmemget(dta + 30, NAME_SIZE, name);
    return 0;
}

/* The files of <path>'s folder, by a search run to its end. Returns how many, and the folder
 * with its last backslash in folder[]. */
static int list_files(const char *path, char folder[FOLDER_SIZE], char (**names)[NAME_SIZE])
{
    const char *last = strrchr(path, '\\');
    char pattern[FOLDER_SIZE + 4], name[NAME_SIZE];
    int n = 0, room = 0, found;

    snprintf(folder, FOLDER_SIZE, "%.*s", last ? (int)(last - path) + 1 : 0, path);
    snprintf(pattern, sizeof pattern, "%s*.*", folder);
    *names = NULL;
    for (found = raw_find(pattern, FILES_ATTR, name) == 0; found; found = raw_find(NULL, 0, name) == 0) {
        if (n == room) {
            room = room ? room * 2 : 1024;
            *names = realloc(*names, (size_t)room * NAME_SIZE);
            if (!*names) return 0;
        }
        memcpy((*names)[n++], name, NAME_SIZE);
    }
    return n;
}

/* the same file under a path n components longer */
static void dotted(char *out, size_t size, const char *path, int n)
{
    const char *last = strrchr(path, '\\');
    int len = last ? (int)(last - path) + 1 : 0;

    snprintf(out, size, "%.*s", len, path);
    while (n-- > 0 && strlen(out) + 3 < size) strcat(out, ".\\");
    snprintf(out + strlen(out), size - strlen(out), "%s", path + len);
}

/* How many DTAs of mode n fit in the transfer buffer behind DTA_OFF. */
static int places(void)
{
    return (int)((_go32_info_block.size_of_transfer_buffer - DTA_OFF - 64) / DTA_STRIDE);
}

static int call_once(char mode, const char *path, const char *self, int i)
{
    static char head[2048], folder[FOLDER_SIZE];
    static char (*names)[NAME_SIZE];
    static int files = -1;
    char varied[300], full[FOLDER_SIZE + NAME_SIZE];
    struct stat st;
    struct ffblk ff;

    if (mode == 'f') {
        FILE *f = fopen(path, "rb");
        if (!f) return 0;
        fread(head, 1, sizeof head, f);
        fclose(f);
        return 1;
    }
    if (mode == 'o') {
        int fd = open(path, O_RDONLY | O_BINARY);
        if (fd < 0) return 0;
        read(fd, head, sizeof head);
        close(fd);
        return 1;
    }
    if (mode == 'r') {
        int h = raw_open(path);
        if (h < 0) return 0;
        raw_read(h, head, 1024);
        raw_close(h);
        return 1;
    }
    if (mode == 's') return stat(path, &st) == 0;
    if (mode == 'd') return findfirst(path, &ff, FA_ARCH) == 0;
    if (mode == 'a') return access(path, R_OK) == 0;
    /* with no label the call fails, and the drive was searched all the same */
    if (mode == 'v') { raw_find(path, LABEL_ATTR, NULL); return 1; }
    if (mode == 'e') {
        if (files < 0) files = list_files(path, folder, &names);
        if (files == 0) return 0;
        snprintf(full, sizeof full, "%s%s", folder, names[i % files]);
        return raw_find(full, FILES_ATTR, NULL) == 0;
    }
    if (mode == 'n') return raw_find(path, FILES_ATTR, NULL) == 0;
    if (mode == 'k') {
        char place[12];
        sprintf(place, "%d", i % places());
        return spawnl(P_WAIT, self, self, "n", path, place, "-", "-", (char *)NULL) == 0;
    }
    dotted(varied, sizeof varied, path, i % CHILD_PATHS);
    return spawnl(P_WAIT, self, self, "d", varied, "1", "-", "-", (char *)NULL) == 0;
}

int main(int argc, char **argv)
{
    char mode;
    const char *path;
    int k, i, ok = 0, released = 1;
    unsigned int attr;
    uclock_t t0, limit;
    FILE *held;

    if (argc != 6) {
        fprintf(stderr, "usage: MEMPROBE <mode a|s|d|o|f|r|v|c|e|k|n> <path> <K> <held file> <go file>\n");
        return 2;
    }
    mode = argv[1][0];
    path = argv[2];
    k = atoi(argv[3]);
    if (!strchr("asdofrvcekn", mode) || argv[1][1]) {
        fprintf(stderr, "MEMPROBE: no such mode: %s\n", argv[1]);
        return 2;
    }
    if (mode == 'n') {
        g_place = k;
        k = CHILD_FINDS;
    }
    t0 = uclock();
    for (i = 0; i < k; i++) ok += call_once(mode, path, argv[0], i);
    t0 = uclock() - t0;
    if (strcmp(argv[4], "-") != 0) {
        held = fopen(argv[4], "w");
        if (held) { fputs("held\n", held); fclose(held); }
        /* 4300h and not access(): the wait must not make searches of its own */
        limit = uclock() + (uclock_t)WAIT_SECONDS * UCLOCKS_PER_SEC;
        while (_dos_getfileattr(argv[5], &attr) != 0) {
            if (uclock() > limit) { released = 0; break; }
            delay(20);
        }
    }
    printf("mode=%c k=%d ok=%d released=%d guest_us=%lu\n", mode, k, ok, released, (unsigned long)(t0 * 1000000UL / UCLOCKS_PER_SEC));
    return ok == k ? 0 : 1;
}
