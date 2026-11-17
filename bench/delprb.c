/* DELPRB.EXE: what a program sees when files of a folder of long names are deleted one by one,
 * and when a search of that folder is still open across a delete or a create.
 *
 *   usage: DELPRB <drive> <output file>                     e.g. DELPRB D: C:\DELPRB.TXT
 *
 * delete.sh beside this file makes the folders. Each of S, L, W, A, P and C holds the eight files
 * "Alpha track 000000.mid" to "Alpha track 000007.mid", A holds PLAIN.TXT too, and each file
 * holds its own host name, so reading a file opened by a short name says which file that name
 * reached. R holds the eight directories "Alpha track 000000" to "Alpha track 000007", each with
 * an ID.TXT holding its directory's host name. A line:
 *
 *   del|shell|listed_after=<files a search lists> after the shell's DEL <drive>\S\*.MID, which
 *       delete.sh runs before this program
 *   del|loop41|found=<entries the search returned> deleted=<41h that succeeded>
 *       failed=<41h that failed> listed_after=<files a new search lists>
 *       (FindFirst *.MID, 41h on each short name returned, FindNext, as a program that deletes
 *       what it finds does)
 *   del|wild7141|ax=<AX after 7141h on *.MID with wildcards allowed> listed_after=<n>
 *   alias|<when>|<short name>=<what the file opened by it holds>, for each file listed:
 *       when is before, after-delete (41h on ALPHAT~1.MID) and after-create (3Ch on NEW.TXT)
 *   search|delete|<i>|<short name>=<what it opens>: one search of P read to its end, after its
 *       second entry the file it returned and the sixth file listed before it started deleted
 *   search|create|before|<short name>=<what it opens>, for each file C lists before its search
 *   search|create|<i>|<short name>=<what it opens>: one search of C read to its end, after
 *       its second entry NEW.TXT created by 3Ch, after its fourth "Alpha track new.mid" by 716Ch
 *       where 716Ch answers
 *   search|<delete|create>|listed_after=<files a new search lists>
 *   search|create|after|<short name>=<what it opens>, for each file C lists after its search
 *   rmdir|<when>|<short name>=<what its ID.TXT holds>, for each directory R lists: when is
 *       before and after-rd
 *   rmdir|removed|41h=<error of 41h on ALPHAT~1\ID.TXT> 3ah=<error of 3Ah on ALPHAT~1>
 *       listed_after=<directories a new search lists>
 *   rmdir|open-search|first=<error of 4Eh on ALPHAT~1\*.* before the RD> next=<error of the
 *       4Fh that continues it after the RD>
 *   alias|after-ren|<short name>=<what it opens>, for each file A lists after its first long name
 *       was renamed RENAMED.TXT by 56h: rename|file|from=<that short name> 56h=<error>
 *   rename|case|name=<the long name> 7156h=<error>: A's last "Alpha track 00000N.mid" the
 *       search finds renamed by 7156h to the same name in capitals, which leaves the host's name;
 *       alias|after-case|<short name>=<what it opens>, for each file A lists after it
 *   rename|remake|716ch=<error of 716Ch making the renamed file's old long name again>, then
 *       alias|after-remake|<short name>=<what it opens> for each file A lists
 *   mkdir|made|39h=<error of 39h on R\NEWDIR> 7139h=<error of 7139h on R\Alpha track new>
 *       listed_after=<directories R lists>
 *   mkdir|after-md|<short name>=<what its ID.TXT holds>, for each directory R lists after them
 *   mkdir|rd-new|3ah=<error of 3Ah removing NEWDIR again>, then mkdir|after-rd-new|<short
 *       name>=<what its ID.TXT holds> for each directory R lists
 *   rename|dir|from=<the first directory R lists with an ID.TXT> 56h=<error of 56h renaming it RENAMED>
 *       listed_after=<directories R lists>
 *   rename|after-ren|<short name>=<what its ID.TXT holds>, for each directory R lists after it
 *   mkdir|inside|<short name>=<n>, rename|inside|<short name>=<n>: the entries other than . and ..
 *       a search of <short name>\*.* lists, for each directory R lists after the MD and the rename
 *   rename|remake|7139h=<error of 7139h making the renamed directory's old long name again>, then
 *       rename|after-remake|<short name>=<what its ID.TXT holds> for each directory R lists
 *   end|lines=<n>
 *
 * "none" is a file the name does not open; a listed_after of -1 is a folder a search cannot reach. A folder that lists nothing ends the report before
 * its trailer: no line would mean anything.
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
#define DTA_SIZE 64
#define PATH_OFF 512
#define DATA_OFF 1024
#define NEW_OFF 2048
#define CONTENT 63
#define MAX_NAMES 16

static unsigned long g_lin;
static unsigned short g_seg;
static FILE *g_out;
static char g_renamed[64];
static int g_lines;
static const char *g_drive;

static void line(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    vfprintf(g_out, fmt, ap);
    va_end(ap);
    fputc('\n', g_out);
    g_lines++;
}

static const char *in(const char *folder, const char *name)
{
    static char path[4][300];
    static int turn;
    char *p = path[turn++ & 3];
    sprintf(p, "%s\\%s\\%s", g_drive, folder, name);
    return p;
}

static int int21(__dpmi_regs *r) { __dpmi_int(0x21, r); return (r->x.flags & 1) ? r->x.ax : 0; }

static void put_path(const char *path) { dosmemput(path, strlen(path) + 1, g_lin + PATH_OFF); }

static int path_call(int ax, int cx, const char *path, __dpmi_regs *r)
{
    put_path(path);
    memset(r, 0, sizeof *r);
    r->x.ax = (unsigned short)ax; r->x.cx = (unsigned short)cx; r->x.ds = g_seg; r->x.dx = PATH_OFF;
    return int21(r);
}

static int find_first_attr(const char *path, int attributes)
{
    __dpmi_regs r;
    return path_call(0x4E00, attributes, path, &r);
}

static int find_first(const char *path) { return find_first_attr(path, 0); }

static int find_next(void)
{
    __dpmi_regs r;
    memset(&r, 0, sizeof r);
    r.h.ah = 0x4F;
    return int21(&r);
}

static void dta_name(char *name)
{
    dosmemget(g_lin + DTA_OFF + 30, 13, name);
    name[12] = 0;
}

static int delete_file(const char *path)
{
    __dpmi_regs r;
    return path_call(0x4100, 0, path, &r);
}

/* 56h: DS:DX the name, ES:DI the new name. */
static int rename_entry(const char *from, const char *to)
{
    __dpmi_regs r;
    dosmemput(to, strlen(to) + 1, g_lin + NEW_OFF);
    put_path(from);
    memset(&r, 0, sizeof r);
    r.x.ax = 0x5600; r.x.ds = g_seg; r.x.dx = PATH_OFF; r.x.es = g_seg; r.x.di = NEW_OFF;
    return int21(&r);
}

