/* Rendering (.agents/design.md §6, §13). plutovg draws straight into the
 * caller's buffer -- the integer vector that becomes the nativeRaster --
 * through plutovg_surface_create_for_data(), so the only pass after drawing
 * is the in-place conversion from premultiplied ARGB to straight RGBA, which
 * on a little-endian machine is R's packed ABGR (§6.2). Between creating the
 * surface and destroying it nothing calls R, so nothing can longjmp through
 * plutovg's frames and leave its objects behind. */
#include <Rconfig.h>
#include <stdint.h>
#include <string.h>

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

/* The palette (design §6.3, §13): names and colours prepared before the
 * surface exists, read by the callback without touching R. */
typedef struct {
    int n;
    const char **names;
    int *lens;
    plutovg_color_t *colors;
} palette_t;

static bool palette_lookup(void *closure, const char *name, int length,
                           plutovg_color_t *color)
{
    const palette_t *p = closure;
    for (int i = 0; i < p->n; i++) {
        if (p->lens[i] == length && memcmp(p->names[i], name, (size_t) length) == 0) {
            *color = p->colors[i];
            return true;
        }
    }
    return false;
}

static plutovg_color_t as_color(SEXP x)
{
    const double *v = REAL(x);
    plutovg_color_t c = {(float) v[0], (float) v[1], (float) v[2], (float) v[3]};
    return c;
}

/* What a render needs, gathered from R before any plutovg object exists:
 * everything R allocates is allocated here (design §13). */
typedef struct {
    plutosvg_document_t *doc;
    unsigned char *data;
    int width, height;
    double box[4];
    plutovg_color_t bg, current;
    const char *element;
    palette_t pal;
    int hook;
} job_t;

static int job_init(job_t *j, SEXP ptr, SEXP buf, SEXP box, SEXP background,
                    SEXP color, SEXP id, SEXP pal_names, SEXP pal_colors, SEXP fail)
{
    j->doc = zsg_doc_get(ptr);
    if (j->doc == NULL)
        return 0;
    SEXP dim = Rf_getAttrib(buf, R_DimSymbol);
    j->height = INTEGER(dim)[0];
    j->width = INTEGER(dim)[1];
    j->data = (unsigned char *) INTEGER(buf);
    for (int k = 0; k < 4; k++)
        j->box[k] = REAL(box)[k];
    j->bg = as_color(background);
    j->current = as_color(color);
    j->element = Rf_isString(id) ? Rf_translateCharUTF8(STRING_ELT(id, 0)) : NULL;
    j->hook = Rf_asInteger(fail);
    palette_t pal = {LENGTH(pal_names), NULL, NULL, NULL};
    if (pal.n > 0) {
        pal.names = (const char **) R_alloc((size_t) pal.n, sizeof *pal.names);
        pal.lens = (int *) R_alloc((size_t) pal.n, sizeof *pal.lens);
        pal.colors = (plutovg_color_t *) R_alloc((size_t) pal.n, sizeof *pal.colors);
        const double *c = REAL(pal_colors);
        for (int i = 0; i < pal.n; i++) {
            pal.names[i] = Rf_translateCharUTF8(STRING_ELT(pal_names, i));
            pal.lens[i] = (int) strlen(pal.names[i]);
            plutovg_color_t ci = {(float) c[4 * i], (float) c[4 * i + 1],
                                  (float) c[4 * i + 2], (float) c[4 * i + 3]};
            pal.colors[i] = ci;
        }
    }
    j->pal = pal;
    return 1;
}

/* Draws the job onto `surface`, a premultiplied ARGB view of j->data.
 * Calls nothing in R. */
static int draw(job_t *j, plutovg_surface_t *surface)
{
    plutovg_canvas_t *canvas = plutovg_canvas_create(surface);
    plutovg_surface_clear(surface, &j->bg);
    plutovg_canvas_scale(canvas, (float) (j->width / j->box[2]),
                         (float) (j->height / j->box[3]));
    plutovg_canvas_translate(canvas, (float) -j->box[0], (float) -j->box[1]);
    int ok = j->hook != 2 &&
        plutosvg_document_render(j->doc, j->element, canvas, &j->current,
                                 j->pal.n > 0 ? palette_lookup : NULL, &j->pal);
    plutovg_canvas_destroy(canvas);
    return ok;
}

