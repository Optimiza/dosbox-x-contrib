/* XCOMSIM.EXE: a model of the directory calls upstream issue 4904 reports from X-COM Apocalypse,
 * built from two sources and nothing of the game itself:
 *
 *   - measured: the game's FindFirst lookups, in their order, each with the name as the game
 *     passed it (slashes, case and trailing spaces kept) and its attribute word, read from an
 *     INT 21h trace of the game and written to <calls file> by xcomsim/extract.sh. A load is the
 *     whole sequence once; the lookups on the CD are skipped, being another drive's.
 *   - described: the reporter's listing, two searches each through its own DTA, FindFirst on
 *     the first, FindFirst on the second, then FindNext on each in turn. The trace of the game
 *     holds no FindNext, so this half is the issue's account, not a measure.
 *
 *   usage: XCOMSIM <calls file> <game folder> <folder A> <folder B> <output file>
 *                  [--loads <n>] [--listing-at <lookup>] [--between <n>] [--relay]
 *          e.g. XCOMSIM C:\CALLS.TXT D:\XCOMA D:\LISTA D:\LISTB C:\XCOMSIM.TXT
 *
 * The game's folder is made the current directory of its drive, as the game's is, and every
 * lookup is: SetDTA to the lookup DTA, FindFirst of the name with its attribute word, SetDTA back
 * to the DTA current before it. The DOS/4GW extender the game runs under relays each of the
 * game's lookups through one real-mode buffer, so the lookups share one DTA address here too.
 * The loads run one after the other; once <lookup> lookups are made (the listing point), the
 * listing starts, and from then on <n> lookups go between one FindNext and the next. The loads
 * go on past their count until both listings have ended.
 *
 * With --relay the listing goes through the lookups' buffer too, its 43 bytes copied out after
 * each call and back before each FindNext: what the extender must do to relay a protected-mode
 * program's FindNext through its one real-mode buffer. The one address is measured (every SetDTA
 * the extender made pointed at it); the copy is inferred, there being no FindNext in the trace.
 *
 * <folder A> holds files whose names start with A, <folder B> with B, so an entry handed back
 * from the wrong search shows in its name. Each folder is listed whole once first: its count is
 * what the interleaved listing is expected to return. The output ends:
 *
 *   listing=<found>/<expected> <found>/<expected> lost=<n>
 *   end|lines=<the lines above>
 *
 * xcomsim.sh beside this file runs it on two builds.
 */

#include <dpmi.h>
#include <go32.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/movedata.h>

#define BLOCK_PARAS 64
#define DTA_SIZE 64
#define DTA_PARK 0          /* the DTA current between the calls */
#define DTA_LOOKUP 1        /* the one buffer every lookup goes through */
#define DTA_A 2
#define DTA_B 3
#define PATH_OFF 512
#define PATH_MAX_LEN 400
#define NAME_OFF 30
#define DTA_BYTES 43
#define LISTING_ATTR 0x00   /* plain files: no "." or ".." to count */
#define NO_MORE_FILES 0x12
#define CALLS_MOST 512
#define FOLDER_MOST 1000    /* the highest file number a listing folder may hold, plus one */
#define MISMATCHES_SHOWN 20
/* Defaults: the listing starts a few dozen lookups short of the emulator's 2,048 search slots and
 * runs through them, two lookups between turns as the game makes per button click (it looks
 * BUTTNDRP.RAW up twice). */
#define SLOTS 2048
#define LISTING_AT_DEFAULT 1960
#define BETWEEN_DEFAULT 2

_Static_assert(DTA_B * DTA_SIZE + DTA_SIZE <= PATH_OFF, "the DTAs overlap the path");
_Static_assert(PATH_OFF + PATH_MAX_LEN + 1 <= BLOCK_PARAS * 16, "the path overflows the block");

char **__crt0_glob_function(char *arg)
{
    (void)arg;
    return 0;
}

struct call {
    char name[PATH_MAX_LEN + 1];
    unsigned short cx;
    int found;              /* the game's answer: 1 found, else 0 and err */
    unsigned short err;
};