static int rename_long(const char *from, const char *to)
{
    __dpmi_regs r;
    dosmemput(to, strlen(to) + 1, g_lin + NEW_OFF);
    put_path(from);
    memset(&r, 0, sizeof r);
    r.x.ax = 0x7156; r.x.ds = g_seg; r.x.dx = PATH_OFF; r.x.es = g_seg; r.x.di = NEW_OFF;
    return int21(&r);
}

static void close_handle(int handle)
{
    __dpmi_regs r;
    memset(&r, 0, sizeof r);
    r.h.ah = 0x3E; r.x.bx = (unsigned short)handle;
    int21(&r);
}

/* What the file a name opens holds, or "none". */
static void content(const char *path, char *text)
{
    __dpmi_regs r;
    int handle, got;
    strcpy(text, "none");
    if (path_call(0x3D00, 0, path, &r) != 0) return;
    handle = r.x.ax;
    memset(&r, 0, sizeof r);
    r.h.ah = 0x3F; r.x.bx = (unsigned short)handle; r.x.cx = CONTENT; r.x.ds = g_seg; r.x.dx = DATA_OFF;
    got = int21(&r) == 0 ? r.x.ax : 0;
    close_handle(handle);
    dosmemget(g_lin + DATA_OFF, (size_t)got, text);
    text[got] = 0;
}