static plutovg_surface_t *job_surface(job_t *j)
{
    return j->hook == 1 ? NULL :
        plutovg_surface_create_for_data(j->data, j->width, j->height, j->width * 4);
}

/* zusvg_render_native(ptr, buf, box, background, color, id, pal_names,
 * pal_colors, fail): draws the document, or the element `id` when that is a
 * string, into `buf`, an integer vector of width * height, where width and
 * height are its "dim" attribute's second and first elements, already
 * checked in R. `box` is c(x, y, w, h), the part of the document mapped onto
 * the whole buffer. pal_names (without "--") and pal_colors (4 per name,
 * 0-1) answer CSS var(). Returns the status name. `fail` is a test hook: 1
 * simulates a surface allocation failure, 2 a failed render. */
SEXP zusvg_render_native(SEXP ptr, SEXP buf, SEXP box, SEXP background,
                         SEXP color, SEXP id, SEXP pal_names, SEXP pal_colors,
                         SEXP fail)
{
    job_t j;
    if (!job_init(&j, ptr, buf, box, background, color, id, pal_names, pal_colors, fail))
        return Rf_mkString("ZSG_ERR_DEAD");
    plutovg_surface_t *surface = job_surface(&j);
    if (surface == NULL)
        return Rf_mkString("ZSG_ERR_NOMEM");
    int ok = draw(&j, surface);
    plutovg_surface_destroy(surface);
    if (!ok)
        return Rf_mkString("ZSG_ERR_RENDER");

    plutovg_convert_argb_to_rgba(j.data, j.data, j.width, j.height, j.width * 4);
#ifdef WORDS_BIGENDIAN
    rgba_to_native((uint32_t *) j.data, (size_t) j.width * (size_t) j.height);
#endif
    return Rf_mkString("ZSG_OK");
}

/* The encoder's output (design §7): a growable malloc() buffer owned by an
 * external pointer, so an R error after encoding cannot leak it. */
typedef struct {
    unsigned char *data;
    size_t len, cap;
    int failed;
} growbuf_t;

static void growbuf_finalize(SEXP ptr)
{
    growbuf_t *g = R_ExternalPtrAddr(ptr);
    if (g != NULL) {
        free(g->data);
        free(g);
    }
    R_ClearExternalPtr(ptr);
}

/* stb_image_write's callback: runs inside plutovg, so it only records an
 * allocation failure and never calls R. */
static void growbuf_write(void *closure, void *data, int size)
{
    growbuf_t *g = closure;
    if (g->failed || size <= 0)
        return;
    if (g->len + (size_t) size > g->cap) {
        size_t cap = g->cap ? g->cap : 4096;
        while (cap < g->len + (size_t) size)
            cap *= 2;
        unsigned char *p = realloc(g->data, cap);
        if (p == NULL) {
            g->failed = 1;
            return;
        }
        g->data = p;
        g->cap = cap;
    }
    memcpy(g->data + g->len, data, (size_t) size);
    g->len += (size_t) size;
}

/* zusvg_render_encode(ptr, buf, box, background, color, id, pal_names,
 * pal_colors, fail, format, quality): as zusvg_render_native(), using `buf`
 * as scratch, then encodes the surface as PNG (format 0) or JPEG (format 1,
 * at `quality`). Returns the encoded bytes as a raw vector, or a status
 * name. */
SEXP zusvg_render_encode(SEXP ptr, SEXP buf, SEXP box, SEXP background,
                         SEXP color, SEXP id, SEXP pal_names, SEXP pal_colors,
                         SEXP fail, SEXP format, SEXP quality)
{
    growbuf_t *g = calloc(1, sizeof *g);
    if (g == NULL)
        return Rf_mkString("ZSG_ERR_NOMEM");
    SEXP gptr = PROTECT(R_MakeExternalPtr(g, R_NilValue, R_NilValue));
    R_RegisterCFinalizerEx(gptr, growbuf_finalize, TRUE);
    job_t j;
    if (!job_init(&j, ptr, buf, box, background, color, id, pal_names, pal_colors, fail)) {
        UNPROTECT(1);
        return Rf_mkString("ZSG_ERR_DEAD");
    }
    int jpeg = Rf_asInteger(format) == 1;
    int q = Rf_asInteger(quality);

    plutovg_surface_t *surface = job_surface(&j);
    if (surface == NULL) {
        UNPROTECT(1);
        return Rf_mkString("ZSG_ERR_NOMEM");
    }
    int ok = draw(&j, surface);
    int written = 0;
    if (ok) {
        written = jpeg ? plutovg_surface_write_to_jpg_stream(surface, growbuf_write, g, q)
                       : plutovg_surface_write_to_png_stream(surface, growbuf_write, g);
    }
    plutovg_surface_destroy(surface);
    if (!ok) {
        UNPROTECT(1);
        return Rf_mkString("ZSG_ERR_RENDER");
    }
    if (g->failed || j.hook == 3) {
        UNPROTECT(1);
        return Rf_mkString("ZSG_ERR_NOMEM");
    }
    if (!written) {
        UNPROTECT(1);
        return Rf_mkString("ZSG_ERR_ENCODE");
    }
    SEXP out = PROTECT(Rf_allocVector(RAWSXP, (R_xlen_t) g->len));
    memcpy(RAW(out), g->data, g->len);
    UNPROTECT(2);
    return out;
}

