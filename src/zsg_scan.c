/* The pre-scan (.agents/design.md §4, §12). It walks the bytes exactly as
 * plutosvg 0.0.8's plutosvg_document_load_from_data() does -- the same
 * BOM, XML declaration, comment, CDATA, DOCTYPE, tag and attribute rules,
 * the same seventeen element names, the same skipping of unknown elements
 * with their subtrees -- so what it counts is what the loader builds and a
 * document it accepts is one the loader accepts or refuses only for its
 * size (§11). It is not an XML parser (design D5). If a re-vendor changes
 * the loader, re-read it against this file.
 *
 * Each limit check carries a GUARD marker for tools/run-mutation-check. */
#include <stdlib.h>
#include <string.h>

#include <zufast/utf8.h>

#include "zsg_scan.h"

static const char *const status_names[ZSG_STATUS_COUNT] = {
    "ZSG_OK", "ZSG_ERR_ENCODING", "ZSG_ERR_SYNTAX", "ZSG_ERR_SIZE",
    "ZSG_ERR_ELEMENTS", "ZSG_ERR_DEPTH", "ZSG_ERR_IMAGE", "ZSG_ERR_NOMEM",
    "ZSG_ERR_LOAD"
};

const char *zsg_status_name(zsg_status status)
{
    return (status >= 0 && status < ZSG_STATUS_COUNT) ? status_names[status]
                                                      : "ZSG_ERR_UNKNOWN";
}

/* plutosvg's elementid() table, in its order. */
static const char *const tag_names[ZSG_TAG_COUNT] = {
    "circle", "clipPath", "defs", "ellipse", "g", "image", "line",
    "linearGradient", "path", "polygon", "polyline", "radialGradient",
    "rect", "stop", "svg", "symbol", "use"
};

static const char *const attr_names[ZSG_ATTR_COUNT] = {
    "clip-path", "clipPathUnits", "height", "style", "transform", "viewBox",
    "width", "x", "y"
};

const char *zsg_attr_name(int attr)
{
    return (attr >= 1 && attr <= ZSG_ATTR_COUNT) ? attr_names[attr - 1] : "";
}

static int attr_id(const char *name, size_t len)
{
    for (int i = 0; i < ZSG_ATTR_COUNT; i++) {
        if (strlen(attr_names[i]) == len && memcmp(attr_names[i], name, len) == 0)
            return i + 1;
    }
    return 0;
}

#define TAG_IMAGE 6 /* 1-based */
#define TAG_SVG 15

const char *zsg_tag_name(int tag)
{
    return (tag >= 1 && tag <= ZSG_TAG_COUNT) ? tag_names[tag - 1] : "";
}

/* plutosvg's lookupid(): names longer than MAX_NAME (19) are unknown. */
static int tag_id(const char *name, size_t len)
{
    if (len > 19)
        return 0;
    for (int i = 0; i < ZSG_TAG_COUNT; i++) {
        if (strlen(tag_names[i]) == len && memcmp(tag_names[i], name, len) == 0)
            return i + 1;
    }
    return 0;
}

#define IS_NUM(c) ((c) >= '0' && (c) <= '9')
#define IS_ALPHA(c) (((c) >= 'a' && (c) <= 'z') || ((c) >= 'A' && (c) <= 'Z'))
#define IS_WS(c) ((c) == ' ' || (c) == '\t' || (c) == '\n' || (c) == '\r')
#define IS_STARTNAMECHAR(c) (IS_ALPHA(c) || (c) == '_' || (c) == ':')
#define IS_NAMECHAR(c) (IS_STARTNAMECHAR(c) || IS_NUM(c) || (c) == '-' || (c) == '.')

static int skip_string(const char **begin, const char *end, const char *s)
{
    const char *it = *begin;
    while (it < end && *s && *it == *s) {
        ++s;
        ++it;
    }
    if (*s == '\0') {
        *begin = it;
        return 1;
    }
    return 0;
}

static const char *string_find(const char *it, const char *end, const char *s)
{
    while (it < end) {
        const char *begin = it;
        if (skip_string(&it, end, s))
            return begin;
        ++it;
    }
    return NULL;
}

static void skip_ws(const char **begin, const char *end)
{
    const char *it = *begin;
    while (it < end && IS_WS(*it))
        ++it;
    *begin = it;
}

static const char *rtrim(const char *begin, const char *end)
{
    while (end > begin && IS_WS(end[-1]))
        --end;
    return end;
}

static int grow(zsg_scan *s)
{
    size_t cap = s->cap ? s->cap * 2 : 64;
    int *parent = realloc(s->parent, cap * sizeof *parent);
    if (parent == NULL)
        return 0;
    s->parent = parent;
    unsigned char *tag = realloc(s->tag, cap);
    if (tag == NULL)
        return 0;
    s->tag = tag;
    size_t *n_text_in = realloc(s->n_text_in, cap * sizeof *n_text_in);
    if (n_text_in == NULL)
        return 0;
    s->n_text_in = n_text_in;
    size_t *id_off = realloc(s->id_off, cap * sizeof *id_off);
    if (id_off == NULL)
        return 0;
    s->id_off = id_off;
    size_t *id_len = realloc(s->id_len, cap * sizeof *id_len);
    if (id_len == NULL)
        return 0;
    s->id_len = id_len;
    s->cap = cap;
    return 1;
}

