/* The document (.agents/design.md §4, §13): a finalized external pointer
 * owning plutosvg's document, the copy of the input bytes it points into,
 * and the pre-scan's arrays. */
#ifndef ZSG_DOC_H
#define ZSG_DOC_H

#include <plutosvg.h>

#include "zusvg.h"
#include "zsg_scan.h"

typedef struct {
    plutosvg_document_t *doc; /* owns `bytes` once loaded */
    char *bytes;              /* the input copy, until plutosvg owns it */
    zsg_scan scan;
} zsg_doc;

/* The loaded document behind an svg_document's pointer, or NULL if the
 * pointer is dead (a saved and restored object). */
plutosvg_document_t *zsg_doc_get(SEXP ptr);

#endif
