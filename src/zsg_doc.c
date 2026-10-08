#include <stdlib.h>
#include <string.h>

#include "zsg_doc.h"

static SEXP doc_tag(void)
{
    static SEXP tag = NULL;
    if (tag == NULL)
        tag = Rf_install("zusvg_document");
    return tag;
}

static void doc_release(zsg_doc *zd)
{
    if (zd == NULL)
        return;
    /* Destroying the document frees the bytes through free_bytes(). */
    if (zd->doc != NULL)
        plutosvg_document_destroy(zd->doc);
    free(zd->bytes);
    zsg_scan_free(&zd->scan);
    free(zd);
}

static void doc_finalize(SEXP ptr)
{
    doc_release(R_ExternalPtrAddr(ptr));
    R_ClearExternalPtr(ptr);
}

static void free_bytes(void *closure)
{
    free(closure);
}

plutosvg_document_t *zsg_doc_get(SEXP ptr)
{
    if (TYPEOF(ptr) != EXTPTRSXP || R_ExternalPtrTag(ptr) != doc_tag())
        return NULL;
    zsg_doc *zd = R_ExternalPtrAddr(ptr);
    return zd == NULL ? NULL : zd->doc;
}

static SEXP fault(zsg_status status, double offset)
{
    const char *names[] = {"status", "offset", ""};
    SEXP out = PROTECT(Rf_mkNamed(VECSXP, names));
    SET_VECTOR_ELT(out, 0, Rf_mkString(zsg_status_name(status)));
    SET_VECTOR_ELT(out, 1, Rf_ScalarReal(offset));
    UNPROTECT(1);
    return out;
}

/* zusvg_load(x, width, height, limits, images): x a raw vector; width and
 * height the container size, or -1; limits c(max_size, max_elements,
 * max_depth). Returns list(status, offset) on a fault, else the document's
 * pointer and what the pre-scan found. Never raises: R maps the status to a
 * condition class (R/conditions.R). */