static int add_attr(zsg_scan *s, size_t elem, int name, size_t off, size_t len)
{
    if (s->n_attr == s->attr_cap) {
        size_t cap = s->attr_cap ? s->attr_cap * 2 : 64;
        zsg_attr *a = realloc(s->attrs, cap * sizeof *a);
        if (a == NULL)
            return 0;
        s->attrs = a;
        s->attr_cap = cap;
    }
    zsg_attr *a = &s->attrs[s->n_attr++];
    a->elem = elem;
    a->name = name;
    a->off = off;
    a->len = len;
    return 1;
}

/* plutosvg's parse_attributes(). Records the id, and the attributes of
 * attr_names, when `entry` is not -1. Returns 0 on a syntax error, -1 when
 * recording ran out of memory. */
static int parse_attributes(const char **begin, const char *end,
                            const char *base, zsg_scan *s, long entry)
{
    const char *it = *begin;
    while (it < end && IS_STARTNAMECHAR(*it)) {
        const char *name = it++;
        while (it < end && IS_NAMECHAR(*it))
            ++it;
        size_t name_len = (size_t) (it - name);
        skip_ws(&it, end);
        if (it >= end || *it != '=')
            return 0;
        ++it;
        skip_ws(&it, end);
        if (it >= end || (*it != '"' && *it != '\''))
            return 0;
        const char quote = *it++;
        skip_ws(&it, end);
        const char *value = it;
        while (it < end && *it != quote)
            ++it;
        if (it >= end || *it != quote)
            return 0;
        if (entry >= 0) {
            size_t off = (size_t) (value - base);
            size_t len = (size_t) (rtrim(value, it) - value);
            int attr;
            /* plutosvg's id cache keeps the last id an element gives. */
            if (name_len == 2 && name[0] == 'i' && name[1] == 'd') {
                s->id_off[entry] = off;
                s->id_len[entry] = len;
            } else if ((attr = attr_id(name, name_len)) != 0) {
                if (!add_attr(s, (size_t) entry, attr, off, len))
                    return -1;
            }
        }
        ++it;
        skip_ws(&it, end);
    }
    *begin = it;
    return 1;
}

#define FAIL(st, at)                                                       \
    do {                                                                   \
        s->status = (st);                                                  \
        s->offset = (size_t) ((at) - data);                                \
        return s->status;                                                  \
    } while (0)

