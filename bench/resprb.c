/* RESPRB.EXE: MEMPROBE with more things to repeat: one thing repeated K times, so that the host
 * can read what each repetition leaves in the emulator.
 *
 *   usage: RESPRB <mode> <path> <K> <held file> <go file>
 *
 *   mode  c  K protected-mode children, each one findfirst() never continued (MEMPROBE's c)
 *         n  K protected-mode children that return from main at once: no search at all
 *         w  K protected-mode children, each a whole search of <path> run to its end
 *         r  K real-mode children (C:\FF.COM): a 4Eh never continued, no DPMI, no FPU
 *         q  K real-mode children (C:\NOP.COM) that end at once
 *         p  no child and no search: K times FNINIT then FLDCW with three exceptions unmasked,
 *            the two control words a protected-mode child's start-up goes through
 *         d  no child: K findfirst() never continued
 *   child modes, for the spawned copy:  x  nothing   e  a whole search of <path>
 *
 * The hold and the result line are MEMPROBE's.
 */
#include <dir.h>
#include <dos.h>
#include <process.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define WAIT_SECONDS 60
#define CHILD_PATHS 16

static void dotted(char *out, size_t size, const char *path, int n)
{
    const char *last = strrchr(path, '\\');
    int len = last ? (int)(last - path) + 1 : 0;

    snprintf(out, size, "%.*s", len, path);
    while (n-- > 0 && strlen(out) + 3 < size) strcat(out, ".\\");
    snprintf(out + strlen(out), size - strlen(out), "%s", path + len);
}

static void fpu_flip(void)
{
    static const unsigned short unmasked = 0x1332;
    __asm__ volatile ("fninit");
    __asm__ volatile ("fldcw %0" : : "m" (unmasked));
}

static int whole_search(const char *path)
{
    struct ffblk ff;
    int n = 0;
    if (findfirst(path, &ff, FA_ARCH | FA_DIREC) != 0) return 0;
    do n++; while (findnext(&ff) == 0);
    return n > 0;
}

static int call_once(char mode, const char *path, const char *self, int i)
{
    char varied[300];
    struct ffblk ff;

    switch (mode) {
    case 'x': return 1;
    case 'e': return whole_search(path);
    case 'd': return findfirst(path, &ff, FA_ARCH) == 0;
    case 'p': fpu_flip(); return 1;
    case 'c':
        dotted(varied, sizeof varied, path, i % CHILD_PATHS);
        return spawnl(P_WAIT, self, self, "d", varied, "1", "-", "-", (char *)NULL) == 0;
    case 'n': return spawnl(P_WAIT, self, self, "x", "-", "1", "-", "-", (char *)NULL) == 0;
    case 'w': return spawnl(P_WAIT, self, self, "e", path, "1", "-", "-", (char *)NULL) == 0;
    case 'r': return spawnl(P_WAIT, "C:\\FF.COM", "C:\\FF.COM", (char *)NULL) == 0;
    case 'q': return spawnl(P_WAIT, "C:\\NOP.COM", "C:\\NOP.COM", (char *)NULL) == 0;
    }
    return 0;
}

int main(int argc, char **argv)
{
    char mode;
    int k, i, ok = 0, released = 1;
    unsigned int attr;
    uclock_t t0, limit;
    FILE *held;

    if (argc != 6) {
        fprintf(stderr, "usage: RESPRB <mode c|n|w|r|q|p|d> <path> <K> <held file> <go file>\n");
        return 2;
    }
    mode = argv[1][0];
    k = atoi(argv[3]);
    if (!strchr("cnwrqpdxe", mode) || argv[1][1]) {
        fprintf(stderr, "RESPRB: no such mode: %s\n", argv[1]);
        return 2;
    }
    t0 = uclock();
    for (i = 0; i < k; i++) ok += call_once(mode, argv[2], argv[0], i);
    t0 = uclock() - t0;
    if (strcmp(argv[4], "-") != 0) {
        held = fopen(argv[4], "w");
        if (held) { fputs("held\n", held); fclose(held); }
        limit = uclock() + (uclock_t)WAIT_SECONDS * UCLOCKS_PER_SEC;
        while (_dos_getfileattr(argv[5], &attr) != 0) {
            if (uclock() > limit) { released = 0; break; }
            delay(20);
        }
    }
    printf("mode=%c k=%d ok=%d released=%d guest_us=%lu\n", mode, k, ok, released, (unsigned long)(t0 * 1000000UL / UCLOCKS_PER_SEC));
    return ok == k ? 0 : 1;
}