struct listing {
    char letter;
    int dta;
    int expected;
    int found;
    int foreign;            /* entries of another folder, or one this listing already returned */
    int live;
    unsigned char seen[FOLDER_MOST];
};

static unsigned long g_lin;
static unsigned short g_seg;
static FILE *g_out;
static int g_lines;
static int g_relay;
static struct call g_calls[CALLS_MOST];

static void usage(FILE *to)
{
    fprintf(to,
        "usage: XCOMSIM <calls file> <game folder> <folder A> <folder B> <output file>\n"
        "               [--loads <n>] [--listing-at <lookup>] [--between <n>] [--relay]\n"
        "\n"
        "A model, not the game: X-COM Apocalypse's FindFirst lookups as measured from its INT 21h\n"
        "trace (the calls file), replayed in order as loads, and the two-DTA listing upstream\n"
        "issue 4904's reporter describes, FindNext on each in turn with lookups between turns.\n"
        "\n"
        "  --loads <n>           loads of the whole sequence at least (default: enough to pass %d\n"
        "                        lookups)\n"
        "  --listing-at <lookup> lookups made before the listing starts (default %d)\n"
        "  --between <n>         lookups between one FindNext and the next (default %d)\n"
        "  --relay               the listing goes through the lookups' one DTA, its bytes copied\n"
        "                        out and back, as the game's extender relays a protected-mode DTA\n",
        SLOTS, LISTING_AT_DEFAULT, BETWEEN_DEFAULT);
}

static void say(const char *fmt, ...) __attribute__((format(printf, 1, 2)));
static void say(const char *fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    vfprintf(g_out, fmt, ap);
    va_end(ap);
    fputc('\n', g_out);
    g_lines++;
}

static int int21(__dpmi_regs *r)
{
    __dpmi_int(0x21, r);
    return (r->x.flags & 1) ? r->x.ax : 0;
}

static void set_dta(int dta)
{
    __dpmi_regs r;
    memset(&r, 0, sizeof r);
    r.h.ah = 0x1A; r.x.ds = g_seg; r.x.dx = dta * DTA_SIZE;
    __dpmi_int(0x21, &r);
}