static int create_83(const char *path)
{
    __dpmi_regs r;
    if (path_call(0x3C00, 0, path, &r) != 0) return r.x.ax;
    close_handle(r.x.ax);
    return 0;
}

static int create_long(const char *path)
{
    __dpmi_regs r;
    put_path(path);
    memset(&r, 0, sizeof r);
    r.x.ax = 0x716C; r.x.bx = 0x0002; r.x.dx = 0x0012; r.x.ds = g_seg; r.x.si = PATH_OFF;
    if (int21(&r) != 0) return r.x.ax;
    close_handle(r.x.ax);
    return 0;
}

/* The short names a search of folder\pattern returns, in its order. */
static int names(const char *folder, const char *pattern, char list[][13])
{
    int n = 0, err = find_first(in(folder, pattern));
    if (err == 3) return -1;
    if (err != 0) return 0;
    do { if (n < MAX_NAMES) dta_name(list[n++]); } while (find_next() == 0);
    return n;
}

static int listed(const char *folder)
{
    char list[MAX_NAMES][13];
    return names(folder, "*.*", list);
}

/* The short names of the directories a search of folder\*.* returns, dot entries left out. */
static int dir_names(const char *folder, char list[][13])
{
    unsigned char attr;
    int n = 0, err = find_first_attr(in(folder, "*.*"), 0x10);
    if (err == 3) return -1;
    if (err != 0) return 0;
    do {
        dosmemget(g_lin + DTA_OFF + 21, 1, &attr);
        if ((attr & 0x10) && n < MAX_NAMES) {
            dta_name(list[n]);
            if (list[n][0] != '.') n++;
        }
    } while (find_next() == 0);
    return n;
}

static int need(const char *folder, int want)
{
    int n = listed(folder);
    if (n == want) return 1;
    fprintf(stderr, "DELPRB: %s lists %d files, not %d\n", folder, n, want);
    return 0;
}

static int need_dirs(const char *folder, int want)
{
    char list[MAX_NAMES][13];
    int n = dir_names(folder, list);
    if (n == want) return 1;
    fprintf(stderr, "DELPRB: %s lists %d directories, not %d\n", folder, n, want);
    return 0;
}

static void loop41(void)
{
    char name[13];
    int found = 0, deleted = 0, failed = 0;
    if (find_first(in("L", "*.MID")) == 0) {
        do {
            dta_name(name);
            found++;
            if (delete_file(in("L", name)) == 0) deleted++; else failed++;
        } while (find_next() == 0);
    }
    line("del|loop41|found=%d deleted=%d failed=%d listed_after=%d", found, deleted, failed, listed("L"));
}

static void wild7141(void)
{
    __dpmi_regs r;
    put_path(in("W", "*.MID"));
    memset(&r, 0, sizeof r);
    r.x.ax = 0x7141; r.x.si = 1; r.x.ds = g_seg; r.x.dx = PATH_OFF;
    __dpmi_int(0x21, &r);
    line("del|wild7141|ax=%04X listed_after=%d", (r.x.flags & 1) ? r.x.ax : 0, listed("W"));
}

static void aliases(const char *when)
{
    char list[MAX_NAMES][13], text[CONTENT + 1];
    int i, n = names("A", "*.*", list);
    for (i = 0; i < n; i++) {
        content(in("A", list[i]), text);
        line("alias|%s|%s=%s", when, list[i], text);
    }
}

static void search_delete(void)
{
    char before[MAX_NAMES][13], name[13], text[CONTENT + 1];
    int i = 0, n = names("P", "*.MID", before);
    if (n < 6 || find_first(in("P", "*.MID")) != 0) { line("search|delete|listed=%d", n); return; }
    do {
        dta_name(name);
        i++;
        content(in("P", name), text);
        line("search|delete|%d|%s=%s", i, name, text);
        if (i == 2) {
            delete_file(in("P", name));
            delete_file(in("P", before[5]));
        }
    } while (find_next() == 0);
    line("search|delete|listed_after=%d", listed("P"));
}

