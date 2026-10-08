/* The pre-scan (.agents/design.md §4, §12): one pass over the input bytes,
 * before plutosvg sees them, that enforces the limits and records what the
 * package needs to report about a document. It contains no R, so the fuzz
 * target can run it alone. */
#ifndef ZSG_SCAN_H
#define ZSG_SCAN_H

#include <stddef.h>

/* Statuses travel to R by enumerator name (zsg_status_name()); R maps each
 * to a condition class. Never reorder without updating R/conditions.R. */
typedef enum {
    ZSG_OK = 0,
    ZSG_ERR_ENCODING, /* not UTF-8, or a NUL byte */
    ZSG_ERR_SYNTAX,   /* plutosvg's loader would refuse the document */
    ZSG_ERR_SIZE,     /* max_size */
    ZSG_ERR_ELEMENTS, /* max_elements */
    ZSG_ERR_DEPTH,    /* max_depth */
    ZSG_ERR_IMAGE,    /* an <image> element with images = FALSE */
    ZSG_ERR_NOMEM,    /* an allocation failed */
    ZSG_ERR_LOAD,     /* plutosvg_document_load_from_data() returned NULL */
    ZSG_STATUS_COUNT
} zsg_status;

const char *zsg_status_name(zsg_status status);

#define ZSG_NO_OFFSET ((size_t) -1)

typedef struct {
    double max_size;     /* bytes; may be Inf */
    double max_elements; /* start tags; may be Inf */
    double max_depth;    /* element nesting; may be Inf */
    int images;          /* 0: refuse any <image> element */
} zsg_limits;

/* The attributes the pre-scan records, for what R reports about a document
 * (clip paths, design D15). The id is recorded separately. */
#define ZSG_ATTR_COUNT 9
const char *zsg_attr_name(int attr);

typedef struct {
    size_t elem;          /* index of the element entry */
    int name;             /* 1-based index into zsg_attr_name() */
    size_t off;           /* byte offset of the trimmed value */
    size_t len;
} zsg_attr;

/* The seventeen elements plutosvg builds, as zsg_tag_name() names them.
 * Every other element is skipped with its subtree, as the loader does. */
#define ZSG_TAG_COUNT 17
const char *zsg_tag_name(int tag);

typedef struct {
    zsg_status status;
    size_t offset;        /* byte offset of the fault, or ZSG_NO_OFFSET */
    size_t start_tags;    /* every start tag, built or skipped */
    size_t n_text;        /* <text> start tags */
    size_t n_image;       /* <image> start tags */
    /* One entry per element plutosvg builds, in document order. */
    size_t n;
    size_t cap;
    int *parent;          /* index of the parent entry, or -1 */
    unsigned char *tag;   /* 1-based index into zsg_tag_name() */
    size_t *n_text_in;    /* <text> start tags in its subtree */
    size_t *id_off;       /* byte offset of the id value */
    size_t *id_len;       /* its length; (size_t) -1 when there is no id */
    /* Recorded attributes, in document order. */
    size_t n_attr;
    size_t attr_cap;
    zsg_attr *attrs;
} zsg_scan;

/* Scans data[0, n) under the limits. Returns scan->status. The arrays are
 * malloc()ed; zsg_scan_free() releases them, whatever the status. */
zsg_status zsg_scan_run(const char *data, size_t n, const zsg_limits *limits,
                        zsg_scan *scan);
void zsg_scan_free(zsg_scan *scan);

#endif