static int first(int dta, const char *path, unsigned short attr)
{
    __dpmi_regs r;
    int err;
    set_dta(dta);
    dosmemput(path, strlen(path) + 1, g_lin + PATH_OFF);
    memset(&r, 0, sizeof r);
    r.h.ah = 0x4E; r.x.cx = attr; r.x.ds = g_seg; r.x.dx = PATH_OFF;
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

/* The game's folder, made the current directory of its drive by raw calls, so that libc makes no
 * call of its own on that drive. */
static int enter(const char *folder)
{
    __dpmi_regs r;
    char letter = folder[0];
    if (letter >= 'a' && letter <= 'z') letter -= 'a' - 'A';
    if (letter < 'A' || letter > 'Z' || folder[1] != ':') return 1;
    memset(&r, 0, sizeof r);
    r.h.ah = 0x0E; r.h.dl = (unsigned char)(letter - 'A');
    __dpmi_int(0x21, &r);
    dosmemput(folder, strlen(folder) + 1, g_lin + PATH_OFF);
    memset(&r, 0, sizeof r);
    r.h.ah = 0x3B; r.x.ds = g_seg; r.x.dx = PATH_OFF;
    return int21(&r);
}

static int read_calls(const char *path, int *cd_skipped)
{
    char line[600], *field[6], *p;
    int n = 0, i;
    FILE *f = fopen(path, "r");
    if (!f) return -1;
    *cd_skipped = 0;
    while (fgets(line, sizeof line, f)) {
        line[strcspn(line, "\r\n")] = 0;
        if (line[0] == '#' || line[0] == 0) continue;
        /* n|caller|cx|drive|answer|name: the name is the rest of the line, '|' and all. */
        p = line;
        for (i = 0; i < 5; i++) {
            field[i] = p;
            p = strchr(p, '|');
            if (!p) { fclose(f); return -2; }
            *p++ = 0;
        }
        field[5] = p;
        if (strcmp(field[3], "cd") == 0) { (*cd_skipped)++; continue; }
        if (strcmp(field[3], "c") != 0 || strlen(field[5]) > PATH_MAX_LEN || n == CALLS_MOST) { fclose(f); return -2; }
        strcpy(g_calls[n].name, field[5]);
        g_calls[n].cx = (unsigned short)strtoul(field[2], NULL, 16);
        g_calls[n].found = strcmp(field[4], "found") == 0;
        g_calls[n].err = 0;
        if (!g_calls[n].found) {
            if (strncmp(field[4], "err=", 4) != 0) { fclose(f); return -2; }
            g_calls[n].err = (unsigned short)strtoul(field[4] + 4, NULL, 16);
        }
        n++;
    }
    fclose(f);
    return n;
}

static int g_lookups, g_as_the_game, g_mismatches;

static void lookup(int count)
{
    const struct call *c = &g_calls[g_lookups % count];
    int err = first(DTA_LOOKUP, c->name, c->cx);
    int same = c->found ? err == 0 : err == c->err;
    char game[12], here[12];
    if (same) g_as_the_game++;
    else if (++g_mismatches <= MISMATCHES_SHOWN) {
        if (c->found) strcpy(game, "found"); else sprintf(game, "err=%04X", c->err);
        if (err == 0) strcpy(here, "found"); else sprintf(here, "err=%04X", err);
        say("lookup-differs|%d|%s|game=%s here=%s", g_lookups, c->name, game, here);
    }
    g_lookups++;
}

static void dta_copy(int from, int to)
{
    char bytes[DTA_BYTES];
    dosmemget(g_lin + from * DTA_SIZE, DTA_BYTES, bytes);
    dosmemput(bytes, DTA_BYTES, g_lin + to * DTA_SIZE);
}

/* The listing's FindFirst and FindNext, through its own DTA or relayed through the lookups'. */
static int listing_first(int dta, const char *pattern)
{
    int err;
    if (!g_relay) return first(dta, pattern, LISTING_ATTR);
    err = first(DTA_LOOKUP, pattern, LISTING_ATTR);
    dta_copy(DTA_LOOKUP, dta);
    return err;
}

static int listing_next(int dta)
{
    int err;
    if (!g_relay) return next(dta);
    dta_copy(dta, DTA_LOOKUP);
    err = next(DTA_LOOKUP);
    dta_copy(DTA_LOOKUP, dta);
    return err;
}

/* The DTA's name, counted against the listing: a name of its folder it has not returned yet. */
static void take(struct listing *l)
{
    char name[13];
    int number;
    dosmemget(g_lin + l->dta * DTA_SIZE + NAME_OFF, 13, name);
    name[12] = 0;
    number = (name[0] == l->letter) ? atoi(name + 1) : -1;
    if (number < 0 || number >= FOLDER_MOST || l->seen[number]) { l->foreign++; return; }
    l->seen[number] = 1;
    l->found++;
}

static int whole(int dta, const char *pattern)
{
    int n = 0;
    if (first(dta, pattern, LISTING_ATTR) != 0) return 0;
    do n++; while (next(dta) == 0);
    return n;
}

static void turn(struct listing *l)
{
    int err;
    if (!l->live) return;
    err = listing_next(l->dta);
    if (err == 0) { take(l); return; }
    l->live = 0;
    if (l->found < l->expected || err != NO_MORE_FILES)
        say("findnext-failed|%c|after=%d of %d|error=%04X|lookups=%d", l->letter, l->found, l->expected, err, g_lookups);
}

static int number_arg(const char *s, int *out)
{
    char *end;
    long v = strtol(s, &end, 10);
    if (*s == 0 || *end != 0 || v < 0 || v > 1000000) return 1;
    *out = (int)v;
    return 0;
}

int main(int argc, char **argv)
{
    char pattern_a[300], pattern_b[300];
    static struct listing a, b;
    struct listing *whose;
    int count, cd_skipped, sel, s, i, loads = -1, listing_at = LISTING_AT_DEFAULT, between = BETWEEN_DEFAULT;
    int started = 0, since = 0;
    const char *positional[5];
    int npos = 0;

    for (i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--help") == 0) { usage(stdout); return 0; }
        if (strcmp(argv[i], "--relay") == 0) { g_relay = 1; continue; }
        if (strncmp(argv[i], "--", 2) == 0) {
            int *target = strcmp(argv[i], "--loads") == 0 ? &loads
                        : strcmp(argv[i], "--listing-at") == 0 ? &listing_at
                        : strcmp(argv[i], "--between") == 0 ? &between : NULL;
            if (!target || i + 1 == argc || number_arg(argv[i + 1], target)) { usage(stderr); return 2; }
            i++;
            continue;
        }
        if (npos == 5) { usage(stderr); return 2; }
        positional[npos++] = argv[i];
    }
    if (npos != 5 || strlen(positional[2]) > 250 || strlen(positional[3]) > 250) { usage(stderr); return 2; }

    count = read_calls(positional[0], &cd_skipped);
    if (count <= 0) { fprintf(stderr, "XCOMSIM: no lookup could be read from %s\n", positional[0]); return 3; }
    if (loads < 0) loads = SLOTS / count + 1;
    if (listing_at > loads * count) { fprintf(stderr, "XCOMSIM: the listing point is past the loads' %d lookups\n", loads * count); return 2; }

    s = __dpmi_allocate_dos_memory(BLOCK_PARAS, &sel);
    if (s == -1) { fprintf(stderr, "XCOMSIM: no conventional memory\n"); return 3; }
    g_seg = (unsigned short)s;
    g_lin = (unsigned long)g_seg << 4;
    set_dta(DTA_PARK);

    g_out = fopen(positional[4], "w");
    if (!g_out) { fprintf(stderr, "XCOMSIM: cannot write %s\n", positional[4]); return 3; }
    say("model|a model built from X-COM Apocalypse's measured FindFirst lookups and the two-DTA listing upstream issue 4904's reporter describes; not the game");
    say("calls|lookups_a_load=%d cd_skipped=%d loads=%d listing_at=%d between=%d listing_dta=%s", count, cd_skipped, loads, listing_at, between, g_relay ? "relayed" : "own");

    sprintf(pattern_a, "%s\\*.*", positional[2]);
    sprintf(pattern_b, "%s\\*.*", positional[3]);
    a.letter = 'A'; a.dta = DTA_A; a.expected = whole(DTA_A, pattern_a);
    b.letter = 'B'; b.dta = DTA_B; b.expected = whole(DTA_B, pattern_b);
    if (a.expected < 8 || b.expected < 8 || a.expected > FOLDER_MOST || b.expected > FOLDER_MOST) {
        say("folders|a=%d b=%d: not two folders of 8 to %d files", a.expected, b.expected, FOLDER_MOST);
        say("end|lines=%d", g_lines);
        fclose(g_out);
        return 3;
    }
    if (enter(positional[1]) != 0) {
        say("folders|cannot enter the game's folder %s", positional[1]);
        say("end|lines=%d", g_lines);
        fclose(g_out);
        return 3;
    }

    whose = &a;
    while (g_lookups < loads * count || !started || a.live || b.live) {
        if (!started && g_lookups == listing_at) {
            started = 1;
            a.live = listing_first(DTA_A, pattern_a) == 0;
            if (a.live) take(&a);
            b.live = listing_first(DTA_B, pattern_b) == 0;
            if (b.live) take(&b);
            since = between;
        }
        if (started && since == between && (a.live || b.live)) {
            if (!whose->live) whose = whose == &a ? &b : &a;
            turn(whose);
            whose = whose == &a ? &b : &a;
            since = 0;
            continue;
        }
        lookup(count);
        since++;
    }

    say("lookups|made=%d as_the_game=%d differ=%d loads=%d.%02d", g_lookups, g_as_the_game, g_mismatches,
        g_lookups / count, g_lookups % count * 100 / count);
    say("listing|A|%d of %d|foreign=%d", a.found, a.expected, a.foreign);
    say("listing|B|%d of %d|foreign=%d", b.found, b.expected, b.foreign);
    say("listing=%d/%d %d/%d lost=%d", a.found, a.expected, b.found, b.expected, a.expected - a.found + b.expected - b.found);
    fprintf(g_out, "end|lines=%d\n", g_lines);
    fclose(g_out);
    return 0;
}