static void search_create(void)
{
    char before[MAX_NAMES][13], name[13], text[CONTENT + 1];
    int i = 0, rc_short = -1, rc_long = -1, n = names("C", "*.*", before);
    for (i = 0; i < n; i++) {
        content(in("C", before[i]), text);
        line("search|create|before|%s=%s", before[i], text);
    }
    i = 0;
    if (find_first(in("C", "*.*")) != 0) { line("search|create|listed=0"); return; }
    do {
        dta_name(name);
        i++;
        content(in("C", name), text);
        line("search|create|%d|%s=%s", i, name, text);
        if (i == 2) rc_short = create_83(in("C", "NEW.TXT"));
        if (i == 4) rc_long = create_long(in("C", "Alpha track new.mid"));
    } while (find_next() == 0);
    line("search|create|3ch=%04X 716ch=%04X listed_after=%d", rc_short, rc_long, listed("C"));
    n = names("C", "*.*", before);
    for (i = 0; i < n; i++) {
        content(in("C", before[i]), text);
        line("search|create|after|%s=%s", before[i], text);
    }
}

static void dir_aliases(const char *step, const char *when)
{
    char list[MAX_NAMES][13], text[CONTENT + 1], id[40];
    int i, n = dir_names("R", list);
    for (i = 0; i < n; i++) {
        sprintf(id, "%.12s\\ID.TXT", list[i]);
        content(in("R", id), text);
        line("%s|%s|%s=%s", step, when, list[i], text);
    }
}

/* ALPHAT~1 emptied by 41h, then removed by 3Ah, with the other seven directories read before
 * and after. */
static void remove_dir(void)
{
    char list[MAX_NAMES][13];
    __dpmi_regs r;
    int rc_file, rc_dir, rc_first, rc_next;
    dir_aliases("rmdir", "before");
    rc_file = delete_file(in("R", "ALPHAT~1\\ID.TXT"));
    rc_first = find_first_attr(in("R", "ALPHAT~1\\*.*"), 0x10);
    rc_dir = path_call(0x3A00, 0, in("R", "ALPHAT~1"), &r);
    rc_next = find_next();
    line("rmdir|open-search|first=%04X next=%04X", rc_first, rc_next);
    line("rmdir|removed|41h=%04X 3ah=%04X listed_after=%d", rc_file, rc_dir, dir_names("R", list));
    dir_aliases("rmdir", "after-rd");
}

/* A's first long name renamed by 56h to an 8.3 name, A read after it. */
static void rename_file(void)
{
    char list[MAX_NAMES][13];
    int n = names("A", "*.MID", list);
    if (n > 0) content(in("A", list[0]), g_renamed);
    line("rename|file|from=%s 56h=%04X", n > 0 ? list[0] : "-", n > 0 ? rename_entry(in("A", list[0]), in("A", "RENAMED.TXT")) : 0xFFFF);
    aliases("after-ren");
}

/* A case-only rename by 7156h, where 7156h answers: the name resolves to the entry's own. */
static void rename_case(void)
{
    char from[40], to[40];
    int i, rc = 0xFFFF;
    for (i = 7; i >= 0; i--) {
        sprintf(from, "Alpha track %06d.mid", i);
        sprintf(to, "ALPHA TRACK %06d.MID", i);
        rc = rename_long(in("A", from), in("A", to));
        if (rc != 2) break;
    }
    line("rename|case|name=%s 7156h=%04X", i >= 0 ? from : "-", rc);
    aliases("after-case");
}

/* The renamed file's old long name made again by 716Ch, where it answers: a stale entry for it
 * would hand the new file the renamed one's short name. */
static void remake_file(void)
{
    line("rename|remake|716ch=%04X", g_renamed[0] ? create_long(in("A", g_renamed)) : 0xFFFF);
    aliases("after-remake");
}