/* zusvg_extents(ptr, id): c(x, y, w, h) of the drawn content of the
 * document, or of the element `id` when that is a string; NULL if there is
 * no such element. */
SEXP zusvg_extents(SEXP ptr, SEXP id)
{
    plutosvg_document_t *doc = zsg_doc_get(ptr);
    if (doc == NULL)
        return Rf_mkString("ZSG_ERR_DEAD");
    const char *element = Rf_isString(id) ? Rf_translateCharUTF8(STRING_ELT(id, 0)) : NULL;
    plutovg_rect_t r;
    if (!plutosvg_document_extents(doc, element, &r))
        return R_NilValue;
    SEXP out = PROTECT(Rf_allocVector(REALSXP, 4));
    REAL(out)[0] = r.x;
    REAL(out)[1] = r.y;
    REAL(out)[2] = r.w;
    REAL(out)[3] = r.h;
    UNPROTECT(1);
    return out;
}

/* R's packed colour, whatever the byte order: R | G << 8 | B << 16 | A << 24. */
#define CH(v, k) ((unsigned) (((uint32_t) (v) >> (8 * (k))) & 0xFFu))

/* zusvg_native_to_array(buf): a height x width x 4 double array in [0, 1],
 * the shape rsvg::rsvg() returns (design §5). */
SEXP zusvg_native_to_array(SEXP buf)
{
    SEXP dim = Rf_getAttrib(buf, R_DimSymbol);
    R_xlen_t h = INTEGER(dim)[0], w = INTEGER(dim)[1], n = h * w;
    SEXP out = PROTECT(Rf_allocVector(REALSXP, n * 4));
    const int *px = INTEGER(buf);
    double *o = REAL(out);
    for (R_xlen_t y = 0; y < h; y++)
        for (R_xlen_t x = 0; x < w; x++) {
            int v = px[y * w + x];
            for (int k = 0; k < 4; k++)
                o[y + x * h + k * n] = CH(v, k) / 255.0;
        }
    SEXP d = PROTECT(Rf_allocVector(INTSXP, 3));
    INTEGER(d)[0] = (int) h;
    INTEGER(d)[1] = (int) w;
    INTEGER(d)[2] = 4;
    Rf_setAttrib(out, R_DimSymbol, d);
    UNPROTECT(2);
    return out;
}

/* zusvg_native_to_raw(buf): RGBA bytes with dim c(4, width, height), the
 * shape rsvg::rsvg_raw() returns (design §5). */
SEXP zusvg_native_to_raw(SEXP buf)
{
    SEXP dim = Rf_getAttrib(buf, R_DimSymbol);
    R_xlen_t h = INTEGER(dim)[0], w = INTEGER(dim)[1], n = h * w;
    SEXP out = PROTECT(Rf_allocVector(RAWSXP, n * 4));
    const int *px = INTEGER(buf);
    Rbyte *o = RAW(out);
    for (R_xlen_t i = 0; i < n; i++)
        for (int k = 0; k < 4; k++)
            o[4 * i + k] = (Rbyte) CH(px[i], k);
    SEXP d = PROTECT(Rf_allocVector(INTSXP, 3));
    INTEGER(d)[0] = 4;
    INTEGER(d)[1] = (int) w;
    INTEGER(d)[2] = (int) h;
    Rf_setAttrib(out, R_DimSymbol, d);
    UNPROTECT(2);
    return out;
}
