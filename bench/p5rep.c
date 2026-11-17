/* P5REP.EXE: the guest step of the wall-clock timer's cases taken from the reporters' issues. Every
 * call a raw INT 21h.
 *
 *   usage: P5REP w <ready file> <go file>
 *            makes the ready file, waits for the go file, and returns: the shell's next command
 *            is what the host times
 *          P5REP o <path> <stop file> <ready file> <go file> <output file>
 *            makes the ready file, waits for the go file, opens <path> with 716Ch (read, open
 *            existing), closes it, makes the stop file, then writes its line
 *          P5REP f <path> <stop file> <ready file> <go file> <output file>
 *            the same with the C library's fopen(path, "rb") and fclose: what a program's
 *            own open asks of DOS, whatever calls that is
 *          P5REP m <what DIR printed> <output file>
 *            reads the file the shell's DIR wrote, after the host stopped its clock, and writes
 *            how many files DIR counted
 *
 * Lines:  p5rep|mode=o open=<0, or the error code>
 *         p5rep|mode=f open=<0, or errno>
 *         p5rep|mode=m files=<the count of DIR's "File(s)" line, or none> lines=<lines read>
 *         end|lines=1
 * DJGPP's start-up passes every argument through glob() before main, which searches the folder a
 * path names: with the folder unread that is the whole first read, outside the timed step. So
 * this program turns it off, and its own call is the first to reach the folder.
 * The waits ask 4300h, which makes no search.
 */
#include <dos.h>
#include <crt0.h>
#include <dpmi.h>
#include <errno.h>
#include <go32.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/movedata.h>

static void wait_for(const char *file)
{
    unsigned attr;
    while (_dos_getfileattr(file, &attr) != 0) delay(20);
}

static void touch(const char *file)
{
    FILE *f = fopen(file, "w");
    if (f) { fputs("1\n", f); fclose(f); }
}

static int open_716c(const char *path)
{
    __dpmi_regs r;
    dosmemput(path, strlen(path) + 1, __tb);
    memset(&r, 0, sizeof r);
    r.x.ax = 0x716C; r.x.bx = 0x0000; r.x.cx = 0; r.x.dx = 0x0001;
    r.x.ds = (unsigned short)(__tb >> 4); r.x.si = (unsigned short)(__tb & 15);
    __dpmi_int(0x21, &r);
    if (r.x.flags & 1) return r.x.ax ? r.x.ax : 0xFFFF;
    r.x.bx = r.x.ax; r.h.ah = 0x3E;
    __dpmi_int(0x21, &r);
    return 0;
}

/* The count before "File(s)" on DIR's summary line, or -1 when no line holds one. */
static long dir_files(const char *file, long *lines)
{
    char line[512], *p;
    long files = -1;
    FILE *f = fopen(file, "r");
    *lines = 0;
    if (!f) return -1;
    while (fgets(line, sizeof line, f)) {
        (*lines)++;
        p = strstr(line, "File(s)");
        if (p) files = atol(line);
    }
    fclose(f);
    return files;
}

char **__crt0_glob_function(char *arg)
{
    (void)arg;
    return 0;
}

int main(int argc, char **argv)
{
    FILE *out;
    if (argc == 4 && strcmp(argv[1], "w") == 0) {
        touch(argv[2]);
        wait_for(argv[3]);
        return 0;
    }
    if (argc == 7 && (strcmp(argv[1], "o") == 0 || strcmp(argv[1], "f") == 0)) {
        int rc;
        const char *path = argv[2];
        touch(argv[4]);
        wait_for(argv[5]);
        if (argv[1][0] == 'o') rc = open_716c(path);
        else {
            FILE *f = fopen(path, "rb");
            rc = f ? 0 : (errno ? errno : 0xFFFF);
            if (f) fclose(f);
        }
        touch(argv[3]);
        out = fopen(argv[6], "w");
        if (!out) return 3;
        fprintf(out, "p5rep|mode=%c open=%04X\nend|lines=1\n", argv[1][0], rc);
        fclose(out);
        return 0;
    }
    if (argc == 4 && strcmp(argv[1], "m") == 0) {
        long lines, files = dir_files(argv[2], &lines);
        out = fopen(argv[3], "w");
        if (!out) return 3;
        if (files < 0) fprintf(out, "p5rep|mode=m files=none lines=%ld\nend|lines=1\n", lines);
        else fprintf(out, "p5rep|mode=m files=%ld lines=%ld\nend|lines=1\n", files, lines);
        fclose(out);
        return 0;
    }
    fprintf(stderr, "usage: P5REP w <ready> <go> | o|f <path> <stop> <ready> <go> <output> | m <dir output> <output>\n");
    return 2;
}
