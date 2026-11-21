/* REDIR <file> <command line>: runs the line through COMMAND.COM with its output and errors
 * appended to <file>: DOS has no 2>. The line is read from the PSP's tail as typed,
 * since through argv the C library would quote its words and COMMAND.COM would not find them. */
#include <fcntl.h>
#include <go32.h>
#include <process.h>
#include <stdlib.h>
#include <string.h>
#include <sys/movedata.h>
#include <sys/system.h>
#include <unistd.h>

int main(void)
{
    unsigned char tail[129];
    char out[128], *p, *q;
    int fd;

    dosmemget(_go32_info_block.linear_address_of_original_psp + 0x80, 128, tail);
    tail[1 + tail[0]] = 0;
    p = (char *)tail + 1;
    if ((q = strchr(p, '\r')) != NULL) *q = 0;
    while (*p == ' ') p++;
    q = out;
    while (*p && *p != ' ' && q < out + sizeof out - 1) *q++ = *p++;
    *q = 0;
    while (*p == ' ') p++;
    if (!*out || !*p) return 2;
    fd = open(out, O_WRONLY | O_CREAT | O_APPEND | O_BINARY, 0666);
    if (fd < 0) return 3;
    dup2(fd, 1);
    dup2(fd, 2);
    close(fd);
    __system_flags |= __system_call_cmdproc;
    system(p);
    return 0;
}