/* What a search inside each directory R lists, dot entries left out. */
static void inside(const char *step)
{
    char list[MAX_NAMES][13], sub[40], name[13];
    int i, k, err, n = dir_names("R", list);
    for (i = 0; i < n; i++) {
        sprintf(sub, "%.12s\\*.*", list[i]);
        k = 0;
        err = find_first_attr(in("R", sub), 0x10);
        if (err == 0) {
            do { dta_name(name); if (name[0] != '.') k++; } while (find_next() == 0);
        }
        line("%s|inside|%s=%d", step, list[i], err == 0 || err == 18 ? k : -err);
    }
}

/* After the RD: R's NEWDIR made by 39h and "Alpha track new" by 7139h, then the first directory R
 * lists with an ID.TXT renamed RENAMED by 56h, R read after each. */
static void make_and_rename_dirs(void)
{
    char list[MAX_NAMES][13], from[13], text[CONTENT + 1], id[40];
    __dpmi_regs r;
    int i, n;
    int rc_short = path_call(0x3900, 0, in("R", "NEWDIR"), &r);
    int rc_long = path_call(0x7139, 0, in("R", "Alpha track new"), &r);
    int rc_ren = 0xFFFF;
    line("mkdir|made|39h=%04X 7139h=%04X listed_after=%d", rc_short, rc_long, dir_names("R", list));
    dir_aliases("mkdir", "after-md");
    inside("mkdir");
    line("mkdir|rd-new|3ah=%04X", path_call(0x3A00, 0, in("R", "NEWDIR"), &r));
    dir_aliases("mkdir", "after-rd-new");
    strcpy(from, "-");
    n = dir_names("R", list);
    for (i = 0; i < n; i++) {
        sprintf(id, "%.12s\\ID.TXT", list[i]);
        content(in("R", id), text);
        if (strcmp(text, "none") != 0) {
            strcpy(from, list[i]);
            strcpy(g_renamed, text);
            rc_ren = rename_entry(in("R", from), in("R", "RENAMED"));
            break;
        }
    }
    line("rename|dir|from=%s 56h=%04X listed_after=%d", from, rc_ren, dir_names("R", list));
    dir_aliases("rename", "after-ren");
    inside("rename");
    line("rename|remake|7139h=%04X", rc_ren == 0 ? path_call(0x7139, 0, in("R", g_renamed), &r) : 0xFFFF);
    dir_aliases("rename", "after-remake");
}

int main(int argc, char **argv)
{
    int sel;
    __dpmi_regs r;

    if (argc != 3) { fprintf(stderr, "usage: DELPRB <drive> <output file>\n"); return 2; }
    g_drive = argv[1];
    g_out = fopen(argv[2], "w");
    if (!g_out) { fprintf(stderr, "DELPRB: cannot write %s\n", argv[2]); return 2; }
    g_seg = (unsigned short)__dpmi_allocate_dos_memory(BLOCK_PARAS, &sel);
    if (g_seg == 0xFFFF) { fprintf(stderr, "DELPRB: no DOS memory\n"); return 3; }
    g_lin = (unsigned long)g_seg * 16;
    memset(&r, 0, sizeof r);
    r.h.ah = 0x1A; r.x.ds = g_seg; r.x.dx = DTA_OFF;
    __dpmi_int(0x21, &r);

    if (!need("L", 8) || !need("W", 8) || !need("A", 9) || !need("P", 8) || !need("C", 8)
        || !need_dirs("R", 8)) {
        fclose(g_out);
        return 3;
    }
    line("del|shell|listed_after=%d", listed("S"));
    loop41();
    wild7141();
    aliases("before");
    delete_file(in("A", "ALPHAT~1.MID"));
    aliases("after-delete");
    create_83(in("A", "NEW.TXT"));
    aliases("after-create");
    rename_file();
    rename_case();
    remake_file();
    search_delete();
    search_create();
    remove_dir();
    make_and_rename_dirs();
    fprintf(g_out, "end|lines=%d\n", g_lines);
    fclose(g_out);
    __dpmi_free_dos_memory(sel);
    return 0;
}
