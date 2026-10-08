/* The pre-scan from the command line, for tools/run-mutation-check:
 *   probe FILE MAX_SIZE MAX_ELEMENTS MAX_DEPTH IMAGES
 * prints the status name. */
#include <stdio.h>
#include <stdlib.h>

#include "zsg_scan.h"

int main(int argc, char **argv)
{
    if (argc != 6)
        return 2;
    FILE *f = fopen(argv[1], "rb");
    if (f == NULL)
        return 2;
    static char buf[1 << 20];
    size_t n = fread(buf, 1, sizeof buf, f);
    fclose(f);
    zsg_limits lim = {atof(argv[2]), atof(argv[3]), atof(argv[4]), atoi(argv[5])};
    zsg_scan scan;
    zsg_status st = zsg_scan_run(buf, n, &lim, &scan);
    zsg_scan_free(&scan);
    printf("%s\n", zsg_status_name(st));
    return 0;
}