zsg_status zsg_scan_run(const char *data, size_t n, const zsg_limits *limits,
                        zsg_scan *s)
{
    memset(s, 0, sizeof *s);
    s->status = ZSG_OK;

    /* GUARD: max_size */
    if ((double) n > limits->max_size)
        FAIL(ZSG_ERR_SIZE, data + (size_t) limits->max_size);
    /* plutosvg takes the length as an int. */
    if (n > 2147483647u)
        FAIL(ZSG_ERR_SIZE, data);

    /* zuf_utf8_valid() reports no position: the offset is unknown. */
    if (!zuf_utf8_valid(data, n)) {
        s->status = ZSG_ERR_ENCODING;
        s->offset = ZSG_NO_OFFSET;
        return s->status;
    }
    const char *nul = memchr(data, '\0', n);
    if (nul != NULL)
        FAIL(ZSG_ERR_ENCODING, nul);

    const char *it = data;
    const char *end = data + n;
    if (n >= 3 && (unsigned char) it[0] == 0xEF &&
        (unsigned char) it[1] == 0xBB && (unsigned char) it[2] == 0xBF)
        it += 3;

    long current = -1;  /* open built element, or -1 */
    size_t open = 0;    /* open built elements */
    size_t ignoring = 0;
    int have_root = 0;

    while (it < end) {
        if (current < 0) {
            skip_ws(&it, end);
            if (it >= end)
                break;
        } else {
            while (it < end && *it != '<')
                ++it;
        }

        const char *tag_start = it;
        if (it >= end || *it != '<')
            FAIL(ZSG_ERR_SYNTAX, it);
        ++it;

        if (it < end && *it == '?') {
            ++it;
            if (!skip_string(&it, end, "xml"))
                FAIL(ZSG_ERR_SYNTAX, tag_start);
            skip_ws(&it, end);
            if (!parse_attributes(&it, end, data, s, -1))
                FAIL(ZSG_ERR_SYNTAX, tag_start);
            if (!skip_string(&it, end, "?>"))
                FAIL(ZSG_ERR_SYNTAX, tag_start);
            skip_ws(&it, end);
            continue;
        }

        if (it < end && *it == '!') {
            ++it;
            if (skip_string(&it, end, "--")) {
                const char *close = string_find(it, end, "-->");
                if (close == NULL)
                    FAIL(ZSG_ERR_SYNTAX, tag_start);
                it = close + 3;
                skip_ws(&it, end);
                continue;
            }
            if (skip_string(&it, end, "[CDATA[")) {
                const char *close = string_find(it, end, "]]>");
                if (close == NULL)
                    FAIL(ZSG_ERR_SYNTAX, tag_start);
                it = close + 3;
                skip_ws(&it, end);
                continue;
            }
            if (skip_string(&it, end, "DOCTYPE")) {
                while (it < end && *it != '>') {
                    if (*it == '[') {
                        ++it;
                        int depth = 1;
                        while (it < end && depth > 0) {
                            if (*it == '[')
                                ++depth;
                            else if (*it == ']')
                                --depth;
                            ++it;
                        }
                    } else {
                        ++it;
                    }
                }
                if (it >= end || *it != '>')
                    FAIL(ZSG_ERR_SYNTAX, tag_start);
                ++it;
                skip_ws(&it, end);
                continue;
            }
            FAIL(ZSG_ERR_SYNTAX, tag_start);
        }

        if (it < end && *it == '/') {
            if (current < 0 && ignoring == 0)
                FAIL(ZSG_ERR_SYNTAX, tag_start);
            ++it;
            if (it >= end || !IS_STARTNAMECHAR(*it))
                FAIL(ZSG_ERR_SYNTAX, tag_start);
            const char *name = it++;
            while (it < end && IS_NAMECHAR(*it))
                ++it;
            if (ignoring == 0) {
                if (tag_id(name, (size_t) (it - name)) != s->tag[current])
                    FAIL(ZSG_ERR_SYNTAX, tag_start);
                current = s->parent[current];
                --open;
            } else {
                --ignoring;
            }
            skip_ws(&it, end);
            if (it >= end || *it != '>')
                FAIL(ZSG_ERR_SYNTAX, tag_start);
            ++it;
            continue;
        }

        /* A start tag. */
        if (it >= end || !IS_STARTNAMECHAR(*it))
            FAIL(ZSG_ERR_SYNTAX, tag_start);
        const char *name = it++;
        while (it < end && IS_NAMECHAR(*it))
            ++it;
        size_t name_len = (size_t) (it - name);

        s->start_tags++;
        /* GUARD: max_elements */
        if ((double) s->start_tags > limits->max_elements)
            FAIL(ZSG_ERR_ELEMENTS, tag_start);
        /* The element's nesting level: the root is 1. */
        /* GUARD: max_depth */
        if ((double) (open + ignoring + 1) > limits->max_depth)
            FAIL(ZSG_ERR_DEPTH, tag_start);

        if (name_len == 4 && memcmp(name, "text", 4) == 0) {
            s->n_text++;
            for (long e = current; e >= 0; e = s->parent[e])
                s->n_text_in[e]++;
        }

        long entry = -1;
        if (ignoring > 0) {
            ++ignoring;
        } else {
            int id = tag_id(name, name_len);
            if (id == 0) {
                ignoring = 1;
            } else {
                if (id == TAG_IMAGE) {
                    s->n_image++;
                    /* GUARD: images */
                    if (!limits->images)
                        FAIL(ZSG_ERR_IMAGE, tag_start);
                }
                if (have_root && current < 0)
                    FAIL(ZSG_ERR_SYNTAX, tag_start);
                if (!have_root && id != TAG_SVG)
                    FAIL(ZSG_ERR_SYNTAX, tag_start);
                have_root = 1;
                if (s->n == s->cap && !grow(s))
                    FAIL(ZSG_ERR_NOMEM, tag_start);
                entry = (long) s->n++;
                s->parent[entry] = (int) current;
                s->tag[entry] = (unsigned char) id;
                s->n_text_in[entry] = 0;
                s->id_off[entry] = 0;
                s->id_len[entry] = (size_t) -1;
            }
        }

        skip_ws(&it, end);
        int parsed = parse_attributes(&it, end, data, s, entry);
        if (parsed < 0)
            FAIL(ZSG_ERR_NOMEM, tag_start);
        if (parsed == 0)
            FAIL(ZSG_ERR_SYNTAX, tag_start);
        if (it < end && *it == '>') {
            if (entry >= 0) {
                current = entry;
                ++open;
            }
            ++it;
            continue;
        }
        if (it < end && *it == '/') {
            ++it;
            if (it >= end || *it != '>')
                FAIL(ZSG_ERR_SYNTAX, tag_start);
            if (ignoring > 0)
                --ignoring;
            ++it;
            continue;
        }
        FAIL(ZSG_ERR_SYNTAX, tag_start);
    }

    if (ignoring != 0 || current >= 0 || !have_root)
        FAIL(ZSG_ERR_SYNTAX, end);
    return ZSG_OK;
}

void zsg_scan_free(zsg_scan *s)
{
    free(s->parent);
    free(s->tag);
    free(s->n_text_in);
    free(s->attrs);
    free(s->id_off);
    free(s->id_len);
    s->parent = NULL;
    s->tag = NULL;
    s->n_text_in = NULL;
    s->attrs = NULL;
    s->n_attr = s->attr_cap = 0;
    s->id_off = NULL;
    s->id_len = NULL;
    s->n = s->cap = 0;
}
