/* Rendering (.agents/design.md §6, §13). plutovg draws straight into the
 * caller's buffer -- the integer vector that becomes the nativeRaster --
 * through plutovg_surface_create_for_data(), so the only pass after drawing
 * is the in-place conversion from premultiplied ARGB to straight RGBA, which
 * on a little-endian machine is R's packed ABGR (§6.2). Between creating the
 * surface and destroying it nothing calls R, so nothing can longjmp through
 * plutovg's frames and leave its objects behind. */
#include <Rconfig.h>
#include <stdint.h>

#include "zsg_doc.h"

#ifdef WORDS_BIGENDIAN
/* Straight RGBA bytes read as a big-endian word are 0xRRGGBBAA; R's packed
 * colour is A << 24 | B << 16 | G << 8 | R whatever the byte order. */
static void rgba_to_native(uint32_t *px, size_t n)
{
    for (size_t i = 0; i < n; i++) {
        uint32_t v = px[i];
        px[i] = (v >> 24) | ((v >> 8) & 0xFF00u) | ((v << 8) & 0xFF0000u) | (v << 24);
    }
}
#endif

static plutovg_color_t as_color(SEXP x)
{
    const double *v = REAL(x);
    plutovg_color_t c = {(float) v[0], (float) v[1], (float) v[2], (float) v[3]};
    return c;
}

/* zusvg_render_native(ptr, buf, box, background, color, fail): draws the
 * document into `buf`, an integer vector of width * height, where width and
 * height are its "dim" attribute's second and first elements, already
 * checked in R. `box` is c(x, y, w, h), the part of the document mapped onto
 * the whole buffer. Returns the status name. `fail` is a test hook: 1
 * simulates a surface allocation failure, 2 a failed render. */
SEXP zusvg_render_native(SEXP ptr, SEXP buf, SEXP box, SEXP background,
                         SEXP color, SEXP fail)
{
    plutosvg_document_t *doc = zsg_doc_get(ptr);
    if (doc == NULL)
        return Rf_mkString("ZSG_ERR_DEAD");
    SEXP dim = Rf_getAttrib(buf, R_DimSymbol);
    int height = INTEGER(dim)[0];
    int width = INTEGER(dim)[1];
    const double *b = REAL(box);
    plutovg_color_t bg = as_color(background);
    plutovg_color_t current = as_color(color);
    int hook = Rf_asInteger(fail);
    unsigned char *data = (unsigned char *) INTEGER(buf);

    plutovg_surface_t *surface = hook == 1 ? NULL :
        plutovg_surface_create_for_data(data, width, height, width * 4);
    if (surface == NULL)
        return Rf_mkString("ZSG_ERR_NOMEM");
    plutovg_canvas_t *canvas = plutovg_canvas_create(surface);
    plutovg_surface_clear(surface, &bg);
    plutovg_canvas_scale(canvas, (float) (width / b[2]), (float) (height / b[3]));
    plutovg_canvas_translate(canvas, (float) -b[0], (float) -b[1]);
    int ok = hook != 2 &&
        plutosvg_document_render(doc, NULL, canvas, &current, NULL, NULL);
    plutovg_canvas_destroy(canvas);
    plutovg_surface_destroy(surface);
    if (!ok)
        return Rf_mkString("ZSG_ERR_RENDER");

    plutovg_convert_argb_to_rgba(data, data, width, height, width * 4);
#ifdef WORDS_BIGENDIAN
    rgba_to_native((uint32_t *) data, (size_t) width * (size_t) height);
#endif
    return Rf_mkString("ZSG_OK");
}