SEXP zusvg_load(SEXP x, SEXP width, SEXP height, SEXP limits, SEXP images)
{
    zsg_doc *zd = calloc(1, sizeof *zd);
    if (zd == NULL)
        return fault(ZSG_ERR_NOMEM, NA_REAL);
    /* The pointer exists before anything else is allocated, so an R error
     * from here on leaves its finalizer to release what was made. */
    SEXP ptr = PROTECT(R_MakeExternalPtr(zd, doc_tag(), R_NilValue));
    R_RegisterCFinalizerEx(ptr, doc_finalize, TRUE);

    zsg_limits lim = {REAL(limits)[0], REAL(limits)[1], REAL(limits)[2],
                      Rf_asLogical(images)};
    const char *data = (const char *) RAW(x);
    size_t n = (size_t) XLENGTH(x);
    if (zsg_scan_run(data, n, &lim, &zd->scan) != ZSG_OK) {
        size_t at = zd->scan.offset;
        SEXP out = fault(zd->scan.status, at == ZSG_NO_OFFSET ? NA_REAL : (double) at);
        UNPROTECT(1);
        return out;
    }

    zd->bytes = malloc(n);
    if (zd->bytes == NULL) {
        UNPROTECT(1);
        return fault(ZSG_ERR_NOMEM, NA_REAL);
    }
    memcpy(zd->bytes, data, n);
    /* plutosvg owns the bytes from here: on success it frees them when the
     * document is destroyed, and on failure it has already called
     * free_bytes() (design §9). */
    char *bytes = zd->bytes;
    zd->bytes = NULL;
    zd->doc = plutosvg_document_load_from_data(bytes, (int) n,
                                               (float) Rf_asReal(width),
                                               (float) Rf_asReal(height),
                                               free_bytes, bytes);
    if (zd->doc == NULL) {
        UNPROTECT(1);
        return fault(ZSG_ERR_LOAD, NA_REAL);
    }

    zsg_scan *s = &zd->scan;
    R_xlen_t ne = (R_xlen_t) s->n, na = (R_xlen_t) s->n_attr;
    /* Elements: one row per element plutosvg built, in document order. */
    SEXP ids = PROTECT(Rf_allocVector(STRSXP, ne));
    SEXP tags = PROTECT(Rf_allocVector(STRSXP, ne));
    SEXP parent = PROTECT(Rf_allocVector(INTSXP, ne));
    SEXP n_text = PROTECT(Rf_allocVector(REALSXP, ne));
    for (R_xlen_t i = 0; i < ne; i++) {
        SET_STRING_ELT(ids, i, s->id_len[i] == (size_t) -1 ? NA_STRING :
                       Rf_mkCharLenCE(data + s->id_off[i], (int) s->id_len[i], CE_UTF8));
        SET_STRING_ELT(tags, i, Rf_mkChar(zsg_tag_name(s->tag[i])));
        INTEGER(parent)[i] = s->parent[i] < 0 ? NA_INTEGER : s->parent[i] + 1;
        REAL(n_text)[i] = (double) s->n_text_in[i];
    }
    /* Attributes: element (1-based), name, value. */
    SEXP a_elem = PROTECT(Rf_allocVector(INTSXP, na));
    SEXP a_name = PROTECT(Rf_allocVector(STRSXP, na));
    SEXP a_value = PROTECT(Rf_allocVector(STRSXP, na));
    for (R_xlen_t i = 0; i < na; i++) {
        const zsg_attr *a = &s->attrs[i];
        INTEGER(a_elem)[i] = (int) a->elem + 1;
        SET_STRING_ELT(a_name, i, Rf_mkChar(zsg_attr_name(a->name)));
        SET_STRING_ELT(a_value, i, Rf_mkCharLenCE(data + a->off, (int) a->len, CE_UTF8));
    }

    const char *names[] = {"status", "ptr", "width", "height", "start_tags",
                           "n_text", "n_image", "ids", "tags", "parent",
                           "n_text_in", "attr_elem", "attr_name", "attr_value",
                           ""};
    SEXP out = PROTECT(Rf_mkNamed(VECSXP, names));
    SET_VECTOR_ELT(out, 0, Rf_mkString("ZSG_OK"));
    SET_VECTOR_ELT(out, 1, ptr);
    SET_VECTOR_ELT(out, 2, Rf_ScalarReal(plutosvg_document_get_width(zd->doc)));
    SET_VECTOR_ELT(out, 3, Rf_ScalarReal(plutosvg_document_get_height(zd->doc)));
    SET_VECTOR_ELT(out, 4, Rf_ScalarReal((double) s->start_tags));
    SET_VECTOR_ELT(out, 5, Rf_ScalarReal((double) s->n_text));
    SET_VECTOR_ELT(out, 6, Rf_ScalarReal((double) s->n_image));
    SET_VECTOR_ELT(out, 7, ids);
    SET_VECTOR_ELT(out, 8, tags);
    SET_VECTOR_ELT(out, 9, parent);
    SET_VECTOR_ELT(out, 10, n_text);
    SET_VECTOR_ELT(out, 11, a_elem);
    SET_VECTOR_ELT(out, 12, a_name);
    SET_VECTOR_ELT(out, 13, a_value);
    zsg_scan_free(s);
    UNPROTECT(9);
    return out;
}

/* zusvg_status_names(): every status C can report, for test-conditions.R. */
SEXP zusvg_status_names(void)
{
    SEXP out = PROTECT(Rf_allocVector(STRSXP, ZSG_STATUS_COUNT));
    for (int i = 0; i < ZSG_STATUS_COUNT; i++)
        SET_STRING_ELT(out, i, Rf_mkChar(zsg_status_name((zsg_status) i)));
    UNPROTECT(1);
    return out;
}

/* zusvg_doc_alive(ptr): FALSE for a saved and restored document. */
SEXP zusvg_doc_alive(SEXP ptr)
{
    return Rf_ScalarLogical(zsg_doc_get(ptr) != NULL);
}
