/* The fuzz gate's canary: the same pre-scan and flags, trapping as soon as
 * the pre-scan accepts an input, which the seed corpus guarantees.
 * tools/run-fuzz requires this to crash before trusting the real target: a
 * gate is trusted once it has been seen to fail. */
#include <stdint.h>

#include "zsg_scan.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    zsg_limits lim = {64.0 * 1024 * 1024, 1e5, 256, 1};
    zsg_scan scan;
    zsg_status st = zsg_scan_run((const char *) data, size, &lim, &scan);
    zsg_scan_free(&scan);
    if (st == ZSG_OK)
        __builtin_trap();
    return 0;
}
