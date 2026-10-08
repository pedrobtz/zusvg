#include <string.h>

#include <plutosvg.h>

#include "zusvg.h"
#include "zsg_vendor.h"

/* A 4 by 4 document filled with opaque red. Loading and rendering it proves
 * both vendored libraries are linked and working, before any of the
 * package's own loading or rendering code exists. */
static const char smoke_svg[] =
    "<svg xmlns='http://www.w3.org/2000/svg' width='4' height='4'>"
    "<rect width='4' height='4' fill='#ff0000'/></svg>";

static int smoke_renders(void)
{
    plutosvg_document_t *doc = plutosvg_document_load_from_data(
        smoke_svg, (int) strlen(smoke_svg), -1, -1, NULL, NULL);
    if (doc == NULL)
        return 0;
    plutovg_surface_t *surface =
        plutosvg_document_render_to_surface(doc, NULL, -1, -1, NULL, NULL, NULL);
    int ok = 0;
    if (surface != NULL) {
        const unsigned char *data = plutovg_surface_get_data(surface);
        unsigned int px;
        memcpy(&px, data, sizeof px);
        /* Premultiplied ARGB in native endian: opaque red is 0xFFFF0000. */
        ok = plutovg_surface_get_width(surface) == 4 &&
             plutovg_surface_get_height(surface) == 4 && px == 0xFFFF0000u;
        plutovg_surface_destroy(surface);
    }
    plutosvg_document_destroy(doc);
    return ok;
}

SEXP zusvg_build_info(void)
{
    const char *names[] = {"plutosvg_version", "plutovg_version",
                           "plutosvg_tag", "plutosvg_commit",
                           "plutovg_tag", "plutovg_commit",
                           "patches", "smoke_ok", ""};
    SEXP out = PROTECT(Rf_mkNamed(VECSXP, names));
    SET_VECTOR_ELT(out, 0, Rf_mkString(plutosvg_version_string()));
    SET_VECTOR_ELT(out, 1, Rf_mkString(plutovg_version_string()));
    SET_VECTOR_ELT(out, 2, Rf_mkString(ZSG_PLUTOSVG_TAG));
    SET_VECTOR_ELT(out, 3, Rf_mkString(ZSG_PLUTOSVG_COMMIT));
    SET_VECTOR_ELT(out, 4, Rf_mkString(ZSG_PLUTOVG_TAG));
    SET_VECTOR_ELT(out, 5, Rf_mkString(ZSG_PLUTOVG_COMMIT));
    SET_VECTOR_ELT(out, 6, Rf_mkString(ZSG_PATCHES));
    SET_VECTOR_ELT(out, 7, Rf_ScalarLogical(smoke_renders()));
    UNPROTECT(1);
    return out;
}
