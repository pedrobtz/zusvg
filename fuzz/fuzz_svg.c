/* The fuzz target (.agents/design.md §15, roadmap Stage 5): the pre-scan,
 * plutosvg's loader and a 64 by 64 render, as zusvg runs them, without R.
 *
 * Invariants, each a crash if broken:
 *   - no crash, leak or undefined behaviour (ASan, UBSan);
 *   - the pre-scan mirrors the loader: an input it refuses as malformed
 *     (ZSG_ERR_SYNTAX) is one the loader refuses too;
 *   - every object made is destroyed on every path (LeakSanitizer). */
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include <plutosvg.h>

#include "zsg_scan.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
    zsg_limits lim = {64.0 * 1024 * 1024, 1e5, 256, 1};
    zsg_scan scan;
    zsg_status st = zsg_scan_run((const char *) data, size, &lim, &scan);
    zsg_scan_free(&scan);
    if (size > 2147483647u)
        return 0;

    char *copy = malloc(size ? size : 1);
    if (copy == NULL)
        return 0;
    memcpy(copy, data, size);
    plutosvg_document_t *doc =
        plutosvg_document_load_from_data(copy, (int) size, -1, -1, free, copy);
    if (st == ZSG_ERR_SYNTAX && doc != NULL)
        __builtin_trap();
    if (doc == NULL)
        return 0;

    if (st == ZSG_OK) {
        plutovg_rect_t r;
        plutosvg_document_extents(doc, NULL, &r);
        float w = plutosvg_document_get_width(doc);
        float h = plutosvg_document_get_height(doc);
        plutovg_surface_t *surface = plutovg_surface_create(64, 64);
        if (surface != NULL) {
            plutovg_canvas_t *canvas = plutovg_canvas_create(surface);
            plutovg_canvas_scale(canvas, 64.f / w, 64.f / h);
            plutovg_color_t black = {0, 0, 0, 1};
            plutosvg_document_render(doc, NULL, canvas, &black, NULL, NULL);
            plutovg_canvas_destroy(canvas);
            plutovg_surface_destroy(surface);
        }
    }
    plutosvg_document_destroy(doc);
    return 0;
}
