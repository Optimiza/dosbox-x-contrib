/*
 * SIDEFX: what an attribute change does besides changing the attribute, read from the guest.
 *   usage: SIDEFX <folder> <file of it> <held file> <go file> <report>
 * Lists <folder>\*.* and reads the drive's label (4Eh, attribute 08h), creates <held file> and
 * waits (4300h polls, no search) for <go file>, which the host writes after it has added NEW.TXT
 * to <folder>; lists and reads the label again; sets the read-only bit of <file> (4301h); lists
 * and reads the label a third time. Each step prints how many entries it listed, whether NEW.TXT
 * was among them, and the label.
 */
#include <dos.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

static FILE *out;

static void step(const char *name, const char *folder)
{
    struct find_t f;
    char pattern[160], drive_root[8], label[260] = "";
    int n = 0, seen = 0, rc;
    snprintf(pattern, sizeof pattern, "%s\\*.*", folder);
    for (rc = _dos_findfirst(pattern, _A_NORMAL | _A_RDONLY | _A_HIDDEN | _A_SYSTEM | _A_SUBDIR | _A_ARCH, &f);
         rc == 0; rc = _dos_findnext(&f)) {
        if (f.name[0] == '.') continue;
        n++;
        if (strcmp(f.name, "NEW.TXT") == 0) seen = 1;
    }
    snprintf(drive_root, sizeof drive_root, "%c:\\*.*", folder[0]);
    rc = _dos_findfirst(drive_root, _A_VOLID, &f);
    if (rc == 0) snprintf(label, sizeof label, "%s", f.name);
    fprintf(out, "sidefx|%s|listed=%d new=%d label_rc=%d label=%s\n", name, n, seen, rc, label);
}

int main(int argc, char **argv)
{
    FILE *held;
    unsigned attr;
    clock_t limit;
    int released = 1, rc;
    if (argc != 6) { fprintf(stderr, "usage: SIDEFX <folder> <file> <held> <go> <report>\n"); return 2; }
    out = fopen(argv[5], "w");
    if (!out) return 3;
    step("before", argv[1]);
    held = fopen(argv[3], "w");
    if (held) { fputs("held\n", held); fclose(held); }
    limit = clock() + 60 * CLOCKS_PER_SEC;
    while (_dos_getfileattr(argv[4], &attr) != 0) {
        if (clock() > limit) { released = 0; break; }
        delay(20);
    }
    fprintf(out, "sidefx|released=%d\n", released);
    step("after-host-create", argv[1]);
    rc = _dos_getfileattr(argv[2], &attr);
    if (rc == 0) rc = _dos_setfileattr(argv[2], attr | _A_RDONLY);
    fprintf(out, "sidefx|setattr|rc=%d\n", rc);
    step("after-setattr", argv[1]);
    fprintf(out, "sidefx|end\n");
    fclose(out);
    return 0;
}
